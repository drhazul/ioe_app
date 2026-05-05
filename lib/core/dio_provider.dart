import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'auth/auth_controller.dart';
import 'env.dart';

export 'storage.dart' show storageProvider;

final apiConnectivityAlertProvider = StateProvider<String?>((ref) => null);
final apiOfflineModeProvider = StateProvider<bool>((ref) => false);

String _compactErrorBody(dynamic value, {int max = 800}) {
  if (value == null) return '-';
  final text = value is String ? value : value.toString();
  if (text.length <= max) return text;
  return '${text.substring(0, max)}...';
}

final dioProvider = Provider<Dio>((ref) {
  final authController = ref.read(authControllerProvider.notifier);
  Timer? healthRetryTimer;
  var healthFailures = 0;
  var healthProbeRunning = false;

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      // En Web, dio_web_adapter usa este timeout para la request completa.
      // Algunos procesos (ej. apply-adjustment) pueden tardar >30s aunque se completen correctamente.
      connectTimeout: kIsWeb
          ? const Duration(minutes: 5)
          : const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Duration nextHealthDelay() {
    final seconds = switch (healthFailures) {
      <= 0 => 1,
      1 => 1,
      2 => 2,
      3 => 4,
      4 => 8,
      _ => 16,
    };
    return Duration(seconds: seconds);
  }

  Future<void> runHealthProbe() async {
    if (healthProbeRunning) return;
    healthProbeRunning = true;
    try {
      await dio.get(
        '/health',
        options: Options(
          extra: {'__connectivity_probe': true},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      healthFailures = 0;
      healthRetryTimer?.cancel();
      healthRetryTimer = null;
      ref.read(apiOfflineModeProvider.notifier).state = false;
      ref.read(apiConnectivityAlertProvider.notifier).state = null;
    } on DioException {
      healthFailures += 1;
      healthRetryTimer?.cancel();
      healthRetryTimer = Timer(nextHealthDelay(), () {
        runHealthProbe();
      });
    } finally {
      healthProbeRunning = false;
    }
  }

  void scheduleHealthProbe() {
    if (healthProbeRunning || (healthRetryTimer?.isActive ?? false)) return;
    healthRetryTimer = Timer(nextHealthDelay(), () {
      runHealthProbe();
    });
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.data is! FormData) {
          options.contentType = Headers.jsonContentType;
          options.headers['Content-Type'] = Headers.jsonContentType;
        }

        final isProbe = options.extra['__connectivity_probe'] == true;
        if (_isPublicCall(options.path) || isProbe) {
          return handler.next(options);
        }

        authController.protectedRequestStarted();
        options.extra['__tracked_protected_request'] = true;

        final token = await authController.ensureValidAccessToken();
        if (token == null || token.isEmpty) {
          _finishTrackedProtectedRequest(options, authController);
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'AUTH_REQUIRED',
              message: 'No hay sesión activa para la solicitud protegida.',
            ),
          );
        }
        options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onResponse: (response, handler) {
        healthFailures = 0;
        healthRetryTimer?.cancel();
        healthRetryTimer = null;
        ref.read(apiOfflineModeProvider.notifier).state = false;
        ref.read(apiConnectivityAlertProvider.notifier).state = null;
        _finishTrackedProtectedRequest(response.requestOptions, authController);
        handler.next(response);
      },
      onError: (err, handler) async {
        _finishTrackedProtectedRequest(err.requestOptions, authController);
        if (_isConnectivityError(err)) {
          ref.read(apiOfflineModeProvider.notifier).state = true;
          ref.read(apiConnectivityAlertProvider.notifier).state =
              'Offline Mode: sin conexión con API (${Env.apiBaseUrl}). Recuperando...';
          scheduleHealthProbe();
        }

        // Log network/connection errors to help debugging (prints visible in console)
        // err is a DioException on modern dio versions
        if (!_isExpectedAuthRequiredCancel(err)) {
          try {
            final method = err.requestOptions.method;
            final status = err.response?.statusCode;
            final body = _compactErrorBody(err.response?.data);
            // ignore: avoid_print
            print(
              'Dio onError: type=${err.type} method=$method status=$status '
              'uri=${err.requestOptions.uri} error=${err.error} body=$body',
            );
          } catch (_) {}
        }

        // Intento de refresh token en 401 (excepto si ya se intentó o es /auth/refresh)
        final status = err.response?.statusCode;
        final isAuthCall = _isPublicCall(err.requestOptions.path);
        final alreadyRetried = err.requestOptions.extra['__retried'] == true;
        if (status == 401 &&
            !isAuthCall &&
            !alreadyRetried &&
            !_isBusinessUnauthorizedPath(err.requestOptions.path)) {
          final newAccess = await authController.ensureValidAccessToken(
            forceRefresh: true,
          );
          if (newAccess != null && newAccess.isNotEmpty) {
            // Reintenta la llamada original con el nuevo token
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccess';
            opts.extra['__retried'] = true;
            final clone = await dio.fetch(opts);
            return handler.resolve(clone);
          }
        }
        handler.next(err);
      },
    ),
  );

  ref.onDispose(() {
    healthRetryTimer?.cancel();
    healthRetryTimer = null;
  });

  return dio;
});

bool _isConnectivityError(DioException err) {
  if (err.response != null) return false;
  return err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.unknown;
}

bool _isPublicCall(String path) {
  final normalized = path.toLowerCase();
  return normalized.contains('/auth/login') ||
      normalized.contains('/auth/refresh') ||
      normalized.contains('/health');
}

bool _isBusinessUnauthorizedPath(String path) {
  final normalized = path.toLowerCase();
  // These endpoints may intentionally return 401 for business authorization
  // (not auth token expiry), so do not trigger token refresh/retry.
  return normalized.contains('/pv/devoluciones/crear');
}

bool _isExpectedAuthRequiredCancel(DioException err) {
  return err.type == DioExceptionType.cancel && err.error == 'AUTH_REQUIRED';
}

void _finishTrackedProtectedRequest(
  RequestOptions options,
  AuthController authController,
) {
  final tracked = options.extra['__tracked_protected_request'] == true;
  if (!tracked) return;

  options.extra['__tracked_protected_request'] = false;
  authController.protectedRequestFinished();
}

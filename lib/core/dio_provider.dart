import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth/auth_controller.dart';
import 'env.dart';

export 'storage.dart' show storageProvider;

String _compactErrorBody(dynamic value, {int max = 800}) {
  if (value == null) return '-';
  final text = value is String ? value : value.toString();
  if (text.length <= max) return text;
  return '${text.substring(0, max)}...';
}

final dioProvider = Provider<Dio>((ref) {
  final authController = ref.read(authControllerProvider.notifier);

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

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_isAuthCall(options.path)) {
          return handler.next(options);
        }

        authController.protectedRequestStarted();
        options.extra['__tracked_protected_request'] = true;

        final token = await authController.ensureValidAccessToken();
        if (token == null || token.isEmpty) {
          options.headers.remove('Authorization');
        } else {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        _finishTrackedProtectedRequest(response.requestOptions, authController);
        handler.next(response);
      },
      onError: (err, handler) async {
        _finishTrackedProtectedRequest(err.requestOptions, authController);

        // Log network/connection errors to help debugging (prints visible in console)
        // err is a DioException on modern dio versions
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

        // Intento de refresh token en 401 (excepto si ya se intentó o es /auth/refresh)
        final status = err.response?.statusCode;
        final isAuthCall = _isAuthCall(err.requestOptions.path);
        final alreadyRetried = err.requestOptions.extra['__retried'] == true;
        if (status == 401 && !isAuthCall && !alreadyRetried) {
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

  return dio;
});

bool _isAuthCall(String path) {
  final normalized = path.toLowerCase();
  return normalized.contains('/auth/login') ||
      normalized.contains('/auth/refresh');
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

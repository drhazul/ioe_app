import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'env.dart';
import 'storage.dart';

final storageProvider = Provider<Storage>((ref) => Storage());

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(storageProvider);

  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (err, handler) async {
      // Log network/connection errors to help debugging (prints visible in console)
      // err is a DioException on modern dio versions
      try {
        // ignore: avoid_print
        print('Dio onError: type=${err.type} uri=${err.requestOptions.uri} error=${err.error}');
      } catch (_) {}

      // Intento de refresh token en 401 (excepto si ya se intentó o es /auth/refresh)
      final status = err.response?.statusCode;
      final isRefreshCall = err.requestOptions.path.contains('/auth/refresh');
      final alreadyRetried = err.requestOptions.extra['__retried'] == true;
      if (status == 401 && !isRefreshCall && !alreadyRetried) {
        final refresh = await storage.getRefreshToken();
        if (refresh != null && refresh.isNotEmpty) {
          try {
            final refreshClient = Dio(BaseOptions(
              baseUrl: Env.apiBaseUrl,
              headers: {'Content-Type': 'application/json'},
            ));
            final res = await refreshClient.post('/auth/refresh', data: {'refreshToken': refresh});
            final newAccess = res.data['accessToken'] as String;
            final newRefresh = res.data['refreshToken'] as String;
            await storage.saveTokens(access: newAccess, refresh: newRefresh);

            // Reintenta la llamada original con el nuevo token
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccess';
            opts.extra['__retried'] = true;
            final clone = await dio.fetch(opts);
            return handler.resolve(clone);
          } catch (_) {
            await storage.clear();
          }
        } else {
          await storage.clear();
        }
      }
      handler.next(err);
    },
  ));

  return dio;
});

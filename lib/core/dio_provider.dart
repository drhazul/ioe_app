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
    onError: (err, handler) {
      // Log network/connection errors to help debugging (prints visible in console)
      // err is a DioException on modern dio versions
      try {
        // ignore: avoid_print
        print('Dio onError: type=${err.type} uri=${err.requestOptions.uri} error=${err.error}');
      } catch (_) {}
      handler.next(err);
    },
  ));

  return dio;
});

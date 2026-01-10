import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../dio_provider.dart';
import '../api_error.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;
  final StreamController<AuthState> _controller = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get stream => _controller.stream;

  AuthController(this.ref) : super(AuthState.initial()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      final payload = _decodeJwt(token);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userId: _asInt(payload['sub']),
        username: payload['username'] as String?,
        roleId: _asInt(payload['roleId']),
      );
    } else {
      state = state.copyWith(isLoading: false, isAuthenticated: false, userId: null, username: null, roleId: null);
    }
    _controller.add(state);
  }

  Future<void> login({required String username, required String password}) async {
    final dio = ref.read(dioProvider);
    final storage = ref.read(storageProvider);

    try {
      final res = await dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

      final status = res.statusCode;
      if (status != 200 && status != 201) {
        throw Exception('Respuesta inesperada del servidor');
      }

      final access = res.data['accessToken'] as String;
      final refresh = res.data['refreshToken'] as String;

      await storage.saveTokens(access: access, refresh: refresh);
      final payload = _decodeJwt(access);
      state = state.copyWith(
        isAuthenticated: true,
        userId: _asInt(payload['sub']),
        username: payload['username'] as String?,
        roleId: _asInt(payload['roleId']),
      );
      _controller.add(state);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        throw Exception('Usuario o contraseña incorrectos');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception('No se pudo conectar con el servidor');
      }
      final msg = apiErrorMessage(e, fallback: 'No se pudo iniciar sesión');
      throw Exception(msg);
    }
  }

  Future<void> logout() async {
    await ref.read(storageProvider).clear();
    state = state.copyWith(isAuthenticated: false, userId: null, username: null, roleId: null);
    _controller.add(state);
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return Map<String, dynamic>.from(json.decode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

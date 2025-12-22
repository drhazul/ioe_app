import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../dio_provider.dart';
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
    state = state.copyWith(isLoading: false, isAuthenticated: token != null && token.isNotEmpty);
    _controller.add(state);
  }

  Future<void> login({required String username, required String password}) async {
    final dio = ref.read(dioProvider);
    final storage = ref.read(storageProvider);

    try {
      final res = await dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      final access = res.data['accessToken'] as String;
      final refresh = res.data['refreshToken'] as String;

      await storage.saveTokens(access: access, refresh: refresh);
      state = state.copyWith(isAuthenticated: true);
      _controller.add(state);
    } on DioException catch (e) {
      // Provide a clearer message for connection errors
      final msg = StringBuffer();
      msg.write('Network error: ${e.type} - ${e.message}.');
      msg.write('\nPossible causes: server down, wrong API URL, emulator network, or CORS (when running on web).');
      throw Exception(msg.toString());
    }
  }

  Future<void> logout() async {
    await ref.read(storageProvider).clear();
    state = state.copyWith(isAuthenticated: false);
    _controller.add(state);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

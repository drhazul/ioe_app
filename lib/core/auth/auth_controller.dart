import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_error.dart';
import '../env.dart';
import '../storage.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref);
  },
);

class AuthController extends StateNotifier<AuthState> {
  static const _jwtExpiryLeeway = Duration(seconds: 30);
  static const _proactiveRefreshBeforeExpiry = Duration(minutes: 2);
  static const _idleTimeout = Duration(minutes: 15);
  static const _idleCheckWhileBusy = Duration(seconds: 30);
  static const _activityPersistMinInterval = Duration(seconds: 15);

  final Ref ref;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  Future<String?>? _refreshInFlight;
  Timer? _refreshTimer;
  Timer? _idleTimer;
  String? _activeAccessToken;
  int _inFlightProtectedRequests = 0;
  DateTime? _lastUserActivityAtUtc;
  DateTime? _lastPersistedActivityAtUtc;

  @override
  Stream<AuthState> get stream => _controller.stream;

  AuthController(this.ref) : super(AuthState.initial()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storage = ref.read(storageProvider);
    final persistedLastActivity = await storage.getLastActivityAt();
    if (_isIdleExpired(persistedLastActivity)) {
      await storage.clear();
      _setUnauthenticated();
      return;
    }

    _lastUserActivityAtUtc = persistedLastActivity;
    _lastPersistedActivityAtUtc = persistedLastActivity;

    await ensureValidAccessToken();

    if (state.isAuthenticated) {
      if (_lastUserActivityAtUtc == null) {
        registerUserActivity();
      } else {
        _scheduleIdleCheck();
      }
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final dio = _authClient();
    final storage = ref.read(storageProvider);

    try {
      final res = await dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
        options: Options(
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw Exception('Respuesta inesperada del servidor');
      }

      final access = _readTokenValue(res.data, 'accessToken');
      final refresh = _readTokenValue(res.data, 'refreshToken');
      if (access == null || refresh == null) {
        throw Exception('Respuesta de autenticación inválida');
      }

      await storage.saveTokens(access: access, refresh: refresh);
      _setAuthenticatedFromToken(access);
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

  Future<String?> ensureValidAccessToken({bool forceRefresh = false}) async {
    final storage = ref.read(storageProvider);
    final access = await storage.getAccessToken();

    if (!forceRefresh && _isAccessTokenUsable(access)) {
      _setAuthenticatedFromToken(access!);
      return access;
    }

    final refreshedAccess = await _refreshAccessToken();
    if (_isAccessTokenUsable(refreshedAccess)) {
      _setAuthenticatedFromToken(refreshedAccess!);
      return refreshedAccess;
    }

    await storage.clear();
    _setUnauthenticated();
    return null;
  }

  void registerUserActivity() {
    if (!state.isAuthenticated) return;

    final now = DateTime.now().toUtc();
    _lastUserActivityAtUtc = now;
    _scheduleIdleCheck();

    final canPersist =
        _lastPersistedActivityAtUtc == null ||
        now.difference(_lastPersistedActivityAtUtc!) >=
            _activityPersistMinInterval;
    if (!canPersist) return;

    _lastPersistedActivityAtUtc = now;
    unawaited(ref.read(storageProvider).saveLastActivityAt(now));
  }

  void protectedRequestStarted() {
    _inFlightProtectedRequests += 1;
  }

  void protectedRequestFinished() {
    if (_inFlightProtectedRequests > 0) {
      _inFlightProtectedRequests -= 1;
    }
  }

  Future<void> logout() async {
    await ref.read(storageProvider).clear();
    _setUnauthenticated();
  }

  Future<String?> _refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final future = _runRefreshAccessToken();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<String?> _runRefreshAccessToken() async {
    final storage = ref.read(storageProvider);
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final res = await _authClient().post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          validateStatus: (status) =>
              status != null && status >= 200 && status < 500,
        ),
      );

      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) return null;

      final newAccess = _readTokenValue(res.data, 'accessToken');
      final newRefresh = _readTokenValue(res.data, 'refreshToken');
      if (newAccess == null || newRefresh == null) return null;

      await storage.saveTokens(access: newAccess, refresh: newRefresh);
      return newAccess;
    } on DioException {
      return null;
    }
  }

  Dio _authClient() {
    return Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  String? _readTokenValue(dynamic data, String key) {
    if (data is! Map) return null;
    final value = data[key];
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  bool _isAccessTokenUsable(String? token) {
    if (token == null || token.isEmpty) return false;
    return !_isJwtExpired(token);
  }

  bool _isJwtExpired(String token) {
    final payload = _decodeJwt(token);
    final exp = _asInt(payload['exp']);
    if (exp == null) {
      // Si no trae claim exp, no se puede validar localmente; dejamos que el backend responda 401.
      return false;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    final nowWithLeeway = DateTime.now().toUtc().add(_jwtExpiryLeeway);
    return nowWithLeeway.isAfter(expiresAt);
  }

  DateTime? _readJwtExpiry(String token) {
    final payload = _decodeJwt(token);
    final exp = _asInt(payload['exp']);
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  void _setAuthenticatedFromToken(String token) {
    _activeAccessToken = token;
    _scheduleProactiveRefresh(token);
    _ensureActivityTimestamp();
    _scheduleIdleCheck();

    final payload = _decodeJwt(token);
    _setState(
      AuthState(
        isLoading: false,
        isAuthenticated: true,
        userId: _asInt(payload['sub']),
        username: payload['username'] as String?,
        roleId: _asInt(payload['roleId']),
      ),
    );
  }

  void _setUnauthenticated() {
    _clearRuntimeSessionState();
    _setState(
      const AuthState(
        isLoading: false,
        isAuthenticated: false,
        userId: null,
        username: null,
        roleId: null,
      ),
    );
  }

  void _setState(AuthState next) {
    final current = state;
    final unchanged =
        current.isLoading == next.isLoading &&
        current.isAuthenticated == next.isAuthenticated &&
        current.userId == next.userId &&
        current.username == next.username &&
        current.roleId == next.roleId;
    if (unchanged) return;

    state = next;
    _controller.add(state);
  }

  void _scheduleProactiveRefresh(String token) {
    _refreshTimer?.cancel();
    final expiresAt = _readJwtExpiry(token);
    if (expiresAt == null) return;

    final target = expiresAt.subtract(_proactiveRefreshBeforeExpiry);
    var delay = target.difference(DateTime.now().toUtc());
    if (delay <= Duration.zero) {
      delay = const Duration(seconds: 5);
    }

    _refreshTimer = Timer(delay, () async {
      if (!state.isAuthenticated) return;

      final currentToken = _activeAccessToken;
      if (currentToken == null || currentToken != token) return;

      await ensureValidAccessToken(forceRefresh: true);
    });
  }

  void _scheduleIdleCheck() {
    _idleTimer?.cancel();
    if (!state.isAuthenticated) return;

    final now = DateTime.now().toUtc();
    final lastActivity = _lastUserActivityAtUtc ?? now;
    final idle = now.difference(lastActivity);

    if (idle >= _idleTimeout) {
      _handleIdleTimeout();
      return;
    }

    _idleTimer = Timer(_idleTimeout - idle, _handleIdleTimeout);
  }

  Future<void> _handleIdleTimeout() async {
    if (!state.isAuthenticated) return;

    final now = DateTime.now().toUtc();
    final lastActivity = _lastUserActivityAtUtc ?? now;
    final idle = now.difference(lastActivity);

    if (idle < _idleTimeout) {
      _scheduleIdleCheck();
      return;
    }

    if (_inFlightProtectedRequests > 0) {
      _idleTimer = Timer(_idleCheckWhileBusy, _handleIdleTimeout);
      return;
    }

    await logout();
  }

  bool _isIdleExpired(DateTime? lastActivityUtc) {
    if (lastActivityUtc == null) return false;
    final now = DateTime.now().toUtc();
    return now.difference(lastActivityUtc) >= _idleTimeout;
  }

  void _ensureActivityTimestamp() {
    if (_lastUserActivityAtUtc != null) return;
    final now = DateTime.now().toUtc();
    _lastUserActivityAtUtc = now;
    _lastPersistedActivityAtUtc = now;
    unawaited(ref.read(storageProvider).saveLastActivityAt(now));
  }

  void _clearRuntimeSessionState() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    _activeAccessToken = null;
    _inFlightProtectedRequests = 0;
    _lastUserActivityAtUtc = null;
    _lastPersistedActivityAtUtc = null;
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
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
    _clearRuntimeSessionState();
    _controller.close();
    super.dispose();
  }
}

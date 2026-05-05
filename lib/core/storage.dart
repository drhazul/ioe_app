import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storageProvider = Provider<Storage>((ref) => Storage());

class Storage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kLastActivityEpochMs = 'last_activity_epoch_ms';
  static const _kSessionToken = 'session_token_cached';
  static const _kSessionUserJson = 'session_user_json_cached';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, access);
    await sp.setString(_kRefresh, refresh);
  }

  Future<String?> getAccessToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAccess);
  }

  Future<String?> getRefreshToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kRefresh);
  }

  Future<void> saveLastActivityAt(DateTime atUtc) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(
      _kLastActivityEpochMs,
      atUtc.toUtc().millisecondsSinceEpoch,
    );
  }

  Future<DateTime?> getLastActivityAt() async {
    final sp = await SharedPreferences.getInstance();
    final millis = sp.getInt(_kLastActivityEpochMs);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> saveSession({
    required String token,
    required String userJson,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSessionToken, token);
    await sp.setString(_kSessionUserJson, userJson);
  }

  Future<String?> getSessionToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kSessionToken);
  }

  Future<String?> getSessionUserJson() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kSessionUserJson);
  }

  Future<void> clearAuthTokens() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
    await sp.remove(_kLastActivityEpochMs);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }
}

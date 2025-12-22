import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<void> saveTokens({required String access, required String refresh}) async {
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

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
  }
}

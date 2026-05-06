import 'package:flutter/foundation.dart'
    show kIsWeb, kReleaseMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Desarrollo local (web/desktop): API local levantada desde ioe-api.
  static const String _devBaseUrl = 'http://127.0.0.1:3001';
  // Android emulator usa 10.0.2.2 para alcanzar localhost del host.
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:3001';
  static String get apiBaseUrl {
    if (!kReleaseMode) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return _androidEmulatorBaseUrl;
      }
      return _devBaseUrl;
    }

    if (kIsWeb) {
      final fromDefine = const String.fromEnvironment('API_BASE_URL_WEB');
      if (fromDefine.isNotEmpty) {
        return fromDefine;
      }

      final fromEnv = dotenv.env['API_BASE_URL_WEB'];
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv;
      }

      // Flutter Web -> usar proxy de Nginx
      return '/api';
    }

    // 1) Si viene desde .env (override explícito)
    final fromDefine = const String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }

    final fromEnv = dotenv.env['API_BASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }

    // 2) Mobile emulator (Android)
    return 'http://192.168.10.234:3001';
  }

  static String get attendanceHmacSecret {
    const fromDefine = String.fromEnvironment('ATTENDANCE_HMAC_SECRET');
    if (fromDefine.isNotEmpty) return fromDefine;

    final fromEnv = dotenv.env['ATTENDANCE_HMAC_SECRET'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    return 'ATTENDANCE_DEV_SECRET_CHANGE_ME';
  }

  static String get rrhhSecret {
    const fromDefine = String.fromEnvironment('RRHH_SECRET');
    if (fromDefine.isNotEmpty) return fromDefine;

    final fromEnv = dotenv.env['RRHH_SECRET'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    return 'RRHH_SECRET';
  }
}

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static const String _devBaseUrl = 'http://localhost:3001';

  static String get apiBaseUrl {
    if (!kReleaseMode) {
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
}

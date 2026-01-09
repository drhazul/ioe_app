import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl {
    // 1) Si viene desde .env (override explícito)
    final fromEnv = dotenv.env['API_BASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }

    // 2) Flutter Web → usar proxy de Nginx
    if (kIsWeb) {
      return '/api';
    }

    // 3) Mobile emulator (Android)
    return 'http://10.0.2.2:3001';
  }
}

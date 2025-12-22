import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Prefer explicit `API_BASE_URL` in assets/.env. If missing, choose a
  // sensible default for common dev environments:
  // - web: http://localhost:3001 (assumes backend allows CORS)
  // - mobile emulator: http://10.0.2.2:3001 (Android emulator -> host machine)
  static String get apiBaseUrl {
    final fromEnv = dotenv.env['API_BASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:3001';
    return 'http://10.0.2.2:3001';
  }
}

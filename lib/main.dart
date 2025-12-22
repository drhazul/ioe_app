import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'core/router.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');

  // Health check to validate backend connectivity early and provide
  // actionable console messages for common failures (CORS, wrong host, etc.).
  await _checkBackendHealth();

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _checkBackendHealth() async {
  final dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl, connectTimeout: const Duration(seconds: 5)));
  try {
    final res = await dio.get('/health');
    // ignore: avoid_print
    print('Backend health OK (${Env.apiBaseUrl}/health) -> status: ${res.statusCode}');
  } on DioException catch (e) {
    // Provide helpful hint messages for debugging common issues.
    // ignore: avoid_print
    print('Backend health check FAILED for ${Env.apiBaseUrl}/health');
    // ignore: avoid_print
    print('DioException: type=${e.type} message=${e.message}');

    if (kIsWeb) {
      // On web, this is commonly CORS or the server not reachable.
      // ignore: avoid_print
      print('If you run the app on Web, this error is often caused by CORS.');
      // ignore: avoid_print
      print('Enable CORS in your backend (see project instructions).');
    } else {
      // On mobile emulators, localhost is different.
      // ignore: avoid_print
      print('If running on Android emulator, ensure backend uses 10.0.2.2 as host or use device IP.');
    }
  } catch (e) {
    // ignore: avoid_print
    print('Unexpected error during backend health check: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'IOE',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(useMaterial3: true),
    );
  }
}

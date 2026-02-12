import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

import 'core/auth/auth_controller.dart';
import 'core/router.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En debug no usamos .env para apiBaseUrl (Env devuelve localhost), y en web
  // evita warnings de AssetManifest.json cuando el manifest no está disponible.
  if (kReleaseMode) {
    await dotenv.load(fileName: 'assets/.env');
  }

  // Health check to validate backend connectivity early and provide
  // actionable console messages for common failures (CORS, wrong host, etc.).
  await _checkBackendHealth();

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _checkBackendHealth() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
    ),
  );
  try {
    final res = await dio.get('/health');
    // ignore: avoid_print
    print(
      'Backend health OK (${Env.apiBaseUrl}/health) -> status: ${res.statusCode}',
    );
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
      print(
        'If running on Android emulator, ensure backend uses 10.0.2.2 as host or use device IP.',
      );
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
    final authController = ref.read(authControllerProvider.notifier);
    const appFontSize = 11.0;
    final baseTheme = ThemeData(useMaterial3: true);
    final textTheme = _fixedFontSizeTextTheme(baseTheme.textTheme, appFontSize);
    const appBarColor = Color(0xFF148D8D);
    final appBarTitleStyle = textTheme.titleLarge?.copyWith(
      color: Colors.white,
    );
    final appBarToolbarStyle = textTheme.bodyMedium?.copyWith(
      color: Colors.white,
    );
    final theme = baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        surfaceTintColor: appBarColor,
        toolbarHeight: 64,
        titleTextStyle: appBarTitleStyle,
        toolbarTextStyle: appBarToolbarStyle,
      ),
      tabBarTheme: baseTheme.tabBarTheme.copyWith(
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        labelStyle: textTheme.bodySmall,
        hintStyle: textTheme.bodySmall,
      ),
      dataTableTheme: DataTableThemeData(
        dataTextStyle: textTheme.bodySmall,
        headingTextStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => authController.registerUserActivity(),
      onPointerSignal: (_) => authController.registerUserActivity(),
      child: MaterialApp.router(
        title: 'IOE',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: theme,
      ),
    );
  }
}

TextTheme _fixedFontSizeTextTheme(TextTheme base, double size) {
  TextStyle? withSize(TextStyle? style) => style?.copyWith(fontSize: size);
  return base.copyWith(
    displayLarge: withSize(base.displayLarge),
    displayMedium: withSize(base.displayMedium),
    displaySmall: withSize(base.displaySmall),
    headlineLarge: withSize(base.headlineLarge),
    headlineMedium: withSize(base.headlineMedium),
    headlineSmall: withSize(base.headlineSmall),
    titleLarge: withSize(base.titleLarge),
    titleMedium: withSize(base.titleMedium),
    titleSmall: withSize(base.titleSmall),
    bodyLarge: withSize(base.bodyLarge),
    bodyMedium: withSize(base.bodyMedium),
    bodySmall: withSize(base.bodySmall),
    labelLarge: withSize(base.labelLarge),
    labelMedium: withSize(base.labelMedium),
    labelSmall: withSize(base.labelSmall),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'core/dio_provider.dart';
import 'core/router.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fuerza inicialización de dioProvider para que el probe /health se dispare
    // desde el arranque y no dependa del ciclo de vida de una pantalla.
    ref.read(dioProvider);

    GoRouterRouterConfigResult routerResult;
    try {
      final router = ref.watch(routerProvider);
      routerResult = GoRouterRouterConfigResult.router(router);
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'main.dart',
          context: ErrorDescription('while building routerProvider'),
        ),
      );
      routerResult = GoRouterRouterConfigResult.error(e.toString());
    }
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

    if (routerResult.hasError) {
      return MaterialApp(
        title: 'IOE',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Text('Error router: ${routerResult.errorMessage}'),
          ),
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => authController.registerUserActivity(),
      onPointerSignal: (_) => authController.registerUserActivity(),
      child: MaterialApp.router(
        title: 'IOE',
        debugShowCheckedModeBanner: false,
        routerConfig: routerResult.router!,
        theme: theme,
      ),
    );
  }
}

class GoRouterRouterConfigResult {
  final GoRouter? router;
  final String? errorMessage;

  const GoRouterRouterConfigResult._({this.router, this.errorMessage});

  factory GoRouterRouterConfigResult.router(GoRouter router) =>
      GoRouterRouterConfigResult._(router: router);

  factory GoRouterRouterConfigResult.error(String message) =>
      GoRouterRouterConfigResult._(errorMessage: message);

  bool get hasError => errorMessage != null;
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

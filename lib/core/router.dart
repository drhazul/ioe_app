import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/login/login_page.dart';
import '../features/home/home_page.dart';
import '../features/masterdata/masterdata_page.dart';
import '../features/masterdata/roles/roles_page.dart';
import '../features/masterdata/deptos/deptos_page.dart';
import '../features/masterdata/users/users_page.dart';

import 'auth/auth_controller.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authControllerProvider.notifier).stream,
    ),
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (auth.isLoading) return null;

      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (auth.isAuthenticated && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(
        path: '/',
        builder: (c, s) => const HomePage(),
        routes: [
          GoRoute(path: 'masterdata', builder: (c, s) => const MasterDataPage(), routes: [
            GoRoute(path: 'roles', builder: (c, s) => const RolesPage()),
            GoRoute(path: 'deptos', builder: (c, s) => const DeptosPage()),
            GoRoute(path: 'users', builder: (c, s) => const UsersPage()),
          ]),
        ],
      ),
    ],
  );
});

/// Helper para refrescar go_router desde Riverpod (stream)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

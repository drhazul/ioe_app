import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/dio_provider.dart';
import 'home_api.dart';
import 'home_models.dart';

final homeApiProvider = Provider<HomeApi>((ref) => HomeApi(ref.read(dioProvider)));

final homeModulesProvider = FutureProvider.autoDispose<HomeModulesResponse>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated) {
    return const HomeModulesResponse(roleId: 0, accesoTotal: false, modulos: []);
  }
  final api = ref.read(homeApiProvider);
  return api.fetchHomeModules();
});

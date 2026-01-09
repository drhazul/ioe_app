import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dio_provider.dart';
import 'home_api.dart';
import 'home_models.dart';

final homeApiProvider = Provider<HomeApi>((ref) => HomeApi(ref.read(dioProvider)));

final homeModulesProvider = FutureProvider.autoDispose<HomeModulesResponse>((ref) async {
  final api = ref.read(homeApiProvider);
  return api.fetchHomeModules();
});

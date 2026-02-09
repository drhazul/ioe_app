import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'access_reg_suc_api.dart';
import 'access_reg_suc_models.dart';

final accessRegSucApiProvider = Provider<AccessRegSucApi>((ref) => AccessRegSucApi(ref.read(dioProvider)));

final accessRegSucListProvider = FutureProvider.autoDispose<List<AccessRegSucModel>>((ref) async {
  final api = ref.read(accessRegSucApiProvider);
  return api.fetchAll();
});

final accessRegSucProvider = FutureProvider.autoDispose.family<AccessRegSucModel, AccessRegSucKey>((ref, key) async {
  final api = ref.read(accessRegSucApiProvider);
  return api.fetchOne(key.modulo, key.usuario, key.suc);
});

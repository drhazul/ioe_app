import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'sucursales_api.dart';
import 'sucursales_models.dart';

final sucursalesApiProvider = Provider<SucursalesApi>(
  (ref) => SucursalesApi(ref.read(dioProvider), ref.read(storageProvider)),
);

final sucursalesListProvider = FutureProvider.autoDispose<List<SucursalModel>>((ref) async {
  final api = ref.read(sucursalesApiProvider);
  return api.fetchSucursales();
});

final sucursalProvider = FutureProvider.autoDispose.family<SucursalModel, String>((ref, suc) async {
  final api = ref.read(sucursalesApiProvider);
  return api.fetchSucursal(suc);
});

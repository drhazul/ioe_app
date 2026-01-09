import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'puestos_api.dart';
import 'puestos_models.dart';

final puestosApiProvider = Provider<PuestosApi>((ref) => PuestosApi(ref.read(dioProvider)));

final puestosListProvider = FutureProvider.autoDispose<List<PuestoModel>>((ref) async {
  final api = ref.read(puestosApiProvider);
  return api.fetchPuestos();
});

final puestoProvider = FutureProvider.autoDispose.family<PuestoModel, int>((ref, id) async {
  final api = ref.read(puestosApiProvider);
  return api.fetchPuesto(id);
});

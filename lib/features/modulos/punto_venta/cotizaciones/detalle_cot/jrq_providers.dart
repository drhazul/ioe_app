import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'jrq_api.dart';
import 'jrq_models.dart';

final jrqApiProvider = Provider<JrqApi>((ref) => JrqApi(ref.read(dioProvider)));

final jrqDepaListProvider = FutureProvider.autoDispose<List<JrqDepaModel>>((ref) async {
  return ref.read(jrqApiProvider).fetchDepa();
});

final jrqSubdListProvider = FutureProvider.autoDispose.family<List<JrqSubdModel>, double?>((ref, depa) async {
  if (depa == null) return [];
  return ref.read(jrqApiProvider).fetchSubd(depa: depa);
});

final jrqClasListProvider = FutureProvider.autoDispose.family<List<JrqClasModel>, double?>((ref, subd) async {
  if (subd == null) return [];
  return ref.read(jrqApiProvider).fetchClas(subd: subd);
});

final jrqSclaListProvider = FutureProvider.autoDispose.family<List<JrqSclaModel>, double?>((ref, clas) async {
  if (clas == null) return [];
  return ref.read(jrqApiProvider).fetchScla(clas: clas);
});

final jrqScla2ListProvider = FutureProvider.autoDispose.family<List<JrqScla2Model>, double?>((ref, scla) async {
  if (scla == null) return [];
  return ref.read(jrqApiProvider).fetchScla2(scla: scla);
});

final jrqGuiaListProvider = FutureProvider.autoDispose.family<List<JrqGuiaModel>, double?>((ref, scla2) async {
  if (scla2 == null) return [];
  return ref.read(jrqApiProvider).fetchGuia(scla2: scla2);
});

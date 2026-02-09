import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'jrq_api.dart';
import 'jrq_models.dart';

final jrqApiProvider = Provider<JrqApi>((ref) => JrqApi(ref.read(dioProvider)));

class JrqCache {
  List<JrqDepaModel>? depa;
  final Map<double, List<JrqSubdModel>> subd = {};
  final Map<double, List<JrqClasModel>> clas = {};
  final Map<double, List<JrqSclaModel>> scla = {};
  final Map<double, List<JrqScla2Model>> scla2 = {};
  final Map<double, List<JrqGuiaModel>> guia = {};

  void clear() {
    depa = null;
    subd.clear();
    clas.clear();
    scla.clear();
    scla2.clear();
    guia.clear();
  }
}

final jrqCacheProvider = Provider<JrqCache>((ref) => JrqCache());

final jrqDepaListProvider = FutureProvider.autoDispose<List<JrqDepaModel>>((ref) async {
  final cache = ref.read(jrqCacheProvider);
  if (cache.depa != null) return cache.depa!;
  final items = await ref.read(jrqApiProvider).fetchDepa();
  cache.depa = items;
  return items;
});

final jrqSubdListProvider = FutureProvider.autoDispose.family<List<JrqSubdModel>, double?>((ref, depa) async {
  if (depa == null) return [];
  final cache = ref.read(jrqCacheProvider);
  final cached = cache.subd[depa];
  if (cached != null) return cached;
  final items = await ref.read(jrqApiProvider).fetchSubd(depa: depa);
  cache.subd[depa] = items;
  return items;
});

final jrqClasListProvider = FutureProvider.autoDispose.family<List<JrqClasModel>, double?>((ref, subd) async {
  if (subd == null) return [];
  final cache = ref.read(jrqCacheProvider);
  final cached = cache.clas[subd];
  if (cached != null) return cached;
  final items = await ref.read(jrqApiProvider).fetchClas(subd: subd);
  cache.clas[subd] = items;
  return items;
});

final jrqSclaListProvider = FutureProvider.autoDispose.family<List<JrqSclaModel>, double?>((ref, clas) async {
  if (clas == null) return [];
  final cache = ref.read(jrqCacheProvider);
  final cached = cache.scla[clas];
  if (cached != null) return cached;
  final items = await ref.read(jrqApiProvider).fetchScla(clas: clas);
  cache.scla[clas] = items;
  return items;
});

final jrqScla2ListProvider = FutureProvider.autoDispose.family<List<JrqScla2Model>, double?>((ref, scla) async {
  if (scla == null) return [];
  final cache = ref.read(jrqCacheProvider);
  final cached = cache.scla2[scla];
  if (cached != null) return cached;
  final items = await ref.read(jrqApiProvider).fetchScla2(scla: scla);
  cache.scla2[scla] = items;
  return items;
});

final jrqGuiaListProvider = FutureProvider.autoDispose.family<List<JrqGuiaModel>, double?>((ref, scla2) async {
  if (scla2 == null) return [];
  final cache = ref.read(jrqCacheProvider);
  final cached = cache.guia[scla2];
  if (cached != null) return cached;
  final items = await ref.read(jrqApiProvider).fetchGuia(scla2: scla2);
  cache.guia[scla2] = items;
  return items;
});

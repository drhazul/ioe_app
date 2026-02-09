import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'mb51_api.dart';
import 'mb51_models.dart';

final mb51ApiProvider = Provider<Mb51Api>((ref) => Mb51Api(ref.read(dioProvider)));

final mb51FiltrosProvider = StateProvider<Mb51Filtros>((ref) => const Mb51Filtros());

final mb51SelectedSucsProvider = StateProvider<List<String>>((ref) => const []);
final mb51SelectedArtsProvider = StateProvider<List<String>>((ref) => const []);
final mb51SelectedAlmacenesProvider = StateProvider<List<String>>((ref) => const []);
final mb51SelectedClsmsProvider = StateProvider<List<double>>((ref) => const []);

final almacenCatalogProvider = FutureProvider.autoDispose<List<DatAlmacenModel>>((ref) async {
  final api = ref.read(mb51ApiProvider);
  return api.getAlmacenes();
});

final cmovCatalogProvider = FutureProvider.autoDispose<List<DatCmovModel>>((ref) async {
  final api = ref.read(mb51ApiProvider);
  return api.getClasesMovimiento();
});

final mb51SearchProvider = FutureProvider.autoDispose.family<Mb51SearchResult, Mb51Filtros>((ref, filtros) async {
  final api = ref.read(mb51ApiProvider);
  return api.searchMb51(filtros);
});

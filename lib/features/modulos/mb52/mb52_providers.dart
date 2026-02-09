import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'mb52_api.dart';
import 'mb52_models.dart';

final mb52ApiProvider = Provider<Mb52Api>((ref) => Mb52Api(ref.read(dioProvider)));

final mb52FiltrosProvider = StateProvider<Mb52Filtros>((ref) => const Mb52Filtros());

final mb52SelectedSucsProvider = StateProvider<List<String>>((ref) => const []);
final mb52SelectedArtsProvider = StateProvider<List<String>>((ref) => const []);
final mb52SelectedAlmacenesProvider = StateProvider<List<String>>((ref) => const []);

final mb52AlmacenCatalogProvider = FutureProvider.autoDispose<List<DatAlmacenModel>>((ref) async {
  final api = ref.read(mb52ApiProvider);
  return api.getAlmacenes();
});

final mb52ResumenProvider = FutureProvider.autoDispose.family<List<DatMb52ResumenModel>, Mb52Filtros>((ref, filtros) async {
  final api = ref.read(mb52ApiProvider);
  return api.fetchResumen(filtros);
});

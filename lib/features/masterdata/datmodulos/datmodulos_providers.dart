import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'datmodulos_api.dart';
import 'datmodulos_models.dart';

final datmodulosApiProvider = Provider<DatmodulosApi>((ref) => DatmodulosApi(ref.read(dioProvider)));

final datmodulosListProvider = FutureProvider.autoDispose<List<DatModuloModel>>((ref) async {
  final api = ref.read(datmodulosApiProvider);
  return api.fetchModulos();
});

final datmoduloProvider = FutureProvider.autoDispose.family<DatModuloModel, String>((ref, modulo) async {
  final api = ref.read(datmodulosApiProvider);
  return api.fetchModulo(modulo);
});

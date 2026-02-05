import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'datcatuso_api.dart';
import 'datcatuso_models.dart';

final datCatUsoApiProvider = Provider<DatCatUsoApi>(
  (ref) => DatCatUsoApi(ref.read(dioProvider), ref.read(storageProvider)),
);

final datCatUsoListProvider = FutureProvider.autoDispose<List<DatCatUsoModel>>((ref) async {
  final api = ref.read(datCatUsoApiProvider);
  return api.fetchUsos();
});

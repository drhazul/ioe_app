import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'datcatreg_api.dart';
import 'datcatreg_models.dart';

final datCatRegApiProvider = Provider<DatCatRegApi>(
  (ref) => DatCatRegApi(ref.read(dioProvider), ref.read(storageProvider)),
);

final datCatRegListProvider = FutureProvider.autoDispose<List<DatCatRegModel>>((ref) async {
  final api = ref.read(datCatRegApiProvider);
  return api.fetchRegimenes();
});

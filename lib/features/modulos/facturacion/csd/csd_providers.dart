import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'csd_api.dart';
import 'csd_models.dart';

final csdApiProvider = Provider<CsdApi>((ref) => CsdApi(ref.read(dioProvider)));

final csdListProvider = FutureProvider.autoDispose<List<CsdModel>>((ref) async {
  return ref.read(csdApiProvider).listar();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'deptos_api.dart';
import 'deptos_models.dart';

final deptosApiProvider = Provider<DeptosApi>((ref) => DeptosApi(ref.read(dioProvider)));

final deptosListProvider = FutureProvider.autoDispose<List<DeptoModel>>((ref) async {
  final api = ref.read(deptosApiProvider);
  return api.fetchDeptos();
});

final deptoProvider = FutureProvider.autoDispose.family<DeptoModel, int>((ref, id) async {
  final api = ref.read(deptosApiProvider);
  return api.fetchDepto(id);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'empresas_api.dart';
import 'empresas_models.dart';

final empresasApiProvider = Provider<EmpresasApi>(
  (ref) => EmpresasApi(ref.read(dioProvider)),
);

final empresasListProvider = FutureProvider.autoDispose<List<EmpresaModel>>((
  ref,
) async {
  final api = ref.read(empresasApiProvider);
  return api.fetchEmpresas();
});

final empresaProvider = FutureProvider.autoDispose.family<EmpresaModel, int>((
  ref,
  id,
) async {
  final api = ref.read(empresasApiProvider);
  return api.fetchEmpresa(id);
});

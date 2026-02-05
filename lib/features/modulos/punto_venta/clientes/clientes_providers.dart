import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'clientes_api.dart';
import 'clientes_models.dart';

final clientesApiProvider = Provider<ClientesApi>((ref) => ClientesApi(ref.read(dioProvider)));

final clientesListProvider = FutureProvider.autoDispose<List<FactClientShpModel>>((ref) async {
  final api = ref.read(clientesApiProvider);
  return api.fetchClientes();
});

final clienteProvider = FutureProvider.autoDispose.family<FactClientShpModel, String>((ref, id) async {
  final api = ref.read(clientesApiProvider);
  return api.fetchCliente(id);
});

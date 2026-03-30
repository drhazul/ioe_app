import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ioe_app/features/modulos/punto_venta/clientes/clientes_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/clientes/clientes_providers.dart';

class FacturaClientesFilter {
  const FacturaClientesFilter({this.suc});

  final String? suc;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FacturaClientesFilter && other.suc == suc;
  }

  @override
  int get hashCode => suc.hashCode;
}

final facturaMttoAllowedSucursalesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final api = ref.read(clientesApiProvider);
  return api.fetchAuthorizedSucursales();
});

final facturaClientesProvider = FutureProvider.autoDispose
    .family<List<FactClientShpModel>, FacturaClientesFilter>(
  (ref, filter) async {
    final api = ref.read(clientesApiProvider);
    final suc = filter.suc;
    return api.fetchClientes(suc: suc);
  },
);

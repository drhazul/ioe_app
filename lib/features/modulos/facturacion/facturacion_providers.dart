import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'facturacion_api.dart';

final facturacionApiProvider = Provider<FacturacionApi>(
  (ref) => FacturacionApi(ref.read(dioProvider)),
);

final facturasPendientesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(facturacionApiProvider).fetchPendientes(),
);

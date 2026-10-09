import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'cfdi_quadrum_api.dart';

final cfdiQuadrumApiProvider = Provider<CfdiQuadrumApi>(
  (ref) => CfdiQuadrumApi(ref.read(dioProvider)),
);

/// CSD cargado, ambiente y conexion con el PAC. No gasta timbre.
final cfdiEstadoProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.read(cfdiQuadrumApiProvider).estado(),
);

/// Catalogo de motivos de cancelacion del SAT.
final cfdiMotivosCancelacionProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.read(cfdiQuadrumApiProvider).motivosCancelacion(),
    );

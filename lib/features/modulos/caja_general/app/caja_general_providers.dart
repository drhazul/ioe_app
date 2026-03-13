import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'caja_general_api.dart';
import 'caja_general_models.dart';

final cajaGeneralApiProvider = Provider<CajaGeneralApi>(
  (ref) => CajaGeneralApi(ref.read(dioProvider)),
);

final cajaGeneralFiltrosProvider = StateProvider<CajaGeneralFiltros>((ref) {
  final now = DateTime.now();
  return CajaGeneralFiltros(
    suc: '',
    fecha: DateTime(now.year, now.month, now.day),
    opv: '',
    tipo: 'GLOBAL',
  );
});

final cajaGeneralEntregaOpvProvider =
    FutureProvider.autoDispose.family<CajaGeneralOpvResumen, CajaGeneralFiltros>(
  (ref, filtros) async {
    final api = ref.read(cajaGeneralApiProvider);
    return api.fetchResumenOpv(
      suc: filtros.suc,
      fecha: filtros.fecha,
      opv: filtros.opv,
      tipo: filtros.tipo,
    );
  },
);

final cajaGeneralResumenGlobalProvider =
    FutureProvider.autoDispose.family<CajaGeneralGlobalResumen, CajaGeneralFiltros>(
  (ref, filtros) async {
    final api = ref.read(cajaGeneralApiProvider);
    return api.fetchResumenGlobal(
      suc: filtros.suc,
      fecha: filtros.fecha,
      tipo: filtros.tipo,
    );
  },
);

final cajaGeneralAccionesProvider = Provider<CajaGeneralApi>(
  (ref) => ref.read(cajaGeneralApiProvider),
);

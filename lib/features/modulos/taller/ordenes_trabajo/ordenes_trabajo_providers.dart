import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'ordenes_trabajo_api.dart';
import 'ordenes_trabajo_models.dart';

final ordenesTrabajoApiProvider = Provider<OrdenesTrabajoApi>(
  (ref) => OrdenesTrabajoApi(ref.read(dioProvider)),
);

final ordenesTrabajoFilterProvider = StateProvider<OrdenesTrabajoFilter>(
  (ref) => const OrdenesTrabajoFilter(),
);

final ordenesTrabajoEnviarRelacionProvider =
    StateProvider<List<OrdenTrabajoEnviarRelacionItem>>(
  (ref) => const <OrdenTrabajoEnviarRelacionItem>[],
);

final ordenesTrabajoRecibirRelacionProvider =
    StateProvider<List<OrdenTrabajoEnviarRelacionItem>>(
  (ref) => const <OrdenTrabajoEnviarRelacionItem>[],
);

final ordenesTrabajoEntregarRelacionProvider =
    StateProvider<List<OrdenTrabajoEnviarRelacionItem>>(
  (ref) => const <OrdenTrabajoEnviarRelacionItem>[],
);

final ordenesTrabajoAsignarRelacionProvider =
    StateProvider<List<OrdenTrabajoEnviarRelacionItem>>(
  (ref) => const <OrdenTrabajoEnviarRelacionItem>[],
);

final ordenesTrabajoTrabajoTerminadoRelacionProvider =
    StateProvider<List<OrdenTrabajoEnviarRelacionItem>>(
  (ref) => const <OrdenTrabajoEnviarRelacionItem>[],
);

final ordenesTrabajoIncidenciaRelacionProvider =
    StateProvider<List<OrdenTrabajoEnviarRelacionItem>>(
  (ref) => const <OrdenTrabajoEnviarRelacionItem>[],
);

final ordenesTrabajoRegresarTiendaRelacionProvider =
    StateProvider<List<OrdenTrabajoEnviarRelacionItem>>(
  (ref) => const <OrdenTrabajoEnviarRelacionItem>[],
);

final ordenesTrabajoPanelProvider =
    FutureProvider.autoDispose<OrdenTrabajoPanelResponse>((ref) async {
  final api = ref.read(ordenesTrabajoApiProvider);
  final filter = ref.watch(ordenesTrabajoFilterProvider);
  return api.fetchPanel(filter);
});

final ordenTrabajoDetalleProvider = FutureProvider.autoDispose
    .family<OrdenTrabajoDetalleResponse, String>((ref, iord) async {
  final api = ref.read(ordenesTrabajoApiProvider);
  return api.fetchDetail(iord.trim());
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'devoluciones_api.dart';
import 'devoluciones_models.dart';

final devolucionesApiProvider = Provider<DevolucionesApi>(
  (ref) => DevolucionesApi(ref.read(dioProvider)),
);

final devolucionesPanelProvider =
    FutureProvider.autoDispose.family<List<DevolucionPanelItem>, DevolucionesPanelQuery>(
      (ref, query) async {
        final api = ref.read(devolucionesApiProvider);
        return api.fetchPanel(
          suc: query.suc,
          opv: query.opv,
          search: query.search,
        );
      },
    );

final devolucionDetalleProvider =
    FutureProvider.autoDispose.family<DevolucionDetalleResponse, String>(
      (ref, idfolDev) async {
        final api = ref.read(devolucionesApiProvider);
        return api.fetchDetalle(idfolDev.trim());
      },
    );

final devolucionDetallePreparadoProvider = FutureProvider.autoDispose
    .family<DevolucionDetallePreparadoResponse, String>((ref, idfolDev) async {
      final api = ref.read(devolucionesApiProvider);
      return api.prepararDetalle(idfolDev.trim());
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'ps_api.dart';
import 'ps_models.dart';

final psApiProvider = Provider<PsApi>((ref) => PsApi(ref.read(dioProvider)));

final psPanelQueryProvider = StateProvider<PsPanelQuery>(
  (ref) => const PsPanelQuery(),
);

final psFoliosProvider = FutureProvider.autoDispose<List<PsFolioItem>>((ref) async {
  final api = ref.read(psApiProvider);
  final query = ref.watch(psPanelQueryProvider);
  final folios = await api.fetchFolios(
    suc: query.suc,
    opv: query.opv,
    esta: 'ALL',
    search: query.search,
  );
  const estadosPermitidos = {'PENDIENTE', 'EDITANDO', 'PAGADO'};
  final opvNorm = query.opv.trim().toUpperCase();
  return folios
      .where(
        (folio) {
          final estadoValido = estadosPermitidos.contains(
            (folio.esta ?? '').trim().toUpperCase(),
          );
          if (!estadoValido) return false;
          if (opvNorm.isEmpty) return true;
          return (folio.opv ?? '').trim().toUpperCase() == opvNorm;
        },
      )
      .toList(growable: false);
});

final psDetalleProvider =
    FutureProvider.autoDispose.family<PsDetalleResponse, String>((ref, idFol) async {
      final api = ref.read(psApiProvider);
      return api.fetchDetalle(idFol.trim());
    });

final psAdeudosProvider = FutureProvider.autoDispose
    .family<PsAdeudosResponse, PsAdeudosQuery>((ref, query) async {
      final api = ref.read(psApiProvider);
      return api.fetchAdeudosCliente(
        query.client,
        folio: query.folio,
      );
    });

final psPagoSummaryProvider =
    FutureProvider.autoDispose.family<PsPagoSummary, String>((ref, idFol) async {
      final api = ref.read(psApiProvider);
      return api.fetchSummary(idFol.trim());
    });

final psFormasPagoProvider =
    FutureProvider.autoDispose.family<List<PsFormaPagoItem>, String>((ref, idFol) async {
      final summary = await ref.watch(psPagoSummaryProvider(idFol).future);
      return summary.formas;
    });

final psFormasCatalogProvider =
    FutureProvider.autoDispose<List<PsFormaCatalogItem>>((ref) async {
      final api = ref.read(psApiProvider);
      return api.fetchFormasPagoCatalog();
    });

class PsPagoDraftFormasNotifier extends StateNotifier<List<PsFormaPagoDraftItem>> {
  PsPagoDraftFormasNotifier() : super(const []);

  void add(PsFormaPagoDraftItem item) {
    state = [...state, item];
  }

  void removeByLocalId(String localId) {
    state = state.where((item) => item.localId != localId).toList(growable: false);
  }

  void clear() {
    state = const [];
  }
}

final psPagoDraftFormasProvider = StateNotifierProvider.family<PsPagoDraftFormasNotifier,
    List<PsFormaPagoDraftItem>, String>((ref, idFol) {
  return PsPagoDraftFormasNotifier();
});

final psSelectedArtProvider = StateProvider<String?>((ref) => null);

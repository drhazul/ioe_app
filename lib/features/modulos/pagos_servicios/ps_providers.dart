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
  return api.fetchFolios(
    suc: query.suc,
    esta: query.esta,
    search: query.search,
  );
});

final psDetalleProvider =
    FutureProvider.autoDispose.family<PsDetalleResponse, String>((ref, idFol) async {
      final api = ref.read(psApiProvider);
      return api.fetchDetalle(idFol.trim());
    });

final psAdeudosProvider =
    FutureProvider.autoDispose.family<PsAdeudosResponse, int>((ref, client) async {
      final api = ref.read(psApiProvider);
      return api.fetchAdeudosCliente(client);
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

final psSelectedArtProvider = StateProvider<String?>((ref) => null);

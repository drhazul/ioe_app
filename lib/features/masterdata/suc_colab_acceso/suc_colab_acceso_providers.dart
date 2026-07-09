import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'suc_colab_acceso_api.dart';
import 'suc_colab_acceso_models.dart';

final sucColabAccesoApiProvider = Provider<SucColabAccesoApi>(
  (ref) => SucColabAccesoApi(ref.read(dioProvider)),
);

final sucColabAccesoListProvider = FutureProvider.autoDispose
    .family<List<SucColabAccesoModel>, SucColabAccesoFilters>((
      ref,
      filters,
    ) async {
      final api = ref.read(sucColabAccesoApiProvider);
      return api.fetchAll(
        sucDestino: filters.sucDestino,
        sucOrigen: filters.sucOrigen,
        search: filters.search,
        includeInactive: filters.includeInactive,
      );
    });

final sucColabAccesoProvider = FutureProvider.autoDispose
    .family<SucColabAccesoModel, int>((ref, id) async {
      final api = ref.read(sucColabAccesoApiProvider);
      return api.fetchOne(id);
    });

final sucColabAccesoFiltersProvider = StateProvider<SucColabAccesoFilters>(
  (ref) => const SucColabAccesoFilters(),
);

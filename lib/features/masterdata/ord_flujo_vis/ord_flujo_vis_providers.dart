import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'ord_flujo_vis_api.dart';
import 'ord_flujo_vis_models.dart';

final ordFlujoVisApiProvider = Provider<OrdFlujoVisApi>(
  (ref) => OrdFlujoVisApi(ref.read(dioProvider)),
);

final ordFlujoVisListProvider =
    FutureProvider.autoDispose<List<OrdFlujoVisModel>>((ref) async {
      final api = ref.read(ordFlujoVisApiProvider);
      return api.fetchList(includeInactive: true, modulo: 'DAT_JAO_ORD');
    });

final ordFlujoVisProvider =
    FutureProvider.autoDispose.family<OrdFlujoVisModel, int>((ref, id) async {
      final api = ref.read(ordFlujoVisApiProvider);
      return api.fetchById(id);
    });

final ordFlujoVisCatalogosProvider =
    FutureProvider.autoDispose<OrdFlujoVisCatalogos>((ref) async {
      final api = ref.read(ordFlujoVisApiProvider);
      return api.fetchCatalogos();
    });

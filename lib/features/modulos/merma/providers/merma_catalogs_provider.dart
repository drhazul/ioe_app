import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/merma_models.dart';
import 'merma_provider.dart';

final mermaMotivosProvider =
    FutureProvider.autoDispose<List<MermaCatalogOptionModel>>((ref) async {
      final api = ref.read(mermaApiProvider);
      return api.catalogMotivos();
    });

final mermaClasificacionesProvider =
    FutureProvider.autoDispose<List<MermaCatalogOptionModel>>((ref) async {
      final api = ref.read(mermaApiProvider);
      return api.catalogClasificaciones();
    });

final mermaEstatusProvider =
    FutureProvider.autoDispose<List<MermaCatalogOptionModel>>((ref) async {
      final api = ref.read(mermaApiProvider);
      return api.catalogEstatus();
    });

final mermaAreasProvider =
    FutureProvider.autoDispose<List<MermaCatalogOptionModel>>((ref) async {
      final api = ref.read(mermaApiProvider);
      return api.catalogAreas();
    });

final mermaSucursalesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final api = ref.read(mermaApiProvider);
  return api.catalogSucursales();
});

final mermaCatalogArticulosProvider = FutureProvider.autoDispose
    .family<MermaPagedResult<MermaArticuloModel>, Map<String, dynamic>>((
      ref,
      query,
    ) async {
      final api = ref.read(mermaApiProvider);
      return api.catalogArticulos(
        search: (query['search'] ?? '').toString().trim(),
        suc: (query['suc'] ?? '').toString().trim(),
        page: _toInt(query['page'], 1),
        limit: _toInt(query['limit'], 30),
      );
    });

int _toInt(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

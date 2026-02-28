import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'ref_detalle_api.dart';
import 'ref_detalle_models.dart';

final refDetalleApiProvider = Provider<RefDetalleApi>(
  (ref) => RefDetalleApi(ref.read(dioProvider)),
);

final refDetalleListProvider = FutureProvider.autoDispose
    .family<List<RefDetalleItem>, RefDetalleListQuery>((ref, query) async {
  final api = ref.read(refDetalleApiProvider);
  return api.fetchByFolio(idfol: query.idfol, tipo: query.tipo);
});

class RefDetalleListQuery {
  const RefDetalleListQuery({
    required this.idfol,
    this.tipo,
  });

  final String idfol;
  final String? tipo;

  @override
  bool operator ==(Object other) {
    return other is RefDetalleListQuery &&
        other.idfol == idfol &&
        other.tipo == tipo;
  }

  @override
  int get hashCode => Object.hash(idfol, tipo);
}


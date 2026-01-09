import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'inventarios_api.dart';
import 'inventarios_models.dart';

final inventariosApiProvider = Provider<InventariosApi>((ref) => InventariosApi(ref.read(dioProvider)));

final inventariosListProvider = FutureProvider.autoDispose<List<DatContCtrlModel>>((ref) async {
  final api = ref.read(inventariosApiProvider);
  return api.fetchAll();
});

final inventarioProvider = FutureProvider.autoDispose.family<DatContCtrlModel, String>((ref, tokenreg) async {
  final api = ref.read(inventariosApiProvider);
  return api.fetchOne(tokenreg);
});

class ConteoDetQuery {
  final String cont;
  final int page;
  final int limit;

  const ConteoDetQuery({required this.cont, this.page = 1, this.limit = 50});

  ConteoDetQuery copyWith({String? cont, int? page, int? limit}) {
    return ConteoDetQuery(
      cont: cont ?? this.cont,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConteoDetQuery && other.cont == cont && other.page == page && other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(cont, page, limit);
}

final inventarioDetalleProvider = FutureProvider.autoDispose.family<ConteoDetResponse, ConteoDetQuery>((ref, query) async {
  final api = ref.read(inventariosApiProvider);
  return api.fetchDetalles(query.cont, page: query.page, limit: query.limit);
});

final inventarioDetalleSummaryProvider = FutureProvider.autoDispose.family<ConteoSummaryModel, String>((ref, cont) async {
  final api = ref.read(inventariosApiProvider);
  return api.fetchDetalleSummary(cont);
});

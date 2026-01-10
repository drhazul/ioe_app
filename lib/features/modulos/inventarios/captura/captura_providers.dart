import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'captura_api.dart';
import 'captura_models.dart';

final capturaApiProvider = Provider<CapturaApi>((ref) => CapturaApi(ref.read(dioProvider)));

final conteosDisponiblesProvider = FutureProvider.autoDispose<List<ConteoDisponible>>((ref) async {
  final api = ref.read(capturaApiProvider);
  return api.fetchConteosDisponibles();
});

final capturaCorrectionUpcProvider = StateProvider<String?>((ref) => null);
final capturaSelectedContProvider = StateProvider<String?>((ref) => null);

class CapturaListQuery {
  final String cont;
  final String almacen;
  final String upc;
  final int page;
  final int limit;

  const CapturaListQuery({
    required this.cont,
    this.almacen = 'TODOS',
    this.upc = '',
    this.page = 1,
    this.limit = 50,
  });

  CapturaListQuery copyWith({String? cont, String? almacen, String? upc, int? page, int? limit}) {
    return CapturaListQuery(
      cont: cont ?? this.cont,
      almacen: almacen ?? this.almacen,
      upc: upc ?? this.upc,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CapturaListQuery &&
        other.cont == cont &&
        other.almacen == almacen &&
        other.upc == upc &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(cont, almacen, upc, page, limit);
}

final capturasListProvider = FutureProvider.autoDispose.family<CapturaListResponse, CapturaListQuery>((ref, query) async {
  final api = ref.read(capturaApiProvider);
  return api.listarCapturas(
    cont: query.cont,
    almacen: query.almacen == 'TODOS' ? null : query.almacen,
    upc: query.upc.isEmpty ? null : query.upc,
    page: query.page,
    limit: query.limit,
  );
});

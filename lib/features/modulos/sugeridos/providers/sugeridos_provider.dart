import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dio_provider.dart';
import '../data/sugeridos_api.dart';
import '../domain/sugeridos_models.dart';

class SugeridosFilters {
  const SugeridosFilters({
    this.page = 1,
    this.limit = 30,
    this.search,
    this.suc,
    this.estatus,
    this.prov,
    this.fecha,
  });

  final int page;
  final int limit;
  final String? search;
  final String? suc;
  final String? estatus;
  final int? prov;
  final String? fecha;

  @override
  bool operator ==(Object other) {
    return other is SugeridosFilters &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.suc == suc &&
        other.estatus == estatus &&
        other.prov == prov &&
        other.fecha == fecha;
  }

  @override
  int get hashCode =>
      Object.hash(page, limit, search, suc, estatus, prov, fecha);
}

class SugeridosCalculoFilters {
  const SugeridosCalculoFilters({
    required this.suc,
    this.prov,
    this.marca,
    this.tipo,
    this.lineaProducto,
    this.categoria,
    this.dias = 90,
    this.page = 1,
    this.limit = 100,
  });

  final String suc;
  final int? prov;
  final String? marca;
  final String? tipo;
  final String? lineaProducto;
  final String? categoria;
  final int dias;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is SugeridosCalculoFilters &&
        other.suc == suc &&
        other.prov == prov &&
        other.marca == marca &&
        other.tipo == tipo &&
        other.lineaProducto == lineaProducto &&
        other.categoria == categoria &&
        other.dias == dias &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    suc,
    prov,
    marca,
    tipo,
    lineaProducto,
    categoria,
    dias,
    page,
    limit,
  );
}

final sugeridosApiProvider = Provider<SugeridosApi>((ref) {
  return SugeridosApi(ref.read(dioProvider));
});

final sugeridosProvider = FutureProvider.autoDispose
    .family<SugeridosPagedResult<SugeridoOrdenModel>, SugeridosFilters>((
      ref,
      filters,
    ) {
      return ref
          .read(sugeridosApiProvider)
          .fetch(
            page: filters.page,
            limit: filters.limit,
            search: _toText(filters.search),
            suc: _toText(filters.suc),
            estatus: _toText(filters.estatus),
            prov: filters.prov,
            from: _toText(filters.fecha),
            to: _toText(filters.fecha),
          );
    });

final sugeridosCalculoProvider = FutureProvider.autoDispose
    .family<
      SugeridosPagedResult<SugeridoCalculoModel>,
      SugeridosCalculoFilters
    >((ref, filters) {
      return ref
          .read(sugeridosApiProvider)
          .calcular(
            suc: filters.suc,
            prov: filters.prov,
            marca: _toText(filters.marca),
            tipo: _toText(filters.tipo),
            lineaProducto: _toText(filters.lineaProducto),
            categoria: _toText(filters.categoria),
            dias: filters.dias,
            page: filters.page,
            limit: filters.limit,
          );
    });

final sugeridoDetalleProvider = FutureProvider.autoDispose
    .family<SugeridoOrdenModel, String>((ref, nped) {
      return ref.read(sugeridosApiProvider).fetchOne(nped);
    });

final sugeridosSucursalesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) {
  return ref.read(sugeridosApiProvider).sucursales();
});

final sugeridosEstatusProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) {
  return ref.read(sugeridosApiProvider).estatus();
});

final sugeridosProveedoresProvider =
    FutureProvider.autoDispose<List<SugeridoProveedorModel>>((ref) {
      return ref.read(sugeridosApiProvider).proveedores();
    });

String? _toText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

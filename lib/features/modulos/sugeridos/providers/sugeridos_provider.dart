import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dio_provider.dart';
import '../../punto_venta/cotizaciones/detalle_cot/jrq_api.dart';
import '../../punto_venta/cotizaciones/detalle_cot/jrq_models.dart';
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
    this.depa = const [],
    this.subd = const [],
    this.clas = const [],
    this.scla = const [],
    this.scla2 = const [],
    this.dias = 90,
    this.page = 1,
    this.limit = 100,
  });

  final String suc;
  final int? prov;
  final List<double> depa;
  final List<double> subd;
  final List<double> clas;
  final List<double> scla;
  final List<double> scla2;
  final int dias;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is SugeridosCalculoFilters &&
        other.suc == suc &&
        other.prov == prov &&
        _listEquals(other.depa, depa) &&
        _listEquals(other.subd, subd) &&
        _listEquals(other.clas, clas) &&
        _listEquals(other.scla, scla) &&
        _listEquals(other.scla2, scla2) &&
        other.dias == dias &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    suc,
    prov,
    Object.hashAll(depa),
    Object.hashAll(subd),
    Object.hashAll(clas),
    Object.hashAll(scla),
    Object.hashAll(scla2),
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
            depa: filters.depa,
            subd: filters.subd,
            clas: filters.clas,
            scla: filters.scla,
            scla2: filters.scla2,
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

final sugeridosJrqDepaProvider = FutureProvider.autoDispose<List<JrqDepaModel>>(
  (ref) => JrqApi(ref.read(dioProvider)).fetchDepa(),
);

final sugeridosJrqSubdProvider = FutureProvider.autoDispose
    .family<List<JrqSubdModel>, String>((ref, key) async {
      final parents = _decodeNumberKey(key);
      final api = JrqApi(ref.read(dioProvider));
      if (parents.isEmpty) return api.fetchSubd();
      final rows = await Future.wait(
        parents.map((depa) => api.fetchSubd(depa: depa)),
      );
      return _uniqueSorted<JrqSubdModel>(
        rows.expand((items) => items),
        (item) => item.subd,
      );
    });

final sugeridosJrqClasProvider = FutureProvider.autoDispose
    .family<List<JrqClasModel>, String>((ref, key) async {
      final parents = _decodeNumberKey(key);
      final api = JrqApi(ref.read(dioProvider));
      if (parents.isEmpty) return api.fetchClas();
      final rows = await Future.wait(
        parents.map((subd) => api.fetchClas(subd: subd)),
      );
      return _uniqueSorted<JrqClasModel>(
        rows.expand((items) => items),
        (item) => item.clas,
      );
    });

final sugeridosJrqSclaProvider = FutureProvider.autoDispose
    .family<List<JrqSclaModel>, String>((ref, key) async {
      final parents = _decodeNumberKey(key);
      final api = JrqApi(ref.read(dioProvider));
      if (parents.isEmpty) return api.fetchScla();
      final rows = await Future.wait(
        parents.map((clas) => api.fetchScla(clas: clas)),
      );
      return _uniqueSorted<JrqSclaModel>(
        rows.expand((items) => items),
        (item) => item.scla,
      );
    });

final sugeridosJrqScla2Provider = FutureProvider.autoDispose
    .family<List<JrqScla2Model>, String>((ref, key) async {
      final parents = _decodeNumberKey(key);
      final api = JrqApi(ref.read(dioProvider));
      if (parents.isEmpty) return api.fetchScla2();
      final rows = await Future.wait(
        parents.map((scla) => api.fetchScla2(scla: scla)),
      );
      return _uniqueSorted<JrqScla2Model>(
        rows.expand((items) => items),
        (item) => item.scla2,
      );
    });

String sugeridosNumberKey(List<double> values) {
  final normalized = values.toSet().toList()..sort();
  return normalized.map((value) => value.toString()).join(',');
}

String? _toText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

List<double> _decodeNumberKey(String key) {
  if (key.trim().isEmpty) return const [];
  final values =
      key
          .split(',')
          .map((value) => double.tryParse(value.trim()))
          .whereType<double>()
          .toSet()
          .toList()
        ..sort();
  return values;
}

List<T> _uniqueSorted<T>(Iterable<T> rows, double Function(T) keyOf) {
  final map = <double, T>{};
  for (final row in rows) {
    map[keyOf(row)] = row;
  }
  return map.values.toList()..sort((a, b) => keyOf(a).compareTo(keyOf(b)));
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

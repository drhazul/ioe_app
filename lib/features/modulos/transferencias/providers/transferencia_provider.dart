import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dio_provider.dart';
import '../data/transferencia_api.dart';
import '../domain/transferencia_models.dart';

class TransferenciaFilters {
  const TransferenciaFilters({
    this.page = 1,
    this.limit = 30,
    this.search,
    this.doc,
    this.usuario,
    this.fecha,
    this.suc,
    this.estatus,
  });

  final int page;
  final int limit;
  final String? search;
  final String? doc;
  final String? usuario;
  final String? fecha;
  final String? suc;
  final String? estatus;

  @override
  bool operator ==(Object other) {
    return other is TransferenciaFilters &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.doc == doc &&
        other.usuario == usuario &&
        other.fecha == fecha &&
        other.suc == suc &&
        other.estatus == estatus;
  }

  @override
  int get hashCode =>
      Object.hash(page, limit, search, doc, usuario, fecha, suc, estatus);
}

final transferenciaApiProvider = Provider<TransferenciaApi>((ref) {
  return TransferenciaApi(ref.read(dioProvider));
});

final transferenciasProvider = FutureProvider.autoDispose
    .family<
      TransferenciaPagedResult<TransferenciaDocModel>,
      TransferenciaFilters
    >((ref, filters) {
      return ref
          .read(transferenciaApiProvider)
          .fetch(
            page: filters.page,
            limit: filters.limit,
            search: _toText(filters.search),
            doc: _toText(filters.doc),
            usuario: _toText(filters.usuario),
            from: _toText(filters.fecha),
            to: _toText(filters.fecha),
            suc: _toText(filters.suc),
            estatus: _toText(filters.estatus),
          );
    });

final transferenciaReportesProvider = FutureProvider.autoDispose
    .family<
      TransferenciaPagedResult<TransferenciaDocModel>,
      TransferenciaFilters
    >((ref, filters) {
      return ref
          .read(transferenciaApiProvider)
          .reportes(
            page: filters.page,
            limit: filters.limit,
            doc: _toText(filters.doc),
            usuario: _toText(filters.usuario),
            from: _toText(filters.fecha),
            to: _toText(filters.fecha),
            suc: _toText(filters.suc),
            estatus: _toText(filters.estatus),
          );
    });

final transferenciaDetalleProvider = FutureProvider.autoDispose
    .family<TransferenciaDocModel, String>((ref, doc) {
      return ref.read(transferenciaApiProvider).fetchOne(doc);
    });

final transferenciaReporteDetalleProvider = FutureProvider.autoDispose
    .family<TransferenciaDocModel, String>((ref, doc) {
      return ref.read(transferenciaApiProvider).reporteDetalle(doc);
    });

final transferenciaNotificacionesProvider =
    FutureProvider.autoDispose<List<TransferenciaDocModel>>((ref) {
      return ref.read(transferenciaApiProvider).notificaciones();
    });

final transferenciaSucursalesProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
      return ref.read(transferenciaApiProvider).sucursales();
    });

final transferenciaMotivosProvider =
    FutureProvider.autoDispose<List<TransferenciaCatalogOptionModel>>((ref) {
      return ref.read(transferenciaApiProvider).motivos();
    });

final transferenciaPrioridadesProvider =
    FutureProvider.autoDispose<List<TransferenciaCatalogOptionModel>>((ref) {
      return ref.read(transferenciaApiProvider).prioridades();
    });

String? _toText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

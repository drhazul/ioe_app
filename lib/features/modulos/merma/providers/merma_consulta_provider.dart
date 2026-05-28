import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/merma_models.dart';
import 'merma_provider.dart';

class MermaConsultaFilters {
  const MermaConsultaFilters({
    this.page = 1,
    this.limit = 50,
    this.docmer,
    this.usuario,
    this.estatus,
    this.suc,
    this.from,
    this.to,
  });

  final int page;
  final int limit;
  final String? docmer;
  final String? usuario;
  final String? estatus;
  final String? suc;
  final String? from;
  final String? to;

  @override
  bool operator ==(Object other) {
    return other is MermaConsultaFilters &&
        other.page == page &&
        other.limit == limit &&
        other.docmer == docmer &&
        other.usuario == usuario &&
        other.estatus == estatus &&
        other.suc == suc &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode =>
      Object.hash(page, limit, docmer, usuario, estatus, suc, from, to);
}

final mermaConsultaProvider = FutureProvider.autoDispose
    .family<MermaPagedResult<MermaDocModel>, MermaConsultaFilters>((
      ref,
      filters,
    ) async {
      final repo = ref.read(mermaRepositoryProvider);
      return repo.fetchConsulta(
        page: filters.page,
        limit: filters.limit,
        docmer: _toText(filters.docmer),
        usuario: _toText(filters.usuario),
        estatus: _toText(filters.estatus),
        from: _toText(filters.from),
        to: _toText(filters.to),
        suc: _toText(filters.suc),
      );
    });

String? _toText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

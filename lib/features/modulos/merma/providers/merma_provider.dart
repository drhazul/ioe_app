import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/dio_provider.dart';
import '../data/merma_api.dart';
import '../data/merma_repository.dart';
import '../domain/merma_models.dart';

class MermaGestionFilters {
  const MermaGestionFilters({
    this.page = 1,
    this.limit = 30,
    this.search,
    this.estatus,
    this.from,
    this.to,
  });

  final int page;
  final int limit;
  final String? search;
  final String? estatus;
  final String? from;
  final String? to;

  @override
  bool operator ==(Object other) {
    return other is MermaGestionFilters &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.estatus == estatus &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(page, limit, search, estatus, from, to);
}

final mermaApiProvider = Provider<MermaApi>((ref) {
  return MermaApi(ref.read(dioProvider));
});

final mermaRepositoryProvider = Provider<MermaRepository>((ref) {
  return MermaRepository(ref.read(mermaApiProvider));
});

final mermaGestionProvider = FutureProvider.autoDispose
    .family<MermaPagedResult<MermaDocModel>, MermaGestionFilters>((
      ref,
      filters,
    ) async {
      final repo = ref.read(mermaRepositoryProvider);
      return repo.fetchGestion(
        page: filters.page,
        limit: filters.limit,
        search: _toText(filters.search),
        estatus: _toText(filters.estatus),
        from: _toText(filters.from),
        to: _toText(filters.to),
      );
    });

final mermaGestionCabecerasProvider = FutureProvider.autoDispose
    .family<List<MermaGestionCabeceraModel>, String?>((ref, suc) async {
      final repo = ref.read(mermaRepositoryProvider);
      return repo.fetchGestionCabecerasAbiertas(suc: _toText(suc));
    });

final mermaDetalleProvider = FutureProvider.autoDispose
    .family<MermaDocModel, String>((ref, docmer) async {
      final api = ref.read(mermaApiProvider);
      return api.fetchMerma(docmer);
    });

final mermaDetalleConsultaProvider = FutureProvider.autoDispose
    .family<MermaDocModel, String>((ref, docmer) async {
      final api = ref.read(mermaApiProvider);
      return api.fetchMerma(docmer, consulta: true);
    });

final mermaCurrentRoleNameProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  final roleId = auth.roleId ?? 0;
  final username = (auth.username ?? '').trim().toUpperCase();
  if (roleId == 0 || roleId == 1 || username == 'ADMIN') return 'ADMIN';

  final dio = ref.read(dioProvider);
  final res = await dio.get('/access/roles');
  final payload = res.data;

  List<dynamic> rows = const [];
  if (payload is Map) {
    final data = payload['data'];
    if (data is List) rows = data;
  } else if (payload is List) {
    rows = payload;
  }

  for (final row in rows) {
    if (row is! Map) continue;
    final id = int.tryParse(
      '${row['IDROL'] ?? row['idRol'] ?? row['idrol'] ?? row['id'] ?? ''}',
    );
    if (id != roleId) continue;
    final name = '${row['NOMBRE'] ?? row['nombre'] ?? row['name'] ?? ''}'
        .trim()
        .toUpperCase();
    return name;
  }

  return '';
});

String? _toText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

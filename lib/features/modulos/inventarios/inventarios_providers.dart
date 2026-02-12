import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/features/masterdata/access_reg_suc/access_reg_suc_providers.dart';

import 'inventarios_api.dart';
import 'inventarios_models.dart';

final inventariosApiProvider = Provider<InventariosApi>(
  (ref) => InventariosApi(ref.read(dioProvider)),
);

const _inventariosModuloCodigo = 'DAT_JAA_ALM';

final inventariosSelectedSucProvider = StateProvider<String?>((ref) => null);

final inventariosAllowedSucProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final username = ref.watch(authControllerProvider).username ?? '';
  if (username.trim().isEmpty) return const <String>[];
  final api = ref.read(accessRegSucApiProvider);
  final rows = await api.fetchAll(
    modulo: _inventariosModuloCodigo,
    usuario: username,
    activo: true,
  );
  final unique = <String>{};
  for (final row in rows) {
    final suc = row.suc.trim();
    if (suc.isNotEmpty) unique.add(suc);
  }
  final list = unique.toList()..sort();
  return list;
});

String? _resolveInventariosSuc({
  required String? selected,
  required List<String> allowed,
  required bool isAdmin,
}) {
  final selectedNormalized = selected?.trim();
  if (selectedNormalized != null && selectedNormalized.isNotEmpty) {
    if (isAdmin || allowed.contains(selectedNormalized)) {
      return selectedNormalized;
    }
  }
  if (allowed.isNotEmpty) return allowed.first;
  return null;
}

final inventariosListProvider =
    FutureProvider.autoDispose<List<DatContCtrlModel>>((ref) async {
      final api = ref.read(inventariosApiProvider);
      final selected = ref.watch(inventariosSelectedSucProvider);
      final auth = ref.watch(authControllerProvider);
      final isAdmin = (auth.roleId ?? 0) == 1;
      final allowed = await ref.watch(inventariosAllowedSucProvider.future);
      if (!isAdmin && allowed.isEmpty) return const <DatContCtrlModel>[];
      final suc = _resolveInventariosSuc(
        selected: selected,
        allowed: allowed,
        isAdmin: isAdmin,
      );
      return api.fetchAll(suc: suc);
    });

final inventarioProvider = FutureProvider.autoDispose
    .family<DatContCtrlModel, String>((ref, tokenreg) async {
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
    return other is ConteoDetQuery &&
        other.cont == cont &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(cont, page, limit);
}

final inventarioDetalleProvider = FutureProvider.autoDispose
    .family<ConteoDetResponse, ConteoDetQuery>((ref, query) async {
      final api = ref.read(inventariosApiProvider);
      final selected = ref.watch(inventariosSelectedSucProvider);
      final auth = ref.watch(authControllerProvider);
      final isAdmin = (auth.roleId ?? 0) == 1;
      final allowed = await ref.watch(inventariosAllowedSucProvider.future);
      final suc = _resolveInventariosSuc(
        selected: selected,
        allowed: allowed,
        isAdmin: isAdmin,
      );
      return api.fetchDetalles(
        query.cont,
        page: query.page,
        limit: query.limit,
        suc: suc,
      );
    });

final inventarioDetalleSummaryProvider = FutureProvider.autoDispose
    .family<ConteoSummaryModel, String>((ref, cont) async {
      final api = ref.read(inventariosApiProvider);
      final selected = ref.watch(inventariosSelectedSucProvider);
      final auth = ref.watch(authControllerProvider);
      final isAdmin = (auth.roleId ?? 0) == 1;
      final allowed = await ref.watch(inventariosAllowedSucProvider.future);
      final suc = _resolveInventariosSuc(
        selected: selected,
        allowed: allowed,
        isAdmin: isAdmin,
      );
      return api.fetchDetalleSummary(cont, suc: suc);
    });

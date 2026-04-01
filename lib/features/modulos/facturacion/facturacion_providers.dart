import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'facturacion_api.dart';

final facturacionApiProvider = Provider<FacturacionApi>(
  (ref) => FacturacionApi(ref.read(dioProvider)),
);

final facturacionPageProvider = StateProvider<int>((ref) => 1);
final facturacionPageSizeProvider = StateProvider<int>((ref) => 100);

final facturasPendientesProvider = FutureProvider<FacturacionPendientesPage>(
  (ref) async {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) {
      return const FacturacionPendientesPage(
        data: [],
        total: 0,
        page: 1,
        pageSize: 60,
        totalPages: 0,
      );
    }

    final selectionFilter = ref.watch(facturacionIdFolSelectionFilterProvider);
    final api = ref.read(facturacionApiProvider);

    if (selectionFilter.isNotEmpty) {
      // Trae páginas hasta cubrir todos los IDFOL seleccionados o agotar datos.
      const maxPages = 10;
      const pageSize = 200;
      final wanted = selectionFilter.map((e) => e.toUpperCase()).toSet();
      final collected = <Map<String, dynamic>>[];
      var page = 1;
      var hasNext = true;

      while (hasNext && page <= maxPages && collected.length < wanted.length) {
        final res = await api.fetchPendientes(
          page: page,
          pageSize: pageSize,
          suc: ref.watch(facturacionFilterSucProvider),
          estatus: ref.watch(facturacionFilterEstatusProvider),
          razonSocialReceptor: ref.watch(facturacionFilterRazonSocialProvider),
          rfcReceptor: ref.watch(facturacionFilterRfcReceptorProvider),
          clien: ref.watch(facturacionFilterClienProvider),
          idFol: ref.watch(facturacionFilterIdFolProvider),
          tipoFact: ref.watch(facturacionFilterTipoFactProvider),
        );
        collected.addAll(res.data);
        hasNext = res.totalPages > page;
        page += 1;
      }

      final filtered = collected
          .where((row) =>
              wanted.contains(
                (row['IDFOL'] ?? row['idfol'] ?? '').toString().toUpperCase(),
              ) &&
              (row['ESTATUS'] ?? row['estatus'] ?? '').toString().toUpperCase() ==
                  'PENDIENTE')
          .toList();

      return FacturacionPendientesPage(
        data: filtered,
        total: filtered.length,
        page: 1,
        pageSize: filtered.length,
        totalPages: filtered.isEmpty ? 0 : 1,
      );
    }

    return api.fetchPendientes(
      page: ref.watch(facturacionPageProvider),
      pageSize: ref.watch(facturacionPageSizeProvider),
      suc: ref.watch(facturacionFilterSucProvider),
      estatus: ref.watch(facturacionFilterEstatusProvider),
      razonSocialReceptor: ref.watch(facturacionFilterRazonSocialProvider),
      rfcReceptor: ref.watch(facturacionFilterRfcReceptorProvider),
      clien: ref.watch(facturacionFilterClienProvider),
      idFol: ref.watch(facturacionFilterIdFolProvider),
      tipoFact: ref.watch(facturacionFilterTipoFactProvider),
    );
  },
);

final selectedFacturaIdFolProvider = StateProvider<String?>((ref) => null);
final selectedFacturasUnificacionProvider =
    StateProvider<Set<String>>((ref) => <String>{});

final facturacionFilterSucProvider = StateProvider<String>((ref) => '');
final facturacionFilterEstatusProvider =
    StateProvider<String>((ref) => 'PENDIENTE');
final facturacionFilterRazonSocialProvider = StateProvider<String>((ref) => '');
final facturacionFilterRfcReceptorProvider = StateProvider<String>((ref) => '');
final facturacionFilterClienProvider = StateProvider<String>((ref) => '');
final facturacionFilterIdFolProvider = StateProvider<String>((ref) => '');
final facturacionFilterTipoFactProvider = StateProvider<String>((ref) => '');

final facturacionDraftFilterSucProvider = StateProvider<String>((ref) => '');
final facturacionDraftFilterEstatusProvider =
    StateProvider<String>((ref) => 'PENDIENTE');
final facturacionDraftFilterRazonSocialProvider =
    StateProvider<String>((ref) => '');
final facturacionDraftFilterRfcReceptorProvider =
    StateProvider<String>((ref) => '');
final facturacionDraftFilterClienProvider = StateProvider<String>((ref) => '');
final facturacionDraftFilterIdFolProvider = StateProvider<String>((ref) => '');
final facturacionDraftFilterTipoFactProvider =
    StateProvider<String>((ref) => '');

final facturacionFilterInputRevisionProvider = StateProvider<int>((ref) => 0);

final facturacionIdFolSelectionFilterProvider =
    StateProvider<Set<String>>((ref) => <String>{});

class FacturacionIdFolIssue {
  const FacturacionIdFolIssue({
    required this.idFol,
    required this.motivo,
  });

  final String idFol;
  final String motivo;
}

class FacturacionIdFolSelectorState {
  const FacturacionIdFolSelectorState({
    this.idFols = const <String>[],
    this.validos = const <String>[],
    this.issues = const <FacturacionIdFolIssue>[],
    this.validated = false,
  });

  final List<String> idFols;
  final List<String> validos;
  final List<FacturacionIdFolIssue> issues;
  final bool validated;

  FacturacionIdFolSelectorState copyWith({
    List<String>? idFols,
    List<String>? validos,
    List<FacturacionIdFolIssue>? issues,
    bool? validated,
  }) {
    return FacturacionIdFolSelectorState(
      idFols: idFols ?? this.idFols,
      validos: validos ?? this.validos,
      issues: issues ?? this.issues,
      validated: validated ?? this.validated,
    );
  }
}

class FacturacionIdFolSelectorNotifier
    extends StateNotifier<FacturacionIdFolSelectorState> {
  FacturacionIdFolSelectorNotifier()
      : super(const FacturacionIdFolSelectorState());

  List<String> _normalize(List<String> ids) {
    final out = <String>[];
    for (final raw in ids) {
      final value = raw.trim().toUpperCase();
      if (value.isEmpty || value == '-') continue;
      if (out.contains(value)) continue;
      out.add(value);
    }
    return out;
  }

  void setAll(List<String> ids, {bool append = false}) {
    final merged = append ? [...state.idFols, ...ids] : [...ids];
    state = FacturacionIdFolSelectorState(
      idFols: _normalize(merged),
      validos: const <String>[],
      issues: const <FacturacionIdFolIssue>[],
      validated: false,
    );
  }

  void add(String id) => setAll(<String>[id], append: true);

  void remove(String id) {
    final normalized = id.trim().toUpperCase();
    state = FacturacionIdFolSelectorState(
      idFols: state.idFols.where((item) => item != normalized).toList(),
      validos: const <String>[],
      issues: const <FacturacionIdFolIssue>[],
      validated: false,
    );
  }

  void setValidation(
    List<String> validos,
    List<FacturacionIdFolIssue> issues,
  ) {
    state = state.copyWith(
      validos: List<String>.unmodifiable(_normalize(validos)),
      issues: List<FacturacionIdFolIssue>.unmodifiable(issues),
      validated: true,
    );
  }

  void clear() {
    state = const FacturacionIdFolSelectorState();
  }
}

final facturacionIdFolSelectorProvider =
    StateNotifierProvider<FacturacionIdFolSelectorNotifier,
        FacturacionIdFolSelectorState>(
  (ref) => FacturacionIdFolSelectorNotifier(),
);

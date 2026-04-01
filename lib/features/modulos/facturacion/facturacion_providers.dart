import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'facturacion_api.dart';

final facturacionApiProvider = Provider<FacturacionApi>(
  (ref) => FacturacionApi(ref.read(dioProvider)),
);

final facturacionPageProvider = StateProvider<int>((ref) => 1);
final facturacionPageSizeProvider = StateProvider<int>((ref) => 60);

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

    return ref.read(facturacionApiProvider).fetchPendientes(
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

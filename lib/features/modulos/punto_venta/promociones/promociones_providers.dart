import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dio_provider.dart';
import 'promociones_api.dart';
import 'promociones_models.dart';

final promocionesApiProvider = Provider<PromocionesApi>(
  (ref) => PromocionesApi(ref.read(dioProvider)),
);

final promocionesListProvider =
    FutureProvider.autoDispose<List<PromocionModel>>((ref) async {
      final api = ref.read(promocionesApiProvider);
      return api.fetchPromociones(includeInactive: true);
    });

final promoSucursalesProvider =
    FutureProvider.autoDispose<List<CatalogTextOptionModel>>((ref) async {
      final api = ref.read(promocionesApiProvider);
      return api.fetchSucursales();
    });

final promoTiposPromocionProvider =
    FutureProvider.autoDispose<List<CatalogOptionModel>>((ref) async {
      final api = ref.read(promocionesApiProvider);
      return api.fetchCatalogOptions('t-prom');
    });

final promoConfigProvider = FutureProvider.autoDispose
    .family<PromoConfigModel?, int>((ref, idProm) async {
      final api = ref.read(promocionesApiProvider);
      return api.fetchConfig(idProm);
    });

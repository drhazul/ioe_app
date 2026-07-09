import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'cambio_forma_pago_api.dart';
import 'cambio_forma_pago_models.dart';

final cambioFormaPagoApiProvider = Provider<CambioFormaPagoApi>(
  (ref) => CambioFormaPagoApi(ref.read(dioProvider)),
);

class CambioFormaPagoSessionNotifier
    extends StateNotifier<CambioFormaPagoOverrideSession?> {
  CambioFormaPagoSessionNotifier() : super(null);

  void setSession(CambioFormaPagoOverrideSession session) {
    state = session;
  }

  void clear() {
    state = null;
  }

  CambioFormaPagoOverrideSession? readValidSession() {
    return state;
  }

  String? readValidToken() {
    final session = readValidSession();
    return session?.overrideToken;
  }
}

final cambioFormaPagoSessionProvider =
    StateNotifierProvider<
      CambioFormaPagoSessionNotifier,
      CambioFormaPagoOverrideSession?
    >((ref) => CambioFormaPagoSessionNotifier());

class CambioFormaPagoTodayFilter {
  const CambioFormaPagoTodayFilter({
    this.idfol = '',
    this.clien = '',
    this.suc = '',
    this.opv = '',
  });

  final String idfol;
  final String clien;
  final String suc;
  final String opv;

  CambioFormaPagoTodayFilter copyWith({
    String? idfol,
    String? clien,
    String? suc,
    String? opv,
  }) {
    return CambioFormaPagoTodayFilter(
      idfol: idfol ?? this.idfol,
      clien: clien ?? this.clien,
      suc: suc ?? this.suc,
      opv: opv ?? this.opv,
    );
  }
}

final cambioFormaPagoTodayFilterProvider =
    StateProvider.autoDispose<CambioFormaPagoTodayFilter>(
      (ref) => const CambioFormaPagoTodayFilter(),
    );

final cambioFormaPagoTodayProvider =
    FutureProvider.autoDispose<List<CambioFormaPagoItem>>((ref) async {
      final filter = ref.watch(cambioFormaPagoTodayFilterProvider);
      final api = ref.read(cambioFormaPagoApiProvider);
      return api.fetchToday(
        idfol: filter.idfol,
        clien: filter.clien,
        suc: filter.suc,
        opv: filter.opv,
      );
    });

final cambioFormaPagoCatalogProvider =
    FutureProvider.autoDispose<List<CambioFormaPagoCatalogItem>>((ref) async {
      final api = ref.read(cambioFormaPagoApiProvider);
      return api.fetchCatalog();
    });

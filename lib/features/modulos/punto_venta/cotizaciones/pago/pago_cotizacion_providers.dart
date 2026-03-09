import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'pago_cotizacion_api.dart';
import 'pago_cotizacion_models.dart';

const Object _errorUnset = Object();

class PagoCotizacionState {
  const PagoCotizacionState({
    required this.idfol,
    required this.loading,
    required this.submitting,
    required this.initialized,
    required this.tipotran,
    required this.rqfac,
    required this.context,
    required this.totales,
    required this.formas,
    required this.error,
  });

  factory PagoCotizacionState.initial(String idfol) => PagoCotizacionState(
    idfol: idfol,
    loading: false,
    submitting: false,
    initialized: false,
    tipotran: 'VF',
    rqfac: false,
    context: null,
    totales: null,
    formas: const [],
    error: null,
  );

  final String idfol;
  final bool loading;
  final bool submitting;
  final bool initialized;
  final String tipotran;
  final bool rqfac;
  final PagoCierreContext? context;
  final PagoCierreTotales? totales;
  final List<PagoCierreFormaDraft> formas;
  final String? error;

  String get visibleIdfol {
    final current = context?.idfol.trim() ?? '';
    return current.isNotEmpty ? current : idfol;
  }

  double get sumPagos => formas.fold(0.0, (acc, item) => acc + item.impp);

  PagoCotizacionState copyWith({
    bool? loading,
    bool? submitting,
    bool? initialized,
    String? tipotran,
    bool? rqfac,
    PagoCierreContext? context,
    PagoCierreTotales? totales,
    List<PagoCierreFormaDraft>? formas,
    Object? error = _errorUnset,
  }) {
    return PagoCotizacionState(
      idfol: idfol,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      initialized: initialized ?? this.initialized,
      tipotran: tipotran ?? this.tipotran,
      rqfac: rqfac ?? this.rqfac,
      context: context ?? this.context,
      totales: totales ?? this.totales,
      formas: formas ?? this.formas,
      error: identical(error, _errorUnset) ? this.error : error as String?,
    );
  }
}

final pagoCotizacionApiProvider = Provider<PagoCotizacionApi>(
  (ref) => PagoCotizacionApi(ref.read(dioProvider)),
);

final pagoFormasCatalogProvider =
    FutureProvider.autoDispose<List<PagoFormaCatalogItem>>((ref) async {
      final api = ref.read(pagoCotizacionApiProvider);
      return api.fetchFormasPago();
    });

final pagoCotizacionControllerProvider = StateNotifierProvider.autoDispose
    .family<PagoCotizacionController, PagoCotizacionState, String>(
      (ref, idfol) => PagoCotizacionController(
        ref.read(pagoCotizacionApiProvider),
        idfol: idfol,
      ),
    );

class PagoCotizacionController extends StateNotifier<PagoCotizacionState> {
  PagoCotizacionController(this._api, {required String idfol})
    : super(PagoCotizacionState.initial(idfol));

  final PagoCotizacionApi _api;

  Future<void> initialize({
    required String tipotran,
    required bool rqfac,
  }) async {
    final normalizedTipo = _normalizeTipoTran(tipotran);
    state = state.copyWith(
      loading: true,
      tipotran: normalizedTipo,
      rqfac: normalizedTipo == 'CA' ? false : rqfac,
      error: null,
    );

    try {
      final context = await _api.fetchContext(state.idfol);
      if (normalizedTipo == 'CA') {
        await _api.updateRqfac(idfol: state.idfol, rqfac: false);
      }
      final effectiveRqfac = normalizedTipo == 'CA'
          ? false
          : (rqfac || context.rqfacDefault);
      final preview = await _api.preview(
        idfol: state.idfol,
        tipotran: normalizedTipo,
        rqfac: effectiveRqfac,
        suc: context.suc,
      );

      state = state.copyWith(
        loading: false,
        initialized: true,
        context: preview.context,
        tipotran: normalizedTipo,
        rqfac: preview.totales.rqfac,
        totales: preview.totales,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        initialized: false,
        error: apiErrorMessage(e, fallback: 'No se pudo inicializar pago'),
      );
    }
  }

  Future<void> setTipoTran(String tipotran) async {
    final normalized = _normalizeTipoTran(tipotran);
    if (normalized == state.tipotran) return;
    if (state.formas.isNotEmpty) {
      state = state.copyWith(
        error:
            'No se puede cambiar el tipo de cierre cuando ya hay formas de pago registradas',
      );
      return;
    }
    final previousTipo = state.tipotran;
    final previousRqfac = state.rqfac;
    final nextRqfac = normalized == 'CA' ? false : state.rqfac;
    state = state.copyWith(tipotran: normalized, rqfac: nextRqfac, error: null);

    if (normalized == 'CA') {
      try {
        await _api.updateRqfac(idfol: state.idfol, rqfac: false);
      } catch (e) {
        state = state.copyWith(
          tipotran: previousTipo,
          rqfac: previousRqfac,
          error: apiErrorMessage(
            e,
            fallback: 'No se pudo actualizar RQFAC para cierre CA',
          ),
        );
        return;
      }
    }

    await _refreshPreview();
  }

  Future<void> setRqfac(bool value) async {
    if (state.tipotran == 'CA') return;
    if (state.formas.isNotEmpty) {
      state = state.copyWith(
        error:
            'No se puede cambiar RQFAC cuando ya hay formas de pago registradas',
      );
      return;
    }
    final previous = state.rqfac;
    state = state.copyWith(rqfac: value, error: null);
    try {
      await _api.updateRqfac(idfol: state.idfol, rqfac: value);
      await _refreshPreview();
    } catch (e) {
      state = state.copyWith(
        loading: false,
        rqfac: previous,
        error: apiErrorMessage(e, fallback: 'No se pudo guardar RQFAC'),
      );
    }
  }

  void addForma({required String form, required double impp, String? aut}) {
    final total = state.totales?.total ?? 0.0;
    final faltante = _round2(
      total > state.sumPagos ? total - state.sumPagos : 0.0,
    );
    final isEfectivo = form.trim().toUpperCase() == 'EFECTIVO';
    if (total > 0 && (state.sumPagos + 0.0001) >= total) {
      state = state.copyWith(
        error:
            'El importe de la cotización ya está cubierto. No puede agregar más formas de pago',
      );
      return;
    }
    if (!isEfectivo && total > 0 && impp - faltante > 0.0001) {
      state = state.copyWith(
        error:
            'El importe de la forma no puede ser mayor al faltante por pagar (${_money(faltante)})',
      );
      return;
    }

    final next = [
      ...state.formas,
      PagoCierreFormaDraft(
        id: _nextId(),
        form: form.toUpperCase().trim(),
        impp: impp,
        aut: aut?.trim().isEmpty ?? true ? null : aut!.trim(),
      ),
    ];
    state = state.copyWith(formas: next, error: null);
  }

  void updateForma(
    String id, {
    required String form,
    required double impp,
    String? aut,
  }) {
    final total = state.totales?.total ?? 0.0;
    final sumOtros = state.formas
        .where((item) => item.id != id)
        .fold(0.0, (acc, item) => acc + item.impp);
    final faltante = _round2(total > sumOtros ? total - sumOtros : 0.0);
    final isEfectivo = form.trim().toUpperCase() == 'EFECTIVO';
    if (!isEfectivo && total > 0 && impp - faltante > 0.0001) {
      state = state.copyWith(
        error:
            'El importe de la forma no puede ser mayor al faltante por pagar (${_money(faltante)})',
      );
      return;
    }

    final next = state.formas.map((item) {
      if (item.id != id) return item;
      return item.copyWith(
        form: form.toUpperCase().trim(),
        impp: impp,
        aut: aut?.trim().isEmpty ?? true ? null : aut!.trim(),
      );
    }).toList();
    state = state.copyWith(formas: next, error: null);
  }

  void removeForma(String id) {
    final next = state.formas.where((item) => item.id != id).toList();
    state = state.copyWith(formas: next, error: null);
  }

  Future<PagoCierreResponse> finalizar({String? idopv}) async {
    if (state.totales == null || state.context == null) {
      throw Exception('No se pudo cargar el contexto de cierre');
    }
    if (state.formas.isEmpty) {
      throw Exception('Debe agregar al menos una forma de pago');
    }

    state = state.copyWith(submitting: true, error: null);
    try {
      final response = await _api.cerrar(
        idfol: state.idfol,
        suc: state.context!.suc,
        tipotran: state.tipotran,
        rqfac: state.rqfac,
        idopv: idopv,
        formas: state.formas,
      );
      PagoCierreContext? refreshedContext;
      try {
        refreshedContext = await _api.fetchContext(response.idfol);
      } catch (_) {
        try {
          refreshedContext = await _api.fetchContext(state.idfol);
        } catch (_) {
          refreshedContext = null;
        }
      }
      state = state.copyWith(
        submitting: false,
        context: refreshedContext ?? state.context,
        totales: response.totales,
        error: null,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        error: apiErrorMessage(e, fallback: 'No se pudo finalizar el cierre'),
      );
      rethrow;
    }
  }

  Future<void> _refreshPreview() async {
    final context = state.context;
    if (context == null) return;

    state = state.copyWith(loading: true, error: null);
    try {
      final preview = await _api.preview(
        idfol: state.idfol,
        tipotran: state.tipotran,
        rqfac: state.rqfac,
        suc: context.suc,
      );
      state = state.copyWith(
        loading: false,
        context: preview.context,
        rqfac: preview.totales.rqfac,
        totales: preview.totales,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: apiErrorMessage(e, fallback: 'No se pudo recalcular totales'),
      );
    }
  }

  String _normalizeTipoTran(String value) {
    final text = value.trim().toUpperCase();
    return text == 'CA' ? 'CA' : 'VF';
  }

  String _nextId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    // En Flutter Web, `1 << 32` puede evaluarse a 0; usar literal evita RangeError.
    final random = Random.secure().nextInt(0x100000000).toRadixString(16);
    return '$now-$random';
  }
}

double _round2(double value) =>
    (value.isFinite ? (value * 100).roundToDouble() / 100 : 0.0);

String _money(double value) => '\$${value.toStringAsFixed(2)}';

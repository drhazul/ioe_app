import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'ctrl_ctas_api.dart';
import 'ctrl_ctas_models.dart';

final ctrlCtasApiProvider = Provider<CtrlCtasApi>((ref) {
  return CtrlCtasApi(ref.read(dioProvider));
});

final ctrlCtasConfigProvider = FutureProvider.autoDispose<CtrlCtasConfig>((ref) async {
  final api = ref.read(ctrlCtasApiProvider);
  return api.getConfig();
});

class CtrlCtasFiltrosNotifier extends StateNotifier<CtrlCtasFiltros> {
  CtrlCtasFiltrosNotifier() : super(const CtrlCtasFiltros());

  List<String> _normalize(List<String> values) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      out.add(value);
    }
    return out;
  }

  void reset() => state = const CtrlCtasFiltros();

  void setSucs(List<String> values) => state = state.copyWith(sucs: _normalize(values));

  void setCtas(List<String> values) => state = state.copyWith(ctas: _normalize(values));

  void setClients(List<String> values) => state = state.copyWith(clients: _normalize(values));

  void setClsds(List<String> values) => state = state.copyWith(clsds: _normalize(values));

  void setIdfols(List<String> values) => state = state.copyWith(idfols: _normalize(values));

  void setOpvs(List<String> values) => state = state.copyWith(opvs: _normalize(values));

  void setFecIni(DateTime? value) => state = state.copyWith(fecIni: value, clearFecIni: value == null);

  void setFecFin(DateTime? value) => state = state.copyWith(fecFin: value, clearFecFin: value == null);
}

final ctrlCtasFiltrosProvider = StateNotifierProvider<CtrlCtasFiltrosNotifier, CtrlCtasFiltros>((ref) {
  return CtrlCtasFiltrosNotifier();
});

final catCtasProvider = FutureProvider.autoDispose.family<List<CtrlCtaOption>, CtrlCatalogParams>((ref, params) async {
  final api = ref.read(ctrlCtasApiProvider);
  return api.getCatalogCtas(search: params.search, sucs: params.sucs, limit: params.limit);
});

final clientesProvider = FutureProvider.autoDispose.family<List<CtrlClienteOption>, CtrlCatalogParams>((ref, params) async {
  final api = ref.read(ctrlCtasApiProvider);
  return api.getCatalogClientes(search: params.search, sucs: params.sucs, limit: params.limit);
});

final opvProvider = FutureProvider.autoDispose.family<List<CtrlOpvOption>, CtrlCatalogParams>((ref, params) async {
  final api = ref.read(ctrlCtasApiProvider);
  return api.getCatalogOpvs(search: params.search, sucs: params.sucs, limit: params.limit);
});

final ctrlCtasResumenClienteProvider =
    FutureProvider.autoDispose.family<List<CtrlCtasResumenClienteItem>, CtrlCtasFiltros>((ref, filtros) async {
  final api = ref.read(ctrlCtasApiProvider);
  return api.resumenCliente(filtros);
});

final ctrlCtasResumenTransProvider =
    FutureProvider.autoDispose.family<List<CtrlCtasResumenTransItem>, CtrlCtasFiltros>((ref, filtros) async {
  final api = ref.read(ctrlCtasApiProvider);
  return api.resumenTransaccion(filtros);
});

final ctrlCtasDetalleProvider =
    FutureProvider.autoDispose.family<List<CtrlCtasDetalleItem>, CtrlCtasFiltros>((ref, filtros) async {
  final api = ref.read(ctrlCtasApiProvider);
  return api.detalle(filtros);
});

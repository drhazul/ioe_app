import 'package:dio/dio.dart';

import 'ctrl_ctas_models.dart';

class CtrlCtasApi {
  final Dio dio;

  CtrlCtasApi(this.dio);

  Future<CtrlCtasConfig> getConfig() async {
    final res = await dio.get('/ctrl-ctas/config');
    if (res.data is Map) {
      return CtrlCtasConfig.fromJson(Map<String, dynamic>.from(res.data as Map));
    }
    return const CtrlCtasConfig(hasIdopv: false, isAdmin: false, forcedSuc: null);
  }

  Future<List<CtrlCtaOption>> getCatalogCtas({
    String? search,
    List<String>? sucs,
    int limit = 200,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    final searchText = (search ?? '').trim();
    if (searchText.isNotEmpty) query['search'] = searchText;
    final sucsList = _normalizeList(sucs);
    if (sucsList.isNotEmpty) query['sucs'] = sucsList.join(',');

    final res = await dio.get('/ctrl-ctas/catalog/ctas', queryParameters: query);
    return _asList(res.data).map((row) => CtrlCtaOption.fromJson(row)).toList();
  }

  Future<List<CtrlClienteOption>> getCatalogClientes({
    String? search,
    List<String>? sucs,
    int limit = 200,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    final searchText = (search ?? '').trim();
    if (searchText.isNotEmpty) query['search'] = searchText;
    final sucsList = _normalizeList(sucs);
    if (sucsList.isNotEmpty) query['sucs'] = sucsList.join(',');

    final res = await dio.get('/ctrl-ctas/catalog/clientes', queryParameters: query);
    return _asList(res.data).map((row) => CtrlClienteOption.fromJson(row)).toList();
  }

  Future<List<CtrlOpvOption>> getCatalogOpvs({
    String? search,
    List<String>? sucs,
    int limit = 200,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    final searchText = (search ?? '').trim();
    if (searchText.isNotEmpty) query['search'] = searchText;
    final sucsList = _normalizeList(sucs);
    if (sucsList.isNotEmpty) query['sucs'] = sucsList.join(',');

    final res = await dio.get('/ctrl-ctas/catalog/opvs', queryParameters: query);
    return _asList(res.data).map((row) => CtrlOpvOption.fromJson(row)).toList();
  }

  Future<List<CtrlCtasResumenClienteItem>> resumenCliente(CtrlCtasFiltros filtros) async {
    final res = await dio.post('/ctrl-ctas/consulta/resumen-cliente', data: filtros.toApiJson());
    return _asList(res.data).map((row) => CtrlCtasResumenClienteItem.fromJson(row)).toList();
  }

  Future<List<CtrlCtasResumenTransItem>> resumenTransaccion(CtrlCtasFiltros filtros) async {
    final res = await dio.post('/ctrl-ctas/consulta/resumen-transaccion', data: filtros.toApiJson());
    return _asList(res.data).map((row) => CtrlCtasResumenTransItem.fromJson(row)).toList();
  }

  Future<List<CtrlCtasDetalleItem>> detalle(CtrlCtasFiltros filtros) async {
    final res = await dio.post('/ctrl-ctas/consulta/detalle', data: filtros.toApiJson());
    return _asList(res.data).map((row) => CtrlCtasDetalleItem.fromJson(row)).toList();
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final rawItems = map['items'];
      if (rawItems is List) {
        return rawItems.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      }
    }
    return const [];
  }

  List<String> _normalizeList(List<String>? values) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in values ?? const <String>[]) {
      final value = raw.trim();
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      out.add(value);
    }
    return out;
  }
}

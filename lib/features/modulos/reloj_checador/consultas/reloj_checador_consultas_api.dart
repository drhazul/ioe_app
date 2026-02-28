import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'reloj_checador_consultas_models.dart';

class RelojChecadorConsultasApi {
  RelojChecadorConsultasApi(this.dio);

  final Dio dio;

  Future<RelojChecadorListResponse<TimelogItem>> listTimelogs(
    TimelogFilters filters,
  ) async {
    final res = await dio.get(
      '/reloj-checador/timelogs',
      queryParameters: filters.toQuery(),
    );

    final map = _asMap(res.data);
    final list = _asList(map['items']);
    return RelojChecadorListResponse<TimelogItem>(
      items: list.map((e) => TimelogItem.fromJson(e)).toList(),
      total: _asInt(map['total']) ?? list.length,
      page: _asInt(map['page']) ?? filters.page,
      limit: _asInt(map['limit']) ?? filters.limit,
    );
  }

  Future<TimelogItem> updateTimelog(
    String idTimelog,
    Map<String, dynamic> data,
  ) async {
    final res = await dio.put('/reloj-checador/timelog/$idTimelog', data: data);
    return TimelogItem.fromJson(_asMap(res.data));
  }

  Future<RelojChecadorListResponse<IncidenciaItem>> listIncidencias({
    String? suc,
    int? idUsuario,
    String? dateFrom,
    String? dateTo,
    String? estatus,
    String? tipo,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    if (idUsuario != null) query['idUsuario'] = idUsuario;
    if ((dateFrom ?? '').trim().isNotEmpty) query['dateFrom'] = dateFrom;
    if ((dateTo ?? '').trim().isNotEmpty) query['dateTo'] = dateTo;
    if ((estatus ?? '').trim().isNotEmpty) query['estatus'] = estatus;
    if ((tipo ?? '').trim().isNotEmpty) query['tipo'] = tipo;

    final res = await dio.get(
      '/reloj-checador/incidencias',
      queryParameters: query,
    );
    final map = _asMap(res.data);
    final list = _asList(map['items']);

    return RelojChecadorListResponse<IncidenciaItem>(
      items: list.map((e) => IncidenciaItem.fromJson(e)).toList(),
      total: _asInt(map['total']) ?? list.length,
      page: _asInt(map['page']) ?? page,
      limit: _asInt(map['limit']) ?? limit,
    );
  }

  Future<IncidenciaItem> createIncidencia(Map<String, dynamic> payload) async {
    final res = await dio.post('/reloj-checador/incidencias', data: payload);
    return IncidenciaItem.fromJson(_asMap(res.data));
  }

  Future<IncidenciaItem> updateIncidenciaStatus(
    String idInc,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.put(
      '/reloj-checador/incidencias/$idInc/status',
      data: payload,
    );
    return IncidenciaItem.fromJson(_asMap(res.data));
  }

  Future<RelojChecadorListResponse<DocumentoItem>> listDocumentos({
    int? userId,
    int? incId,
    String? suc,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (userId != null) query['userId'] = userId;
    if (incId != null) query['incId'] = incId;
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();

    final res = await dio.get(
      '/reloj-checador/documentos',
      queryParameters: query,
    );
    final map = _asMap(res.data);
    final list = _asList(map['items']);

    return RelojChecadorListResponse<DocumentoItem>(
      items: list.map((e) => DocumentoItem.fromJson(e)).toList(),
      total: _asInt(map['total']) ?? list.length,
      page: _asInt(map['page']) ?? page,
      limit: _asInt(map['limit']) ?? limit,
    );
  }

  Future<DocumentoItem> uploadDocumento(Map<String, dynamic> payload) async {
    final res = await dio.post('/reloj-checador/documentos', data: payload);
    return DocumentoItem.fromJson(_asMap(res.data));
  }

  Future<Map<String, dynamic>> downloadDocumento(String idDoc) async {
    final res = await dio.get(
      '/reloj-checador/documentos/$idDoc/download',
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = Uint8List.fromList(List<int>.from(res.data as List<dynamic>));
    final mimeType =
        res.headers.value(Headers.contentTypeHeader) ??
        'application/octet-stream';
    final disposition = res.headers.value('content-disposition') ?? '';

    return {
      'bytes': bytes,
      'mimeType': mimeType,
      'contentDisposition': disposition,
    };
  }

  Future<RelojChecadorListResponse<OverrideItem>> listOverrides({
    String? suc,
    int? idUsuario,
    bool activeOnly = true,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'activeOnly': activeOnly,
      'page': page,
      'limit': limit,
    };
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    if (idUsuario != null) query['idUsuario'] = idUsuario;

    final res = await dio.get(
      '/reloj-checador/overrides',
      queryParameters: query,
    );
    final map = _asMap(res.data);
    final list = _asList(map['items']);

    return RelojChecadorListResponse<OverrideItem>(
      items: list.map((e) => OverrideItem.fromJson(e)).toList(),
      total: _asInt(map['total']) ?? list.length,
      page: _asInt(map['page']) ?? page,
      limit: _asInt(map['limit']) ?? limit,
    );
  }

  Future<OverrideItem> createOverride(Map<String, dynamic> payload) async {
    final res = await dio.post('/reloj-checador/overrides', data: payload);
    return OverrideItem.fromJson(_asMap(res.data));
  }

  Future<OverrideItem> revokeOverride(String idOvr, String reason) async {
    final res = await dio.put(
      '/reloj-checador/overrides/$idOvr/revoke',
      data: {'REASON': reason},
    );
    return OverrideItem.fromJson(_asMap(res.data));
  }

  Future<PolicyModel> getPolicy({required String suc, int? idDepto}) async {
    final query = <String, dynamic>{'suc': suc};
    if (idDepto != null) query['idDepto'] = idDepto;

    final res = await dio.get('/reloj-checador/policy', queryParameters: query);
    return PolicyModel.fromJson(_asMap(res.data));
  }

  Future<PolicyModel> upsertPolicy(Map<String, dynamic> payload) async {
    final res = await dio.post('/reloj-checador/policy', data: payload);
    return PolicyModel.fromJson(_asMap(res.data));
  }

  Future<List<Map<String, dynamic>>> fetchSucs() async {
    final res = await dio.get('/dat-suc');
    return _asList(res.data);
  }

  Future<bool> canManageOverrides() async {
    try {
      await listOverrides(limit: 1);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return false;
      rethrow;
    }
  }

  Future<bool> canManagePolicies({required String suc}) async {
    try {
      await getPolicy(suc: suc);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return false;
      rethrow;
    }
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is List) {
    return value.map((e) => _asMap(e)).toList();
  }
  return const <Map<String, dynamic>>[];
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

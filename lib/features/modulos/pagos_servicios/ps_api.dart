import 'package:dio/dio.dart';

import 'ps_models.dart';

class PsApi {
  PsApi(this.dio);

  final Dio dio;

  Future<List<PsFolioItem>> fetchFolios({
    String? suc,
    String? esta,
    String? search,
  }) async {
    final res = await dio.get(
      '/ps/folios',
      queryParameters: {
        if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
        if ((esta ?? '').trim().isNotEmpty) 'esta': esta!.trim(),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
    );

    final raw = res.data;
    final List items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = (raw['items'] as List?) ?? const [];
    } else {
      items = const [];
    }

    return items
        .map(
          (item) => PsFolioItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> createFolio({
    required String suc,
    String? ter,
    required String opv,
  }) async {
    final res = await dio.post(
      '/ps/folios',
      data: {
        'suc': suc.trim(),
        if ((ter ?? '').trim().isNotEmpty) 'ter': ter!.trim(),
        'opv': opv.trim(),
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<PsDetalleResponse> fetchDetalle(String idFol) async {
    final res = await dio.get('/ps/folios/$idFol');
    return PsDetalleResponse.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Map<String, dynamic>> addService({
    required String idFol,
    required String ids,
  }) async {
    final res = await dio.post(
      '/ps/folios/$idFol/ticket/service',
      data: {'ids': ids.trim().toUpperCase()},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<PsAdeudosResponse> fetchAdeudosCliente(int client) async {
    final res = await dio.get('/ps/clientes/$client/adeudos');
    return PsAdeudosResponse.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<PsClienteItem>> fetchClientes() async {
    final res = await dio.get('/factclientshp');
    final raw = res.data;
    final List items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = (raw['items'] as List?) ?? const [];
    } else {
      items = const [];
    }

    return items
        .map(
          (item) => PsClienteItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> updateFolioCliente({
    required String idFol,
    required int clien,
  }) async {
    final res = await dio.put(
      '/ps/folios/$idFol/cliente',
      data: {'clien': clien},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setReferenceFolio({
    required String idFol,
    required String art,
    required String idFolRef,
  }) async {
    final res = await dio.post(
      '/ps/folios/$idFol/ticket/reference/folio',
      data: {
        'art': art.trim(),
        'idFolRef': idFolRef.trim(),
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setReferenceGasto({
    required String idFol,
    required String art,
    required String refGasto,
  }) async {
    final res = await dio.post(
      '/ps/folios/$idFol/ticket/reference/gasto',
      data: {
        'art': art.trim(),
        'refGasto': refGasto.trim(),
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updatePvta({
    required String idFol,
    required String art,
    required double pvta,
  }) async {
    final res = await dio.put(
      '/ps/folios/$idFol/ticket/pvta',
      data: {
        'art': art.trim(),
        'pvta': pvta,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> deleteLine({
    required String idFol,
    required String art,
  }) async {
    await dio.delete(
      '/ps/folios/$idFol/ticket/line',
      data: {'art': art.trim()},
    );
  }

  Future<Map<String, dynamic>> procesar(String idFol) async {
    final res = await dio.post('/ps/folios/$idFol/procesar');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<PsPagoSummary> addFormaPago({
    required String idFol,
    required String form,
    required double impp,
    String? aut,
  }) async {
    final res = await dio.post(
      '/ps/folios/$idFol/formas-pago',
      data: {
        'form': form.trim().toUpperCase(),
        'impp': impp,
        if ((aut ?? '').trim().isNotEmpty) 'aut': aut!.trim(),
      },
    );
    return PsPagoSummary.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PsPagoSummary> deleteFormaPago({
    required String idFol,
    required String idF,
  }) async {
    final res = await dio.delete('/ps/folios/$idFol/formas-pago/$idF');
    return PsPagoSummary.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PsPagoSummary> fetchSummary(String idFol) async {
    final res = await dio.get('/ps/folios/$idFol/formas-pago/summary');
    return PsPagoSummary.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Map<String, dynamic>> terminar(String idFol) async {
    final res = await dio.post('/ps/folios/$idFol/terminar');
    return Map<String, dynamic>.from(res.data as Map);
  }
}

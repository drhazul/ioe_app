import 'package:dio/dio.dart';

import 'pago_cotizacion_models.dart';

class PagoCotizacionApi {
  PagoCotizacionApi(this.dio);

  final Dio dio;

  Future<PagoCierreContext> fetchContext(String idfol) async {
    final res = await dio.get('/pv/cotizaciones/$idfol/cierre/context');
    final data = Map<String, dynamic>.from(res.data as Map);
    return PagoCierreContext.fromJson(data);
  }

  Future<PagoCierrePreviewResponse> preview({
    required String idfol,
    required String tipotran,
    required bool rqfac,
    String? suc,
  }) async {
    final payload = <String, dynamic>{
      'tipotran': tipotran.toUpperCase(),
      'rqfac': rqfac,
      if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
    };
    final res = await dio.post(
      '/pv/cotizaciones/$idfol/cierre/preview',
      data: payload,
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return PagoCierrePreviewResponse.fromJson(data);
  }

  Future<PagoCierreResponse> cerrar({
    required String idfol,
    required String tipotran,
    required bool rqfac,
    required List<PagoCierreFormaDraft> formas,
    String? suc,
    String? idopv,
  }) async {
    final payload = <String, dynamic>{
      if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
      'tipotran': tipotran.toUpperCase(),
      'rqfac': rqfac,
      if ((idopv ?? '').trim().isNotEmpty) 'idopv': idopv!.trim(),
      'formas': formas.map((item) => item.toApiJson()).toList(),
    };

    final res = await dio.post('/pv/cotizaciones/$idfol/cierre', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return PagoCierreResponse.fromJson(data);
  }

  Future<PagoCierrePrintPreviewResponse> fetchPrintPreview(String idfol) async {
    final res = await dio.get('/pv/cotizaciones/$idfol/cierre/print-preview');
    final data = Map<String, dynamic>.from(res.data as Map);
    return PagoCierrePrintPreviewResponse.fromJson(data);
  }

  Future<void> updateRqfac({required String idfol, required bool rqfac}) async {
    await dio.patch(
      '/pvctrfolasvr/$idfol',
      data: <String, dynamic>{'REQF': rqfac ? 1 : 0},
    );
  }

  Future<void> updateEstado({
    required String idfol,
    required String esta,
  }) async {
    await dio.patch(
      '/pvctrfolasvr/$idfol',
      data: <String, dynamic>{'ESTA': esta.trim().toUpperCase()},
    );
  }

  Future<List<PagoFormaCatalogItem>> fetchFormasPago({
    bool includeInactive = false,
  }) async {
    final res = await dio.get(
      '/dat-form',
      queryParameters: {if (includeInactive) 'includeInactive': 'true'},
    );
    final data = res.data;
    if (data is! List) return const [];

    return data
        .map(
          (row) => PagoFormaCatalogItem.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((item) => item.form.isNotEmpty)
        .toList();
  }
}

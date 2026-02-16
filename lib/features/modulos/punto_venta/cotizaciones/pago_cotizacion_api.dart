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
    final res = await dio.post('/pv/cotizaciones/$idfol/cierre/preview', data: payload);
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
}


import 'package:dio/dio.dart';

import 'cotizaciones_models.dart';

class CotizacionesApi {
  CotizacionesApi(this.dio);

  final Dio dio;

  Future<List<PvCtrFolAsvrModel>> fetchCotizaciones({
    String? suc,
    String? opv,
    String? search,
  }) async {
    final res = await dio.get(
      '/pvctrfolasvr',
      queryParameters: {
        if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
        if ((opv ?? '').trim().isNotEmpty) 'opv': opv!.trim(),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
    );

    final raw = res.data;
    final List rows;
    if (raw is List) {
      rows = raw;
    } else if (raw is Map) {
      rows = (raw['items'] as List?) ?? const [];
    } else {
      rows = const [];
    }

    return rows
        .map(
          (e) => PvCtrFolAsvrModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<PvCtrFolAsvrModel> fetchCotizacion(String idfol) async {
    final res = await dio.get('/pvctrfolasvr/$idfol');
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PvCtrFolAsvrModel> createCotizacion(Map<String, dynamic> payload) async {
    final res = await dio.post('/pvctrfolasvr', data: payload);
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PvCtrFolAsvrModel> createCotizacionAuto({String? ter}) async {
    final payload = <String, dynamic>{};
    final terTrim = (ter ?? '').trim();
    if (terTrim.isNotEmpty) payload['TER'] = terTrim;
    final res = await dio.post('/pvctrfolasvr/auto', data: payload);
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PvCtrFolAsvrModel> updateCotizacion(String idfol, Map<String, dynamic> payload) async {
    final res = await dio.patch('/pvctrfolasvr/$idfol', data: payload);
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteCotizacion(String idfol) async {
    await dio.delete('/pvctrfolasvr/$idfol');
  }
}

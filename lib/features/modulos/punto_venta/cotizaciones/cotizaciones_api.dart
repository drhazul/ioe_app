import 'package:dio/dio.dart';

import 'cotizaciones_models.dart';

class CotizacionesApi {
  CotizacionesApi(this.dio);

  final Dio dio;

  Future<List<PvCtrFolAsvrModel>> fetchCotizaciones() async {
    final res = await dio.get('/pvctrfolasvr', queryParameters: {'_': DateTime.now().millisecondsSinceEpoch});
    final list = (res.data as List<dynamic>)
        .map((e) => PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<PvCtrFolAsvrModel> fetchCotizacion(String idfol) async {
    final res =
        await dio.get('/pvctrfolasvr/$idfol', queryParameters: {'_': DateTime.now().millisecondsSinceEpoch});
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

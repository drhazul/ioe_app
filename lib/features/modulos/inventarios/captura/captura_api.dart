import 'package:dio/dio.dart';

import 'captura_models.dart';

class CapturaApi {
  final Dio dio;
  CapturaApi(this.dio);

  Future<List<ConteoDisponible>> fetchConteosDisponibles() async {
    final res = await dio.get('/capturas/conteos-disponibles');
    return (res.data as List<dynamic>)
        .map((e) => ConteoDisponible.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CapturaResult> registrarCaptura({
    required String cont,
    required String almacen,
    required String upc,
    required double cantidad,
    required String capturaUuid,
    String? art,
    String? suc,
  }) async {
    final payload = <String, dynamic>{
      'cont': cont,
      'almacen': almacen,
      'upc': upc,
      'cantidad': cantidad,
      'capturaUuid': capturaUuid,
      if (art != null && art.isNotEmpty) 'art': art,
      if (suc != null && suc.isNotEmpty) 'suc': suc,
    };

    final res = await dio.post('/capturas', data: payload);
    return CapturaResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<CapturaListResponse> listarCapturas({
    required String cont,
    String? almacen,
    String? upc,
    int page = 1,
    int limit = 50,
    String? suc,
  }) async {
    final res = await dio.get('/capturas', queryParameters: {
      'cont': cont,
      if (almacen != null && almacen.isNotEmpty) 'almacen': almacen,
      if (upc != null && upc.isNotEmpty) 'upc': upc,
      'page': page,
      'limit': limit,
      if (suc != null && suc.isNotEmpty) 'suc': suc,
    });

    return CapturaListResponse.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}

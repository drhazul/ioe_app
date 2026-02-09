import 'package:dio/dio.dart';

import 'mb51_models.dart';

class Mb51Api {
  Mb51Api(this.dio);

  final Dio dio;

  Future<Mb51SearchResult> searchMb51(Mb51Filtros filtros) async {
    final payload = filtros.toApiJson();
    final res = await dio.post(
      '/dat-mb51/search',
      data: payload.isEmpty ? {} : payload,
    );
    if (res.data is Map<String, dynamic>) {
      return Mb51SearchResult.fromJson(Map<String, dynamic>.from(res.data as Map));
    }
    if (res.data is List) {
      final items = (res.data as List<dynamic>)
          .map((e) => DatMb51Model.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return Mb51SearchResult(items: items, total: items.length, page: 1, limit: items.length);
    }
    return Mb51SearchResult(items: const [], total: 0, page: 1, limit: 0);
  }

  Future<List<DatAlmacenModel>> getAlmacenes() async {
    final res = await dio.get('/dat-almacen');
    if (res.data is List) {
      return (res.data as List<dynamic>)
          .map((e) => DatAlmacenModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<List<DatCmovModel>> getClasesMovimiento() async {
    final res = await dio.get('/dat-cmov');
    if (res.data is List) {
      return (res.data as List<dynamic>)
          .map((e) => DatCmovModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }
}

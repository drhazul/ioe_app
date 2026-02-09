import 'package:dio/dio.dart';

import 'mb52_models.dart';

class Mb52Api {
  Mb52Api(this.dio);

  final Dio dio;

  Future<List<DatMb52ResumenModel>> fetchResumen(Mb52Filtros filtros) async {
    final payload = filtros.toApiJson();
    final res = await dio.post(
      '/dat-mb52/resumen',
      data: payload.isEmpty ? {} : payload,
    );
    if (res.data is List) {
      return (res.data as List<dynamic>)
          .map((e) => DatMb52ResumenModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (res.data is Map<String, dynamic>) {
      final map = Map<String, dynamic>.from(res.data as Map);
      final items = (map['items'] as List<dynamic>? ?? [])
          .map((e) => DatMb52ResumenModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return items;
    }
    return [];
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
}

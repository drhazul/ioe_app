import 'package:dio/dio.dart';

import 'datmodulos_models.dart';

class DatmodulosApi {
  final Dio dio;
  DatmodulosApi(this.dio);

  Future<List<DatModuloModel>> fetchModulos({String? codigo, String? depto, String? nombre}) async {
    final query = <String, dynamic>{};
    if (codigo != null && codigo.isNotEmpty) query['codigo'] = codigo;
    if (depto != null && depto.isNotEmpty) query['depto'] = depto;
    if (nombre != null && nombre.isNotEmpty) query['nombre'] = nombre;

    final res = await dio.get('/datmodulos', queryParameters: query.isEmpty ? null : query);
    return (res.data as List<dynamic>)
        .map((e) => DatModuloModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DatModuloModel> fetchModulo(String codigo) async {
    final res = await dio.get('/datmodulos/$codigo');
    return DatModuloModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatModuloModel> createModulo(Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.post('/datmodulos', data: body);
    return DatModuloModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatModuloModel> updateModulo(String codigo, Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.patch('/datmodulos/$codigo', data: body);
    return DatModuloModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteModulo(String codigo) async {
    await dio.delete('/datmodulos/$codigo');
  }

  Map<String, dynamic> _clean(Map<String, dynamic> payload) => Map<String, dynamic>.from(payload);
}

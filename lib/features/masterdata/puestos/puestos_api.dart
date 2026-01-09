import 'package:dio/dio.dart';

import 'puestos_models.dart';

class PuestosApi {
  final Dio dio;
  PuestosApi(this.dio);

  Future<List<PuestoModel>> fetchPuestos({int? iddepto, String? nombre, bool? activo}) async {
    final query = <String, dynamic>{};
    if (iddepto != null) query['iddepto'] = iddepto;
    if (nombre != null && nombre.isNotEmpty) query['nombre'] = nombre;
    if (activo != null) query['activo'] = activo.toString();

    final res = await dio.get('/puestos', queryParameters: query.isEmpty ? null : query);
    return (res.data as List<dynamic>)
        .map((e) => PuestoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PuestoModel> fetchPuesto(int id) async {
    final res = await dio.get('/puestos/$id');
    return PuestoModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PuestoModel> createPuesto(Map<String, dynamic> payload) async {
    final res = await dio.post('/puestos', data: Map<String, dynamic>.from(payload));
    return PuestoModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PuestoModel> updatePuesto(int id, Map<String, dynamic> payload) async {
    final res = await dio.patch('/puestos/$id', data: Map<String, dynamic>.from(payload));
    return PuestoModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deletePuesto(int id) async {
    await dio.delete('/puestos/$id');
  }
}

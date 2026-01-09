import 'package:dio/dio.dart';

import 'deptos_models.dart';

class DeptosApi {
  final Dio dio;
  DeptosApi(this.dio);

  Future<List<DeptoModel>> fetchDeptos({String? nombre, bool? activo}) async {
    final query = <String, dynamic>{};
    if (nombre != null && nombre.isNotEmpty) query['nombre'] = nombre;
    if (activo != null) query['activo'] = activo.toString();

    final res = await dio.get('/deptos', queryParameters: query.isEmpty ? null : query);
    final list = (res.data as List<dynamic>).map((e) => DeptoModel.fromJson(Map<String, dynamic>.from(e))).toList();
    return list;
  }

  Future<DeptoModel> fetchDepto(int id) async {
    final res = await dio.get('/deptos/$id');
    return DeptoModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DeptoModel> createDepto(Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.post('/deptos', data: body);
    return DeptoModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DeptoModel> updateDepto(int id, Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.patch('/deptos/$id', data: body);
    return DeptoModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteDepto(int id) async {
    await dio.delete('/deptos/$id');
  }

  Map<String, dynamic> _clean(Map<String, dynamic> payload) {
    return Map<String, dynamic>.from(payload);
  }
}

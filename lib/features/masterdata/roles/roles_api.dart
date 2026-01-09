import 'package:dio/dio.dart';

import 'roles_models.dart';

class RolesApi {
  final Dio dio;
  RolesApi(this.dio);

  Future<List<RoleModel>> fetchRoles({String? codigo, String? nombre, bool? activo}) async {
    final query = <String, dynamic>{};
    if (codigo != null && codigo.isNotEmpty) query['codigo'] = codigo;
    if (nombre != null && nombre.isNotEmpty) query['nombre'] = nombre;
    if (activo != null) query['activo'] = activo.toString();

    final res = await dio.get('/roles', queryParameters: query.isEmpty ? null : query);
    final list = (res.data as List<dynamic>).map((e) => RoleModel.fromJson(Map<String, dynamic>.from(e))).toList();
    return list;
  }

  Future<RoleModel> fetchRole(int id) async {
    final res = await dio.get('/roles/$id');
    return RoleModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<RoleModel> createRole(Map<String, dynamic> payload) async {
    final body = _cleanPayload(payload);
    final res = await dio.post('/roles', data: body);
    return RoleModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<RoleModel> updateRole(int id, Map<String, dynamic> payload) async {
    final body = _cleanPayload(payload);
    final res = await dio.patch('/roles/$id', data: body);
    return RoleModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteRole(int id) async {
    await dio.delete('/roles/$id');
  }

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> payload) {
    return Map<String, dynamic>.from(payload);
  }
}

import 'package:dio/dio.dart';

import 'access_reg_suc_models.dart';

class AccessRegSucApi {
  final Dio dio;
  AccessRegSucApi(this.dio);

  String _keyPath(String modulo, String usuario, String suc) {
    return '/usr-mod-suc/${Uri.encodeComponent(modulo)}/${Uri.encodeComponent(usuario)}/${Uri.encodeComponent(suc)}';
  }

  Future<List<AccessRegSucModel>> fetchAll({String? modulo, String? usuario, String? suc, bool? activo}) async {
    final query = <String, dynamic>{};
    if (modulo != null && modulo.trim().isNotEmpty) query['modulo'] = modulo.trim();
    if (usuario != null && usuario.trim().isNotEmpty) query['usuario'] = usuario.trim();
    if (suc != null && suc.trim().isNotEmpty) query['suc'] = suc.trim();
    if (activo != null) query['activo'] = activo.toString();

    final res = await dio.get('/usr-mod-suc', queryParameters: query.isEmpty ? null : query);
    return (res.data as List<dynamic>)
        .map((e) => AccessRegSucModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AccessRegSucModel> fetchOne(String modulo, String usuario, String suc) async {
    final res = await dio.get(_keyPath(modulo, usuario, suc));
    return AccessRegSucModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<AccessRegSucModel> create(Map<String, dynamic> payload) async {
    final res = await dio.post('/usr-mod-suc', data: Map<String, dynamic>.from(payload));
    return AccessRegSucModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<AccessRegSucModel> update(String modulo, String usuario, String suc, Map<String, dynamic> payload) async {
    final res = await dio.patch(_keyPath(modulo, usuario, suc), data: Map<String, dynamic>.from(payload));
    return AccessRegSucModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> delete(String modulo, String usuario, String suc) async {
    await dio.delete(_keyPath(modulo, usuario, suc));
  }
}

import 'package:dio/dio.dart';

import 'access_models.dart';

class AccessApi {
  final Dio dio;
  AccessApi(this.dio);

  List<dynamic> _unwrapList(Response res) {
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['data'] as List<dynamic>;
  }

  Future<List<AccessModulo>> fetchBackendModulos({bool includeInactives = false}) async {
    final res = await dio.get(
      '/access/modulos',
      queryParameters: includeInactives ? {'includeInactives': 'true'} : null,
    );
    return _unwrapList(res)
        .map((e) => AccessModulo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AccessModulo> createBackendModulo(Map<String, dynamic> payload) async {
    final res = await dio.post('/access/modulos', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessModulo.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<AccessModulo> updateBackendModulo(int id, Map<String, dynamic> payload) async {
    final res = await dio.put('/access/modulos/$id', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessModulo.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<void> deleteBackendModulo(int id) async {
    await dio.delete('/access/modulos/$id');
  }

  Future<List<AccessGrupoModulo>> fetchBackendGrupos({bool includeInactives = false}) async {
    final res = await dio.get(
      '/access/grupos-modulo',
      queryParameters: includeInactives ? {'includeInactives': 'true'} : null,
    );
    return _unwrapList(res)
        .map((e) => AccessGrupoModulo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AccessGrupoModulo> createBackendGrupo(Map<String, dynamic> payload) async {
    final res = await dio.post('/access/grupos-modulo', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessGrupoModulo.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<AccessGrupoModulo> updateBackendGrupo(int id, Map<String, dynamic> payload) async {
    final res = await dio.put('/access/grupos-modulo/$id', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessGrupoModulo.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<void> deleteBackendGrupo(int id) async {
    await dio.delete('/access/grupos-modulo/$id');
  }

  Future<List<BackendModuloRef>> fetchBackendGroupModules(int groupId) async {
    final res = await dio.get('/access/grupos-modulo/$groupId/modulos');
    return _unwrapList(res)
        .map((e) => BackendModuloRef.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setBackendGroupModules(int groupId, List<int> ids) async {
    await dio.post('/access/grupos-modulo/$groupId/modulos', data: {
      'idModulos': ids,
    });
  }

  Future<List<AccessRole>> fetchRoles({bool includeInactives = false}) async {
    final res = await dio.get(
      '/access/roles',
      queryParameters: includeInactives ? {'includeInactives': 'true'} : null,
    );
    return _unwrapList(res)
        .map((e) => AccessRole.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<BackendGroupPerm>> fetchBackendPerms(int roleId) async {
    final res = await dio.get('/access/roles/$roleId/permisos-backend');
    return _unwrapList(res)
        .map((e) => BackendGroupPerm.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setBackendPerm(int roleId, BackendGroupPerm perm) async {
    await dio.post('/access/roles/$roleId/permisos-backend', data: {
      'idGrupModulo': perm.idGrupModulo,
      'canRead': perm.canRead,
      'canCreate': perm.canCreate,
      'canUpdate': perm.canUpdate,
      'canDelete': perm.canDelete,
      'activo': perm.activo,
    });
  }

  Future<List<AccessModuloFront>> fetchFrontModulos({bool includeInactives = false}) async {
    final res = await dio.get(
      '/access/mod-front',
      queryParameters: includeInactives ? {'includeInactives': 'true'} : null,
    );
    return _unwrapList(res)
        .map((e) => AccessModuloFront.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AccessModuloFront> createFrontModulo(Map<String, dynamic> payload) async {
    final res = await dio.post('/access/mod-front', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessModuloFront.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<AccessModuloFront> updateFrontModulo(int id, Map<String, dynamic> payload) async {
    final res = await dio.put('/access/mod-front/$id', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessModuloFront.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<void> deleteFrontModulo(int id) async {
    await dio.delete('/access/mod-front/$id');
  }

  Future<List<AccessGrupoFront>> fetchFrontGrupos({bool includeInactives = false}) async {
    final res = await dio.get(
      '/access/grupos-front',
      queryParameters: includeInactives ? {'includeInactives': 'true'} : null,
    );
    return _unwrapList(res)
        .map((e) => AccessGrupoFront.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AccessGrupoFront> createFrontGrupo(Map<String, dynamic> payload) async {
    final res = await dio.post('/access/grupos-front', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessGrupoFront.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<AccessGrupoFront> updateFrontGrupo(int id, Map<String, dynamic> payload) async {
    final res = await dio.put('/access/grupos-front/$id', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    return AccessGrupoFront.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<void> deleteFrontGrupo(int id) async {
    await dio.delete('/access/grupos-front/$id');
  }

  Future<List<FrontModuloRef>> fetchFrontGroupModules(int groupId) async {
    final res = await dio.get('/access/grupos-front/$groupId/mods');
    return _unwrapList(res)
        .map((e) => FrontModuloRef.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setFrontGroupModules(int groupId, List<int> ids) async {
    await dio.post('/access/grupos-front/$groupId/mods', data: {
      'idModFront': ids,
    });
  }

  Future<List<FrontGroupEnrollment>> fetchFrontEnrollments(int roleId) async {
    final res = await dio.get('/access/roles/$roleId/enrolamientos-front');
    return _unwrapList(res)
        .map((e) => FrontGroupEnrollment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setFrontEnrollment(int roleId, FrontGroupEnrollment enrollment) async {
    await dio.post('/access/roles/$roleId/enrolamientos-front', data: {
      'idGrupmodFront': enrollment.idGrupmodFront,
      'activo': enrollment.activo,
    });
  }
}

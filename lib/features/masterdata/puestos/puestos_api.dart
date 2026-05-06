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

    final res = await dio.get('/roles', queryParameters: query.isEmpty ? null : query);
    return (res.data as List<dynamic>)
        .map((e) => _fromRoleJson(Map<String, dynamic>.from(e)))
        .where((row) => row.idDepto != null)
        .toList();
  }

  Future<PuestoModel> fetchPuesto(int id) async {
    final res = await dio.get('/roles/$id');
    return _fromRoleJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PuestoModel> createPuesto(Map<String, dynamic> payload) async {
    final source = Map<String, dynamic>.from(payload);
    final depto = source['IDDEPTO'];
    final nombre = (source['NOMBRE'] ?? '').toString().trim();
    final body = <String, dynamic>{
      'CODIGO': _buildCodigo(nombre),
      'NOMBRE': nombre,
      'IDDEPTO': depto,
      'ACTIVO': source['ACTIVO'] ?? true,
    };
    final res = await dio.post('/roles', data: body);
    return _fromRoleJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PuestoModel> updatePuesto(int id, Map<String, dynamic> payload) async {
    final source = Map<String, dynamic>.from(payload);
    final body = <String, dynamic>{
      if (source.containsKey('NOMBRE')) 'NOMBRE': source['NOMBRE'],
      if (source.containsKey('IDDEPTO')) 'IDDEPTO': source['IDDEPTO'],
      if (source.containsKey('ACTIVO')) 'ACTIVO': source['ACTIVO'],
    };
    final res = await dio.patch('/roles/$id', data: body);
    return _fromRoleJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deletePuesto(int id) async {
    await dio.delete('/roles/$id');
  }

  PuestoModel _fromRoleJson(Map<String, dynamic> json) {
    return PuestoModel.fromJson({
      'IDPUESTO': json['IDROL'],
      'IDDEPTO': json['IDDEPTO'],
      'NOMBRE': json['NOMBRE'],
      'ACTIVO': json['ACTIVO'],
      'DEPARTAMENTO': null,
    });
  }

  String _buildCodigo(String nombre) {
    final normalized = nombre
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final fallback = normalized.isEmpty ? 'ROL' : normalized;
    return fallback.length > 50 ? fallback.substring(0, 50) : fallback;
  }
}

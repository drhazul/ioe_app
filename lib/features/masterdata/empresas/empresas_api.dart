import 'package:dio/dio.dart';

import 'empresas_models.dart';

class EmpresasApi {
  EmpresasApi(this.dio);

  final Dio dio;

  Future<List<EmpresaModel>> fetchEmpresas() async {
    final res = await dio.get('/empresas');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => EmpresaModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .where((item) => item.idempresa > 0)
        .toList();
  }

  Future<EmpresaModel> fetchEmpresa(int id) async {
    final res = await dio.get('/empresas/$id');
    return EmpresaModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<EmpresaModel> createEmpresa(Map<String, dynamic> payload) async {
    final res = await dio.post('/empresas', data: _cleanPayload(payload));
    return EmpresaModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<EmpresaModel> updateEmpresa(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.patch('/empresas/$id', data: _cleanPayload(payload));
    return EmpresaModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteEmpresa(int id) async {
    await dio.delete('/empresas/$id');
  }

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> payload) {
    final body = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (entry.key.trim().isEmpty) continue;
      body[entry.key] = entry.value;
    }
    return body;
  }
}

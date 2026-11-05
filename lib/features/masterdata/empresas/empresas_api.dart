import 'package:dio/dio.dart';

import 'empresas_models.dart';
import 'empresa_creditos_config.dart';
import 'entidades_fiscales_models.dart';

class EmpresasApi {
  EmpresasApi(this.dio);

  final Dio dio;

  Future<EmpresaCreditosConfig> fetchCreditosConfig(int id) async {
    final res = await dio.get('/empresas/$id/configuracion/creditos');
    return EmpresaCreditosConfig.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<void> saveCreditosConfig(
    int id, {
    required String modo,
    required bool permitir,
    required String version,
  }) async {
    await dio.patch(
      '/empresas/$id/configuracion/creditos',
      data: {'modo': modo, 'permitir': permitir, 'version': version},
    );
  }

  Future<void> saveCreditosSucursal(
    int id,
    String suc, {
    required bool? permitir,
    required String version,
  }) async {
    await dio.patch(
      '/empresas/$id/configuracion/creditos/sucursales/${Uri.encodeComponent(suc)}',
      data: {'permitir': permitir, 'version': version},
    );
  }

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

  Future<List<EntidadFiscalModel>> fetchEntidadesFiscales() async {
    final res = await dio.get('/entidades-fiscales');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => EntidadFiscalModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((item) => item.idEntidadFiscal > 0)
        .toList();
  }

  Future<List<SucursalFiscalOption>> fetchSucursalesFiscales() async {
    final res = await dio.get('/entidades-fiscales/catalogos/sucursales');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => SucursalFiscalOption.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((item) => item.suc.isNotEmpty)
        .toList();
  }

  Future<void> createEntidadFiscal(Map<String, dynamic> payload) async {
    await dio.post('/entidades-fiscales', data: _cleanPayload(payload));
  }

  Future<void> updateEntidadFiscal(int id, Map<String, dynamic> payload) async {
    await dio.patch('/entidades-fiscales/$id', data: _cleanPayload(payload));
  }

  Future<void> linkEntidadFiscalSucursal(
    int id,
    Map<String, dynamic> payload,
  ) async {
    await dio.post(
      '/entidades-fiscales/$id/sucursales',
      data: _cleanPayload(payload),
    );
  }

  Future<void> updateEntidadFiscalSucursal(
    int id,
    int relationId,
    Map<String, dynamic> payload,
  ) async {
    await dio.patch(
      '/entidades-fiscales/$id/sucursales/$relationId',
      data: _cleanPayload(payload),
    );
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

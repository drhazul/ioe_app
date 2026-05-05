import 'package:dio/dio.dart';

import 'configuracion_maestra_models.dart';

class ConfiguracionMaestraApi {
  ConfiguracionMaestraApi(this.dio);

  final Dio dio;

  Future<ConfiguracionMaestraModel> fetchConfiguracionMaestra() async {
    try {
      final res = await dio.get('/masterdata/configuracion-maestra');
      if (res.data is Map) {
        return ConfiguracionMaestraModel.fromJson(
          Map<String, dynamic>.from(res.data as Map),
        );
      }
    } catch (_) {
      // fallback a catálogos existentes
    }

    final deptosRes = await dio.get('/deptos');
    final puestosRes = await dio.get('/puestos');

    final departamentos = (deptosRes.data is List)
        ? (deptosRes.data as List)
              .whereType<Map>()
              .map(
                (row) =>
                    (row['NOMBRE'] ?? row['nombre'] ?? '').toString().trim(),
              )
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final cargos = (puestosRes.data is List)
        ? (puestosRes.data as List)
              .whereType<Map>()
              .map(
                (row) =>
                    (row['NOMBRE'] ?? row['nombre'] ?? '').toString().trim(),
              )
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    String nombreEmpresa = '';
    String nitEmpresa = '';
    try {
      final sucRes = await dio.get('/sucursales');
      if (sucRes.data is List && (sucRes.data as List).isNotEmpty) {
        final first = Map<String, dynamic>.from(
          ((sucRes.data as List).first as Map),
        );
        nombreEmpresa =
            (first['empresa'] ?? first['empresa_perteneciente'] ?? '')
                .toString()
                .trim();
        nitEmpresa = (first['nit'] ?? '').toString().trim();
      }
    } catch (_) {
      // no-op
    }

    return ConfiguracionMaestraModel(
      nombreEmpresa: nombreEmpresa,
      nitEmpresa: nitEmpresa,
      gpsObligatorio: false,
      livenessObligatorio: false,
      departamentos: departamentos,
      cargos: cargos,
    );
  }

  Future<ConfiguracionMaestraModel> saveConfiguracionMaestra(
    ConfiguracionMaestraModel model,
  ) async {
    final body = model.toJson();
    final res = await dio.put('/masterdata/configuracion-maestra', data: body);
    if (res.data is Map) {
      return ConfiguracionMaestraModel.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    }
    return model;
  }
}

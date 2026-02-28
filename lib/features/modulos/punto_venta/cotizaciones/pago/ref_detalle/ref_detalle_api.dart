import 'package:dio/dio.dart';

import 'ref_detalle_models.dart';

class RefDetalleApi {
  RefDetalleApi(this.dio);

  final Dio dio;

  Future<List<RefDetalleItem>> fetchByFolio({
    required String idfol,
    String? tipo,
  }) async {
    final query = <String, dynamic>{
      'idfol': idfol.trim(),
      if ((tipo ?? '').trim().isNotEmpty) 'tipo': tipo!.trim().toUpperCase(),
    };
    final res = await dio.get('/pv/refdetalle', queryParameters: query);
    final list = (res.data as List<dynamic>)
        .map((e) => RefDetalleItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }

  Future<RefDetalleCrearResponse> crear({
    required String suc,
    required String idfol,
    required int idc,
    required String opv,
    required String rfcEmisor,
    required String tipo,
    required double impt,
    DateTime? fcnd,
    String? idref,
  }) async {
    final payload = <String, dynamic>{
      'suc': suc.trim(),
      'idfol': idfol.trim(),
      'idc': idc,
      'opv': opv.trim(),
      'rfcEmisor': rfcEmisor.trim(),
      'tipo': tipo.trim().toUpperCase(),
      'impt': impt,
      if (fcnd != null) 'fcnd': fcnd.toIso8601String(),
      if ((idref ?? '').trim().isNotEmpty) 'idref': idref!.trim(),
    };
    final res = await dio.post('/pv/refdetalle/crear', data: payload);
    return RefDetalleCrearResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<RefDetalleAsignarResponse> asignar({
    required String idref,
    String? idfol,
  }) async {
    final payload = <String, dynamic>{
      'idref': idref.trim(),
      if ((idfol ?? '').trim().isNotEmpty) 'idfol': idfol!.trim(),
    };
    final res = await dio.post('/pv/refdetalle/asignar', data: payload);
    return RefDetalleAsignarResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<void> eliminar({
    required String idref,
    String? idfol,
  }) async {
    await dio.delete(
      '/pv/refdetalle/${Uri.encodeComponent(idref.trim())}',
      queryParameters: {
        if ((idfol ?? '').trim().isNotEmpty) 'idfol': idfol!.trim(),
      },
    );
  }
}


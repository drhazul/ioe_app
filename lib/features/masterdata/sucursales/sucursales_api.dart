import 'package:dio/dio.dart';
import 'package:ioe_app/core/storage.dart';

import 'sucursales_models.dart';

class SucursalesApi {
  final Dio dio;
  final Storage storage;
  SucursalesApi(this.dio, this.storage);

  Future<List<SucursalModel>> fetchSucursales({String? suc, String? desc}) async {
    final query = <String, dynamic>{};
    if (suc != null && suc.isNotEmpty) query['suc'] = suc;
    if (desc != null && desc.isNotEmpty) query['desc'] = desc;

    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/dat-suc',
      queryParameters: query.isEmpty ? null : query,
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data as List<dynamic>)
        .map((e) => SucursalModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SucursalModel> fetchSucursal(String suc) async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/dat-suc/${Uri.encodeComponent(suc)}',
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<SucursalModel> createSucursal(Map<String, dynamic> payload) async {
    final token = await storage.getAccessToken();
    final res = await dio.post(
      '/dat-suc',
      data: Map<String, dynamic>.from(payload),
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<SucursalModel> updateSucursal(String suc, Map<String, dynamic> payload) async {
    final token = await storage.getAccessToken();
    final res = await dio.patch(
      '/dat-suc/${Uri.encodeComponent(suc)}',
      data: Map<String, dynamic>.from(payload),
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<String?> deleteSucursal(String suc) async {
    final token = await storage.getAccessToken();
    final res = await dio.delete(
      '/dat-suc/${Uri.encodeComponent(suc)}',
      options: Options(
        // Evita que un 409 dispare una excepción y corte el flujo normal (lo manejamos nosotros)
        validateStatus: (status) {
          if (status == null) return false;
          if (status == 409) return true;
          return status >= 200 && status < 300;
        },
        headers: token == null || token.isEmpty ? null : {'Authorization': 'Bearer $token'},
      ),
    );

    if (res.statusCode == 409) {
      final data = res.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'No se puede eliminar la sucursal porque está en uso.';
      return msg;
    }

    return null;
  }
}

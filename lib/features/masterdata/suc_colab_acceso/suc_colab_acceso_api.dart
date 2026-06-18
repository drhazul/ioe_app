import 'package:dio/dio.dart';

import 'suc_colab_acceso_models.dart';

class SucColabAccesoApi {
  final Dio dio;

  SucColabAccesoApi(this.dio);

  Future<List<SucColabAccesoModel>> fetchAll({
    String? sucDestino,
    String? sucOrigen,
    String? search,
    bool includeInactive = true,
  }) async {
    final query = <String, dynamic>{};
    if (includeInactive) query['includeInactive'] = 'true';
    if (sucDestino != null && sucDestino.trim().isNotEmpty) {
      query['sucDestino'] = sucDestino.trim().toUpperCase();
    }
    if (sucOrigen != null && sucOrigen.trim().isNotEmpty) {
      query['sucOrigen'] = sucOrigen.trim().toUpperCase();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final res = await dio.get(
      '/suc-colab-acceso',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((e) => SucColabAccesoModel.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.id > 0)
        .toList();
  }

  Future<SucColabAccesoModel> fetchOne(int id) async {
    final res = await dio.get('/suc-colab-acceso/$id');
    return SucColabAccesoModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SucColabAccesoModel> create(Map<String, dynamic> payload) async {
    final res = await dio.post('/suc-colab-acceso', data: payload);
    return SucColabAccesoModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SucColabAccesoModel> update(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.patch('/suc-colab-acceso/$id', data: payload);
    return SucColabAccesoModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<void> delete(int id) async {
    await dio.delete('/suc-colab-acceso/$id');
  }
}

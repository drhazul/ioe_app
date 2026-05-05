import 'package:dio/dio.dart';

import 'ord_flujo_vis_models.dart';

class OrdFlujoVisApi {
  OrdFlujoVisApi(this.dio);

  final Dio dio;

  Future<List<OrdFlujoVisModel>> fetchList({
    bool includeInactive = true,
    String? modulo,
    String? panelMode,
    String? roleCode,
    String? esta,
  }) async {
    final query = <String, dynamic>{};
    if (includeInactive) query['includeInactive'] = 'true';
    if ((modulo ?? '').trim().isNotEmpty) query['modulo'] = modulo!.trim();
    if ((panelMode ?? '').trim().isNotEmpty) {
      query['panelMode'] = panelMode!.trim();
    }
    if ((roleCode ?? '').trim().isNotEmpty) {
      query['roleCode'] = roleCode!.trim();
    }
    if ((esta ?? '').trim().isNotEmpty) query['esta'] = esta!.trim();

    final res = await dio.get(
      '/ord-flujo-vis',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) =>
              OrdFlujoVisModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .where((row) => row.id > 0 && row.modulo.isNotEmpty)
        .toList();
  }

  Future<OrdFlujoVisModel> fetchById(int id) async {
    final res = await dio.get('/ord-flujo-vis/$id');
    return OrdFlujoVisModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<OrdFlujoVisCatalogos> fetchCatalogos() async {
    final res = await dio.get('/ord-flujo-vis/catalogos');
    return OrdFlujoVisCatalogos.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<OrdFlujoVisModel> create(Map<String, dynamic> payload) async {
    final res = await dio.post('/ord-flujo-vis', data: _cleanPayload(payload));
    return OrdFlujoVisModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<OrdFlujoVisModel> update(int id, Map<String, dynamic> payload) async {
    final res = await dio.patch('/ord-flujo-vis/$id', data: _cleanPayload(payload));
    return OrdFlujoVisModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> updateEstado(int id, bool estado) async {
    await dio.patch('/ord-flujo-vis/$id/estado', data: {'estado': estado});
  }

  Future<void> delete(int id) async {
    await dio.delete('/ord-flujo-vis/$id');
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

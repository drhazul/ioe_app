import 'package:dio/dio.dart';

import 'promociones_models.dart';

class PromocionesApi {
  PromocionesApi(this.dio);

  final Dio dio;

  Future<List<PromocionModel>> fetchPromociones({
    bool includeInactive = true,
    String? suc,
    String? tipo,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (includeInactive) query['includeInactive'] = 'true';
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    if ((tipo ?? '').trim().isNotEmpty) query['tipo'] = tipo!.trim();
    if ((search ?? '').trim().isNotEmpty) query['search'] = search!.trim();

    final res = await dio.get(
      '/promociones',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) =>
              PromocionModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .where((item) => item.idProm > 0)
        .toList();
  }

  Future<PromocionModel> createPromocion(Map<String, dynamic> payload) async {
    final res = await dio.post('/promociones', data: _cleanPayload(payload));
    return PromocionModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PromocionModel> updatePromocion(
    int idProm,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.patch(
      '/promociones/$idProm',
      data: _cleanPayload(payload),
    );
    return PromocionModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deletePromocion(int idProm) async {
    await dio.delete('/promociones/$idProm');
  }

  Future<void> hardDeletePromocion(int idProm) async {
    await dio.delete('/promociones/$idProm/hard');
  }

  Future<List<PromocionCriterioModel>> fetchCriterios(int idProm) async {
    final res = await dio.get('/promociones/$idProm/criterios');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => PromocionCriterioModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((item) => item.idCriterio > 0)
        .toList();
  }

  Future<void> createCriterio(int idProm, Map<String, dynamic> payload) async {
    await dio.post(
      '/promociones/$idProm/criterios',
      data: _cleanPayload(payload),
    );
  }

  Future<void> updateCriterio(
    int idCriterio,
    Map<String, dynamic> payload,
  ) async {
    await dio.patch(
      '/promociones/criterios/$idCriterio',
      data: _cleanPayload(payload),
    );
  }

  Future<void> deleteCriterio(int idCriterio) async {
    await dio.delete('/promociones/criterios/$idCriterio');
  }

  Future<List<PromocionBeneficioModel>> fetchBeneficios(int idProm) async {
    final res = await dio.get('/promociones/$idProm/beneficios');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => PromocionBeneficioModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((item) => item.idBeneficio > 0)
        .toList();
  }

  Future<void> createBeneficio(
    int idProm,
    Map<String, dynamic> payload,
  ) async {
    await dio.post(
      '/promociones/$idProm/beneficios',
      data: _cleanPayload(payload),
    );
  }

  Future<void> updateBeneficio(
    int idBeneficio,
    Map<String, dynamic> payload,
  ) async {
    await dio.patch(
      '/promociones/beneficios/$idBeneficio',
      data: _cleanPayload(payload),
    );
  }

  Future<void> deleteBeneficio(int idBeneficio) async {
    await dio.delete('/promociones/beneficios/$idBeneficio');
  }

  Future<List<CatalogTextOptionModel>> fetchSucursales() async {
    final res = await dio.get('/promociones/catalogos/sucursales');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogTextOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.valor.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchClientes({
    String? suc,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    if ((search ?? '').trim().isNotEmpty) query['search'] = search!.trim();
    final res = await dio.get(
      '/promociones/catalogos/clientes',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => (row['cliente'] ?? row['CLIENTE']) != null)
        .toList();
  }

  Future<List<CatalogOptionModel>> fetchCatalogOptions(String key) async {
    final res = await dio.get('/promociones/catalogos/$key');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.clave.isNotEmpty)
        .toList();
  }

  Future<List<CatalogOptionModel>> addCatalogOption(
    String key, {
    required String clave,
    required String descripcion,
  }) async {
    final res = await dio.post(
      '/promociones/catalogos/$key',
      data: {'clave': clave, 'descripcion': descripcion},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.clave.isNotEmpty)
        .toList();
  }

  Future<List<CatalogNumOptionModel>> fetchDepa({String? suc}) async {
    final res = await dio.get(
      '/promociones/catalogos/depa',
      queryParameters: (suc ?? '').trim().isEmpty ? null : {'suc': suc},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogNumOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.valor > 0)
        .toList();
  }

  Future<List<CatalogNumOptionModel>> fetchSubd(List<int> depa) async {
    final res = await dio.get(
      '/promociones/catalogos/subd',
      queryParameters: depa.isEmpty ? null : {'depa': depa.join(',')},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogNumOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.valor > 0)
        .toList();
  }

  Future<List<CatalogNumOptionModel>> fetchClas(List<int> subd) async {
    final res = await dio.get(
      '/promociones/catalogos/clas',
      queryParameters: subd.isEmpty ? null : {'subd': subd.join(',')},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogNumOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.valor > 0)
        .toList();
  }

  Future<List<CatalogNumOptionModel>> fetchScla(List<int> clas) async {
    final res = await dio.get(
      '/promociones/catalogos/scla',
      queryParameters: clas.isEmpty ? null : {'clas': clas.join(',')},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogNumOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.valor > 0)
        .toList();
  }

  Future<List<CatalogNumOptionModel>> fetchScla2(List<int> scla) async {
    final res = await dio.get(
      '/promociones/catalogos/scla2',
      queryParameters: scla.isEmpty ? null : {'scla': scla.join(',')},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogNumOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.valor > 0)
        .toList();
  }

  Future<List<CatalogTextOptionModel>> fetchGuia(List<int> scla2) async {
    final res = await dio.get(
      '/promociones/catalogos/guia',
      queryParameters: scla2.isEmpty ? null : {'scla2': scla2.join(',')},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => CatalogTextOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.valor.isNotEmpty)
        .toList();
  }

  Future<List<PromoArticuloOptionModel>> fetchArticulos({
    String? suc,
    List<int> depa = const [],
    List<int> subd = const [],
    List<int> clas = const [],
    List<int> scla = const [],
    List<int> scla2 = const [],
    List<String> guia = const [],
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if ((suc ?? '').trim().isNotEmpty && suc != '*') query['suc'] = suc;
    if (depa.isNotEmpty) query['depa'] = depa.join(',');
    if (subd.isNotEmpty) query['subd'] = subd.join(',');
    if (clas.isNotEmpty) query['clas'] = clas.join(',');
    if (scla.isNotEmpty) query['scla'] = scla.join(',');
    if (scla2.isNotEmpty) query['scla2'] = scla2.join(',');
    if (guia.isNotEmpty) query['guia'] = guia.join(',');
    if ((search ?? '').trim().isNotEmpty) query['search'] = search!.trim();
    final res = await dio.get(
      '/promociones/catalogos/articulos',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => PromoArticuloOptionModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((x) => x.art.isNotEmpty || x.upc.isNotEmpty)
        .toList();
  }

  Future<PromoConfigModel?> fetchConfig(int idProm) async {
    final res = await dio.get('/promociones/$idProm/configuracion');
    if (res.data == null) return null;
    if (res.data is! Map) return null;
    return PromoConfigModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PromoConfigModel?> saveConfig(
    int idProm,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.put(
      '/promociones/$idProm/configuracion',
      data: _cleanPayload(payload),
    );
    if (res.data == null || res.data is! Map) return null;
    return PromoConfigModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PromocionModel> reorderPrioridad(int idProm, int prioridad) async {
    final res = await dio.post(
      '/promociones/$idProm/reordenar-prioridad',
      data: {'prioridad': prioridad},
    );
    return PromocionModel.fromJson(Map<String, dynamic>.from(res.data as Map));
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

import 'package:dio/dio.dart';

import '../domain/merma_models.dart';

class MermaApi {
  MermaApi(this.dio);

  final Dio dio;

  Future<MermaPagedResult<MermaDocModel>> fetchMermas({
    bool consulta = false,
    int page = 1,
    int limit = 30,
    String? search,
    String? docmer,
    String? usuario,
    String? suc,
    String? estatus,
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if ((search ?? '').trim().isNotEmpty) query['search'] = search!.trim();
    if ((docmer ?? '').trim().isNotEmpty) query['docmer'] = docmer!.trim();
    if ((usuario ?? '').trim().isNotEmpty) query['usuario'] = usuario!.trim();
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    if ((estatus ?? '').trim().isNotEmpty) query['estatus'] = estatus!.trim();
    if ((from ?? '').trim().isNotEmpty) query['from'] = from!.trim();
    if ((to ?? '').trim().isNotEmpty) query['to'] = to!.trim();

    final endpoint = consulta ? '/mermas/consulta' : '/mermas';
    final res = await dio.get(endpoint, queryParameters: query);
    final data = res.data;
    if (data is! Map) {
      return MermaPagedResult(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final itemsRaw = map['items'];
    final items = itemsRaw is List
        ? itemsRaw
              .map(
                (row) => MermaDocModel.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : <MermaDocModel>[];
    return MermaPagedResult(
      items: items,
      total: _toInt(map['total']),
      page: _toInt(map['page']),
      limit: _toInt(map['limit']),
    );
  }

  Future<List<MermaGestionCabeceraModel>> fetchGestionCabecerasAbiertas({
    String? suc,
  }) async {
    final query = <String, dynamic>{};
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    final res = await dio.get(
      '/mermas/gestion/cabeceras-abiertas',
      queryParameters: query,
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => MermaGestionCabeceraModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<MermaDocModel> createMerma({
    String? suc,
    String? areaM,
    String? txt,
  }) async {
    final payload = <String, dynamic>{};
    if ((suc ?? '').trim().isNotEmpty) payload['suc'] = suc!.trim();
    if ((areaM ?? '').trim().isNotEmpty) payload['areaM'] = areaM!.trim();
    if ((txt ?? '').trim().isNotEmpty) payload['txt'] = txt!.trim();
    final res = await dio.post('/mermas', data: payload);
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> fetchMerma(
    String docmer, {
    bool consulta = false,
  }) async {
    final endpoint = consulta ? '/mermas/consulta/$docmer' : '/mermas/$docmer';
    final res = await dio.get(endpoint);
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> updateMerma(
    String docmer, {
    String? areaM,
    String? txt,
  }) async {
    final payload = <String, dynamic>{};
    if ((areaM ?? '').trim().isNotEmpty) payload['areaM'] = areaM!.trim();
    if ((txt ?? '').trim().isNotEmpty) payload['txt'] = txt!.trim();
    final res = await dio.patch('/mermas/$docmer', data: payload);
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteMerma(String docmer) async {
    await dio.delete('/mermas/$docmer');
  }

  Future<MermaDocModel> addDetalle(
    String docmer, {
    required String art,
    required double ctd,
    required int motM,
    String? areaM,
    String? respM,
    String? obsM,
    String? eviM,
  }) async {
    final payload = <String, dynamic>{
      'art': art,
      'ctd': ctd,
      'motM': motM,
      if ((areaM ?? '').trim().isNotEmpty) 'areaM': areaM!.trim(),
      if ((respM ?? '').trim().isNotEmpty) 'respM': respM!.trim(),
      if ((obsM ?? '').trim().isNotEmpty) 'obsM': obsM!.trim(),
      if ((eviM ?? '').trim().isNotEmpty) 'eviM': eviM!.trim(),
    };
    final res = await dio.post('/mermas/$docmer/detalle', data: payload);
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> updateDetalle(
    String docmer,
    String idpd, {
    double? ctd,
    int? motM,
    String? areaM,
    String? respM,
    String? obsM,
    String? eviM,
  }) async {
    final payload = <String, dynamic>{};
    if (ctd != null) payload['ctd'] = ctd;
    if (motM != null) payload['motM'] = motM;
    if ((areaM ?? '').trim().isNotEmpty) payload['areaM'] = areaM!.trim();
    if ((respM ?? '').trim().isNotEmpty) payload['respM'] = respM!.trim();
    if ((obsM ?? '').trim().isNotEmpty) payload['obsM'] = obsM!.trim();
    if ((eviM ?? '').trim().isNotEmpty) payload['eviM'] = eviM!.trim();
    final res = await dio.patch('/mermas/$docmer/detalle/$idpd', data: payload);
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> removeDetalle(String docmer, String idpd) async {
    final res = await dio.delete('/mermas/$docmer/detalle/$idpd');
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> solicitarAutorizacion(String docmer) async {
    final res = await dio.post('/mermas/$docmer/solicitar-autorizacion');
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> revisar(String docmer, String obs) async {
    final res = await dio.post('/mermas/$docmer/revisar', data: {'obs': obs});
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> contabilizar(String docmer) async {
    final res = await dio.post('/mermas/$docmer/contabilizar');
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> anular(String docmer, String obs) async {
    final res = await dio.post('/mermas/$docmer/anular', data: {'obs': obs});
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<MermaDocModel> auditar(
    String docmer, {
    String? obsAudit,
    bool confirmFisica = true,
  }) async {
    final res = await dio.post(
      '/mermas/$docmer/auditar',
      data: {
        if ((obsAudit ?? '').trim().isNotEmpty) 'obsAudit': obsAudit!.trim(),
        'confirmFisica': confirmFisica,
      },
    );
    return MermaDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<MermaCatalogOptionModel>> catalogMotivos() async {
    final res = await dio.get('/mermas/catalogos/motivos');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => MermaCatalogOptionModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<MermaCatalogOptionModel>> catalogClasificaciones() async {
    final res = await dio.get('/mermas/catalogos/clasificaciones');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => MermaCatalogOptionModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<MermaCatalogOptionModel>> catalogEstatus() async {
    final res = await dio.get('/mermas/catalogos/estatus');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => MermaCatalogOptionModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<MermaCatalogOptionModel>> catalogAreas() async {
    final res = await dio.get('/mermas/catalogos/areas');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => MermaCatalogOptionModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<String>> catalogSucursales() async {
    final res = await dio.get('/mermas/catalogos/sucursales');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => (row ?? '').toString().trim())
        .where((suc) => suc.isNotEmpty)
        .toList();
  }

  Future<MermaPagedResult<MermaArticuloModel>> catalogArticulos({
    String? search,
    String? suc,
    int page = 1,
    int limit = 30,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if ((search ?? '').trim().isNotEmpty) query['search'] = search!.trim();
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    final res = await dio.get(
      '/mermas/catalogos/articulos',
      queryParameters: query,
    );
    final data = res.data;
    if (data is! Map) {
      return MermaPagedResult(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final itemsRaw = map['items'];
    final items = itemsRaw is List
        ? itemsRaw
              .map(
                (row) => MermaArticuloModel.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : <MermaArticuloModel>[];
    return MermaPagedResult(
      items: items,
      total: _toInt(map['total']),
      page: _toInt(map['page']),
      limit: _toInt(map['limit']),
    );
  }

  Future<List<Map<String, dynamic>>> reporte(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    final res = await dio.get(
      '/mermas/reportes/$endpoint',
      queryParameters: query,
    );
    final data = res.data;
    if (data is! List) return const [];
    return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Map<String, dynamic>> soporte(String docmer) async {
    final res = await dio.get('/mermas/consulta/$docmer/soporte');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> etiqueta(String docmer) async {
    final res = await dio.get('/mermas/consulta/$docmer/etiqueta');
    return Map<String, dynamic>.from(res.data as Map);
  }
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

import 'package:dio/dio.dart';

import '../domain/transferencia_models.dart';

class TransferenciaApi {
  TransferenciaApi(this.dio);

  final Dio dio;

  Future<TransferenciaPagedResult<TransferenciaDocModel>> fetch({
    int page = 1,
    int limit = 30,
    String? search,
    String? doc,
    String? usuario,
    String? from,
    String? to,
    String? suc,
    String? estatus,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if ((search ?? '').trim().isNotEmpty) query['search'] = search!.trim();
    if ((doc ?? '').trim().isNotEmpty) query['doc'] = doc!.trim();
    if ((usuario ?? '').trim().isNotEmpty) {
      query['usuario'] = usuario!.trim();
    }
    if ((from ?? '').trim().isNotEmpty) query['from'] = from!.trim();
    if ((to ?? '').trim().isNotEmpty) query['to'] = to!.trim();
    if ((suc ?? '').trim().isNotEmpty) query['suc'] = suc!.trim();
    if ((estatus ?? '').trim().isNotEmpty) query['estatus'] = estatus!.trim();
    final res = await dio.get('/transferencias', queryParameters: query);
    final data = res.data;
    if (data is! Map) {
      return TransferenciaPagedResult(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final raw = map['items'];
    final items = raw is List
        ? raw
              .map(
                (row) => TransferenciaDocModel.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : <TransferenciaDocModel>[];
    return TransferenciaPagedResult(
      items: items,
      total: _toInt(map['total']),
      page: _toInt(map['page']),
      limit: _toInt(map['limit']),
    );
  }

  Future<List<TransferenciaDocModel>> notificaciones() async {
    final res = await dio.get('/transferencias/notificaciones');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => TransferenciaDocModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<TransferenciaDocModel> fetchOne(String doc) async {
    final res = await dio.get('/transferencias/$doc');
    return TransferenciaDocModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<TransferenciaDocModel> create({
    String? sucEnt,
    required String sucSal,
    required String mtv,
    String prio = 'NORMAL',
    String? txt,
  }) async {
    final res = await dio.post(
      '/transferencias',
      data: {
        if ((sucEnt ?? '').trim().isNotEmpty) 'sucEnt': sucEnt!.trim(),
        'sucSal': sucSal.trim(),
        'mtv': mtv.trim(),
        'prio': prio.trim(),
        if ((txt ?? '').trim().isNotEmpty) 'txt': txt!.trim(),
      },
    );
    return TransferenciaDocModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<TransferenciaDocModel> addDetalle(
    String doc, {
    required String art,
    required double ctd,
    String? txt,
  }) async {
    final res = await dio.post(
      '/transferencias/$doc/detalle',
      data: {
        'art': art.trim(),
        'ctd': ctd,
        if ((txt ?? '').trim().isNotEmpty) 'txt': txt!.trim(),
      },
    );
    return TransferenciaDocModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<TransferenciaDocModel> updateDetalle(
    String doc,
    String idpd, {
    double? ctd,
    double? ctdLib,
    double? ctdR,
    String? txt,
  }) async {
    final payload = <String, dynamic>{};
    if (ctd != null) payload['ctd'] = ctd;
    if (ctdLib != null) payload['ctdLib'] = ctdLib;
    if (ctdR != null) payload['ctdR'] = ctdR;
    if ((txt ?? '').trim().isNotEmpty) payload['txt'] = txt!.trim();
    final res = await dio.patch(
      '/transferencias/$doc/detalle/$idpd',
      data: payload,
    );
    return TransferenciaDocModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<TransferenciaDocModel> removeDetalle(String doc, String idpd) async {
    final res = await dio.delete('/transferencias/$doc/detalle/$idpd');
    return TransferenciaDocModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<TransferenciaDocModel> action(
    String doc,
    String action, {
    Map<String, dynamic>? data,
  }) async {
    final res = await dio.post(
      '/transferencias/$doc/$action',
      data: data ?? const {},
    );
    return TransferenciaDocModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<List<String>> sucursales() async {
    final res = await dio.get('/transferencias/catalogos/sucursales');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => '${row ?? ''}'.trim())
        .where((x) => x.isNotEmpty)
        .toList();
  }

  Future<List<TransferenciaCatalogOptionModel>> motivos() async {
    final res = await dio.get('/transferencias/catalogos/motivos');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => TransferenciaCatalogOptionModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<TransferenciaCatalogOptionModel>> prioridades() async {
    final res = await dio.get('/transferencias/catalogos/prioridades');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => TransferenciaCatalogOptionModel.fromJson(
            Map<String, dynamic>.from(row as Map),
            valueKey: 'desc',
            labelKey: 'desc',
          ),
        )
        .toList();
  }

  Future<TransferenciaPagedResult<TransferenciaArticuloModel>> articulos({
    required String sucSal,
    required String sucEnt,
    String? search,
    String? searchBy,
    String? depa,
    String? subd,
    String? clas,
    String? scla,
    String? scla2,
    String? sph,
    String? cyl,
    String? adic,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await dio.get(
      '/transferencias/catalogos/articulos',
      queryParameters: {
        'sucSal': sucSal,
        'sucEnt': sucEnt,
        'page': page,
        'limit': limit,
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        if ((searchBy ?? '').trim().isNotEmpty) 'searchBy': searchBy!.trim(),
        if ((depa ?? '').trim().isNotEmpty) 'depa': depa!.trim(),
        if ((subd ?? '').trim().isNotEmpty) 'subd': subd!.trim(),
        if ((clas ?? '').trim().isNotEmpty) 'clas': clas!.trim(),
        if ((scla ?? '').trim().isNotEmpty) 'scla': scla!.trim(),
        if ((scla2 ?? '').trim().isNotEmpty) 'scla2': scla2!.trim(),
        if ((sph ?? '').trim().isNotEmpty) 'sph': sph!.trim(),
        if ((cyl ?? '').trim().isNotEmpty) 'cyl': cyl!.trim(),
        if ((adic ?? '').trim().isNotEmpty) 'adic': adic!.trim(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      return TransferenciaPagedResult(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final raw = map['items'];
    final items = raw is List
        ? raw
              .map(
                (row) => TransferenciaArticuloModel.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : <TransferenciaArticuloModel>[];
    return TransferenciaPagedResult(
      items: items,
      total: _toInt(map['total']),
      page: _toInt(map['page']),
      limit: _toInt(map['limit']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

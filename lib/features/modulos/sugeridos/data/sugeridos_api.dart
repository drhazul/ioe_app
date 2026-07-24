import 'package:dio/dio.dart';

import '../domain/sugeridos_models.dart';

class SugeridosApi {
  SugeridosApi(this.dio);

  final Dio dio;

  Future<SugeridosPagedResult<SugeridoOrdenModel>> fetch({
    int page = 1,
    int limit = 30,
    String? search,
    String? suc,
    String? estatus,
    int? prov,
    String? from,
    String? to,
  }) async {
    final res = await dio.get(
      '/sugeridos',
      queryParameters: {
        'page': page,
        'limit': limit,
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
        if ((estatus ?? '').trim().isNotEmpty) 'estatus': estatus!.trim(),
        if (prov != null && prov > 0) 'prov': prov,
        if ((from ?? '').trim().isNotEmpty) 'from': from!.trim(),
        if ((to ?? '').trim().isNotEmpty) 'to': to!.trim(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      return const SugeridosPagedResult(
        items: [],
        total: 0,
        page: 1,
        limit: 30,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final raw = map['items'];
    return SugeridosPagedResult(
      items: raw is List
          ? raw
                .map(
                  (row) => SugeridoOrdenModel.fromJson(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
      total: _toInt(map['total']),
      page: _toInt(map['page']),
      limit: _toInt(map['limit']),
    );
  }

  Future<SugeridosPagedResult<SugeridoCalculoModel>> calcular({
    required String suc,
    int? prov,
    String? marca,
    String? tipo,
    String? lineaProducto,
    String? categoria,
    int dias = 90,
    int page = 1,
    int limit = 100,
  }) async {
    final res = await dio.get(
      '/sugeridos/calculo',
      queryParameters: {
        'suc': suc.trim(),
        'dias': dias,
        'page': page,
        'limit': limit,
        if (prov != null && prov > 0) 'prov': prov,
        if ((marca ?? '').trim().isNotEmpty) 'marca': marca!.trim(),
        if ((tipo ?? '').trim().isNotEmpty) 'tipo': tipo!.trim(),
        if ((lineaProducto ?? '').trim().isNotEmpty)
          'depa': lineaProducto!.trim(),
        if ((categoria ?? '').trim().isNotEmpty) 'clas': categoria!.trim(),
      },
    );
    final data = res.data;
    if (data is List) {
      return SugeridosPagedResult(
        items: data
            .map(
              (row) => SugeridoCalculoModel.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
        total: data.length,
        page: page,
        limit: limit,
      );
    }
    if (data is! Map) {
      return SugeridosPagedResult(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final raw = map['items'];
    return SugeridosPagedResult(
      items: raw is List
          ? raw
                .map(
                  (row) => SugeridoCalculoModel.fromJson(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
      total: _toInt(map['total']),
      page: _toInt(map['page']),
      limit: _toInt(map['limit']),
    );
  }

  Future<SugeridoOrdenModel> create({
    required String suc,
    required int nprov,
    required List<SugeridoCalculoModel> items,
  }) async {
    final res = await dio.post(
      '/sugeridos',
      data: {
        'suc': suc.trim(),
        'nprov': nprov,
        'tipo': 'NORMAL',
        'sugerido': true,
        'items': items
            .map(
              (item) => {
                'art': item.art,
                'ctdped': item.cantFinalCompra > 0
                    ? item.cantFinalCompra
                    : item.ped,
                'cto': item.cto,
                'uncom': item.unComp,
              },
            )
            .toList(),
      },
    );
    return SugeridoOrdenModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SugeridoOrdenModel> createRaw({
    required String suc,
    required int nprov,
    required List<SugeridoOrdenDraftItem> items,
    bool sugerido = false,
  }) async {
    final res = await dio.post(
      '/sugeridos',
      data: {
        'suc': suc.trim(),
        'nprov': nprov,
        'tipo': 'NORMAL',
        'sugerido': sugerido,
        'items': items.map((item) => item.toJson()).toList(),
      },
    );
    return SugeridoOrdenModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SugeridoOrdenModel> fetchOne(String nped) async {
    final res = await dio.get('/sugeridos/$nped');
    return SugeridoOrdenModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SugeridoOrdenModel> updateDetalle({
    required String nped,
    required String idped,
    double? ctdped,
    double? cto,
    String? uncom,
  }) async {
    final res = await dio.patch(
      '/sugeridos/$nped/detalle/$idped',
      data: {
        if (ctdped != null) 'ctdped': ctdped,
        if (cto != null) 'cto': cto,
        if ((uncom ?? '').trim().isNotEmpty) 'uncom': uncom!.trim(),
      },
    );
    return SugeridoOrdenModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SugeridoOrdenModel> removeDetalle({
    required String nped,
    required String idped,
  }) async {
    final res = await dio.delete('/sugeridos/$nped/detalle/$idped');
    return SugeridoOrdenModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SugeridoOrdenModel> action(String nped, String action) async {
    final res = await dio.post('/sugeridos/$nped/$action', data: const {});
    return SugeridoOrdenModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<List<String>> sucursales() async {
    final res = await dio.get('/sugeridos/catalogos/sucursales');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => '${row ?? ''}'.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<String>> estatus() async {
    final res = await dio.get('/sugeridos/catalogos/estatus');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map((row) => '${row ?? ''}'.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<SugeridoProveedorModel>> proveedores() async {
    final res = await dio.get('/sugeridos/catalogos/proveedores');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => SugeridoProveedorModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<SugeridoArticuloProveedorModel>> articulosProveedor({
    required String suc,
    required int prov,
  }) async {
    final res = await dio.get(
      '/sugeridos/catalogos/articulos-proveedor',
      queryParameters: {'suc': suc.trim(), 'prov': prov},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => SugeridoArticuloProveedorModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

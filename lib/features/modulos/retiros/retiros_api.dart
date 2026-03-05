import 'package:dio/dio.dart';

import 'retiros_models.dart';

class RetirosApi {
  RetirosApi(this.dio);

  final Dio dio;

  Future<List<RetiroPanelItem>> fetchToday() async {
    final res = await dio.get('/retiros/today');
    final raw = res.data;
    final List items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = (raw['items'] as List?) ?? const [];
    } else {
      items = const [];
    }

    return items
        .map(
          (row) =>
              RetiroPanelItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<RetiroDetailResponse> fetchRetiro(String idret) async {
    final encoded = Uri.encodeComponent(idret.trim());
    final res = await dio.get('/retiros/$encoded');
    return _toDetailResponse(res.data);
  }

  Future<RetiroDetailResponse> createRetiro({String? ter}) async {
    final res = await dio.post(
      '/retiros',
      data: {
        if ((ter ?? '').trim().isNotEmpty) 'ter': ter!.trim(),
      },
    );
    final data = res.data;
    final mapped = _toDetailResponseOrNull(data);
    if (mapped != null) return mapped;

    final row = _toMap(data);
    final idret = (row['idret'] ?? row['IDRET'] ?? '').toString().trim();
    if (idret.isEmpty) {
      throw Exception('No se recibió IDRET al crear retiro');
    }
    return fetchRetiro(idret);
  }

  Future<void> addDetalle({
    required String idret,
    required String forma,
    double? impf,
  }) async {
    final encoded = Uri.encodeComponent(idret.trim());
    await dio.post(
      '/retiros/$encoded/detalles',
      data: {
        'forma': forma.trim().toUpperCase(),
        if (impf != null) 'impf': impf,
      },
    );
  }

  Future<void> setEfectivoSingle({
    required String idfor,
    required double deno,
    required double ctda,
  }) async {
    final encoded = Uri.encodeComponent(idfor.trim());
    await dio.put(
      '/retiros/detalles/$encoded/efectivo',
      data: {
        'deno': deno,
        'ctda': ctda,
      },
    );
  }

  Future<void> setEfectivoBatch({
    required String idfor,
    required List<Map<String, dynamic>> items,
  }) async {
    final encoded = Uri.encodeComponent(idfor.trim());
    await dio.put(
      '/retiros/detalles/$encoded/efectivo',
      data: {
        'items': items
            .map(
              (item) => {
                'deno': item['deno'],
                'ctda': item['ctda'],
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<void> deleteDetalle(String idfor) async {
    final encoded = Uri.encodeComponent(idfor.trim());
    await dio.delete('/retiros/detalles/$encoded');
  }

  Future<void> finalize(String idret) async {
    final encoded = Uri.encodeComponent(idret.trim());
    await dio.post('/retiros/$encoded/finalize');
  }

  Future<void> cancel(String idret) async {
    final encoded = Uri.encodeComponent(idret.trim());
    await dio.post('/retiros/$encoded/cancel');
  }

  Future<List<RetiroFormaCatalogItem>> fetchFormasCatalog() async {
    final res = await dio.get('/catalogos/formas-retiro');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .map(
          (row) => RetiroFormaCatalogItem.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((item) => item.form.isNotEmpty)
        .toList(growable: false);
  }

  RetiroDetailResponse _toDetailResponse(dynamic raw) {
    final mapped = _toDetailResponseOrNull(raw);
    if (mapped != null) return mapped;
    throw Exception('Respuesta de retiro inválida');
  }

  RetiroDetailResponse? _toDetailResponseOrNull(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['header'] is! Map) return null;
    if (map['detalles'] is! List) return null;
    return RetiroDetailResponse.fromJson(map);
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }
}

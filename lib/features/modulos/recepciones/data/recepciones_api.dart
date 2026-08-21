import 'package:dio/dio.dart';

import '../domain/recepciones_models.dart';

class RecepcionesApi {
  RecepcionesApi(this.dio);
  final Dio dio;

  Future<RecepcionesPageResult<RecepcionOrden>> pendientes({
    int page = 1,
    int limit = 30,
    String? oc,
    int? prov,
    String? suc,
    String? from,
    String? to,
  }) async {
    final response = await dio.get(
      '/recepciones',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (_has(oc)) 'oc': oc!.trim(),
        if (prov != null && prov > 0) 'prov': prov,
        if (_has(suc)) 'suc': suc!.trim(),
        if (_has(from)) 'from': from,
        if (_has(to)) 'to': to,
      },
    );
    return _page(response.data, RecepcionOrden.fromJson);
  }

  Future<RecepcionesPageResult<RecepcionResumen>> historial({
    int page = 1,
    int limit = 30,
    String? oc,
    int? prov,
    String? suc,
    String? from,
    String? to,
  }) async {
    final response = await dio.get(
      '/recepciones/historial',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (_has(oc)) 'oc': oc!.trim(),
        if (prov != null && prov > 0) 'prov': prov,
        if (_has(suc)) 'suc': suc!.trim(),
        if (_has(from)) 'from': from,
        if (_has(to)) 'to': to,
      },
    );
    return _page(response.data, RecepcionResumen.fromJson);
  }

  Future<RecepcionOrden> orden(String nped) async {
    final response = await dio.get('/recepciones/$nped');
    return RecepcionOrden.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<Map<String, dynamic>> borrador(String nped) async {
    final response = await dio.get('/recepciones/$nped/borrador');
    return response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
  }

  Future<void> guardarBorrador({
    required String nped,
    required Map<String, dynamic> payload,
  }) async {
    await dio.post('/recepciones/$nped/borrador', data: payload);
  }

  Future<RecepcionDocumento> documento(String docrec) async {
    final response = await dio.get('/recepciones/documentos/$docrec');
    return RecepcionDocumento.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecepcionDocumento> crear({
    required String nped,
    required String tipoRecepcion,
    String? tipoDocumento,
    String? folioDocumento,
    String? observaciones,
    String almacen = '002',
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> guias = const [],
    List<Map<String, dynamic>> incidencias = const [],
    bool masiva = false,
  }) async {
    final response = await dio.post(
      '/recepciones/$nped${masiva ? '/masiva/confirmar' : ''}',
      data: {
        'tipoRecepcion': tipoRecepcion,
        if (_has(tipoDocumento)) 'tipoDocumento': tipoDocumento,
        if (_has(folioDocumento)) 'folioDocumento': folioDocumento,
        if (_has(observaciones)) 'observaciones': observaciones,
        'almacen': almacen,
        'items': items,
        'guias': guias,
        'incidencias': incidencias,
      },
    );
    return RecepcionDocumento.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<Map<String, dynamic>> validarMasiva({
    required String nped,
    required Map<String, dynamic> payload,
  }) async {
    final response = await dio.post(
      '/recepciones/$nped/masiva/validar',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<RecepcionDocumento> accion(
    String docrec,
    String accion, {
    String? motivo,
  }) async {
    final response = await dio.post(
      '/recepciones/documentos/$docrec/$accion',
      data: {if (_has(motivo)) 'motivo': motivo},
    );
    return RecepcionDocumento.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecepcionDocumento> actualizarCantidadFisica({
    required String docrec,
    required String idrec,
    required double cantidadFisica,
  }) async {
    final response = await dio.patch(
      '/recepciones/documentos/$docrec/items/$idrec/cantidad-fisica',
      data: {'cantidadFisica': cantidadFisica},
    );
    return RecepcionDocumento.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecepcionDocumento> actualizarDatos({
    required String docrec,
    required String tipoDocumento,
    required String folioDocumento,
    required String guia,
    required String paqueteria,
    required String observaciones,
  }) async {
    final response = await dio.patch(
      '/recepciones/documentos/$docrec/datos',
      data: {
        'tipoDocumento': tipoDocumento,
        'folioDocumento': folioDocumento,
        'guia': guia,
        'paqueteria': paqueteria,
        'observaciones': observaciones,
      },
    );
    return RecepcionDocumento.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecepcionDocumento> actualizarCosto({
    required String docrec,
    required String idrec,
    required double costo,
  }) async {
    final response = await dio.patch(
      '/recepciones/documentos/$docrec/items/$idrec/costo',
      data: {'costo': costo},
    );
    return RecepcionDocumento.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecepcionIndicadores> indicadores({
    String? suc,
    String? from,
    String? to,
  }) async {
    final response = await dio.get(
      '/recepciones/indicadores',
      queryParameters: {
        if (_has(suc)) 'suc': suc,
        if (_has(from)) 'from': from,
        if (_has(to)) 'to': to,
      },
    );
    return RecepcionIndicadores.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<Map<String, dynamic>>> sucursales() async {
    final response = await dio.get('/recepciones/catalogos/sucursales');
    return response.data is List
        ? (response.data as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : const [];
  }

  Future<List<Map<String, dynamic>>> proveedores() async {
    final response = await dio.get('/recepciones/catalogos/proveedores');
    return response.data is List
        ? (response.data as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : const [];
  }
}

RecepcionesPageResult<T> _page<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parser,
) {
  final map = value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
  final raw = map['items'];
  return RecepcionesPageResult(
    items: raw is List
        ? raw
              .whereType<Map>()
              .map((row) => parser(Map<String, dynamic>.from(row)))
              .toList()
        : const [],
    total: _toInt(map['total']),
    page: _toInt(map['page']),
    limit: _toInt(map['limit']),
  );
}

bool _has(String? value) => (value ?? '').trim().isNotEmpty;
int _toInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

import 'package:dio/dio.dart';

import 'ordenes_trabajo_models.dart';

class OrdenesTrabajoApi {
  OrdenesTrabajoApi(this.dio);

  final Dio dio;

  Future<OrdenTrabajoPanelResponse> fetchPanel(
    OrdenesTrabajoFilter filter,
  ) async {
    final res = await dio.get(
      '/ordenes-trabajo',
      queryParameters: filter.toQuery(),
    );
    return OrdenTrabajoPanelResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<OrdenTrabajoDetalleResponse> fetchDetail(String iord) async {
    final res = await dio.get(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/detalle',
    );
    return OrdenTrabajoDetalleResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<OrdenTrabajoDetalleResponse> saveDetail(
    String iord, {
    int? labor,
    String? comentarios,
    required List<Map<String, dynamic>> details,
  }) async {
    final cleanComments = (comentarios ?? '').trim();
    final payloadDetails = details
        .map(
          (line) => <String, dynamic>{
            if ((line['iordp']?.toString().trim() ?? '').isNotEmpty)
              'iordp': line['iordp'].toString().trim(),
            if ((line['job']?.toString().trim() ?? '').isNotEmpty)
              'job': line['job'].toString().trim(),
            'esf': line['esf']?.toString().trim() ?? '',
            'cil': line['cil']?.toString().trim() ?? '',
            'eje': line['eje']?.toString().trim() ?? '',
          },
        )
        .toList(growable: false);

    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/detalle/guardar',
      data: {
        if (labor != null) 'labor': labor,
        'comentarios': cleanComments,
        'details': payloadDetails,
      },
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final data = map['data'];
    if (data is Map) {
      return OrdenTrabajoDetalleResponse.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return fetchDetail(iord);
  }

  Future<OrdenTrabajoActionResult> autorizar(String iord) async {
    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/autorizar',
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> enviar(
    String iord, {
    String? asign,
    double? labor,
  }) async {
    final asignValue = (asign ?? '').trim();
    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/enviar',
      data: {
        if (asignValue.isNotEmpty) 'asign': asignValue,
        if (labor != null) 'labor': labor,
      },
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoEnviarRelacionItem> validarOrdEnviar(String code) async {
    final cleanCode = code.trim();
    final res = await dio.post(
      '/ordenes-trabajo/enviar/validar',
      data: {'code': cleanCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawData = map['data'];
    if (rawData is! Map) {
      throw const FormatException('Respuesta inválida de validación de ORD');
    }
    return OrdenTrabajoEnviarRelacionItem.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }

  Future<OrdenTrabajoEnviarRelacionItem> validarOrdRecibir(String code) async {
    final cleanCode = code.trim();
    final res = await dio.post(
      '/ordenes-trabajo/recibir/validar',
      data: {'code': cleanCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawData = map['data'];
    if (rawData is! Map) {
      throw const FormatException('Respuesta inválida de validación de ORD');
    }
    return OrdenTrabajoEnviarRelacionItem.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }

  Future<List<OrdenTrabajoColaboradorOption>> fetchAsignarColaboradores(
    String suc,
  ) async {
    final cleanSuc = suc.trim();
    final res = await dio.get(
      '/ordenes-trabajo/asignar/colaboradores',
      queryParameters: {'suc': cleanSuc},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawItems = (map['items'] as List?) ?? const [];
    return rawItems
        .whereType<Map>()
        .map(
          (item) => OrdenTrabajoColaboradorOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.idopv.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<OrdenTrabajoSucursalOption>> fetchSucursales() async {
    final res = await dio.get('/dat-suc');
    final rawItems = (res.data as List?) ?? const [];
    return rawItems
        .whereType<Map>()
        .map(
          (item) => OrdenTrabajoSucursalOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.suc.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<OrdenTrabajoEnviarRelacionItem> validarOrdAsignar(String code) async {
    final cleanCode = code.trim();
    final res = await dio.post(
      '/ordenes-trabajo/asignar/validar',
      data: {'code': cleanCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawData = map['data'];
    if (rawData is! Map) {
      throw const FormatException('Respuesta inválida de validación de ORD');
    }
    return OrdenTrabajoEnviarRelacionItem.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }

  Future<OrdenTrabajoEnviarRelacionItem> validarOrdTrabajoTerminado(
    String code,
  ) async {
    final cleanCode = code.trim();
    final res = await dio.post(
      '/ordenes-trabajo/trabajo-terminado/validar',
      data: {'code': cleanCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawData = map['data'];
    if (rawData is! Map) {
      throw const FormatException('Respuesta inválida de validación de ORD');
    }
    return OrdenTrabajoEnviarRelacionItem.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }

  Future<OrdenTrabajoEnviarRelacionItem> validarOrdRegresarIncidencia(
    String code,
  ) async {
    final cleanCode = code.trim();
    final res = await dio.post(
      '/ordenes-trabajo/regresar-incidencia/validar',
      data: {'code': cleanCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawData = map['data'];
    if (rawData is! Map) {
      throw const FormatException('Respuesta inválida de validación de ORD');
    }
    return OrdenTrabajoEnviarRelacionItem.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }

  Future<OrdenTrabajoEnviarRelacionItem> validarOrdRegresarTienda(
    String code,
  ) async {
    final cleanCode = code.trim();
    final res = await dio.post(
      '/ordenes-trabajo/regresar-tienda/validar',
      data: {'code': cleanCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawData = map['data'];
    if (rawData is! Map) {
      throw const FormatException('Respuesta inválida de validación de ORD');
    }
    return OrdenTrabajoEnviarRelacionItem.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }

  Future<OrdenTrabajoEnviarRelacionItem> validarOrdEntregar(String code) async {
    final cleanCode = code.trim();
    final res = await dio.post(
      '/ordenes-trabajo/entregar/validar',
      data: {'code': cleanCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final rawData = map['data'];
    if (rawData is! Map) {
      throw const FormatException('Respuesta inválida de validación de ORD');
    }
    return OrdenTrabajoEnviarRelacionItem.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }

  Future<OrdenTrabajoActionResult> enviarLote(List<String> iords) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/enviar/lote',
      data: {'iords': normalized},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> anularLote(List<String> iords) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/anular/lote',
      data: {'iords': normalized},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> recibirLote(List<String> iords) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/recibir/lote',
      data: {'iords': normalized},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> asignarLote(
    List<String> iords, {
    required String idopv,
  }) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/asignar/lote',
      data: {'iords': normalized, 'idopv': idopv.trim()},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> trabajoTerminadoLote(
    List<String> iords,
  ) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/trabajo-terminado/lote',
      data: {'iords': normalized},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> regresarIncidenciaLote(
    List<String> iords, {
    required int tipom,
  }) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/regresar-incidencia/lote',
      data: {'iords': normalized, 'tipom': tipom},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> regresarTiendaLote(
    List<String> iords,
  ) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/regresar-tienda/lote',
      data: {'iords': normalized},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> asignarLaboratorioLote(
    List<String> iords, {
    required int labor,
  }) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/asignar-laboratorio/lote',
      data: {'iords': normalized, 'labor': labor},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> entregarLote(List<String> iords) async {
    final normalized = iords
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final res = await dio.post(
      '/ordenes-trabajo/entregar/lote',
      data: {'iords': normalized},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> recibir(String iord) async {
    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/recibir',
      data: const <String, dynamic>{},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> entregar(
    String iord, {
    String? observaciones,
    String? firmaCliente,
  }) async {
    final observacionesValue = (observaciones ?? '').trim();
    final firmaClienteValue = (firmaCliente ?? '').trim();
    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/entregar',
      data: {
        if (observacionesValue.isNotEmpty) 'observaciones': observacionesValue,
        if (firmaClienteValue.isNotEmpty) 'firmaCliente': firmaClienteValue,
      },
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> garantia(
    String iord, {
    required String motivo,
  }) async {
    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/garantia',
      data: {'motivo': motivo.trim()},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> cambioMaterial(
    String iord, {
    required String artNuevo,
    required String motivo,
    double? labor,
    String? docDif,
  }) async {
    final docDifValue = (docDif ?? '').trim();
    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/cambio-material',
      data: {
        'artNuevo': artNuevo.trim(),
        'motivo': motivo.trim(),
        if (labor != null) 'labor': labor,
        if (docDifValue.isNotEmpty) 'docDif': docDifValue,
      },
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> merma(
    String iord, {
    required double cantidadMerma,
    required String motivo,
    bool crearNuevaOrd = true,
  }) async {
    final res = await dio.post(
      '/ordenes-trabajo/${Uri.encodeComponent(iord)}/merma',
      data: {
        'cantidadMerma': cantidadMerma,
        'motivo': motivo.trim(),
        'crearNuevaOrd': crearNuevaOrd,
      },
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> scanRecibir({required String code}) async {
    final res = await dio.post(
      '/ordenes-trabajo/scan/recibir',
      data: {'code': code.trim()},
    );
    return _actionFrom(res);
  }

  Future<OrdenTrabajoActionResult> scanEntregar({required String code}) async {
    final res = await dio.post(
      '/ordenes-trabajo/scan/entregar',
      data: {'code': code.trim()},
    );
    return _actionFrom(res);
  }

  OrdenTrabajoActionResult _actionFrom(Response<dynamic> res) {
    return OrdenTrabajoActionResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }
}

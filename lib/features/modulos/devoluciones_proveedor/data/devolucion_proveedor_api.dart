import 'package:dio/dio.dart';
import '../domain/devolucion_proveedor_models.dart';

class DevolucionProveedorApi {
  DevolucionProveedorApi(this.dio);
  final Dio dio;

  Future<DevPaged<DevDocument>> fetch({
    int page = 1,
    int limit = 30,
    String? document,
    String? suc,
    int? provider,
    String? status,
    String? date,
  }) async {
    final res = await dio.get(
      '/devoluciones-proveedor',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (_text(document) != null) 'doc': _text(document),
        if (_text(suc) != null) 'suc': _text(suc),
        if (provider != null) 'prov': provider,
        if (_text(status) != null) 'estatus': _text(status),
        if (_text(date) != null) 'from': _text(date),
        if (_text(date) != null) 'to': _text(date),
      },
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final raw = map['items'];
    return DevPaged(
      items: raw is List
          ? raw
                .map(
                  (e) =>
                      DevDocument.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : const [],
      total: _int(map['total']),
      page: _int(map['page']),
      limit: _int(map['limit']),
    );
  }

  Future<DevDocument> fetchOne(String doc) async => DevDocument.fromJson(
    Map<String, dynamic>.from(
      (await dio.get('/devoluciones-proveedor/$doc')).data as Map,
    ),
  );

  Future<DevSourceDocument> sourceDocument({
    String? order,
    String? receipt,
  }) async {
    final receiptValue = (receipt ?? '').trim();
    final orderValue = (order ?? '').trim();
    if (receiptValue.isEmpty && orderValue.isEmpty) {
      throw ArgumentError('Se requiere una orden o recepción.');
    }
    final isReceipt = receiptValue.isNotEmpty;
    final document = isReceipt ? receiptValue : orderValue;
    final path = isReceipt
        ? '/recepciones/documentos/${Uri.encodeComponent(document)}'
        : '/sugeridos/${Uri.encodeComponent(document)}';
    final response = await dio.get(path);
    return DevSourceDocument.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      kind: isReceipt ? 'Recepción' : 'Orden de compra',
      document: document,
    );
  }

  Future<List<DevOption>> types() async =>
      _list('/devoluciones-proveedor/catalogos/tipos', DevOption.fromJson);
  Future<List<DevOption>> reasons() async =>
      _list('/devoluciones-proveedor/catalogos/motivos', DevOption.fromJson);
  Future<List<DevProvider>> providers() async => _list(
    '/devoluciones-proveedor/catalogos/proveedores',
    DevProvider.fromJson,
  );
  Future<List<DevBranch>> branches() async =>
      _list('/devoluciones-proveedor/catalogos/sucursales', DevBranch.fromJson);

  Future<DevPaged<DevArticle>> articles({
    required String suc,
    required int provider,
    String? search,
    String searchBy = 'ART',
    String? depa,
    String? subd,
    String? clas,
    String? scla,
    String? scla2,
    String? sph,
    String? cyl,
    String? adic,
    int page = 1,
  }) async {
    final res = await dio.get(
      '/devoluciones-proveedor/catalogos/articulos',
      queryParameters: {
        'suc': suc,
        'prov': provider,
        'page': page,
        'limit': 30,
        if (_text(search) != null) 'search': _text(search),
        'searchBy': searchBy,
        if (_text(depa) != null) 'depa': _text(depa),
        if (_text(subd) != null) 'subd': _text(subd),
        if (_text(clas) != null) 'clas': _text(clas),
        if (_text(scla) != null) 'scla': _text(scla),
        if (_text(scla2) != null) 'scla2': _text(scla2),
        if (_text(sph) != null) 'sph': _text(sph),
        if (_text(cyl) != null) 'cyl': _text(cyl),
        if (_text(adic) != null) 'adic': _text(adic),
      },
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final raw = map['items'];
    return DevPaged(
      items: raw is List
          ? raw
                .map(
                  (e) =>
                      DevArticle.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : const [],
      total: _int(map['total']),
      page: _int(map['page']),
      limit: _int(map['limit']),
    );
  }

  Future<DevDocument> create({
    required String suc,
    required int provider,
    required int type,
    String warehouse = '002',
    String? oc,
    String? receipt,
    String? obs,
  }) async {
    final res = await dio.post(
      '/devoluciones-proveedor',
      data: {
        'suc': suc,
        'provd': provider,
        'tipoDev': type,
        'almacen': warehouse,
        if (_text(oc) != null) 'docOc': _text(oc),
        if (_text(receipt) != null) 'docRec': _text(receipt),
        if (_text(obs) != null) 'obs': _text(obs),
      },
    );
    return DevDocument.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DevDocument> addDetail(
    String doc, {
    required DevArticle article,
    required double quantity,
    required int reason,
    String? lot,
    String? expiration,
    String? obs,
    String? evidenceName,
    String? evidenceMimeType,
    String? evidenceContent,
  }) async {
    final res = await dio.post(
      '/devoluciones-proveedor/$doc/detalle',
      data: {
        'art': article.art,
        'cantidad': quantity,
        // En importaciones el Excel no incluye costo. Al omitirlo, el SP usa
        // DAT_ART.CTOP y recalcula tanto el importe del renglón como el total.
        if (article.cost > 0) 'costo': article.cost,
        'motivo': reason,
        if (_text(lot) != null) 'lote': _text(lot),
        if (_text(expiration) != null) 'caducidad': _text(expiration),
        if (_text(obs) != null) 'obs': _text(obs),
        if (evidenceContent != null && evidenceMimeType != null)
          'evidencia': {
            'nombreArchivo': evidenceName,
            'mimeType': evidenceMimeType,
            'contenido': evidenceContent,
          },
      },
    );
    return DevDocument.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DevDocument> removeDetail(String doc, int idpd) async =>
      DevDocument.fromJson(
        Map<String, dynamic>.from(
          (await dio.delete('/devoluciones-proveedor/$doc/detalle/$idpd')).data
              as Map,
        ),
      );
  Future<DevDocument> updateDetail(
    String doc,
    int idpd, {
    required double quantity,
    required int reason,
    String? lot,
    String? expiration,
  }) async => DevDocument.fromJson(
    Map<String, dynamic>.from(
      (await dio.patch(
            '/devoluciones-proveedor/$doc/detalle/$idpd',
            data: {
              'cantidad': quantity,
              'motivo': reason,
              'lote': _text(lot) ?? '',
              'caducidad': _text(expiration),
            },
          )).data
          as Map,
    ),
  );
  Future<List<DevEvidence>> evidences(String doc, int idpd) async {
    final data = (await dio.get(
      '/devoluciones-proveedor/$doc/detalle/$idpd/evidencias',
    )).data;
    return data is List
        ? data
              .map(
                (item) => DevEvidence.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : const [];
  }

  Future<void> updateEvidence(
    String doc,
    int idpd,
    String evidenceId, {
    required String name,
    required String mimeType,
    required String content,
  }) async {
    await dio.patch(
      '/devoluciones-proveedor/$doc/detalle/$idpd/evidencias/$evidenceId',
      data: {'nombreArchivo': name, 'mimeType': mimeType, 'contenido': content},
    );
  }

  Future<DevDocument> evidence(
    String doc,
    int idpd, {
    required String name,
    required String mimeType,
    required String content,
  }) async => DevDocument.fromJson(
    Map<String, dynamic>.from(
      (await dio.post(
            '/devoluciones-proveedor/$doc/detalle/$idpd/evidencia',
            data: {
              'nombreArchivo': name,
              'mimeType': mimeType,
              'contenido': content,
            },
          )).data
          as Map,
    ),
  );
  Future<DevDocument> documentEvidence(
    String doc, {
    required String name,
    required String mimeType,
    required String content,
  }) async => DevDocument.fromJson(
    Map<String, dynamic>.from(
      (await dio.post(
            '/devoluciones-proveedor/$doc/evidencia',
            data: {
              'nombreArchivo': name,
              'mimeType': mimeType,
              'contenido': content,
            },
          )).data
          as Map,
    ),
  );
  Future<List<DevEvidence>> documentEvidences(String doc) async {
    final data = (await dio.get(
      '/devoluciones-proveedor/$doc/evidencias',
    )).data;
    return data is List
        ? data
              .map(
                (item) => DevEvidence.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : const [];
  }

  Future<DevDocument> action(
    String doc,
    String action, {
    String? reason,
  }) async => DevDocument.fromJson(
    Map<String, dynamic>.from(
      (await dio.post(
            '/devoluciones-proveedor/$doc/$action',
            data: {if (_text(reason) != null) 'motivo': _text(reason)},
          )).data
          as Map,
    ),
  );

  Future<void> transit(
    String doc, {
    required String carrier,
    required String tracking,
    required int boxes,
    String? rma,
    String? obs,
  }) async {
    await dio.post(
      '/devoluciones-proveedor/$doc/transito',
      data: {
        'transportista': carrier.trim(),
        'guia': tracking.trim(),
        'cajas': boxes,
        if (_text(rma) != null) 'rma': _text(rma),
        if (_text(obs) != null) 'obs': _text(obs),
      },
    );
  }

  Future<String> consolidate({
    required List<String> documents,
    required String carrier,
    required String tracking,
    required int boxes,
    String? rma,
    String? obs,
  }) async {
    final res = await dio.post(
      '/devoluciones-proveedor/envios',
      data: {
        'documentos': documents,
        'transportista': carrier.trim(),
        'guia': tracking.trim(),
        'cajas': boxes,
        if (_text(rma) != null) 'rma': _text(rma),
        if (_text(obs) != null) 'obs': _text(obs),
      },
    );
    return '${(res.data as Map)['envio'] ?? ''}'.trim();
  }

  Future<List<Map<String, dynamic>>> shipments() async {
    final data = (await dio.get('/devoluciones-proveedor/envios')).data;
    return data is List
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : const [];
  }

  Future<void> registerDeparture(String shipment) async {
    await dio.post('/devoluciones-proveedor/envios/$shipment/salida');
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) mapper,
  ) async {
    final data = (await dio.get(path)).data;
    return data is List
        ? data.map((e) => mapper(Map<String, dynamic>.from(e as Map))).toList()
        : <T>[];
  }
}

String? _text(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

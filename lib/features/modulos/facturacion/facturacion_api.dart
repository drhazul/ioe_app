import 'package:dio/dio.dart';

class FacturacionPendientesPage {
  const FacturacionPendientesPage({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<Map<String, dynamic>> data;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory FacturacionPendientesPage.fromJson(dynamic rawData) {
    if (rawData is! Map) {
      return const FacturacionPendientesPage(
        data: [],
        total: 0,
        page: 1,
        pageSize: 60,
        totalPages: 0,
      );
    }

    final map = Map<String, dynamic>.from(rawData);
    final rows = (map['data'] is List)
        ? (map['data'] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : const <Map<String, dynamic>>[];

    final total = _toInt(map['total']) ?? rows.length;
    final page = _clampInt(_toInt(map['page']) ?? 1, min: 1, max: 2147483647);
    final pageSize =
        _clampInt(_toInt(map['pageSize']) ?? 60, min: 1, max: 2147483647);
    final totalPages = _clampInt(
      _toInt(map['totalPages']) ?? (total == 0 ? 0 : (total / pageSize).ceil()),
      min: 0,
      max: 2147483647,
    );

    return FacturacionPendientesPage(
      data: rows,
      total: total,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

int _clampInt(
  int value, {
  required int min,
  required int max,
}) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

class FacturacionApi {
  FacturacionApi(this.dio);

  final Dio dio;

  String _folioPath(String idFol) => Uri.encodeComponent(idFol.trim());
  Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from((value as Map?) ?? const <String, dynamic>{});

  List<String> _normalizeIdFols(List<String> idFols) {
    final out = <String>[];
    for (final raw in idFols) {
      final id = raw.trim().toUpperCase();
      if (id.isEmpty) continue;
      if (out.contains(id)) continue;
      out.add(id);
    }
    return out;
  }

  Future<FacturacionPendientesPage> fetchPendientes({
    required int page,
    required int pageSize,
    String? suc,
    String? estatus,
    String? razonSocialReceptor,
    String? rfcReceptor,
    String? clien,
    String? idFol,
    String? tipoFact,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
      if ((estatus ?? '').trim().isNotEmpty) 'estatus': estatus!.trim(),
      if ((razonSocialReceptor ?? '').trim().isNotEmpty)
        'razonSocialReceptor': razonSocialReceptor!.trim(),
      if ((rfcReceptor ?? '').trim().isNotEmpty)
        'rfcReceptor': rfcReceptor!.trim(),
      if ((clien ?? '').trim().isNotEmpty) 'clien': clien!.trim(),
      if ((idFol ?? '').trim().isNotEmpty) 'idFol': idFol!.trim(),
      if ((tipoFact ?? '').trim().isNotEmpty) 'tipoFact': tipoFact!.trim(),
    };

    final res = await dio.get(
      '/facturacion/pendientes',
      queryParameters: query,
    );
    final data = res.data;
    if (data is List) {
      final rows = data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      return FacturacionPendientesPage(
        data: rows,
        total: rows.length,
        page: 1,
        pageSize: rows.isEmpty ? pageSize : rows.length,
        totalPages: rows.isEmpty ? 0 : 1,
      );
    }
    return FacturacionPendientesPage.fromJson(data);
  }

  Future<Map<String, dynamic>> validar(String idFol) async {
    final res = await dio.get('/facturacion/${_folioPath(idFol)}/validar');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> emitir(String idFol) async {
    final res = await dio.post('/facturacion/${_folioPath(idFol)}/emitir', data: const {});
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> actualizarClienteFiscal(
    String idCliente,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.patch(
      '/factclientshp/${Uri.encodeComponent(idCliente.trim())}',
      data: Map<String, dynamic>.from(payload),
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> refrescarEstado(String idFol) async {
    final res = await dio.post('/facturacion/${_folioPath(idFol)}/refrescar-estado', data: const {});
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> reenviarEmail(String idFol, {String? email}) async {
    final res = await dio.post('/facturacion/${_folioPath(idFol)}/reenviar-email', data: {
      if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
    });
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> cancelar(String idFol, {String? motivo}) async {
    final res = await dio.post('/facturacion/${_folioPath(idFol)}/cancelar', data: {
      if ((motivo ?? '').trim().isNotEmpty) 'motivo': motivo!.trim(),
    });
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> obtenerArtefactos(String idFol) async {
    final res = await dio.get('/facturacion/${_folioPath(idFol)}/artifacts');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> previewUnificacion(List<String> idFols) async {
    final ids = _normalizeIdFols(idFols);
    final res = await dio.post(
      '/facturacion/unificaciones/preview',
      data: <String, dynamic>{'idFols': ids},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> crearUnificacion(
    List<String> idFols, {
    String? comentario,
  }) async {
    final ids = _normalizeIdFols(idFols);
    final res = await dio.post(
      '/facturacion/unificaciones',
      data: <String, dynamic>{
        'idFols': ids,
        if ((comentario ?? '').trim().isNotEmpty) 'comentario': comentario!.trim(),
      },
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> reversarUnificacion(
    String grupoId, {
    required String motivo,
  }) async {
    final res = await dio.post(
      '/facturacion/unificaciones/${_folioPath(grupoId)}/reversa',
      data: <String, dynamic>{'motivo': motivo.trim()},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> detalleUnificacion(String grupoId) async {
    final res = await dio.get('/facturacion/unificaciones/${_folioPath(grupoId)}');
    return _asMap(res.data);
  }
}


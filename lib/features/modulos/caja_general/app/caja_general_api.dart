import 'package:dio/dio.dart';

import 'caja_general_models.dart';

class CajaGeneralApi {
  CajaGeneralApi(this.dio);

  final Dio dio;

  Future<CajaGeneralOpvResumen> fetchResumenOpv({
    required String suc,
    required DateTime fecha,
    required String opv,
  }) async {
    const tipoOperacion = 'GLOBAL';
    final res = await dio.get(
      '/caja-general/opv/resumen',
      queryParameters: {
        'suc': suc.trim(),
        'fcn': _formatSqlDate(fecha),
        'opv': opv.trim(),
        'tipo': tipoOperacion,
      },
    );
    return CajaGeneralOpvResumen.fromJson(_toMap(res.data));
  }

  Future<CajaGeneralGlobalResumen> fetchResumenGlobal({
    required String suc,
    required DateTime fecha,
  }) async {
    const tipoOperacion = 'GLOBAL';
    final res = await dio.get(
      '/caja-general/global/resumen',
      queryParameters: {
        'suc': suc.trim(),
        'fcn': _formatSqlDate(fecha),
        'tipo': tipoOperacion,
      },
    );
    return CajaGeneralGlobalResumen.fromJson(_toMap(res.data));
  }

  Future<List<CajaGeneralPendiente>> fetchPendientes({
    required String suc,
    required DateTime fecha,
  }) async {
    const tipoOperacion = 'GLOBAL';
    final res = await dio.get(
      '/caja-general/opv/pendientes',
      queryParameters: {
        'suc': suc.trim(),
        'fcn': _formatSqlDate(fecha),
        'tipo': tipoOperacion,
      },
    );
    final data = _toMap(res.data);
    final itemsRaw = data['items'];
    if (itemsRaw is! List) return const [];
    return itemsRaw
        .whereType<Map>()
        .map((row) => CajaGeneralPendiente.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> cerrarEntregaOpv({
    required String suc,
    required DateTime fecha,
    required String opv,
    String? ter,
    String? user,
    List<CerrarEntregaFormaInput> entregas = const [],
  }) async {
    const tipoOperacion = 'GLOBAL';
    final res = await dio.post(
      '/caja-general/opv/cerrar',
      data: {
        'suc': suc.trim(),
        'fcn': _formatSqlDate(fecha),
        'opv': opv.trim(),
        'tipo': tipoOperacion,
        if ((ter ?? '').trim().isNotEmpty) 'ter': ter!.trim(),
        if ((user ?? '').trim().isNotEmpty) 'user': user!.trim(),
        if (entregas.isNotEmpty)
          'entregas': entregas
              .map((e) => {'form': e.form.trim(), 'impe': e.impe})
              .toList(growable: false),
      },
    );
    return _toMap(res.data);
  }

  Future<Map<String, dynamic>> reactivarEntregaOpv({
    required String suc,
    required DateTime fecha,
    required String opv,
    String? ter,
    String? user,
  }) async {
    final res = await dio.post(
      '/caja-general/opv/reactivar',
      data: {
        'suc': suc.trim(),
        'fcn': _formatSqlDate(fecha),
        'opv': opv.trim(),
        if ((ter ?? '').trim().isNotEmpty) 'ter': ter!.trim(),
        if ((user ?? '').trim().isNotEmpty) 'user': user!.trim(),
      },
    );
    return _toMap(res.data);
  }

  Future<Map<String, dynamic>> fetchReporteOpv({
    required String suc,
    required DateTime fecha,
    required String opv,
    required String tipo,
  }) async {
    final res = await dio.get(
      '/caja-general/opv/reporte',
      queryParameters: {
        'suc': suc.trim(),
        'fcn': _formatSqlDate(fecha),
        'opv': opv.trim(),
        'tipo': tipo.trim().toUpperCase(),
      },
    );
    return _toMap(res.data);
  }

  Future<Map<String, dynamic>> fetchReporteGlobal({
    required String suc,
    required DateTime fecha,
    required String tipo,
  }) async {
    final res = await dio.get(
      '/caja-general/global/reporte',
      queryParameters: {
        'suc': suc.trim(),
        'fcn': _formatSqlDate(fecha),
        'tipo': tipo.trim().toUpperCase(),
      },
    );
    return _toMap(res.data);
  }

  String _formatSqlDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final y = normalized.year.toString().padLeft(4, '0');
    final m = normalized.month.toString().padLeft(2, '0');
    final d = normalized.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}

class CerrarEntregaFormaInput {
  const CerrarEntregaFormaInput({
    required this.form,
    required this.impe,
  });

  final String form;
  final double impe;
}

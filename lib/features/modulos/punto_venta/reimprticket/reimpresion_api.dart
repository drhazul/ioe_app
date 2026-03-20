import 'package:dio/dio.dart';

import '../../pagos_servicios/ps_models.dart';
import '../cotizaciones/cotizaciones_models.dart';
import '../cotizaciones/pago/pago_cotizacion_models.dart';
import '../devoluciones/devoluciones_models.dart';
import 'reimpresion_models.dart';

class ReimpresionApi {
  ReimpresionApi(this.dio);

  final Dio dio;

  Future<ReimpresionAuthorizationSession> autorizarSupervisor({
    required String passwordSupervisor,
  }) async {
    final password = passwordSupervisor.trim();
    final res = await dio.post(
      '/cajon-estado/autorizar',
      data: {'passwordSupervisor': password},
    );
    final data = _toMap(res.data);
    final session = ReimpresionAuthorizationSession.fromJson(data);
    if (session.authorizationToken.isEmpty) {
      throw Exception('No se recibio authorizationToken de supervisor.');
    }
    return session;
  }

  Future<ReimpresionPageResult> fetchReimpresiones({
    String? suc,
    String? opv,
    String? search,
    String? fcnm,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await dio.get(
      '/pvctrfolasvr/reimpresion',
      queryParameters: {
        if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
        if ((opv ?? '').trim().isNotEmpty) 'opv': opv!.trim(),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        if ((fcnm ?? '').trim().isNotEmpty) 'fcnm': fcnm!.trim(),
        'page': page,
        'pageSize': pageSize,
      },
    );

    final raw = res.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final rowsRaw = (map['data'] as List?) ?? const [];
      final rows = rowsRaw
          .map(
            (e) => PvCtrFolAsvrModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(growable: false);
      return ReimpresionPageResult(
        data: rows,
        total: _asInt(map['total']),
        page: _asInt(map['page']),
        pageSize: _asInt(map['pageSize']),
        totalPages: _asInt(map['totalPages']),
      );
    }

    final rowsRaw = raw is List ? raw : const [];
    final rows = rowsRaw
        .map(
          (e) => PvCtrFolAsvrModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false);
    return ReimpresionPageResult(
      data: rows,
      total: rows.length,
      page: page,
      pageSize: pageSize,
      totalPages: rows.isEmpty ? 0 : 1,
    );
  }

  Future<PagoCierrePrintPreviewResponse> fetchCotizacionPrintPreview(
    String idfol,
  ) async {
    final encoded = Uri.encodeComponent(idfol.trim());
    final res = await dio.get('/pv/cotizaciones/$encoded/cierre/print-preview');
    final data = _toMap(res.data);
    return PagoCierrePrintPreviewResponse.fromJson(data);
  }

  Future<DevolucionPrintPreviewResponse> fetchDevolucionPrintPreview(
    String idfolDev,
  ) async {
    final encoded = Uri.encodeComponent(idfolDev.trim());
    final res = await dio.get('/pv/devoluciones/$encoded/print-preview');
    final data = _toMap(res.data);
    return DevolucionPrintPreviewResponse.fromJson(data);
  }

  Future<PsPagoSummary> fetchPsSummary(String idfol) async {
    final encoded = Uri.encodeComponent(idfol.trim());
    final res = await dio.get('/ps/folios/$encoded/formas-pago/summary');
    final data = _toMap(res.data);
    return PsPagoSummary.fromJson(data);
  }

  Future<PsDetalleResponse> fetchPsDetalle(String idfol) async {
    final encoded = Uri.encodeComponent(idfol.trim());
    final res = await dio.get('/ps/folios/$encoded');
    final data = _toMap(res.data);
    return PsDetalleResponse.fromJson(data);
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

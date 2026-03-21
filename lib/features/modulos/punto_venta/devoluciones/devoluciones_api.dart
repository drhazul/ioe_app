import 'package:dio/dio.dart';

import 'devoluciones_models.dart';

class DevolucionesApi {
  DevolucionesApi(this.dio);

  final Dio dio;

  Future<List<DevolucionPanelItem>> fetchPanel({
    String? suc,
    String? opv,
    String? search,
  }) async {
    final res = await dio.get(
      '/pv/devoluciones',
      queryParameters: {
        if ((suc ?? '').trim().isNotEmpty) 'suc': suc!.trim(),
        if ((opv ?? '').trim().isNotEmpty) 'opv': opv!.trim(),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final itemsRaw = (data['items'] as List?) ?? const [];
    final parsed = itemsRaw
        .map(
          (row) => DevolucionPanelItem.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
    return parsed.where((item) => _isVisiblePanelEstado(item.esta)).toList();
  }

  Future<DevolucionDetalleResponse> createDevolucion({
    required String idfolOrig,
    required String authPassword,
  }) async {
    final res = await dio.post(
      '/pv/devoluciones/crear',
      data: {
        'idfolOrig': idfolOrig.trim(),
        'authPassword': authPassword,
      },
    );
    return DevolucionDetalleResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DevolucionDetalleResponse> fetchDetalle(String idfolDev) async {
    final res = await dio.get('/pv/devoluciones/$idfolDev/detalle');
    return DevolucionDetalleResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DevolucionDetalleResponse> devolverTodo(String idfolDev) async {
    final res = await dio.post('/pv/devoluciones/$idfolDev/devolver-todo');
    return DevolucionDetalleResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DevolucionDetalleResponse> updateCtdd({
    required String idfolDev,
    required String lineId,
    required double? ctdd,
  }) async {
    final res = await dio.patch(
      '/pv/devoluciones/$idfolDev/lineas/$lineId',
      data: {'ctdd': ctdd},
    );
    return DevolucionDetalleResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DevolucionDetallePreparadoResponse> prepararDetalle(String idfolDev) async {
    final res = await dio.post('/pv/devoluciones/$idfolDev/detalle/preparar');
    return DevolucionDetallePreparadoResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DevolucionPagoPreviewResponse> previewPago({
    required String idfolDev,
    bool? rqfac,
  }) async {
    final res = await dio.post(
      '/pv/devoluciones/$idfolDev/pago/preview',
      data: {
        if (rqfac != null) 'rqfac': rqfac,
      },
    );
    return DevolucionPagoPreviewResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DevolucionPagoFinalizarResponse> finalizarPago({
    required String idfolDev,
    required bool rqfac,
    required List<DevolucionFormaDraft> formas,
  }) async {
    final res = await dio.post(
      '/pv/devoluciones/$idfolDev/pago/finalizar',
      data: {
        'rqfac': rqfac,
        'formas': formas.map((item) => item.toApiJson()).toList(),
      },
    );
    return DevolucionPagoFinalizarResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<DevolucionPrintPreviewResponse> fetchPrintPreview(String idfolDev) async {
    final res = await dio.get('/pv/devoluciones/$idfolDev/print-preview');
    return DevolucionPrintPreviewResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<void> updateEstado({
    required String idfol,
    required String esta,
  }) async {
    await dio.patch(
      '/pvctrfolasvr/$idfol',
      data: <String, dynamic>{'ESTA': esta.trim().toUpperCase()},
    );
  }

  bool _isVisiblePanelEstado(String? value) {
    final estado = (value ?? '').trim().toUpperCase();
    return estado == 'PENDIENTE' ||
        estado == 'EDITANDO' ||
        estado == 'PAGADO';
  }
}


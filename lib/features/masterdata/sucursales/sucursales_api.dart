import 'package:dio/dio.dart';
import 'package:ioe_app/core/storage.dart';

import 'sucursales_models.dart';

class UsbImportEventPayload {
  final int idUsuario;
  final String tipo;
  final String fechaIso;
  final String? suc;
  final String? deviceId;
  final String? authMethod;

  const UsbImportEventPayload({
    required this.idUsuario,
    required this.tipo,
    required this.fechaIso,
    this.suc,
    this.deviceId,
    this.authMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'idUsuario': idUsuario,
      'tipo': tipo,
      'fecha': fechaIso,
      if (suc != null && suc!.trim().isNotEmpty) 'suc': suc!.trim(),
      if (deviceId != null && deviceId!.trim().isNotEmpty)
        'deviceId': deviceId!.trim(),
      if (authMethod != null && authMethod!.trim().isNotEmpty)
        'authMethod': authMethod!.trim(),
    };
  }
}

class SucursalesApi {
  final Dio dio;
  final Storage storage;
  SucursalesApi(this.dio, this.storage);

  Future<List<SucursalModel>> fetchSucursales({
    String? suc,
    String? desc,
  }) async {
    final query = <String, dynamic>{};
    if (suc != null && suc.isNotEmpty) query['suc'] = suc;
    if (desc != null && desc.isNotEmpty) query['desc'] = desc;

    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/dat-suc',
      queryParameters: query.isEmpty ? null : query,
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data as List<dynamic>)
        .map((e) => SucursalModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SucursalModel> fetchSucursal(String suc) async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/dat-suc/${Uri.encodeComponent(suc)}',
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<SucursalModel> createSucursal(Map<String, dynamic> payload) async {
    final token = await storage.getAccessToken();
    final cleanPayload = _sanitizeSucursalPayload(payload);
    final res = await dio.post(
      '/dat-suc',
      data: cleanPayload,
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<SucursalModel> updateSucursal(
    String suc,
    Map<String, dynamic> payload,
  ) async {
    final token = await storage.getAccessToken();
    final cleanPayload = _sanitizeSucursalPayload(payload);
    final res = await dio.patch(
      '/dat-suc/${Uri.encodeComponent(suc)}',
      data: cleanPayload,
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<String?> deleteSucursal(String suc) async {
    final token = await storage.getAccessToken();
    final res = await dio.delete(
      '/dat-suc/${Uri.encodeComponent(suc)}',
      options: Options(
        // Evita que un 409 dispare una excepción y corte el flujo normal (lo manejamos nosotros)
        validateStatus: (status) {
          if (status == null) return false;
          if (status == 409) return true;
          return status >= 200 && status < 300;
        },
        headers: token == null || token.isEmpty
            ? null
            : {'Authorization': 'Bearer $token'},
      ),
    );

    if (res.statusCode == 409) {
      final data = res.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'No se puede eliminar la sucursal porque está en uso.';
      return msg;
    }

    return null;
  }

  Future<List<SucursalGestionModel>> fetchGestionSucursales() async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/sucursales',
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return (res.data as List<dynamic>)
        .map(
          (e) => SucursalGestionModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<SucursalGestionModel> createGestionSucursal(
    Map<String, dynamic> payload,
  ) async {
    final token = await storage.getAccessToken();
    final cleanPayload = _sanitizeSucursalPayload(payload);
    final res = await dio.post(
      '/sucursales',
      data: cleanPayload,
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return SucursalGestionModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<void> deleteGestionSucursal(int id) async {
    final token = await storage.getAccessToken();
    await dio.delete(
      '/sucursales/$id',
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<SucursalGestionModel> updateGestionSucursal(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final token = await storage.getAccessToken();
    final cleanPayload = _sanitizeSucursalPayload(payload);
    final res = await dio.patch(
      '/sucursales/$id',
      data: cleanPayload,
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalGestionModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<Map<String, dynamic>> importUsbEventos({
    required List<UsbImportEventPayload> events,
    String? suc,
  }) async {
    final token = await storage.getAccessToken();
    final res = await dio.post(
      '/sucursales/import-usb',
      data: {
        'events': events.map((e) => e.toJson()).toList(),
        if (suc != null && suc.trim().isNotEmpty) 'suc': suc.trim(),
      },
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> cleanupComandos({
    String? suc,
    int olderThanMinutes = 30,
  }) async {
    final token = await storage.getAccessToken();
    final res = await dio.post(
      '/sucursales/comandos/cleanup',
      data: {
        if (suc != null && suc.trim().isNotEmpty) 'suc': suc.trim(),
        'olderThanMinutes': olderThanMinutes,
      },
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getSucursalToken(String codigo) async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/sucursales/${Uri.encodeComponent(codigo)}/token',
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<SucursalConfigResponseModel> getSucursalConfig(String codigo) async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/sucursales/${Uri.encodeComponent(codigo)}/config',
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return SucursalConfigResponseModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<Map<String, dynamic>> sendSucursalCommand({
    required String suc,
    required String command,
    String? deviceId,
  }) async {
    final token = await storage.getAccessToken();
    final res = await dio.post(
      '/sucursales/comandos/accion',
      data: {
        'suc': suc.trim(),
        'command': command.trim().toUpperCase(),
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'device_id': deviceId.trim(),
      },
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<SucursalCommandHistoryModel>> listSucursalCommands(
    String codigo, {
    int limit = 5,
  }) async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/sucursales/${Uri.encodeComponent(codigo)}/comandos',
      queryParameters: {'limit': limit},
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final map = Map<String, dynamic>.from(res.data as Map);
    final rows = (map['rows'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map(
          (e) => SucursalCommandHistoryModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _sanitizeSucursalPayload(Map<String, dynamic> payload) {
    final data = Map<String, dynamic>.from(payload);
    data.removeWhere((_, value) => value == null);
    data.remove('latitud');
    data.remove('longitud');
    data.remove('radio_metros');
    data.remove('timezone');
    data.remove('zona_horaria');
    data.remove('id_nomina_erp');
    data.remove('id_externo_nomina');
    data.remove('nombre_sucursal');
    data.remove('empresa_perteneciente');

    return data;
  }
}

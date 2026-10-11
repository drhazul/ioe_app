import 'package:dio/dio.dart';

class CfdiCorreoApi {
  CfdiCorreoApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> configuracion() async {
    final response = await _dio.get<dynamic>('/cfdi/correo/configuracion');
    final data = response.data;
    return data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> guardarConfiguracion({
    required bool automatico,
    required String nombreRemitente,
  }) async {
    final response = await _dio.put<dynamic>(
      '/cfdi/correo/configuracion',
      data: {
        'automatico': automatico,
        'nombreRemitente': nombreRemitente,
      },
    );
    final data = response.data;
    return data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
  }

  Future<String> iniciarOAuth() async {
    final response = await _dio.post<dynamic>('/cfdi/correo/oauth/iniciar');
    final data = response.data;
    if (data is! Map || data['authorizationUrl'] is! String) {
      throw StateError('La API no devolvió la URL de autorización Google.');
    }
    return data['authorizationUrl'] as String;
  }

  Future<Map<String, dynamic>> probar(String destinatario) async {
    final response = await _dio.post<dynamic>(
      '/cfdi/correo/prueba',
      data: {'destinatario': destinatario},
    );
    final data = response.data;
    return data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> envios() async {
    final response = await _dio.get<dynamic>(
      '/cfdi/correo/envios',
      queryParameters: {'limit': 50},
    );
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> reintentar(int id) async {
    await _dio.post<dynamic>('/cfdi/correo/envios/$id/reintentar');
  }
}

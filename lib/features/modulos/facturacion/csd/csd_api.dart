import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'csd_models.dart';

/// Llamadas a `/cfdi/csd` de la API.
class CsdApi {
  CsdApi(this._dio);

  final Dio _dio;

  /// Certificados cargados. Sin archivos ni contrasenas.
  Future<List<CsdModel>> listar() async {
    final res = await _dio.get<dynamic>('/cfdi/csd');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => CsdModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Da de alta o renueva el certificado de una razon social.
  ///
  /// El RFC no se manda: la API lo lee del propio `.cer`, asi no hay forma de
  /// subir el certificado de una empresa bajo el RFC de otra.
  Future<Map<String, dynamic>> guardar({
    required Uint8List cer,
    required Uint8List key,
    required String password,
    required String regimenFiscal,
    required String codigoPostal,
    String? quadrumUsuario,
    String? quadrumPassword,
  }) async {
    final res = await _dio.post<dynamic>(
      '/cfdi/csd',
      data: {
        'cerBase64': base64Encode(cer),
        'keyBase64': base64Encode(key),
        'password': password,
        'regimenFiscal': regimenFiscal,
        'codigoPostal': codigoPostal,
        // Solo se mandan si se capturaron: en blanco, la API conserva
        // la cuenta que ya tuviera ese RFC.
        if (quadrumUsuario != null && quadrumUsuario.trim().isNotEmpty)
          'quadrumUsuario': quadrumUsuario.trim(),
        if (quadrumPassword != null && quadrumPassword.isNotEmpty)
          'quadrumPassword': quadrumPassword,
      },
    );
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}

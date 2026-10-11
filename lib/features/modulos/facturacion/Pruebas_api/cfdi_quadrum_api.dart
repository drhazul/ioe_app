import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Cliente de los endpoints `/cfdi/*` de la API (timbrado directo con Quadrum).
///
/// Incluye las operaciones de prueba, las de consulta y las de un folio real:
/// la SIMULACION (`probarFolio`), que no escribe nada, y la emision
/// (`emitirFolio`), que si timbra y marca el folio.
class CfdiQuadrumApi {
  CfdiQuadrumApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> estado() => _get('/cfdi/estado');

  /// SIMULACION de un folio real: lo arma y lo sella con el CSD de su RFC
  /// emisor. No llama al PAC y no escribe en la base.
  Future<Map<String, dynamic>> probarFolio(String idFol) =>
      _post('/cfdi/probar/${Uri.encodeComponent(idFol)}');

  /// Timbra un folio REAL con Quadrum y lo marca con CFDI_PAC = 'QUADRUM'.
  Future<Map<String, dynamic>> emitirFolio(String idFol) => _post(
    '/cfdi/emitir/${Uri.encodeComponent(idFol)}',
    {'confirmar': true},
  );

  /// XML timbrado del folio: el documento fiscal, tal como se sello.
  Future<Uint8List> descargarXml(String idFol) =>
      _bytes('/cfdi/xml/${Uri.encodeComponent(idFol)}');

  /// Representacion impresa que genera el PAC a partir del UUID.
  Future<Uint8List> descargarPdf(String idFol) =>
      _bytes('/cfdi/pdf/${Uri.encodeComponent(idFol)}');

  /// Acuse de cancelacion que firma el SAT, si el folio se cancelo.
  Future<Uint8List> descargarAcuseCancelacion(String idFol) =>
      _bytes('/cfdi/acuse-cancelacion/${Uri.encodeComponent(idFol)}');

  /// Conceptos de la factura que todavia se pueden devolver.
  Future<Map<String, dynamic>> conceptosNotaCredito(String idFol) =>
      _get('/cfdi/nota-credito/${Uri.encodeComponent(idFol)}/conceptos');

  /// Simula la nota de credito: no gasta timbre ni escribe en la base.
  Future<Map<String, dynamic>> probarNotaCredito(
    String idFol,
    List<Map<String, dynamic>> conceptos,
  ) => _post(
    '/cfdi/nota-credito/${Uri.encodeComponent(idFol)}/probar',
    {'confirmar': true, 'conceptos': conceptos},
  );

  /// Emite la nota de credito. Genera un CFDI ante el SAT y gasta un timbre.
  Future<Map<String, dynamic>> emitirNotaCredito(
    String idFol,
    List<Map<String, dynamic>> conceptos,
  ) => _post(
    '/cfdi/nota-credito/${Uri.encodeComponent(idFol)}',
    {'confirmar': true, 'conceptos': conceptos},
  );

  /// XML timbrado de una nota de credito ya emitida.
  Future<Uint8List> descargarXmlNota(String idFol, String uuid) => _bytes(
    '/cfdi/nota-credito/${Uri.encodeComponent(idFol)}/xml/${Uri.encodeComponent(uuid)}',
  );

  /// Representacion impresa de una nota de credito.
  Future<Uint8List> descargarPdfNota(String idFol, String uuid) => _bytes(
    '/cfdi/nota-credito/${Uri.encodeComponent(idFol)}/pdf/${Uri.encodeComponent(uuid)}',
  );

  /// Cuanto se ha cobrado de una factura a credito y cuanto falta.
  Future<Map<String, dynamic>> estadoDePagos(String idFol) =>
      _get('/cfdi/complemento-pago/${Uri.encodeComponent(idFol)}');

  /// Simula el complemento de pago: no gasta timbre ni escribe en la base.
  Future<Map<String, dynamic>> probarComplementoPago(
    String idFol,
    Map<String, dynamic> pago,
  ) => _post(
    '/cfdi/complemento-pago/${Uri.encodeComponent(idFol)}/probar',
    pago,
  );

  /// Emite el complemento de pago. Genera un CFDI ante el SAT.
  Future<Map<String, dynamic>> emitirComplementoPago(
    String idFol,
    Map<String, dynamic> pago,
  ) => _post(
    '/cfdi/complemento-pago/${Uri.encodeComponent(idFol)}',
    pago,
  );

  /// Sella el comprobante de prueba. No sale a internet ni gasta timbre.
  Future<Map<String, dynamic>> sellarPrueba() => _post('/cfdi/prueba/sellar');

  /// Timbra una factura de prueba en el ambiente de pruebas. Gasta un timbre.
  Future<Map<String, dynamic>> timbrarPrueba() =>
      _post('/cfdi/prueba/timbrar', {'confirmar': true});

  /// Factura a credito (PPD, forma de pago 99): la unica que admite un REP.
  Future<Map<String, dynamic>> timbrarFacturaPpd() =>
      _post('/cfdi/prueba/factura-ppd', {'confirmar': true});

  /// Nota de credito (egreso) que acredita una factura ya timbrada.
  Future<Map<String, dynamic>> timbrarNotaCredito({
    required String uuidRelacionado,
    int? cantidadDevuelta,
  }) => _post('/cfdi/prueba/nota-credito', {
    'confirmar': true,
    'uuidRelacionado': uuidRelacionado,
    if (cantidadDevuelta != null) 'cantidadDevuelta': cantidadDevuelta,
  });

  /// Recibo electronico de pago (complemento de pagos 2.0) de un abono.
  Future<Map<String, dynamic>> timbrarPago({
    required String uuidFactura,
    String? serieFactura,
    String? folioFactura,
    String? monto,
    int? parcialidad,
    String? saldoAnterior,
  }) => _post('/cfdi/prueba/pago', {
    'confirmar': true,
    'uuidFactura': uuidFactura,
    if (serieFactura != null && serieFactura.isNotEmpty)
      'serieFactura': serieFactura,
    if (folioFactura != null && folioFactura.isNotEmpty)
      'folioFactura': folioFactura,
    if (monto != null && monto.isNotEmpty) 'monto': monto,
    if (parcialidad != null) 'parcialidad': parcialidad,
    if (saldoAnterior != null && saldoAnterior.isNotEmpty)
      'saldoAnterior': saldoAnterior,
  });

  /// Estado de un CFDI en el PAC.
  Future<Map<String, dynamic>> consultar(String uuid) =>
      _get('/cfdi/consultar/$uuid');

  /// Catalogo c_MotivoCancelacion y cual exige folio de sustitucion.
  Future<List<Map<String, dynamic>>> motivosCancelacion() async {
    final res = await _dio.get<dynamic>('/cfdi/cancelacion/motivos');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Pregunta al SAT si el CFDI se puede cancelar. Solo lectura.
  Future<Map<String, dynamic>> estatusCancelacion({
    required String uuid,
    required String rfcReceptor,
    required String total,
  }) => _get(
    '/cfdi/cancelacion/estatus/$uuid',
    query: {'rfcReceptor': rfcReceptor, 'total': total},
  );

  /// Solicita la cancelacion ante el SAT. No se deshace.
  Future<Map<String, dynamic>> cancelar({
    required String uuid,
    required String motivo,
    required String rfcReceptor,
    required String total,
    String? folioSustitucion,
  }) => _post('/cfdi/cancelacion', {
    'confirmar': true,
    'uuid': uuid,
    'motivo': motivo,
    'rfcReceptor': rfcReceptor,
    'total': total,
    if (folioSustitucion != null && folioSustitucion.isNotEmpty)
      'folioSustitucion': folioSustitucion,
  });

  /// Acuse del SAT de una cancelacion ya solicitada.
  Future<Map<String, dynamic>> acuseCancelacion(String uuid) =>
      _get('/cfdi/cancelacion/acuse/$uuid');

  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.get<dynamic>(path, queryParameters: query);
    return _mapa(res.data);
  }

  Future<Uint8List> _bytes(String path) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      // Con responseType bytes el cuerpo del error tambien viene en bytes,
      // asi que apiErrorMessage no lo sabe leer: se traduce aqui.
      final mensaje = _mensajeDeBytes(e.response?.data);
      if (mensaje != null) throw Exception(mensaje);
      rethrow;
    }
  }

  /// Saca el `message` de un cuerpo de error que llego como bytes.
  String? _mensajeDeBytes(Object? data) {
    if (data is! List<int> || data.isEmpty) return null;
    try {
      final cuerpo = jsonDecode(utf8.decode(data));
      if (cuerpo is Map && cuerpo["message"] != null) {
        final m = cuerpo["message"];
        return m is List ? m.join(", ") : "$m";
      }
    } catch (_) {
      // No era JSON; mejor dejar que Dio cuente lo suyo.
    }
    return null;
  }

  Future<Map<String, dynamic>> _post(String path, [Object? body]) async {
    final res = await _dio.post<dynamic>(path, data: body);
    return _mapa(res.data);
  }

  Map<String, dynamic> _mapa(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : {'respuesta': '$data'};
}

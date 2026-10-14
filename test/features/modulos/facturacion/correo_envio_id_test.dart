import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/facturacion/Pruebas_api/correo_envio_id.dart';

void main() {
  test('accepts SQL text and numeric ID with same endpoint value', () {
    expect(correoEnvioId('3'), 3);
    expect(correoEnvioId(3), 3);
  });
  test('rejects missing, malformed, nonpositive and unsafe IDs', () {
    for (final value in [
      null,
      '',
      'bad',
      '3.5',
      3.5,
      0,
      -1,
      '9007199254740992',
    ]) {
      expect(() => correoEnvioId(value), throwsFormatException);
    }
  });
}

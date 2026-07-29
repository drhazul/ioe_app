import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/catalogo/ean13.dart';

void main() {
  group('buildEan13FromUpc', () {
    test('toma primeros 12 dígitos y reemplaza verificador inválido', () {
      final result = buildEan13FromUpc('7000060111696');

      expect(result?.ean13, '7000060111695');
      expect(result?.sourceHasCheckDigit, isTrue);
      expect(result?.sourceCheckDigitValid, isFalse);
    });

    test('conserva resultado cuando verificador recibido es válido', () {
      final result = buildEan13FromUpc('7000060111695');

      expect(result?.ean13, '7000060111695');
      expect(result?.sourceHasCheckDigit, isTrue);
      expect(result?.sourceCheckDigitValid, isTrue);
    });

    test('ignora caracteres no numéricos antes de normalizar', () {
      final result = buildEan13FromUpc('7000-0601 1169-6');

      expect(result?.sourceDigits, '7000060111696');
      expect(result?.ean13, '7000060111695');
    });

    test('rellena a la izquierda cuando UPC tiene menos de 12 dígitos', () {
      final result = buildEan13FromUpc('60111696');

      expect(result?.ean13, '0000601116964');
      expect(result?.sourceHasCheckDigit, isFalse);
      expect(result?.sourceCheckDigitValid, isNull);
    });

    test('retorna null cuando UPC no contiene dígitos', () {
      expect(buildEan13FromUpc('ABC-'), isNull);
    });
  });

  test('ean13CheckDigit rechaza bases distintas de 12 dígitos', () {
    expect(() => ean13CheckDigit('123'), throwsArgumentError);
  });
}

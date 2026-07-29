class Ean13Result {
  const Ean13Result({
    required this.ean13,
    required this.sourceDigits,
    required this.sourceHasCheckDigit,
    required this.sourceCheckDigitValid,
  });

  final String ean13;
  final String sourceDigits;
  final bool sourceHasCheckDigit;
  final bool? sourceCheckDigitValid;
}

Ean13Result? buildEan13FromUpc(String upc) {
  final digits = upc.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;

  final base12 = digits.length >= 12
      ? digits.substring(0, 12)
      : digits.padLeft(12, '0');
  final checkDigit = ean13CheckDigit(base12);
  final hasSourceCheckDigit = digits.length >= 13;

  return Ean13Result(
    ean13: '$base12$checkDigit',
    sourceDigits: digits,
    sourceHasCheckDigit: hasSourceCheckDigit,
    sourceCheckDigitValid: hasSourceCheckDigit
        ? int.parse(digits[12]) == checkDigit
        : null,
  );
}

int ean13CheckDigit(String base12) {
  if (!RegExp(r'^\d{12}$').hasMatch(base12)) {
    throw ArgumentError.value(
      base12,
      'base12',
      'Debe contener exactamente 12 dígitos',
    );
  }

  var sum = 0;
  for (var i = 0; i < base12.length; i += 1) {
    final digit = int.parse(base12[i]);
    sum += i.isEven ? digit : digit * 3;
  }
  return (10 - (sum % 10)) % 10;
}

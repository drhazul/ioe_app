/// Accept legacy SQL BIGINT strings and the numeric public API contract.
int correoEnvioId(Object? value) {
  final int? id;
  if (value is int) {
    id = value;
  } else if (value is String && RegExp(r'^[0-9]+$').hasMatch(value)) {
    id = int.tryParse(value);
  } else {
    id = null;
  }
  if (id == null || id <= 0 || id > 9007199254740991) {
    throw const FormatException(
      'Identificador de envío inválido. Actualiza la lista.',
    );
  }
  return id;
}

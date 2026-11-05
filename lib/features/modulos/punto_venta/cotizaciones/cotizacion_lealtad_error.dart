class CotizacionLealtadError implements Exception {
  const CotizacionLealtadError(this.code);

  final String code;

  String get message => switch (code) {
    'LEALTAD_URL_NO_CONFIGURADA' || 'LEALTAD_URL_INVALIDA' =>
      'La conexión al programa de lealtad requiere configuración.',
    'LEALTAD_CUENTA_NO_CONFIGURADA' =>
      'La cuenta de conexión al programa de lealtad requiere configuración.',
    'LEALTAD_AUTH_RECHAZADA' || 'LEALTAD_PERMISO_DENEGADO' =>
      'El programa de lealtad rechazó la cuenta de conexión.',
    'LEALTAD_TIMEOUT' => 'El programa de lealtad no respondió a tiempo.',
    'LEALTAD_RESPUESTA_INVALIDA' || 'LEALTAD_CLIENTE_INCONSISTENTE' =>
      'No se pudo validar la respuesta del programa de lealtad.',
    _ => 'El programa de lealtad no está disponible para esta consulta.',
  };
}

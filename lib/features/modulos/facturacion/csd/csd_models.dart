/// Un certificado de sello digital (CSD) cargado en la API.
///
/// Nunca trae el `.key` ni la contrasena: la API solo devuelve los datos que
/// se pueden mostrar en pantalla.
class CsdModel {
  const CsdModel({
    required this.rfc,
    required this.noCertificado,
    required this.regimenFiscal,
    required this.codigoPostal,
    required this.validoDesde,
    required this.validoHasta,
    required this.activo,
    this.nombre,
    this.fechaAlta,
    this.usuarioAlta,
    this.quadrumUsuario,
  });

  final String rfc;
  final String? nombre;
  final String noCertificado;
  final String regimenFiscal;
  final String codigoPostal;
  final DateTime? validoDesde;
  final DateTime? validoHasta;
  final bool activo;
  final DateTime? fechaAlta;
  final String? usuarioAlta;

  /// Cuenta de Quadrum con la que timbra este RFC. Null = la del .env.
  final String? quadrumUsuario;

  factory CsdModel.fromJson(Map<String, dynamic> json) {
    return CsdModel(
      rfc: '${json['rfc'] ?? ''}',
      nombre: json['nombre'] as String?,
      noCertificado: '${json['noCertificado'] ?? ''}',
      regimenFiscal: '${json['regimenFiscal'] ?? ''}',
      codigoPostal: '${json['codigoPostal'] ?? ''}',
      validoDesde: _fecha(json['validoDesde']),
      validoHasta: _fecha(json['validoHasta']),
      activo: json['activo'] == true,
      fechaAlta: _fecha(json['fechaAlta']),
      usuarioAlta: json['usuarioAlta'] as String?,
      quadrumUsuario: json['quadrumUsuario'] as String?,
    );
  }

  /// Dias que le quedan de vigencia. Negativo si ya vencio.
  int get diasRestantes {
    final hasta = validoHasta;
    if (hasta == null) return 0;
    return hasta.difference(DateTime.now()).inDays;
  }

  /// Un CSD dura 4 anios; un mes de aviso alcanza para renovarlo sin prisas.
  bool get porVencer => activo && diasRestantes >= 0 && diasRestantes <= 30;

  bool get vencido => diasRestantes < 0;

  String get estado {
    if (!activo) return 'REEMPLAZADO';
    if (vencido) return 'VENCIDO';
    if (porVencer) return 'POR VENCER';
    return 'VIGENTE';
  }

  static DateTime? _fecha(dynamic valor) {
    if (valor == null) return null;
    return DateTime.tryParse('$valor')?.toLocal();
  }
}

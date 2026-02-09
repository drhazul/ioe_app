class AccessRegSucModel {
  final String modulo;
  final String usuario;
  final String suc;
  final bool activo;
  final DateTime? fcnr;

  const AccessRegSucModel({
    required this.modulo,
    required this.usuario,
    required this.suc,
    required this.activo,
    required this.fcnr,
  });

  factory AccessRegSucModel.fromJson(Map<String, dynamic> json) {
    return AccessRegSucModel(
      modulo: json['MODULO'] as String,
      usuario: json['USUARIO'] as String,
      suc: json['SUC'] as String,
      activo: json['ACTIVO'] == true || json['ACTIVO'] == 1,
      fcnr: json['FCNR'] != null ? DateTime.tryParse(json['FCNR'].toString()) : null,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'MODULO': modulo,
      'USUARIO': usuario,
      'SUC': suc,
      'ACTIVO': activo,
    };
  }
}

class AccessRegSucKey {
  final String modulo;
  final String usuario;
  final String suc;

  const AccessRegSucKey({required this.modulo, required this.usuario, required this.suc});
}

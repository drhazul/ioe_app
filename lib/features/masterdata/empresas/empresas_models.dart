class EmpresaModel {
  const EmpresaModel({
    required this.idempresa,
    required this.razonSocial,
    required this.direccion,
    required this.correo,
    required this.cp,
    required this.rfc,
    required this.telefono,
  });

  final int idempresa;
  final String razonSocial;
  final String? direccion;
  final String correo;
  final String? cp;
  final String? rfc;
  final String? telefono;

  factory EmpresaModel.fromJson(Map<String, dynamic> json) {
    return EmpresaModel(
      idempresa: _asInt(json['idempresa'] ?? json['IDEMPRESA']) ?? 0,
      razonSocial: (json['razonSocial'] ?? json['razon_social'] ?? '')
          .toString()
          .trim(),
      direccion: _asNullable(json['direccion']),
      correo: (json['correo'] ?? '').toString().trim().toLowerCase(),
      cp: _asNullable(json['cp']),
      rfc: _asNullable(json['rfc']),
      telefono: _asNullable(json['telefono']),
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asNullable(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

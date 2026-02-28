class DatFormModel {
  const DatFormModel({
    required this.idform,
    required this.aspel,
    required this.form,
    required this.nom,
    required this.estado,
  });

  final int idform;
  final int? aspel;
  final String form;
  final String nom;
  final bool estado;

  factory DatFormModel.fromJson(Map<String, dynamic> json) {
    final formRaw = (json['form'] ?? json['FORM'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    return DatFormModel(
      idform: _asInt(json['idform'] ?? json['IDFORM']) ?? 0,
      aspel: _asInt(json['aspel'] ?? json['ASPEL']),
      form: formRaw,
      nom: (json['nom'] ?? json['NOM'] ?? '').toString().trim(),
      estado: _asBool(json['estado'] ?? json['ESTADO']),
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value.toInt() == 1;
  final text = value.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'si';
}

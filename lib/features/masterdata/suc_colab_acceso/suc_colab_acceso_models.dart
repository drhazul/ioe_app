class SucColabAccesoModel {
  final int id;
  final String sucDestino;
  final String? sucDestinoDesc;
  final String sucOrigen;
  final String? sucOrigenDesc;
  final bool activo;
  final String? observacion;
  final DateTime? fcreg;
  final DateTime? fcmod;

  const SucColabAccesoModel({
    required this.id,
    required this.sucDestino,
    required this.sucDestinoDesc,
    required this.sucOrigen,
    required this.sucOrigenDesc,
    required this.activo,
    required this.observacion,
    required this.fcreg,
    required this.fcmod,
  });

  factory SucColabAccesoModel.fromJson(Map<String, dynamic> json) {
    return SucColabAccesoModel(
      id: _asInt(json['ID'] ?? json['id']) ?? 0,
      sucDestino: (json['SUC_DESTINO'] ?? json['sucDestino'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
      sucDestinoDesc: _asText(
        json['SUC_DESTINO_DESC'] ?? json['sucDestinoDesc'],
      ),
      sucOrigen: (json['SUC_ORIGEN'] ?? json['sucOrigen'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
      sucOrigenDesc: _asText(json['SUC_ORIGEN_DESC'] ?? json['sucOrigenDesc']),
      activo: _asBool(json['ACTIVO'] ?? json['activo']),
      observacion: _asText(json['OBSERVACION'] ?? json['observacion']),
      fcreg: _asDate(json['FCREG'] ?? json['fcreg']),
      fcmod: _asDate(json['FCMOD'] ?? json['fcmod']),
    );
  }
}

class SucColabAccesoFilters {
  final String? sucDestino;
  final String? sucOrigen;
  final String? search;
  final bool includeInactive;

  const SucColabAccesoFilters({
    this.sucDestino,
    this.sucOrigen,
    this.search,
    this.includeInactive = true,
  });

  SucColabAccesoFilters copyWith({
    String? sucDestino,
    String? sucOrigen,
    String? search,
    bool? includeInactive,
  }) {
    return SucColabAccesoFilters(
      sucDestino: sucDestino ?? this.sucDestino,
      sucOrigen: sucOrigen ?? this.sucOrigen,
      search: search ?? this.search,
      includeInactive: includeInactive ?? this.includeInactive,
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

String? _asText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

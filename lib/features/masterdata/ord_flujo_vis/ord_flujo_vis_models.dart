class OrdFlujoVisModel {
  const OrdFlujoVisModel({
    required this.id,
    required this.modulo,
    required this.panelMode,
    required this.roleCode,
    required this.esta,
    required this.soloExterno,
    required this.activo,
    required this.orden,
    required this.fcreg,
    required this.fcmod,
  });

  final int id;
  final String modulo;
  final String panelMode;
  final String roleCode;
  final double esta;
  final bool soloExterno;
  final bool activo;
  final int? orden;
  final String? fcreg;
  final String? fcmod;

  factory OrdFlujoVisModel.fromJson(Map<String, dynamic> json) {
    return OrdFlujoVisModel(
      id: _asInt(json['id'] ?? json['ID']) ?? 0,
      modulo: (json['modulo'] ?? json['MODULO'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
      panelMode: (json['panelMode'] ?? json['PANEL_MODE'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      roleCode: (json['roleCode'] ?? json['ROLE_CODE'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
      esta: _asDouble(json['esta'] ?? json['ESTA']) ?? 0,
      soloExterno: _asBool(json['soloExterno'] ?? json['SOLO_EXTERNO']),
      activo: _asBool(json['activo'] ?? json['ACTIVO']),
      orden: _asInt(json['orden'] ?? json['ORDEN']),
      fcreg: _asStringOrNull(json['fcreg'] ?? json['FCREG']),
      fcmod: _asStringOrNull(json['fcmod'] ?? json['FCMOD']),
    );
  }
}

class OrdFlujoVisRoleOption {
  const OrdFlujoVisRoleOption({
    required this.roleCode,
    required this.roleName,
  });

  final String roleCode;
  final String roleName;

  factory OrdFlujoVisRoleOption.fromJson(Map<String, dynamic> json) {
    return OrdFlujoVisRoleOption(
      roleCode: (json['roleCode'] ?? json['ROLE_CODE'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
      roleName: (json['roleName'] ?? json['ROLE_NAME'] ?? '')
          .toString()
          .trim(),
    );
  }
}

class OrdFlujoVisEstadoOption {
  const OrdFlujoVisEstadoOption({
    required this.esta,
    required this.tipo,
    required this.ordenSugerido,
  });

  final double esta;
  final String tipo;
  final int ordenSugerido;

  factory OrdFlujoVisEstadoOption.fromJson(Map<String, dynamic> json) {
    return OrdFlujoVisEstadoOption(
      esta: _asDouble(json['esta'] ?? json['ESTA']) ?? 0,
      tipo: (json['tipo'] ?? json['TIPO'] ?? '').toString().trim(),
      ordenSugerido: _asInt(json['ordenSugerido'] ?? json['ORDEN_SUGERIDO']) ?? 0,
    );
  }
}

class OrdFlujoVisCatalogos {
  const OrdFlujoVisCatalogos({
    required this.modulo,
    required this.roles,
    required this.estados,
  });

  final String modulo;
  final List<OrdFlujoVisRoleOption> roles;
  final List<OrdFlujoVisEstadoOption> estados;

  factory OrdFlujoVisCatalogos.fromJson(Map<String, dynamic> json) {
    final roleRows = (json['roles'] as List?) ?? const [];
    final estadoRows = (json['estados'] as List?) ?? const [];
    return OrdFlujoVisCatalogos(
      modulo: (json['modulo'] ?? 'DAT_JAO_ORD').toString().trim().toUpperCase(),
      roles: roleRows
          .whereType<Map>()
          .map((row) => OrdFlujoVisRoleOption.fromJson(Map<String, dynamic>.from(row)))
          .where((row) => row.roleCode.isNotEmpty)
          .toList(),
      estados: estadoRows
          .whereType<Map>()
          .map((row) => OrdFlujoVisEstadoOption.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value.toInt() == 1;
  final text = value.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'si';
}

String? _asStringOrNull(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

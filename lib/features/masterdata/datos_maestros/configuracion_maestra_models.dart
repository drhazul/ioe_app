class ConfiguracionMaestraModel {
  const ConfiguracionMaestraModel({
    required this.nombreEmpresa,
    required this.nitEmpresa,
    required this.gpsObligatorio,
    required this.livenessObligatorio,
    required this.departamentos,
    required this.cargos,
  });

  final String nombreEmpresa;
  final String nitEmpresa;
  final bool gpsObligatorio;
  final bool livenessObligatorio;
  final List<String> departamentos;
  final List<String> cargos;

  factory ConfiguracionMaestraModel.empty() {
    return const ConfiguracionMaestraModel(
      nombreEmpresa: '',
      nitEmpresa: '',
      gpsObligatorio: false,
      livenessObligatorio: false,
      departamentos: <String>[],
      cargos: <String>[],
    );
  }

  ConfiguracionMaestraModel copyWith({
    String? nombreEmpresa,
    String? nitEmpresa,
    bool? gpsObligatorio,
    bool? livenessObligatorio,
    List<String>? departamentos,
    List<String>? cargos,
  }) {
    return ConfiguracionMaestraModel(
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      nitEmpresa: nitEmpresa ?? this.nitEmpresa,
      gpsObligatorio: gpsObligatorio ?? this.gpsObligatorio,
      livenessObligatorio: livenessObligatorio ?? this.livenessObligatorio,
      departamentos: departamentos ?? this.departamentos,
      cargos: cargos ?? this.cargos,
    );
  }

  factory ConfiguracionMaestraModel.fromJson(Map<String, dynamic> json) {
    final reglas = _asMap(json['reglasNegocio']) ?? const <String, dynamic>{};
    final departamentosRaw = _asList(json['departamentos']);
    final cargosRaw = _asList(json['cargos']);

    return ConfiguracionMaestraModel(
      nombreEmpresa:
          _asString(reglas['nombreEmpresa']) ??
          _asString(reglas['nombre_empresa']) ??
          _asString(reglas['empresa']) ??
          '',
      nitEmpresa:
          _asString(reglas['nitEmpresa']) ??
          _asString(reglas['nit_empresa']) ??
          _asString(reglas['nit']) ??
          '',
      gpsObligatorio:
          _asBool(reglas['gpsObligatorio']) ??
          _asBool(reglas['gps_obligatorio']) ??
          false,
      livenessObligatorio:
          _asBool(reglas['livenessObligatorio']) ??
          _asBool(reglas['liveness_obligatorio']) ??
          false,
      departamentos: _normalizeCatalogList(departamentosRaw),
      cargos: _normalizeCatalogList(cargosRaw),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reglasNegocio': {
        'nombreEmpresa': nombreEmpresa.trim(),
        'nitEmpresa': nitEmpresa.trim(),
        'gpsObligatorio': gpsObligatorio,
        'livenessObligatorio': livenessObligatorio,
      },
      'departamentos': departamentos
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      'cargos': cargos
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    };
  }

  static List<String> _normalizeCatalogList(List<dynamic> values) {
    final normalized = <String>[];
    for (final value in values) {
      String? name;
      if (value is String) {
        name = value;
      } else if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        name =
            _asString(map['nombre']) ??
            _asString(map['NOMBRE']) ??
            _asString(map['descripcion']) ??
            _asString(map['DESCRIPCION']);
      }
      final clean = (name ?? '').trim();
      if (clean.isEmpty) continue;
      if (!normalized.any(
        (existing) => existing.toUpperCase() == clean.toUpperCase(),
      )) {
        normalized.add(clean);
      }
    }
    return List<String>.unmodifiable(normalized);
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true' || normalized == 'si') {
        return true;
      }
      if (normalized == '0' || normalized == 'false' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }
}

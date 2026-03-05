class EstadoCajonAuthorizationSession {
  EstadoCajonAuthorizationSession({
    required this.authorizationToken,
    required this.supervisorUserId,
  });

  final String authorizationToken;
  final String supervisorUserId;

  factory EstadoCajonAuthorizationSession.fromJson(Map<String, dynamic> json) {
    return EstadoCajonAuthorizationSession(
      authorizationToken: (json['authorizationToken'] ??
              json['authorization_token'] ??
              json['token'] ??
              '')
          .toString()
          .trim(),
      supervisorUserId: (json['supervisorUserId'] ??
              json['supervisor_user_id'] ??
              json['supervisorId'] ??
              '')
          .toString()
          .trim(),
    );
  }
}

class EstadoCajonResumenRow {
  EstadoCajonResumenRow({
    required this.opv,
    required this.form,
    required this.nom,
    required this.impt,
    required this.impr,
    required this.impe,
    required this.difd,
  });

  final String opv;
  final String form;
  final String nom;
  final double impt;
  final double impr;
  final double? impe;
  final double difd;

  factory EstadoCajonResumenRow.fromJson(Map<String, dynamic> json) {
    return EstadoCajonResumenRow(
      opv: (json['opv'] ?? json['OPV'] ?? '').toString().trim(),
      form: (json['form'] ?? json['FORM'] ?? '').toString().trim().toUpperCase(),
      nom: (json['nom'] ?? json['NOM'] ?? '').toString().trim(),
      impt: _asDouble(json['impt'] ?? json['IMPT']) ?? 0,
      impr: _asDouble(json['impr'] ?? json['IMPR']) ?? 0,
      impe: _asDouble(json['impe'] ?? json['IMPE']),
      difd: _asDouble(json['difd'] ?? json['DIFD']) ?? 0,
    );
  }
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

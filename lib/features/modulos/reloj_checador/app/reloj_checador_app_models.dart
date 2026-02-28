class RelojChecadorContext {
  final int? idUsuario;
  final String suc;
  final String? lastTipo;
  final DateTime? lastFcnr;
  final String nextAllowedTipo;
  final bool requireGps;
  final bool requireLiveness;
  final bool enforceWindows;
  final double? geofenceLat;
  final double? geofenceLon;
  final int? geofenceRadiusM;
  final int gpsMaxAccuracyM;
  final String message;

  const RelojChecadorContext({
    required this.idUsuario,
    required this.suc,
    required this.lastTipo,
    required this.lastFcnr,
    required this.nextAllowedTipo,
    required this.requireGps,
    required this.requireLiveness,
    required this.enforceWindows,
    required this.geofenceLat,
    required this.geofenceLon,
    required this.geofenceRadiusM,
    required this.gpsMaxAccuracyM,
    required this.message,
  });

  factory RelojChecadorContext.fromJson(Map<String, dynamic> json) {
    return RelojChecadorContext(
      idUsuario: _asInt(json['IDUSUARIO'] ?? json['idUsuario']),
      suc: _asString(json['SUC'] ?? json['suc']) ?? '',
      lastTipo: _asString(json['LAST_TIPO'] ?? json['lastTipo']),
      lastFcnr: _asDate(json['LAST_FCNR'] ?? json['lastFcnr']),
      nextAllowedTipo:
          _asString(json['NEXT_ALLOWED_TIPO'] ?? json['nextAllowedTipo']) ??
          'ENTRADA',
      requireGps: _asBool(json['REQUIRE_GPS'] ?? json['requireGps']),
      requireLiveness: _asBool(
        json['REQUIRE_LIVENESS'] ?? json['requireLiveness'],
      ),
      enforceWindows: _asBool(
        json['ENFORCE_WINDOWS'] ?? json['enforceWindows'],
      ),
      geofenceLat: _asDouble(json['GEOFENCE_LAT'] ?? json['geofenceLat']),
      geofenceLon: _asDouble(json['GEOFENCE_LON'] ?? json['geofenceLon']),
      geofenceRadiusM: _asInt(
        json['GEOFENCE_RADIUS_M'] ?? json['geofenceRadiusM'],
      ),
      gpsMaxAccuracyM:
          _asInt(json['GPS_MAX_ACCURACY_M'] ?? json['gpsMaxAccuracyM']) ?? 50,
      message: _asString(json['MESSAGE'] ?? json['message']) ?? '',
    );
  }
}

class TimelogCreateRequest {
  final String? suc;
  final String tipo;
  final String authMethod;
  final bool livenessOk;
  final double? lat;
  final double? lon;
  final int? gpsAccuracyM;
  final String? deviceId;
  final String? notes;

  const TimelogCreateRequest({
    required this.suc,
    required this.tipo,
    required this.authMethod,
    required this.livenessOk,
    required this.lat,
    required this.lon,
    required this.gpsAccuracyM,
    required this.deviceId,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'TIPO': tipo,
      'AUTH_METHOD': authMethod,
      'LIVENESS_OK': livenessOk ? 1 : 0,
    };
    if ((suc ?? '').trim().isNotEmpty) data['SUC'] = suc!.trim();
    if (lat != null) data['LAT'] = lat;
    if (lon != null) data['LON'] = lon;
    if (gpsAccuracyM != null) data['GPS_ACCURACY_M'] = gpsAccuracyM;
    if ((deviceId ?? '').trim().isNotEmpty) {
      data['DEVICE_ID'] = deviceId!.trim();
    }
    if ((notes ?? '').trim().isNotEmpty) data['NOTES'] = notes!.trim();
    return data;
  }
}

class TimelogCreateResponse {
  final bool ok;
  final String message;
  final String? idTimelog;

  const TimelogCreateResponse({
    required this.ok,
    required this.message,
    required this.idTimelog,
  });

  factory TimelogCreateResponse.fromJson(Map<String, dynamic> json) {
    return TimelogCreateResponse(
      ok: _asBool(json['OK'] ?? json['ok']),
      message: _asString(json['MESSAGE'] ?? json['message']) ?? '',
      idTimelog: _asString(json['IDTIMELOG'] ?? json['idTimelog']),
    );
  }
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
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
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'si' || text == 'sí';
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

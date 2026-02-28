class RelojChecadorListResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int limit;

  const RelojChecadorListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });
}

class TimelogFilters {
  final String? suc;
  final int? idUsuario;
  final String? dateFrom;
  final String? dateTo;
  final int page;
  final int limit;

  const TimelogFilters({
    this.suc,
    this.idUsuario,
    this.dateFrom,
    this.dateTo,
    this.page = 1,
    this.limit = 50,
  });

  Map<String, dynamic> toQuery() {
    final data = <String, dynamic>{'page': page, 'limit': limit};
    if ((suc ?? '').trim().isNotEmpty) data['suc'] = suc!.trim();
    if (idUsuario != null) data['idUsuario'] = idUsuario;
    if ((dateFrom ?? '').trim().isNotEmpty) data['dateFrom'] = dateFrom;
    if ((dateTo ?? '').trim().isNotEmpty) data['dateTo'] = dateTo;
    return data;
  }
}

class TimelogItem {
  final String idTimelog;
  final int? idUsuario;
  final String? username;
  final String? nombre;
  final String suc;
  final String tipo;
  final DateTime? fcnr;
  final String? notes;

  const TimelogItem({
    required this.idTimelog,
    required this.idUsuario,
    required this.username,
    required this.nombre,
    required this.suc,
    required this.tipo,
    required this.fcnr,
    required this.notes,
  });

  factory TimelogItem.fromJson(Map<String, dynamic> json) {
    return TimelogItem(
      idTimelog: _asString(json['IDTIMELOG'] ?? json['idTimelog']) ?? '',
      idUsuario: _asInt(json['IDUSUARIO'] ?? json['idUsuario']),
      username: _asString(json['USERNAME'] ?? json['username']),
      nombre: _asString(json['NOMBRE_COMPLETO'] ?? json['nombreCompleto']),
      suc: _asString(json['SUC'] ?? json['suc']) ?? '',
      tipo: _asString(json['TIPO'] ?? json['tipo']) ?? '',
      fcnr: _asDate(json['FCNR'] ?? json['fcnr']),
      notes: _asString(json['NOTES'] ?? json['notes']),
    );
  }
}

class IncidenciaItem {
  final String idInc;
  final int? idUsuario;
  final String? username;
  final String suc;
  final String tipo;
  final String estatus;
  final DateTime? fechaIni;
  final DateTime? fechaFin;
  final String? motivo;

  const IncidenciaItem({
    required this.idInc,
    required this.idUsuario,
    required this.username,
    required this.suc,
    required this.tipo,
    required this.estatus,
    required this.fechaIni,
    required this.fechaFin,
    required this.motivo,
  });

  factory IncidenciaItem.fromJson(Map<String, dynamic> json) {
    return IncidenciaItem(
      idInc: _asString(json['IDINC'] ?? json['idInc']) ?? '',
      idUsuario: _asInt(json['IDUSUARIO'] ?? json['idUsuario']),
      username: _asString(json['USERNAME'] ?? json['username']),
      suc: _asString(json['SUC'] ?? json['suc']) ?? '',
      tipo: _asString(json['TIPO'] ?? json['tipo']) ?? '',
      estatus: _asString(json['ESTATUS'] ?? json['estatus']) ?? '',
      fechaIni: _asDate(json['FECHA_INI'] ?? json['fechaIni']),
      fechaFin: _asDate(json['FECHA_FIN'] ?? json['fechaFin']),
      motivo: _asString(json['MOTIVO'] ?? json['motivo']),
    );
  }
}

class DocumentoItem {
  final String idDoc;
  final int? idUsuario;
  final String? username;
  final String suc;
  final String tipo;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final DateTime? fcnr;

  const DocumentoItem({
    required this.idDoc,
    required this.idUsuario,
    required this.username,
    required this.suc,
    required this.tipo,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.fcnr,
  });

  factory DocumentoItem.fromJson(Map<String, dynamic> json) {
    return DocumentoItem(
      idDoc: _asString(json['IDDOC'] ?? json['idDoc']) ?? '',
      idUsuario: _asInt(json['IDUSUARIO'] ?? json['idUsuario']),
      username: _asString(json['USERNAME'] ?? json['username']),
      suc: _asString(json['SUC'] ?? json['suc']) ?? '',
      tipo: _asString(json['TIPO'] ?? json['tipo']) ?? '',
      fileName: _asString(json['FILE_NAME'] ?? json['fileName']) ?? '',
      mimeType: _asString(json['MIME_TYPE'] ?? json['mimeType']) ?? '',
      fileSize: _asInt(json['FILE_SIZE'] ?? json['fileSize']) ?? 0,
      fcnr: _asDate(json['FCNR'] ?? json['fcnr']),
    );
  }
}

class OverrideItem {
  final String idOvr;
  final int? idUsuario;
  final String suc;
  final String tipo;
  final String reason;
  final DateTime? validUntil;
  final bool isActive;

  const OverrideItem({
    required this.idOvr,
    required this.idUsuario,
    required this.suc,
    required this.tipo,
    required this.reason,
    required this.validUntil,
    required this.isActive,
  });

  factory OverrideItem.fromJson(Map<String, dynamic> json) {
    return OverrideItem(
      idOvr: _asString(json['IDOVR'] ?? json['idOvr']) ?? '',
      idUsuario: _asInt(json['IDUSUARIO'] ?? json['idUsuario']),
      suc: _asString(json['SUC'] ?? json['suc']) ?? '',
      tipo: _asString(json['TIPO'] ?? json['tipo']) ?? '',
      reason: _asString(json['REASON'] ?? json['reason']) ?? '',
      validUntil: _asDate(json['VALID_UNTIL'] ?? json['validUntil']),
      isActive: _asBool(json['IS_ACTIVE'] ?? json['isActive']),
    );
  }
}

class PolicyModel {
  final String suc;
  final int? idDepto;
  final int allowEarlyMin;
  final int allowLateMin;
  final bool requireGps;
  final double? geofenceLat;
  final double? geofenceLon;
  final int? geofenceRadiusM;
  final int gpsMaxAccuracyM;
  final bool requireLiveness;
  final bool enforceWindows;
  final String? shiftStart;
  final String? shiftEnd;
  final String? lunchStart;
  final String? lunchEnd;
  final double overtimeDailyLimit;
  final double overtimeWeeklyLimit;

  const PolicyModel({
    required this.suc,
    required this.idDepto,
    required this.allowEarlyMin,
    required this.allowLateMin,
    required this.requireGps,
    required this.geofenceLat,
    required this.geofenceLon,
    required this.geofenceRadiusM,
    required this.gpsMaxAccuracyM,
    required this.requireLiveness,
    required this.enforceWindows,
    required this.shiftStart,
    required this.shiftEnd,
    required this.lunchStart,
    required this.lunchEnd,
    required this.overtimeDailyLimit,
    required this.overtimeWeeklyLimit,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(
      suc: _asString(json['SUC'] ?? json['suc']) ?? '',
      idDepto: _asInt(json['IDDEPTO'] ?? json['idDepto']),
      allowEarlyMin:
          _asInt(json['ALLOW_EARLY_MIN'] ?? json['allowEarlyMin']) ?? 15,
      allowLateMin:
          _asInt(json['ALLOW_LATE_MIN'] ?? json['allowLateMin']) ?? 15,
      requireGps: _asBool(json['REQUIRE_GPS'] ?? json['requireGps']),
      geofenceLat: _asDouble(json['GEOFENCE_LAT'] ?? json['geofenceLat']),
      geofenceLon: _asDouble(json['GEOFENCE_LON'] ?? json['geofenceLon']),
      geofenceRadiusM: _asInt(
        json['GEOFENCE_RADIUS_M'] ?? json['geofenceRadiusM'],
      ),
      gpsMaxAccuracyM:
          _asInt(json['GPS_MAX_ACCURACY_M'] ?? json['gpsMaxAccuracyM']) ?? 50,
      requireLiveness: _asBool(
        json['REQUIRE_LIVENESS'] ?? json['requireLiveness'],
      ),
      enforceWindows: _asBool(
        json['ENFORCE_WINDOWS'] ?? json['enforceWindows'],
      ),
      shiftStart: _asString(json['SHIFT_START'] ?? json['shiftStart']),
      shiftEnd: _asString(json['SHIFT_END'] ?? json['shiftEnd']),
      lunchStart: _asString(json['LUNCH_START'] ?? json['lunchStart']),
      lunchEnd: _asString(json['LUNCH_END'] ?? json['lunchEnd']),
      overtimeDailyLimit:
          _asDouble(
            json['OVERTIME_DAILY_LIMIT_HOURS'] ??
                json['overtimeDailyLimitHours'],
          ) ??
          3,
      overtimeWeeklyLimit:
          _asDouble(
            json['OVERTIME_WEEKLY_LIMIT_HOURS'] ??
                json['overtimeWeeklyLimitHours'],
          ) ??
          9,
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

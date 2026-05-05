// ignore_for_file: non_constant_identifier_names

class RelojChecadorContext {
  final int? idUsuario;
  final String suc;
  final DateTime? serverTime;
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
    required this.serverTime,
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
      serverTime: _asDate(json['serverTime'] ?? json['SERVER_TIME']),
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

class ColaboradorSqlModel {
  final int id_usuario;
  final String nombre;
  final String apellido;
  final String pin;
  final int? sucursal_id;
  final String? departamento;
  final String? cargo;
  final bool status_activo;

  const ColaboradorSqlModel({
    required this.id_usuario,
    required this.nombre,
    required this.apellido,
    required this.pin,
    required this.sucursal_id,
    required this.departamento,
    required this.cargo,
    required this.status_activo,
  });

  factory ColaboradorSqlModel.fromJson(Map<String, dynamic> json) {
    return ColaboradorSqlModel(
      id_usuario: _asInt(json['id_usuario'] ?? json['id']) ?? 0,
      nombre: _asString(json['nombre']) ?? '',
      apellido: _asString(json['apellido']) ?? '',
      pin: _asString(json['pin']) ?? '',
      sucursal_id: _asInt(json['sucursal_id']),
      departamento: _asString(json['departamento']),
      cargo: _asString(json['cargo']),
      status_activo: _asBool(json['status_activo'] ?? json['estado']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': id_usuario,
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'pin': pin.trim(),
      'sucursal_id': sucursal_id,
      'departamento': (departamento ?? '').trim(),
      'cargo': (cargo ?? '').trim(),
      'status_activo': status_activo,
    };
  }
}

class MarcajeSqlModel {
  final int id_usuario;
  final String? punch_time;
  final String pin;
  final String suc;
  final String tipo;
  final String verify_mode_label;

  const MarcajeSqlModel({
    required this.id_usuario,
    required this.punch_time,
    required this.pin,
    required this.suc,
    required this.tipo,
    required this.verify_mode_label,
  });

  factory MarcajeSqlModel.fromJson(Map<String, dynamic> json) {
    return MarcajeSqlModel(
      id_usuario: _asInt(json['id_usuario']) ?? 0,
      punch_time: _asString(json['punch_time']),
      pin: _asString(json['pin']) ?? '',
      suc: _asString(json['suc']) ?? '',
      tipo: _asString(json['tipo']) ?? '',
      verify_mode_label: _asString(json['verify_mode_label']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': id_usuario,
      if ((punch_time ?? '').trim().isNotEmpty)
        'punch_time': punch_time!.trim(),
      'pin': pin.trim(),
      'suc': suc.trim(),
      'tipo': tipo.trim(),
      'verify_mode_label': verify_mode_label.trim().toUpperCase(),
    };
  }
}

class TimelogCreateRequest {
  final int id_usuario;
  final String pin;
  final String? suc;
  final String tipo;
  final String authMethod;
  final bool livenessOk;
  final double? lat;
  final double? lon;
  final int? gpsAccuracyM;
  final String? deviceId;
  final String clientIdUnico;
  final String fechaHoraLocal;
  final String? notes;

  const TimelogCreateRequest({
    required this.id_usuario,
    required this.pin,
    required this.suc,
    required this.tipo,
    required this.authMethod,
    required this.livenessOk,
    required this.lat,
    required this.lon,
    required this.gpsAccuracyM,
    required this.deviceId,
    required this.clientIdUnico,
    required this.fechaHoraLocal,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    final tipoSql = _normalizeTipoSql(tipo);
    final data = <String, dynamic>{
      'id_usuario': id_usuario,
      'pin': pin.trim(),
      'tipo': tipoSql,
      'verify_mode_label': authMethod.trim().toUpperCase(),
      'liveness_ok': livenessOk ? 1 : 0,
    };
    if ((suc ?? '').trim().isNotEmpty) data['suc'] = suc!.trim();
    if (lat != null) data['lat'] = lat;
    if (lon != null) data['lon'] = lon;
    if (gpsAccuracyM != null) data['gps_accuracy_m'] = gpsAccuracyM;
    if ((deviceId ?? '').trim().isNotEmpty) {
      data['device_id'] = deviceId!.trim();
    }
    data['client_id_unico'] = clientIdUnico.trim().toUpperCase();
    data['fecha_hora_local'] = fechaHoraLocal.trim();
    if ((notes ?? '').trim().isNotEmpty) data['notes'] = notes!.trim();
    return data;
  }

  String _normalizeTipoSql(String input) {
    final value = input.trim().toUpperCase();
    switch (value) {
      case 'ENTRADA':
        return 'Entrada';
      case 'SALIDA_COMER':
        return 'Salida Comer';
      case 'REGRESO_COMER':
        return 'Regreso Comer';
      case 'SALIDA':
        return 'Salida';
      default:
        return input.trim();
    }
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
      idTimelog: _asString(
        json['IDTIMELOG'] ??
            json['idTimelog'] ??
            json['REF_ID'] ??
            json['ref_id'],
      ),
    );
  }
}

class SucursalGeofenceConfig {
  final String codigo;
  final double? latitud;
  final double? longitud;
  final int? radioMetros;
  final bool hasGeofence;

  const SucursalGeofenceConfig({
    required this.codigo,
    required this.latitud,
    required this.longitud,
    required this.radioMetros,
    required this.hasGeofence,
  });

  factory SucursalGeofenceConfig.fromJson(Map<String, dynamic> json) {
    return SucursalGeofenceConfig(
      codigo: _asString(json['codigo']) ?? '',
      latitud: _asDouble(json['latitud']),
      longitud: _asDouble(json['longitud']),
      radioMetros: _asInt(json['radioMetros'] ?? json['radio_metros']),
      hasGeofence: _asBool(json['hasGeofence']),
    );
  }
}

class SucursalOptionModel {
  final int id;
  final String codigo;
  final String nombre;

  const SucursalOptionModel({
    required this.id,
    required this.codigo,
    required this.nombre,
  });

  factory SucursalOptionModel.fromJson(Map<String, dynamic> json) {
    return SucursalOptionModel(
      id: _asInt(json['id']) ?? 0,
      codigo: _asString(json['codigo']) ?? '',
      nombre: _asString(json['nombre']) ?? '',
    );
  }
}

class HorarioModel {
  final int id;
  final String nombre;
  final String horaEntrada;
  final String horaSalida;
  final int toleranciaMinutos;
  final bool diaFestivo;
  final String? inicioEntrada;
  final String? finEntrada;
  final int minutosAlmuerzo;
  final int redondeoEntrada;
  final bool esFlexible;
  final int otMinimoMinutos;
  final bool otRequiereAutorizacion;
  final int horasJornadaMinutos;
  final int horasExtraMinimoMinutos;
  final bool horasExtraRequiereAutorizacion;
  final bool activo;

  const HorarioModel({
    required this.id,
    required this.nombre,
    required this.horaEntrada,
    required this.horaSalida,
    required this.toleranciaMinutos,
    required this.diaFestivo,
    required this.inicioEntrada,
    required this.finEntrada,
    required this.minutosAlmuerzo,
    required this.redondeoEntrada,
    required this.esFlexible,
    required this.otMinimoMinutos,
    required this.otRequiereAutorizacion,
    required this.horasJornadaMinutos,
    required this.horasExtraMinimoMinutos,
    required this.horasExtraRequiereAutorizacion,
    required this.activo,
  });

  factory HorarioModel.fromJson(Map<String, dynamic> json) {
    return HorarioModel(
      id: _asInt(json['id']) ?? 0,
      nombre: _asString(json['nombre']) ?? '',
      horaEntrada: _asString(json['hora_entrada']) ?? '00:00:00',
      horaSalida: _asString(json['hora_salida']) ?? '00:00:00',
      toleranciaMinutos: _asInt(json['tolerancia_minutos']) ?? 0,
      diaFestivo: _asBool(json['dia_festivo']),
      inicioEntrada: _asString(json['inicio_entrada']),
      finEntrada: _asString(json['fin_entrada']),
      minutosAlmuerzo: _asInt(json['minutos_almuerzo']) ?? 0,
      redondeoEntrada: _asInt(json['redondeo_entrada']) ?? 0,
      esFlexible: _asBool(json['es_flexible']),
      otMinimoMinutos: _asInt(json['ot_minimo_minutos']) ?? 0,
      otRequiereAutorizacion: _asBool(json['ot_requiere_autorizacion']),
      horasJornadaMinutos: _asInt(json['horas_jornada_minutos']) ?? 480,
      horasExtraMinimoMinutos: _asInt(json['horas_extra_minimo_minutos']) ?? 0,
      horasExtraRequiereAutorizacion: _asBool(json['horas_extra_requiere_autorizacion']),
      activo: _asBool(json['activo']),
    );
  }
}

class HorarioUpsertRequest {
  final String nombre;
  final String horaEntrada;
  final String horaSalida;
  final int toleranciaMinutos;
  final bool diaFestivo;
  final String? inicioEntrada;
  final String? finEntrada;
  final int minutosAlmuerzo;
  final int redondeoEntrada;
  final bool esFlexible;
  final int otMinimoMinutos;
  final bool otRequiereAutorizacion;
  final int horasJornadaMinutos;
  final int horasExtraMinimoMinutos;
  final bool horasExtraRequiereAutorizacion;
  final bool activo;

  const HorarioUpsertRequest({
    required this.nombre,
    required this.horaEntrada,
    required this.horaSalida,
    required this.toleranciaMinutos,
    required this.diaFestivo,
    required this.inicioEntrada,
    required this.finEntrada,
    required this.minutosAlmuerzo,
    required this.redondeoEntrada,
    required this.esFlexible,
    required this.otMinimoMinutos,
    required this.otRequiereAutorizacion,
    required this.horasJornadaMinutos,
    required this.horasExtraMinimoMinutos,
    required this.horasExtraRequiereAutorizacion,
    required this.activo,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'nombre': nombre.trim(),
      'hora_entrada': _normalizeTime(horaEntrada),
      'hora_salida': _normalizeTime(horaSalida),
      'tolerancia_minutos': toleranciaMinutos,
      'dia_festivo': diaFestivo,
      'minutos_almuerzo': minutosAlmuerzo,
      'redondeo_entrada': redondeoEntrada,
      'es_flexible': esFlexible,
      'ot_minimo_minutos': otMinimoMinutos,
      'ot_requiere_autorizacion': otRequiereAutorizacion,
      'horas_jornada_minutos': horasJornadaMinutos,
      'horas_extra_minimo_minutos': horasExtraMinimoMinutos,
      'horas_extra_requiere_autorizacion': horasExtraRequiereAutorizacion,
      'activo': activo,
    };

    if ((inicioEntrada ?? '').trim().isNotEmpty) {
      data['inicio_entrada'] = _normalizeTime(inicioEntrada!);
    }
    if ((finEntrada ?? '').trim().isNotEmpty) {
      data['fin_entrada'] = _normalizeTime(finEntrada!);
    }

    return data;
  }

  String _normalizeTime(String value) {
    final text = value.trim();
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) {
      return '$text:00';
    }
    return text;
  }
}

class TurnoCatalogoModel {
  final int id;
  final String nombre;
  final String hrEntrada;
  final String hrSalidaComida;
  final String hrRegresoComida;
  final String hrSalida;
  final String jornadaTipo;

  const TurnoCatalogoModel({
    required this.id,
    required this.nombre,
    required this.hrEntrada,
    required this.hrSalidaComida,
    required this.hrRegresoComida,
    required this.hrSalida,
    required this.jornadaTipo,
  });

  factory TurnoCatalogoModel.fromJson(Map<String, dynamic> json) {
    return TurnoCatalogoModel(
      id: _asInt(json['id']) ?? 0,
      nombre: _asString(json['nombre']) ?? '',
      hrEntrada: _asString(json['hr_entrada']) ?? '00:00:00',
      hrSalidaComida: _asString(json['hr_salida_comida']) ?? '00:00:00',
      hrRegresoComida: _asString(json['hr_regreso_comida']) ?? '00:00:00',
      hrSalida: _asString(json['hr_salida']) ?? '00:00:00',
      jornadaTipo: (_asString(json['jornada_tipo']) ?? 'DIURNA').toUpperCase(),
    );
  }
}

class HorarioSemanalRowModel {
  final int colaboradorId;
  final String idEmpleado;
  final String nombreCompleto;
  final String sucursal;
  final String departamento;
  final String cargo;
  final String turnoPredeterminado;
  final String evento;
  final String lunes;
  final String martes;
  final String miercoles;
  final String jueves;
  final String viernes;
  final String sabado;
  final String domingo;

  const HorarioSemanalRowModel({
    required this.colaboradorId,
    required this.idEmpleado,
    required this.nombreCompleto,
    required this.sucursal,
    required this.departamento,
    required this.cargo,
    required this.turnoPredeterminado,
    required this.evento,
    required this.lunes,
    required this.martes,
    required this.miercoles,
    required this.jueves,
    required this.viernes,
    required this.sabado,
    required this.domingo,
  });

  factory HorarioSemanalRowModel.fromJson(Map<String, dynamic> json) {
    return HorarioSemanalRowModel(
      colaboradorId: _asInt(json['colaborador_id']) ?? 0,
      idEmpleado: _asString(json['id_empleado']) ?? '',
      nombreCompleto: _asString(json['nombre_completo']) ?? '',
      sucursal: _asString(json['sucursal']) ?? '',
      departamento: _asString(json['departamento']) ?? '',
      cargo: _asString(json['cargo']) ?? '',
      turnoPredeterminado: _asString(json['turno_predeterminado']) ?? '',
      evento: _asString(json['evento']) ?? '',
      lunes: _asString(json['lunes']) ?? '',
      martes: _asString(json['martes']) ?? '',
      miercoles: _asString(json['miercoles']) ?? '',
      jueves: _asString(json['jueves']) ?? '',
      viernes: _asString(json['viernes']) ?? '',
      sabado: _asString(json['sabado']) ?? '',
      domingo: _asString(json['domingo']) ?? '',
    );
  }
}

class HorarioSemanalConfirmacionModel {
  final String sucursal;
  final String departamento;
  final String semana;
  final String estatus;

  const HorarioSemanalConfirmacionModel({
    required this.sucursal,
    required this.departamento,
    required this.semana,
    required this.estatus,
  });

  factory HorarioSemanalConfirmacionModel.fromJson(Map<String, dynamic> json) {
    return HorarioSemanalConfirmacionModel(
      sucursal: _asString(json['sucursal']) ?? '',
      departamento: _asString(json['departamento']) ?? '',
      semana: _asString(json['semana']) ?? '',
      estatus: (_asString(json['estatus']) ?? 'PENDIENTE').toUpperCase(),
    );
  }
}

class HorarioSemanalModel {
  final String weekStart;
  final String weekEnd;
  final List<String> days;
  final List<HorarioSemanalRowModel> rows;
  final List<HorarioSemanalConfirmacionModel> confirmaciones;

  const HorarioSemanalModel({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.rows,
    required this.confirmaciones,
  });

  factory HorarioSemanalModel.fromJson(Map<String, dynamic> json) {
    final dayList = (json['days'] is List)
        ? (json['days'] as List)
              .map((e) => _asString(e) ?? '')
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final rowList = (json['rows'] is List) ? (json['rows'] as List) : const [];
    final confirmationList = (json['confirmaciones'] is List)
        ? (json['confirmaciones'] as List)
        : const [];
    return HorarioSemanalModel(
      weekStart: _asString(json['week_start']) ?? '',
      weekEnd: _asString(json['week_end']) ?? '',
      days: dayList,
      rows: rowList
          .whereType<Map>()
          .map(
            (row) =>
                HorarioSemanalRowModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(),
      confirmaciones: confirmationList
          .whereType<Map>()
          .map(
            (row) => HorarioSemanalConfirmacionModel.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(),
    );
  }
}

class HorarioAsignacionModel {
  final int horarioId;
  final String nombre;
  final String horaEntrada;
  final String horaSalida;
  final int prioridad;
  final String origen;

  const HorarioAsignacionModel({
    required this.horarioId,
    required this.nombre,
    required this.horaEntrada,
    required this.horaSalida,
    required this.prioridad,
    required this.origen,
  });

  factory HorarioAsignacionModel.fromJson(Map<String, dynamic> json) {
    return HorarioAsignacionModel(
      horarioId: _asInt(json['horario_id']) ?? 0,
      nombre: _asString(json['nombre']) ?? '',
      horaEntrada: _asString(json['hora_entrada']) ?? '00:00:00',
      horaSalida: _asString(json['hora_salida']) ?? '00:00:00',
      prioridad: _asInt(json['prioridad']) ?? 0,
      origen: (_asString(json['origen']) ?? 'ROTATIVO').toUpperCase(),
    );
  }
}

class ColaboradorHorarioCalendarModel {
  final int colaboradorId;
  final String idEmpleado;
  final String pin;
  final String nombre;
  final List<HorarioAsignacionModel> asignaciones;

  const ColaboradorHorarioCalendarModel({
    required this.colaboradorId,
    required this.idEmpleado,
    required this.pin,
    required this.nombre,
    required this.asignaciones,
  });

  factory ColaboradorHorarioCalendarModel.fromJson(Map<String, dynamic> json) {
    final rawList = (json['asignaciones'] is List)
        ? (json['asignaciones'] as List)
        : const [];
    return ColaboradorHorarioCalendarModel(
      colaboradorId: _asInt(json['colaborador_id']) ?? 0,
      idEmpleado: _asString(json['id_empleado']) ?? '',
      pin: _asString(json['pin']) ?? _asString(json['id_empleado']) ?? '',
      nombre: _asString(json['nombre']) ?? '',
      asignaciones: rawList
          .whereType<Map>()
          .map(
            (row) =>
                HorarioAsignacionModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(),
    );
  }
}

class ColaboradorGestionModel {
  final int id;
  final String idEmpleado;
  final String pin;
  final String nombre;
  final String apellido;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String nombreCompleto;
  final int sucursalId;
  final String sucursalCodigo;
  final String sucursalNombre;
  final String departamento;
  final String cargo;
  final List<int> sucursalesIds;
  final int privilegio;
  final bool estado;
  final bool appAccess;
  final bool gpsAllowed;
  final bool qrAllowed;
  final String? rfc;
  final String? curp;
  final String? nss;
  final String jornadaTipo;
  final String estatusContrato;
  final bool documentacionCompleta;
  final int? horarioId;
  final String horarioNombre;
  final DateTime? vencimientoContrato;
  final bool esAdminDispositivo;
  final bool hasHuella;
  final bool hasRostro;
  final bool hasPalma;
  final bool hasPin;
  final bool hasFace;
  final bool hasFingerprint;
  final String? qrCodeToken;
  final String? preferredAuthMethod;
  final List<String> templates;

  const ColaboradorGestionModel({
    required this.id,
    required this.idEmpleado,
    required this.pin,
    required this.nombre,
    required this.apellido,
    this.apellidoPaterno = '',
    this.apellidoMaterno = '',
    required this.nombreCompleto,
    required this.sucursalId,
    required this.sucursalCodigo,
    required this.sucursalNombre,
    required this.departamento,
    required this.cargo,
    required this.sucursalesIds,
    required this.privilegio,
    required this.estado,
    required this.appAccess,
    required this.gpsAllowed,
    required this.qrAllowed,
    required this.rfc,
    required this.curp,
    required this.nss,
    required this.jornadaTipo,
    required this.estatusContrato,
    required this.documentacionCompleta,
    required this.horarioId,
    required this.horarioNombre,
    required this.vencimientoContrato,
    required this.esAdminDispositivo,
    required this.hasHuella,
    required this.hasRostro,
    required this.hasPalma,
    required this.hasPin,
    required this.hasFace,
    required this.hasFingerprint,
    required this.qrCodeToken,
    required this.preferredAuthMethod,
    required this.templates,
  });

  factory ColaboradorGestionModel.fromJson(Map<String, dynamic> json) {
    final templates = (json['templates'] is List)
        ? (json['templates'] as List)
              .map((e) => _asString(e) ?? '')
              .where((e) => e.isNotEmpty)
              .map((e) => e.toUpperCase())
              .toList()
        : <String>[];

    final sucursalesIds = (json['sucursales_ids'] is List)
        ? (json['sucursales_ids'] as List)
              .map((e) => _asInt(e) ?? 0)
              .where((e) => e > 0)
              .toList()
        : <int>[];

    final hasHuellaFromList = templates.contains('HUELLA');
    final hasRostroFromList = templates.contains('ROSTRO');
    final hasPalmaFromList = templates.contains('PALMA');

    return ColaboradorGestionModel(
      id: _asInt(json['id']) ?? 0,
      idEmpleado:
          (_asString(json['id_empleado']) ??
                  _asString(json['matricula']) ??
                  _asString(json['id']) ??
                  '')
              .trim(),
      pin: _asString(json['pin']) ?? '',
      nombre: _asString(json['nombre']) ?? '',
      apellido: _asString(json['apellido']) ?? '',
      apellidoPaterno: _asString(json['apellido_paterno']) ?? '',
      apellidoMaterno: _asString(json['apellido_materno']) ?? '',
      nombreCompleto:
          _asString(json['nombreCompleto']) ??
          '${_asString(json['nombre']) ?? ''} ${_asString(json['apellido']) ?? ''}'
              .trim(),
      sucursalId: _asInt(json['sucursal_id']) ?? 0,
      sucursalCodigo: _asString(json['sucursal_codigo']) ?? '',
      sucursalNombre: _asString(json['sucursal_nombre']) ?? '',
      departamento: _asString(json['departamento']) ?? '',
      cargo: _asString(json['cargo']) ?? '',
      sucursalesIds: sucursalesIds,
      privilegio: _asInt(json['privilegio']) ?? 0,
      estado: _asBool(json['estado']),
      appAccess: _asBool(json['app_access']),
      gpsAllowed: _asBool(json['gps_allowed']),
      qrAllowed: _asBool(json['qr_allowed']),
      rfc: _asString(json['rfc']),
      curp: _asString(json['curp']),
      nss: _asString(json['nss']),
      jornadaTipo: (_asString(json['jornada_tipo']) ?? 'DIURNA').toUpperCase(),
      estatusContrato: (_asString(json['estatus_contrato']) ?? 'PLANTA')
          .toUpperCase(),
      documentacionCompleta: _asBool(json['documentacion_completa']),
      horarioId: _asInt(json['horario_id']),
      horarioNombre: _asString(json['horario_nombre']) ?? '',
      vencimientoContrato: _asDate(json['vencimiento_contrato']),
      esAdminDispositivo: _asBool(json['es_admin_dispositivo']),
      hasHuella: hasHuellaFromList || _asBool(json['hasHuella']),
      hasRostro: hasRostroFromList || _asBool(json['hasRostro']),
      hasPalma: hasPalmaFromList || _asBool(json['hasPalma']),
      hasPin:
          _asBool(json['has_pin']) || (_asString(json['pin']) ?? '').isNotEmpty,
      hasFace:
          _asBool(json['has_face']) ||
          hasRostroFromList ||
          _asBool(json['hasRostro']),
      hasFingerprint:
          _asBool(json['has_fingerprint']) ||
          hasHuellaFromList ||
          _asBool(json['hasHuella']),
      qrCodeToken: _asString(json['qr_code_token']),
      preferredAuthMethod: _asString(json['preferred_auth_method']),
      templates: templates,
    );
  }
}

class TerminalColaboradorProfile {
  final int id;
  final String pin;
  final String nombre;
  final String apellido;
  final String? cargo;
  final String? departamento;
  final int? sucursalId;
  final String? sucursalCodigo;
  final bool hasPin;
  final bool hasFace;
  final bool hasFingerprint;
  final String? qrCodeToken;
  final String preferredAuthMethod;

  const TerminalColaboradorProfile({
    required this.id,
    required this.pin,
    required this.nombre,
    required this.apellido,
    required this.cargo,
    required this.departamento,
    required this.sucursalId,
    required this.sucursalCodigo,
    required this.hasPin,
    required this.hasFace,
    required this.hasFingerprint,
    required this.qrCodeToken,
    required this.preferredAuthMethod,
  });

  factory TerminalColaboradorProfile.fromJson(Map<String, dynamic> json) {
    final root = (json['colaborador'] is Map)
        ? Map<String, dynamic>.from(json['colaborador'] as Map)
        : json;

    return TerminalColaboradorProfile(
      id: _asInt(root['id']) ?? 0,
      pin: _asString(root['pin']) ?? '',
      nombre: _asString(root['nombre']) ?? '',
      apellido: _asString(root['apellido']) ?? '',
      cargo: _asString(root['cargo']),
      departamento: _asString(root['departamento']),
      sucursalId: _asInt(root['sucursal_id']),
      sucursalCodigo: _asString(root['sucursal_codigo']),
      hasPin:
          _asBool(root['has_pin']) || (_asString(root['pin']) ?? '').isNotEmpty,
      hasFace: _asBool(root['has_face']),
      hasFingerprint: _asBool(root['has_fingerprint']),
      qrCodeToken: _asString(root['qr_code_token']),
      preferredAuthMethod: (_asString(root['preferred_auth_method']) ?? 'PIN')
          .trim()
          .toUpperCase(),
    );
  }
}

class ColaboradorCreateRequest {
  final String? idEmpleado;
  final String pin;
  final String nombre;
  final String apellido;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final int sucursalId;
  final List<int> sucursalesIds;
  final String departamento;
  final String cargo;
  final String tipoContrato;
  final String estatusColaborador;
  final int privilegio;
  final bool estado;
  final bool appAccess;
  final bool gpsAllowed;
  final bool qrAllowed;
  final String? rfc;
  final String? curp;
  final String? nss;
  final String jornadaTipo;
  final String estatusContrato;
  final bool documentacionCompleta;
  final int? horarioId;
  final String? vencimientoContrato;
  final bool esAdminDispositivo;

  const ColaboradorCreateRequest({
    required this.idEmpleado,
    required this.pin,
    required this.nombre,
    required this.apellido,
    this.apellidoPaterno = '',
    this.apellidoMaterno = '',
    required this.sucursalId,
    required this.sucursalesIds,
    required this.departamento,
    required this.cargo,
    required this.tipoContrato,
    required this.estatusColaborador,
    required this.privilegio,
    required this.estado,
    required this.appAccess,
    required this.gpsAllowed,
    required this.qrAllowed,
    required this.rfc,
    required this.curp,
    required this.nss,
    required this.jornadaTipo,
    required this.estatusContrato,
    required this.documentacionCompleta,
    required this.horarioId,
    required this.vencimientoContrato,
    required this.esAdminDispositivo,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'pin': pin.trim(),
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'sucursal_id': sucursalId,
      'departamento': departamento.trim(),
      'cargo': cargo.trim(),
      'tipo_contrato': tipoContrato.trim().toUpperCase(),
      'estatus_colaborador': estatusColaborador.trim(),
      'privilegio': privilegio,
      'estado': estado,
      'app_access': appAccess,
      'gps_allowed': gpsAllowed,
      'qr_allowed': qrAllowed,
      'jornada_tipo': jornadaTipo.trim().toUpperCase(),
      'estatus_contrato': estatusContrato.trim().toUpperCase(),
      'documentacion_completa': documentacionCompleta,
      'es_admin_dispositivo': esAdminDispositivo,
      'sucursales_ids': sucursalesIds,
    };

    if (apellidoPaterno.trim().isNotEmpty) {
      data['apellido_paterno'] = apellidoPaterno.trim();
    }
    if (apellidoMaterno.trim().isNotEmpty) {
      data['apellido_materno'] = apellidoMaterno.trim();
    }

    if ((idEmpleado ?? '').trim().isNotEmpty) {
      data['id_empleado'] = idEmpleado!.trim();
    }

    if ((rfc ?? '').trim().isNotEmpty) {
      data['rfc'] = rfc!.trim().toUpperCase();
    }
    if ((curp ?? '').trim().isNotEmpty) {
      data['curp'] = curp!.trim().toUpperCase();
    }
    if ((nss ?? '').trim().isNotEmpty) {
      data['nss'] = nss!.trim();
    }
    if (horarioId != null) {
      data['horario_id'] = horarioId;
    }
    if ((vencimientoContrato ?? '').trim().isNotEmpty) {
      data['vencimiento_contrato'] = vencimientoContrato!.trim();
    }

    return data;
  }
}

class Nom035RespuestaModel {
  final int id;
  final int colaboradorId;
  final DateTime? fecha;
  final int p1;
  final int p2;
  final int p3;
  final String? comentario;

  const Nom035RespuestaModel({
    required this.id,
    required this.colaboradorId,
    required this.fecha,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.comentario,
  });

  factory Nom035RespuestaModel.fromJson(Map<String, dynamic> json) {
    return Nom035RespuestaModel(
      id: _asInt(json['id']) ?? 0,
      colaboradorId: _asInt(json['colaborador_id']) ?? 0,
      fecha: _asDate(json['fecha']),
      p1: _asInt(json['p1']) ?? 0,
      p2: _asInt(json['p2']) ?? 0,
      p3: _asInt(json['p3']) ?? 0,
      comentario: _asString(json['comentario']),
    );
  }
}

class SaveNom035Request {
  final int p1;
  final int p2;
  final int p3;
  final String? comentario;

  const SaveNom035Request({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.comentario,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'p1': p1, 'p2': p2, 'p3': p3};
    if ((comentario ?? '').trim().isNotEmpty) {
      data['comentario'] = comentario!.trim();
    }
    return data;
  }
}

class ColaboradorDocumentoModel {
  final int id;
  final int colaboradorId;
  final String tipoDoc;
  final String fileName;
  final String? mimeType;
  final String fileUrl;
  final DateTime? uploadedAt;

  const ColaboradorDocumentoModel({
    required this.id,
    required this.colaboradorId,
    required this.tipoDoc,
    required this.fileName,
    required this.mimeType,
    required this.fileUrl,
    required this.uploadedAt,
  });

  factory ColaboradorDocumentoModel.fromJson(Map<String, dynamic> json) {
    return ColaboradorDocumentoModel(
      id: _asInt(json['id']) ?? 0,
      colaboradorId: _asInt(json['colaborador_id']) ?? 0,
      tipoDoc: (_asString(json['tipo_doc']) ?? '').toUpperCase(),
      fileName: _asString(json['file_name']) ?? '',
      mimeType: _asString(json['mime_type']),
      fileUrl: _asString(json['file_url']) ?? '',
      uploadedAt: _asDate(json['uploaded_at']),
    );
  }
}

class AsistenciaReporteRow {
  final String fecha;
  final String workdayId;
  final int colaboradorId;
  final int? sucursalId;
  final String pin;
  final String nombre;
  final String? rfc;
  final String? curp;
  final String? entrada;
  final String? salida;
  final String estatus;
  final String suc;
  final String? horarioNombre;
  final int minutosTrabajados;
  final int minutosExtra;
  final int retardoMinutos;
  final int salidaTempranaMinutos;
  final bool flexibleCumplido;

  const AsistenciaReporteRow({
    required this.fecha,
    required this.workdayId,
    required this.colaboradorId,
    required this.sucursalId,
    required this.pin,
    required this.nombre,
    required this.rfc,
    required this.curp,
    required this.entrada,
    required this.salida,
    required this.estatus,
    required this.suc,
    required this.horarioNombre,
    required this.minutosTrabajados,
    required this.minutosExtra,
    required this.retardoMinutos,
    required this.salidaTempranaMinutos,
    required this.flexibleCumplido,
  });

  factory AsistenciaReporteRow.fromJson(Map<String, dynamic> json) {
    return AsistenciaReporteRow(
      fecha: _asString(json['fecha']) ?? '',
      workdayId:
          _asString(json['workday_id']) ?? (_asString(json['fecha']) ?? ''),
      colaboradorId: _asInt(json['colaborador_id']) ?? 0,
      sucursalId: _asInt(json['sucursal_id']),
      pin: _asString(json['pin']) ?? '',
      nombre: _asString(json['nombre']) ?? '',
      rfc: _asString(json['rfc']),
      curp: _asString(json['curp']),
      entrada: _asString(json['entrada']),
      salida: _asString(json['salida']),
      estatus: (_asString(json['estatus']) ?? 'FALTA').toUpperCase(),
      suc: _asString(json['suc']) ?? '',
      horarioNombre: _asString(json['horario_nombre']),
      minutosTrabajados: _asInt(json['minutos_trabajados']) ?? 0,
      minutosExtra: _asInt(json['minutos_extra']) ?? 0,
      retardoMinutos: _asInt(json['retardo_minutos']) ?? 0,
      salidaTempranaMinutos: _asInt(json['salida_temprana_minutos']) ?? 0,
      flexibleCumplido: _asBool(json['flexible_cumplido']),
    );
  }
}

class AsistenciaReporteQuery {
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int? sucursalId;
  final int? departamentoId;
  final int? cargoId;
  final String? departamento;
  final String? cargo;
  final String? idEmpleado;
  final String? pin;

  const AsistenciaReporteQuery({
    required this.fechaInicio,
    required this.fechaFin,
    required this.sucursalId,
    required this.departamentoId,
    required this.cargoId,
    required this.departamento,
    required this.cargo,
    required this.idEmpleado,
    required this.pin,
  });

  Map<String, dynamic> toQueryParams() {
    return {
      'fecha_inicio': _dateIso(fechaInicio),
      'fecha_fin': _dateIso(fechaFin),
      if (sucursalId != null) 'sucursal_id': sucursalId,
      if (departamentoId != null) 'departamento_id': departamentoId,
      if (cargoId != null) 'cargo_id': cargoId,
      if ((idEmpleado ?? '').trim().isNotEmpty)
        'id_empleado': idEmpleado!.trim(),
      if ((pin ?? '').trim().isNotEmpty) 'pin': pin!.trim(),
    };
  }
}

class ColaboradorQrCredential {
  final String token;
  final int colaboradorId;
  final String pin;
  final String nombre;
  final String? sucursalCodigo;

  const ColaboradorQrCredential({
    required this.token,
    required this.colaboradorId,
    required this.pin,
    required this.nombre,
    required this.sucursalCodigo,
  });

  factory ColaboradorQrCredential.fromJson(Map<String, dynamic> json) {
    final colaborador = (json['colaborador'] is Map)
        ? Map<String, dynamic>.from(json['colaborador'] as Map)
        : <String, dynamic>{};
    return ColaboradorQrCredential(
      token: _asString(json['token']) ?? '',
      colaboradorId: _asInt(colaborador['id']) ?? 0,
      pin: _asString(colaborador['pin']) ?? '',
      nombre: _asString(colaborador['nombre']) ?? '',
      sucursalCodigo: _asString(colaborador['sucursal']),
    );
  }
}

class SelfServiceSession {
  final String token;
  final int colaboradorId;
  final String pin;
  final String nombre;
  final int? sucursalId;
  final String? sucursalCodigo;
  final double? latitud;
  final double? longitud;
  final int? radioMetros;
  final bool geofenceEnabled;
  final bool gpsOverride;

  const SelfServiceSession({
    required this.token,
    required this.colaboradorId,
    required this.pin,
    required this.nombre,
    required this.sucursalId,
    required this.sucursalCodigo,
    required this.latitud,
    required this.longitud,
    required this.radioMetros,
    required this.geofenceEnabled,
    required this.gpsOverride,
  });

  factory SelfServiceSession.fromJson(
    Map<String, dynamic> json, {
    required String token,
  }) {
    final colab = (json['colaborador'] is Map)
        ? Map<String, dynamic>.from(json['colaborador'] as Map)
        : <String, dynamic>{};
    final geo = (json['geofence'] is Map)
        ? Map<String, dynamic>.from(json['geofence'] as Map)
        : <String, dynamic>{};

    return SelfServiceSession(
      token: token,
      colaboradorId: _asInt(colab['id']) ?? 0,
      pin: _asString(colab['pin']) ?? '',
      nombre: _asString(colab['nombre']) ?? '',
      sucursalId: _asInt(colab['sucursal_id']),
      sucursalCodigo: _asString(colab['sucursal_codigo']),
      latitud: _asDouble(geo['latitud']),
      longitud: _asDouble(geo['longitud']),
      radioMetros: _asInt(geo['radio_metros']),
      geofenceEnabled: _asBool(geo['enabled']),
      gpsOverride: _asBool(geo['gps_override']),
    );
  }
}

class PermisoTipoModel {
  final int id;
  final String nombre;
  final String codigo;
  final bool goceSueldo;
  final bool justificaAsistencia;

  const PermisoTipoModel({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.goceSueldo,
    required this.justificaAsistencia,
  });

  factory PermisoTipoModel.fromJson(Map<String, dynamic> json) {
    return PermisoTipoModel(
      id: _asInt(json['id']) ?? 0,
      nombre: _asString(json['nombre']) ?? '',
      codigo: _asString(json['codigo']) ?? '',
      goceSueldo: _asBool(json['goce_sueldo']),
      justificaAsistencia: _asBool(json['justifica_asistencia']),
    );
  }
}

class SolicitudIncidenciaModel {
  final int id;
  final int colaboradorId;
  final String colaboradorNombre;
  final String pin;
  final int tipoId;
  final String tipoNombre;
  final String tipoCodigo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? motivo;
  final String? evidenciaUrl;
  final String estatus;

  const SolicitudIncidenciaModel({
    required this.id,
    required this.colaboradorId,
    required this.colaboradorNombre,
    required this.pin,
    required this.tipoId,
    required this.tipoNombre,
    required this.tipoCodigo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.motivo,
    required this.evidenciaUrl,
    required this.estatus,
  });

  factory SolicitudIncidenciaModel.fromJson(Map<String, dynamic> json) {
    return SolicitudIncidenciaModel(
      id: _asInt(json['id'] ?? json['IDINC'] ?? json['idinc']) ?? 0,
      colaboradorId:
          _asInt(
            json['colaborador_id'] ??
                json['IDCOLAB'] ??
                json['idcolab'] ??
                json['id_colaborador'],
          ) ??
          0,
      colaboradorNombre:
          _asString(
            json['colaborador_nombre'] ??
                json['COLABORADOR_NOMBRE'] ??
                json['nombre_colaborador'],
          ) ??
          '',
      pin: _asString(json['pin'] ?? json['PIN']) ?? '',
      tipoId: _asInt(json['tipo_id'] ?? json['IDTIPO'] ?? json['idtipo']) ?? 0,
      tipoNombre:
          _asString(
            json['tipo_nombre'] ?? json['TIPO_NOMBRE'] ?? json['tipo'],
          ) ??
          '',
      tipoCodigo:
          _asString(
            json['tipo_codigo'] ?? json['TIPO_CODIGO'] ?? json['codigo'],
          ) ??
          '',
      fechaInicio:
          _asDate(json['fecha_inicio'] ?? json['FECHA_INICIO']) ??
          DateTime.now(),
      fechaFin:
          _asDate(json['fecha_fin'] ?? json['FECHA_FIN']) ?? DateTime.now(),
      motivo: _asString(json['motivo'] ?? json['MOTIVO']),
      evidenciaUrl: _asString(json['evidencia_url'] ?? json['EVIDENCIA_URL']),
      estatus: (_asString(json['estatus'] ?? json['ESTATUS']) ?? 'PENDIENTE')
          .toUpperCase(),
    );
  }
}

class SolicitudIncidenciaCreateRequest {
  final int colaboradorId;
  final int tipoId;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? motivo;
  final String? evidenciaUrl;

  const SolicitudIncidenciaCreateRequest({
    required this.colaboradorId,
    required this.tipoId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.motivo,
    required this.evidenciaUrl,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'colaborador_id': colaboradorId,
      'tipo_id': tipoId,
      'fecha_inicio': _dateIso(fechaInicio),
      'fecha_fin': _dateIso(fechaFin),
    };
    if ((motivo ?? '').trim().isNotEmpty) data['motivo'] = motivo!.trim();
    if ((evidenciaUrl ?? '').trim().isNotEmpty) {
      data['evidencia_url'] = evidenciaUrl!.trim();
    }
    return data;
  }
}

class AusenciaCalendarioItem {
  final int id;
  final int colaboradorId;
  final String colaboradorNombre;
  final String pin;
  final String tipoNombre;
  final String tipoCodigo;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const AusenciaCalendarioItem({
    required this.id,
    required this.colaboradorId,
    required this.colaboradorNombre,
    required this.pin,
    required this.tipoNombre,
    required this.tipoCodigo,
    required this.fechaInicio,
    required this.fechaFin,
  });

  factory AusenciaCalendarioItem.fromJson(Map<String, dynamic> json) {
    return AusenciaCalendarioItem(
      id: _asInt(json['id']) ?? 0,
      colaboradorId: _asInt(json['colaborador_id']) ?? 0,
      colaboradorNombre: _asString(json['colaborador_nombre']) ?? '',
      pin: _asString(json['pin']) ?? '',
      tipoNombre: _asString(json['tipo_nombre']) ?? '',
      tipoCodigo: _asString(json['tipo_codigo']) ?? '',
      fechaInicio: _asDate(json['fecha_inicio']) ?? DateTime.now(),
      fechaFin: _asDate(json['fecha_fin']) ?? DateTime.now(),
    );
  }
}

class VacacionesDashboardModel {
  final int colaboradorId;
  final int anio;
  final int diasDisponibles;
  final int diasTomados;
  final int diasTotales;
  final List<ProximaVacacionModel> proximasVacaciones;

  const VacacionesDashboardModel({
    required this.colaboradorId,
    required this.anio,
    required this.diasDisponibles,
    required this.diasTomados,
    required this.diasTotales,
    required this.proximasVacaciones,
  });

  factory VacacionesDashboardModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['proximas_vacaciones'] is List)
        ? (json['proximas_vacaciones'] as List)
        : const [];
    return VacacionesDashboardModel(
      colaboradorId: _asInt(json['colaborador_id']) ?? 0,
      anio: _asInt(json['anio']) ?? DateTime.now().year,
      diasDisponibles: _asInt(json['dias_disponibles']) ?? 0,
      diasTomados: _asInt(json['dias_tomados']) ?? 0,
      diasTotales: _asInt(json['dias_totales']) ?? 0,
      proximasVacaciones: raw
          .whereType<Map>()
          .map(
            (item) =>
                ProximaVacacionModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class ProximaVacacionModel {
  final int id;
  final String tipo;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const ProximaVacacionModel({
    required this.id,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaFin,
  });

  factory ProximaVacacionModel.fromJson(Map<String, dynamic> json) {
    return ProximaVacacionModel(
      id: _asInt(json['id']) ?? 0,
      tipo: _asString(json['tipo']) ?? '',
      fechaInicio: _asDate(json['fecha_inicio']) ?? DateTime.now(),
      fechaFin: _asDate(json['fecha_fin']) ?? DateTime.now(),
    );
  }
}

class RelojRealtimePunchEvent {
  final int? idTimeLog;
  final int? idUsuario;
  final String suc;
  final String tipo;
  final DateTime? punchTime;
  final String? terminalId;
  final String? eventPhoto;
  final String? expedientePhoto;
  final double? bodyTemp;
  final int? verifyMode;
  final String? verifyModeLabel;
  final bool isOffline;
  final bool requiresReview;
  final bool silentAlert;
  final String source;

  const RelojRealtimePunchEvent({
    required this.idTimeLog,
    required this.idUsuario,
    required this.suc,
    required this.tipo,
    required this.punchTime,
    required this.terminalId,
    required this.eventPhoto,
    required this.expedientePhoto,
    required this.bodyTemp,
    required this.verifyMode,
    required this.verifyModeLabel,
    required this.isOffline,
    required this.requiresReview,
    required this.silentAlert,
    required this.source,
  });

  factory RelojRealtimePunchEvent.fromJson(Map<String, dynamic> json) {
    return RelojRealtimePunchEvent(
      idTimeLog: _asInt(json['idTimeLog'] ?? json['id_timelog']),
      idUsuario: _asInt(json['idUsuario'] ?? json['id_usuario']),
      suc: _asString(json['suc']) ?? '',
      tipo: _asString(json['tipo']) ?? '',
      punchTime: _asDate(json['punchTime'] ?? json['punch_time']),
      terminalId: _asString(json['terminalId'] ?? json['terminal_id']),
      eventPhoto: _asString(json['eventPhoto'] ?? json['event_photo']),
      expedientePhoto: _asString(
        json['expedientePhoto'] ?? json['expediente_photo'],
      ),
      bodyTemp: _asDouble(json['bodyTemp'] ?? json['body_temp']),
      verifyMode: _asInt(json['verifyMode'] ?? json['verify_mode']),
      verifyModeLabel: _asString(
        json['verifyModeLabel'] ?? json['verify_mode_label'],
      ),
      isOffline: _asBool(json['isOffline'] ?? json['is_offline']),
      requiresReview: _asBool(
        json['requiresReview'] ?? json['requires_review'],
      ),
      silentAlert: _asBool(json['silentAlert'] ?? json['silent_alert']),
      source: _asString(json['source']) ?? 'ADMS_PUSH',
    );
  }

  static RelojRealtimePunchEvent? fromSocket(dynamic payload) {
    if (payload is! Map) return null;
    return RelojRealtimePunchEvent.fromJson(Map<String, dynamic>.from(payload));
  }
}

class RelojRealtimeTemplateEvent {
  final int colaboradorId;
  final String pin;
  final String tipo;
  final DateTime? updatedAt;

  const RelojRealtimeTemplateEvent({
    required this.colaboradorId,
    required this.pin,
    required this.tipo,
    required this.updatedAt,
  });

  factory RelojRealtimeTemplateEvent.fromJson(Map<String, dynamic> json) {
    return RelojRealtimeTemplateEvent(
      colaboradorId:
          _asInt(json['colaboradorId'] ?? json['colaborador_id']) ?? 0,
      pin: _asString(json['pin']) ?? '',
      tipo: _asString(json['tipo']) ?? '',
      updatedAt: _asDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static RelojRealtimeTemplateEvent? fromSocket(dynamic payload) {
    if (payload is! Map) return null;
    return RelojRealtimeTemplateEvent.fromJson(
      Map<String, dynamic>.from(payload),
    );
  }
}

String _dateIso(DateTime value) {
  return value.toIso8601String();
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

class SucursalModel {
  final String suc;
  final String? desc;
  final String? encar;
  final String? zona;
  final String? rfc;
  final String? direccion;
  final String? contacto;
  final int? ivaIntegrado;

  const SucursalModel({
    required this.suc,
    this.desc,
    this.encar,
    this.zona,
    this.rfc,
    this.direccion,
    this.contacto,
    this.ivaIntegrado,
  });

  factory SucursalModel.fromJson(Map<String, dynamic> json) {
    final iva = json['IVA_INTEGRADO'];
    return SucursalModel(
      suc: json['SUC'] as String,
      desc: json['DESC'] as String?,
      encar: json['ENCAR'] as String?,
      zona: json['ZONA'] as String?,
      rfc: json['RFC'] as String?,
      direccion: json['DIRECCION'] as String?,
      contacto: json['CONTACTO'] as String?,
      ivaIntegrado: iva == null ? null : (iva as num).toInt(),
    );
  }

  Map<String, dynamic> toPayload({bool includeSuc = true}) {
    return {
      if (includeSuc) 'SUC': suc,
      'DESC': desc,
      'ENCAR': encar,
      'ZONA': zona,
      'RFC': rfc,
      'DIRECCION': direccion,
      'CONTACTO': contacto,
      'IVA_INTEGRADO': ivaIntegrado,
    };
  }
}

class SucursalGestionModel {
  final int id;
  final String codigo;
  final String nombre;
  final String empresa;
  final bool estado;
  final String? direccion;
  final String? telefono;
  final int comandosPendientes;
  final int dispositivosTotal;
  final int dispositivosConectados;
  final List<SucursalDispositivoEstadoModel> dispositivos;
  final String? sucursalToken;
  final DateTime? lastSeenAt;
  final bool isOffline;

  const SucursalGestionModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.empresa,
    required this.estado,
    this.direccion,
    this.telefono,
    this.comandosPendientes = 0,
    this.dispositivosTotal = 0,
    this.dispositivosConectados = 0,
    this.dispositivos = const [],
    this.sucursalToken,
    this.lastSeenAt,
    this.isOffline = false,
  });

  factory SucursalGestionModel.fromJson(Map<String, dynamic> json) {
    final dispositivosRaw = (json['dispositivos'] as List?) ?? const [];
    final dispositivos = dispositivosRaw
        .whereType<Map>()
        .map(
          (e) => SucursalDispositivoEstadoModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();

    return SucursalGestionModel(
      id: (json['id'] as num).toInt(),
      codigo: (json['codigo'] as String? ?? '').trim(),
      nombre: (json['nombre'] as String? ?? '').trim(),
      empresa: (json['empresa'] as String? ?? '').trim(),
      estado: json['estado'] == true || json['estado'] == 1,
      direccion:
          (json['direccion_completa'] as String? ??
                  json['direccion'] as String?)
              ?.trim(),
      telefono:
          (json['telefono'] as String? ?? json['contacto'] as String?)?.trim(),
      comandosPendientes: ((json['comandosPendientes'] as num?)?.toInt()) ?? 0,
      dispositivosTotal:
          ((json['dispositivosTotal'] as num?)?.toInt()) ?? dispositivos.length,
      dispositivosConectados:
          ((json['dispositivosConectados'] as num?)?.toInt()) ??
          dispositivos.where((d) => d.connected).length,
      dispositivos: dispositivos,
      sucursalToken: (json['sucursal_token'] as String?)?.trim(),
      lastSeenAt: _parseDate(json['last_seen_at']),
      isOffline: json['is_offline'] == true || json['is_offline'] == 1,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'empresa': empresa,
      'estado': estado,
      if ((direccion ?? '').trim().isNotEmpty)
        'direccion_completa': direccion,
      if ((telefono ?? '').trim().isNotEmpty) 'telefono': telefono,
    };
  }
}

class SucursalCommandHistoryModel {
  final String dispositivoId;
  final String comando;
  final String estado;
  final DateTime? fechaCreacion;

  const SucursalCommandHistoryModel({
    required this.dispositivoId,
    required this.comando,
    required this.estado,
    required this.fechaCreacion,
  });

  factory SucursalCommandHistoryModel.fromJson(Map<String, dynamic> json) {
    return SucursalCommandHistoryModel(
      dispositivoId: (json['dispositivo_id'] as String? ?? '').trim(),
      comando: (json['comando'] as String? ?? '').trim(),
      estado: ((json['estado'] as String?) ?? 'PENDIENTE').trim().toUpperCase(),
      fechaCreacion: _parseDate(json['fecha_creacion']),
    );
  }
}

class SucursalDeviceConfigModel {
  final String deviceId;
  final String? modelo;
  final String? firmware;
  final String? sn;

  const SucursalDeviceConfigModel({
    required this.deviceId,
    required this.modelo,
    required this.firmware,
    required this.sn,
  });

  factory SucursalDeviceConfigModel.fromJson(Map<String, dynamic> json) {
    return SucursalDeviceConfigModel(
      deviceId: (json['device_id'] as String? ?? '').trim(),
      modelo: (json['modelo'] as String?)?.trim(),
      firmware: (json['firmware'] as String?)?.trim(),
      sn: (json['sn'] as String?)?.trim(),
    );
  }
}

class SucursalConfigResponseModel {
  final SucursalGestionModel sucursal;
  final List<SucursalDeviceConfigModel> devices;
  final List<SucursalCommandHistoryModel> comandos;

  const SucursalConfigResponseModel({
    required this.sucursal,
    required this.devices,
    required this.comandos,
  });

  factory SucursalConfigResponseModel.fromJson(Map<String, dynamic> json) {
    final sucMap = Map<String, dynamic>.from(
      (json['sucursal'] as Map?) ?? const {},
    );
    final base = {
      ...sucMap,
      'dispositivos': const [],
      'comandosPendientes': 0,
      'dispositivosTotal': 0,
      'dispositivosConectados': 0,
    };

    final devicesRaw = (json['devices'] as List?) ?? const [];
    final comandosRaw = (json['comandos'] as List?) ?? const [];

    return SucursalConfigResponseModel(
      sucursal: SucursalGestionModel.fromJson(Map<String, dynamic>.from(base)),
      devices: devicesRaw
          .whereType<Map>()
          .map(
            (e) => SucursalDeviceConfigModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      comandos: comandosRaw
          .whereType<Map>()
          .map(
            (e) => SucursalCommandHistoryModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

class SucursalDispositivoEstadoModel {
  final String deviceId;
  final bool connected;
  final int secondsSinceLastSeen;
  final int minutesSinceLastSeen;
  final DateTime? lastSeenUtc;
  final String timezone;

  const SucursalDispositivoEstadoModel({
    required this.deviceId,
    required this.connected,
    required this.secondsSinceLastSeen,
    required this.minutesSinceLastSeen,
    this.lastSeenUtc,
    required this.timezone,
  });

  factory SucursalDispositivoEstadoModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastSeen;
    final rawLastSeen = (json['lastSeenUtc'] as String?)?.trim();
    if (rawLastSeen != null && rawLastSeen.isNotEmpty) {
      lastSeen = DateTime.tryParse(rawLastSeen)?.toUtc();
    }

    return SucursalDispositivoEstadoModel(
      deviceId: (json['deviceId'] as String? ?? '').trim(),
      connected: json['connected'] == true || json['connected'] == 1,
      secondsSinceLastSeen:
          ((json['secondsSinceLastSeen'] as num?)?.toInt()) ??
          ((((json['minutesSinceLastSeen'] as num?)?.toInt()) ?? 0) * 60),
      minutesSinceLastSeen:
          ((json['minutesSinceLastSeen'] as num?)?.toInt()) ?? 0,
      lastSeenUtc: lastSeen,
      timezone: (json['timezone'] as String? ?? 'America/Mexico_City').trim(),
    );
  }
}

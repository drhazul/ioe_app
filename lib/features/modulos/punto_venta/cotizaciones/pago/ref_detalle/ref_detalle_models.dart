class RefDetallePageArgs {
  const RefDetallePageArgs({
    required this.idfol,
    required this.suc,
    required this.idc,
    required this.opv,
    required this.rfcEmisor,
    required this.tipo,
    required this.impt,
    required this.maxImpt,
    required this.rqfac,
    this.initialIdref,
  });

  final String idfol;
  final String suc;
  final int idc;
  final String opv;
  final String rfcEmisor;
  final String tipo;
  final double impt;
  final double maxImpt;
  final bool rqfac;
  final String? initialIdref;

  RefDetallePageArgs copyWith({
    String? idfol,
    String? suc,
    int? idc,
    String? opv,
    String? rfcEmisor,
    String? tipo,
    double? impt,
    double? maxImpt,
    bool? rqfac,
    String? initialIdref,
  }) {
    return RefDetallePageArgs(
      idfol: idfol ?? this.idfol,
      suc: suc ?? this.suc,
      idc: idc ?? this.idc,
      opv: opv ?? this.opv,
      rfcEmisor: rfcEmisor ?? this.rfcEmisor,
      tipo: tipo ?? this.tipo,
      impt: impt ?? this.impt,
      maxImpt: maxImpt ?? this.maxImpt,
      rqfac: rqfac ?? this.rqfac,
      initialIdref: initialIdref ?? this.initialIdref,
    );
  }

  Map<String, dynamic> toMap() => {
        'idfol': idfol,
        'suc': suc,
        'idc': idc,
        'opv': opv,
        'rfcEmisor': rfcEmisor,
        'tipo': tipo,
        'impt': impt,
        'maxImpt': maxImpt,
        'rqfac': rqfac,
        'initialIdref': initialIdref,
      };

  factory RefDetallePageArgs.fromMap(Map<String, dynamic> map) {
    return RefDetallePageArgs(
      idfol: map['idfol']?.toString() ?? '',
      suc: map['suc']?.toString() ?? '',
      idc: _asInt(map['idc']) ?? 0,
      opv: map['opv']?.toString() ?? '',
      rfcEmisor: map['rfcEmisor']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
      impt: _asDouble(map['impt']) ?? 0,
      maxImpt: _asDouble(map['maxImpt']) ?? 0,
      rqfac: map['rqfac'] == true,
      initialIdref: map['initialIdref']?.toString(),
    );
  }
}

class RefDetalleItem {
  const RefDetalleItem({
    required this.idref,
    required this.suc,
    required this.fcnr,
    required this.fcnd,
    required this.opv,
    required this.idfol,
    required this.idc,
    required this.rfcEmisor,
    required this.tipo,
    required this.impt,
    required this.estatus,
  });

  final String idref;
  final String? suc;
  final DateTime? fcnr;
  final DateTime? fcnd;
  final String? opv;
  final String? idfol;
  final int? idc;
  final String? rfcEmisor;
  final String? tipo;
  final double? impt;
  final String? estatus;

  factory RefDetalleItem.fromJson(Map<String, dynamic> json) {
    return RefDetalleItem(
      idref: json['IDREF']?.toString() ?? '',
      suc: json['SUC']?.toString(),
      fcnr: _asDate(json['FCNR']),
      fcnd: _asDate(json['FCND']),
      opv: json['OPV']?.toString(),
      idfol: json['IDFOL']?.toString(),
      idc: _asInt(json['IDC']),
      rfcEmisor: json['RfcEmisor']?.toString() ?? json['RFCEMISOR']?.toString(),
      tipo: json['TIPO']?.toString(),
      impt: _asDouble(json['IMPT']),
      estatus: json['ESTATUS']?.toString(),
    );
  }
}

class RefDetalleCrearResponse {
  const RefDetalleCrearResponse({
    required this.ok,
    required this.idref,
    required this.fcnd,
  });

  final bool ok;
  final String idref;
  final DateTime? fcnd;

  factory RefDetalleCrearResponse.fromJson(Map<String, dynamic> json) {
    return RefDetalleCrearResponse(
      ok: json['ok'] == true,
      idref: json['idref']?.toString() ?? '',
      fcnd: _asDate(json['fcnd']),
    );
  }
}

class RefDetalleAsignarResponse {
  const RefDetalleAsignarResponse({
    required this.ok,
    required this.idref,
  });

  final bool ok;
  final String idref;

  factory RefDetalleAsignarResponse.fromJson(Map<String, dynamic> json) {
    return RefDetalleAsignarResponse(
      ok: json['ok'] == true,
      idref: json['idref']?.toString() ?? '',
    );
  }
}

class RefDetalleSelectionResult {
  const RefDetalleSelectionResult({
    required this.idref,
    required this.impt,
  });

  final String idref;
  final double impt;
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

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

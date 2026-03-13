class CajaGeneralFiltros {
  const CajaGeneralFiltros({
    required this.suc,
    required this.fecha,
    required this.opv,
    required this.tipo,
  });

  final String suc;
  final DateTime fecha;
  final String opv;
  final String tipo;

  CajaGeneralFiltros copyWith({
    String? suc,
    DateTime? fecha,
    String? opv,
    String? tipo,
  }) {
    return CajaGeneralFiltros(
      suc: suc ?? this.suc,
      fecha: fecha ?? this.fecha,
      opv: opv ?? this.opv,
      tipo: tipo ?? this.tipo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CajaGeneralFiltros &&
        suc == other.suc &&
        fecha.year == other.fecha.year &&
        fecha.month == other.fecha.month &&
        fecha.day == other.fecha.day &&
        opv == other.opv &&
        tipo == other.tipo;
  }

  @override
  int get hashCode => Object.hash(
        suc,
        fecha.year,
        fecha.month,
        fecha.day,
        opv,
        tipo,
      );
}

class CajaGeneralValidation {
  CajaGeneralValidation({
    required this.ok,
    required this.status,
    required this.message,
    required this.pagadoCount,
    required this.totalTransacciones,
  });

  final bool ok;
  final String status;
  final String message;
  final int pagadoCount;
  final int totalTransacciones;

  factory CajaGeneralValidation.fromJson(Map<String, dynamic> json) {
    return CajaGeneralValidation(
      ok: _asBool(json['ok']) ?? false,
      status: (json['status'] ?? '').toString().trim(),
      message: (json['message'] ?? '').toString().trim(),
      pagadoCount: _asInt(json['pagadoCount']) ?? 0,
      totalTransacciones: _asInt(json['totalTransacciones']) ?? 0,
    );
  }
}

class CajaGeneralHeader {
  CajaGeneralHeader({
    required this.ide,
    required this.opv,
    required this.opvNombre,
    required this.fcn,
    required this.art,
    required this.trn,
    required this.dif,
    required this.esta,
    required this.suc,
  });

  final String ide;
  final String opv;
  final String? opvNombre;
  final String? fcn;
  final double art;
  final double trn;
  final double dif;
  final String esta;
  final String suc;

  factory CajaGeneralHeader.fromJson(Map<String, dynamic> json) {
    return CajaGeneralHeader(
      ide: (json['IDE'] ?? json['ide'] ?? '').toString().trim(),
      opv: (json['OPV'] ?? json['opv'] ?? '').toString().trim(),
      opvNombre: _nullIfEmpty(json['OPV_NOMBRE'] ?? json['opvNombre']),
      fcn: _nullIfEmpty(json['FCN'] ?? json['fcn']),
      art: _asDouble(json['ART'] ?? json['art']) ?? 0,
      trn: _asDouble(json['TRN'] ?? json['trn']) ?? 0,
      dif: _asDouble(json['DIF'] ?? json['dif']) ?? 0,
      esta: (json['ESTA'] ?? json['esta'] ?? '').toString().trim(),
      suc: (json['SUC'] ?? json['suc'] ?? '').toString().trim(),
    );
  }
}

class CajaGeneralFormaPago {
  CajaGeneralFormaPago({
    required this.form,
    required this.nom,
    required this.impt,
    required this.impr,
    required this.impe,
    required this.difd,
    required this.trecibido,
  });

  final String form;
  final String nom;
  final double impt;
  final double impr;
  final double impe;
  final double difd;
  final double trecibido;

  factory CajaGeneralFormaPago.fromJson(Map<String, dynamic> json) {
    return CajaGeneralFormaPago(
      form: (json['FORM'] ?? json['form'] ?? '').toString().trim(),
      nom: (json['NOM'] ?? json['nom'] ?? '').toString().trim(),
      impt: _asDouble(json['IMPT'] ?? json['impt']) ?? 0,
      impr: _asDouble(json['IMPR'] ?? json['impr']) ?? 0,
      impe: _asDouble(json['IMPE'] ?? json['impe']) ?? 0,
      difd: _asDouble(json['DIFD'] ?? json['difd']) ?? 0,
      trecibido: _asDouble(json['TRECIBIDO'] ?? json['trecibido']) ?? 0,
    );
  }
}

class CajaGeneralFormaDetalle {
  CajaGeneralFormaDetalle({
    required this.opv,
    required this.form,
    required this.idfol,
    required this.impt,
    required this.aut,
    required this.esta,
  });

  final String opv;
  final String form;
  final String idfol;
  final double impt;
  final String aut;
  final String esta;

  factory CajaGeneralFormaDetalle.fromJson(Map<String, dynamic> json) {
    return CajaGeneralFormaDetalle(
      opv: (json['OPV'] ?? json['opv'] ?? '').toString().trim(),
      form: (json['FORM'] ?? json['form'] ?? '').toString().trim(),
      idfol: (json['IDFOL'] ?? json['idfol'] ?? '').toString().trim(),
      impt: _asDouble(json['IMPT'] ?? json['impt']) ?? 0,
      aut: (json['AUT'] ?? json['aut'] ?? '').toString().trim(),
      esta: (json['ESTA'] ?? json['esta'] ?? '').toString().trim(),
    );
  }
}

class CajaGeneralTransaccion {
  CajaGeneralTransaccion({
    required this.aut,
    required this.desc,
    required this.cta,
    required this.total,
  });

  final String aut;
  final String desc;
  final double cta;
  final double total;

  factory CajaGeneralTransaccion.fromJson(Map<String, dynamic> json) {
    return CajaGeneralTransaccion(
      aut: (json['AUT'] ?? json['aut'] ?? '').toString().trim(),
      desc: (json['DESC'] ?? json['desc'] ?? '').toString().trim(),
      cta: _asDouble(json['CTA'] ?? json['cta']) ?? 0,
      total: _asDouble(json['TOTAL'] ?? json['total']) ?? 0,
    );
  }
}

class CajaGeneralVenta {
  CajaGeneralVenta({
    required this.ddepa,
    required this.dsubd,
    required this.vtapzs,
    required this.vtapsos,
  });

  final String ddepa;
  final String dsubd;
  final double vtapzs;
  final double vtapsos;

  factory CajaGeneralVenta.fromJson(Map<String, dynamic> json) {
    return CajaGeneralVenta(
      ddepa: (json['DDEPA'] ?? json['ddepa'] ?? '').toString().trim(),
      dsubd: (json['DSUBD'] ?? json['dsubd'] ?? '').toString().trim(),
      vtapzs: _asDouble(json['VTAPZS'] ?? json['vtapzs']) ?? 0,
      vtapsos: _asDouble(json['VTAPSOS'] ?? json['vtapsos']) ?? 0,
    );
  }
}

class CajaGeneralEfectivo {
  CajaGeneralEfectivo({
    required this.deno,
    required this.ctda,
    required this.total,
  });

  final double deno;
  final double ctda;
  final double total;

  factory CajaGeneralEfectivo.fromJson(Map<String, dynamic> json) {
    return CajaGeneralEfectivo(
      deno: _asDouble(json['DENO'] ?? json['deno']) ?? 0,
      ctda: _asDouble(json['CTDA'] ?? json['ctda']) ?? 0,
      total: _asDouble(
            json['TOTAL'] ??
                json['EFECTIVO'] ??
                json['total'] ??
                json['efectivo'],
          ) ??
          0,
    );
  }
}

class CajaGeneralPendiente {
  CajaGeneralPendiente({
    required this.opv,
    required this.opvNombre,
    required this.trn,
    required this.total,
    required this.estaEntrega,
    required this.ide,
  });

  final String opv;
  final String opvNombre;
  final double trn;
  final double total;
  final String estaEntrega;
  final String ide;

  factory CajaGeneralPendiente.fromJson(Map<String, dynamic> json) {
    return CajaGeneralPendiente(
      opv: (json['OPV'] ?? json['opv'] ?? '').toString().trim(),
      opvNombre:
          (json['OPV_NOMBRE'] ?? json['opvNombre'] ?? '').toString().trim(),
      trn: _asDouble(json['TRN'] ?? json['trn']) ?? 0,
      total: _asDouble(json['TOTAL'] ?? json['total']) ?? 0,
      estaEntrega: (json['ESTA_ENTREGA'] ?? json['estaEntrega'] ?? '')
          .toString()
          .trim(),
      ide: (json['IDE'] ?? json['ide'] ?? '').toString().trim(),
    );
  }
}

class CajaGeneralPendienteTransaccion {
  CajaGeneralPendienteTransaccion({
    required this.opv,
    required this.idfol,
    required this.aut,
    required this.autDesc,
    required this.esta,
    required this.total,
    required this.fcnm,
  });

  final String opv;
  final String idfol;
  final String aut;
  final String autDesc;
  final String esta;
  final double total;
  final String fcnm;

  factory CajaGeneralPendienteTransaccion.fromJson(Map<String, dynamic> json) {
    return CajaGeneralPendienteTransaccion(
      opv: (json['OPV'] ?? json['opv'] ?? '').toString().trim(),
      idfol: (json['IDFOL'] ?? json['idfol'] ?? '').toString().trim(),
      aut: (json['AUT'] ?? json['aut'] ?? '').toString().trim(),
      autDesc: (json['AUT_DESC'] ?? json['autDesc'] ?? '').toString().trim(),
      esta: (json['ESTA'] ?? json['esta'] ?? '').toString().trim(),
      total: _asDouble(json['TOTAL'] ?? json['total']) ?? 0,
      fcnm: (json['FCNM'] ?? json['fcnm'] ?? '').toString().trim(),
    );
  }
}

class CajaGeneralOpvResumen {
  CajaGeneralOpvResumen({
    required this.validation,
    required this.header,
    required this.formasPago,
    required this.transacciones,
    required this.ventas,
    required this.efectivo,
  });

  final CajaGeneralValidation? validation;
  final CajaGeneralHeader? header;
  final List<CajaGeneralFormaPago> formasPago;
  final List<CajaGeneralTransaccion> transacciones;
  final List<CajaGeneralVenta> ventas;
  final List<CajaGeneralEfectivo> efectivo;

  factory CajaGeneralOpvResumen.fromJson(Map<String, dynamic> json) {
    final validationMap = _toMap(json['validation']);
    final headerMap = _toMap(json['header']);
    return CajaGeneralOpvResumen(
      validation: validationMap == null
          ? null
          : CajaGeneralValidation.fromJson(validationMap),
      header: headerMap == null ? null : CajaGeneralHeader.fromJson(headerMap),
      formasPago: _toList(json['formasPago'])
          .map((e) => CajaGeneralFormaPago.fromJson(e))
          .toList(growable: false),
      transacciones: _toList(json['transacciones'])
          .map((e) => CajaGeneralTransaccion.fromJson(e))
          .toList(growable: false),
      ventas: _toList(json['ventas'])
          .map((e) => CajaGeneralVenta.fromJson(e))
          .toList(growable: false),
      efectivo: _toList(json['efectivo'])
          .map((e) => CajaGeneralEfectivo.fromJson(e))
          .toList(growable: false),
    );
  }
}

class CajaGeneralGlobalResumen {
  CajaGeneralGlobalResumen({
    required this.formasPago,
    required this.transacciones,
    required this.ventas,
    required this.efectivo,
    required this.pendientes,
    required this.hasPendingOpv,
  });

  final List<CajaGeneralFormaPago> formasPago;
  final List<CajaGeneralTransaccion> transacciones;
  final List<CajaGeneralVenta> ventas;
  final List<CajaGeneralEfectivo> efectivo;
  final List<CajaGeneralPendiente> pendientes;
  final bool hasPendingOpv;

  factory CajaGeneralGlobalResumen.fromJson(Map<String, dynamic> json) {
    return CajaGeneralGlobalResumen(
      formasPago: _toList(json['forms'])
          .map((e) => CajaGeneralFormaPago.fromJson(e))
          .toList(growable: false),
      transacciones: _toList(json['transacciones'])
          .map((e) => CajaGeneralTransaccion.fromJson(e))
          .toList(growable: false),
      ventas: _toList(json['ventas'])
          .map((e) => CajaGeneralVenta.fromJson(e))
          .toList(growable: false),
      efectivo: _toList(json['efectivo'])
          .map((e) => CajaGeneralEfectivo.fromJson(e))
          .toList(growable: false),
      pendientes: _toList(json['pendientes'])
          .map((e) => CajaGeneralPendiente.fromJson(e))
          .toList(growable: false),
      hasPendingOpv: _asBool(json['hasPendingOpv']) ?? false,
    );
  }
}

Map<String, dynamic>? _toMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _toList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value > 0;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}

String? _nullIfEmpty(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

class PsPanelQuery {
  const PsPanelQuery({
    this.suc = '',
    this.opv = '',
    this.search = '',
  });

  final String suc;
  final String opv;
  final String search;

  PsPanelQuery copyWith({
    String? suc,
    String? opv,
    String? search,
  }) {
    return PsPanelQuery(
      suc: suc ?? this.suc,
      opv: opv ?? this.opv,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PsPanelQuery &&
        other.suc == suc &&
        other.opv == opv &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(suc, opv, search);
}

class PsFolioItem {
  PsFolioItem({
    required this.idfol,
    this.suc,
    this.tra,
    this.opv,
    this.esta,
    this.aut,
    this.impt,
    this.clien,
    this.fcn,
    this.razonSocialReceptor,
    this.idfolinicial,
    this.origenAut,
  });

  final String idfol;
  final String? suc;
  final String? tra;
  final String? opv;
  final String? esta;
  final String? aut;
  final double? impt;
  final double? clien;
  final DateTime? fcn;
  final String? razonSocialReceptor;
  final String? idfolinicial;
  final String? origenAut;

  factory PsFolioItem.fromJson(Map<String, dynamic> json) {
    return PsFolioItem(
      idfol: json['IDFOL']?.toString() ?? '',
      suc: _asText(json['SUC']),
      tra: _asText(json['TRA']),
      opv: _asText(json['OPV']),
      esta: _asText(json['ESTA']),
      aut: _asText(json['AUT']),
      impt: _asDouble(json['IMPT']),
      clien: _asDouble(json['CLIEN']),
      fcn: _asDate(json['FCN']),
      razonSocialReceptor: _asText(json['RazonSocialReceptor']),
      idfolinicial: _asText(json['IDFOLINICIAL']),
      origenAut: _asText(json['ORIGEN_AUT']),
    );
  }
}

class PsDetalleHeader {
  PsDetalleHeader({
    required this.idfol,
    this.suc,
    this.ter,
    this.tra,
    this.opv,
    this.opvm,
    this.esta,
    this.aut,
    this.fpgo,
    this.impt,
    this.impp,
    this.reqf,
    this.clien,
    this.razonSocialReceptor,
    this.idfolinicial,
    this.origenAut,
  });

  final String idfol;
  final String? suc;
  final String? ter;
  final String? tra;
  final String? opv;
  final String? opvm;
  final String? esta;
  final String? aut;
  final String? fpgo;
  final double? impt;
  final double? impp;
  final int? reqf;
  final int? clien;
  final String? razonSocialReceptor;
  final String? idfolinicial;
  final String? origenAut;

  factory PsDetalleHeader.fromJson(Map<String, dynamic> json) {
    return PsDetalleHeader(
      idfol: json['IDFOL']?.toString() ?? '',
      suc: _asText(json['SUC']),
      ter: _asText(json['TER']),
      tra: _asText(json['TRA']),
      opv: _asText(json['OPV']),
      opvm: _asText(json['OPVM']),
      esta: _asText(json['ESTA']),
      aut: _asText(json['AUT']),
      fpgo: _asText(json['FPGO']),
      impt: _asDouble(json['IMPT']),
      impp: _asDouble(json['IMPP']),
      reqf: _asInt(json['REQF']),
      clien: _asInt(json['CLIEN']),
      razonSocialReceptor: _asText(json['RazonSocialReceptor']),
      idfolinicial: _asText(json['IDFOLINICIAL']),
      origenAut: _asText(json['ORIGEN_AUT']),
    );
  }
}

class PsTicketLine {
  PsTicketLine({
    this.id,
    this.idfol,
    this.art,
    this.upc,
    this.des,
    this.ord,
    this.ctd,
    this.pvta,
    this.pvtat,
    this.total,
  });

  final String? id;
  final String? idfol;
  final String? art;
  final String? upc;
  final String? des;
  final String? ord;
  final double? ctd;
  final double? pvta;
  final double? pvtat;
  final double? total;

  factory PsTicketLine.fromJson(Map<String, dynamic> json) {
    return PsTicketLine(
      id: _asText(json['ID']),
      idfol: _asText(json['IDFOL']),
      art: _asText(json['ART']),
      upc: _asText(json['UPC']),
      des: _asText(json['DES']),
      ord: _asText(json['ORD']),
      ctd: _asDouble(json['CTD']),
      pvta: _asDouble(json['PVTA']),
      pvtat: _asDouble(json['PVTAT']),
      total: _asDouble(json['TOTAL']),
    );
  }
}

class PsServicioItem {
  PsServicioItem({
    required this.ids,
    required this.dessv,
    required this.tipo,
  });

  final String ids;
  final String dessv;
  final String tipo;

  factory PsServicioItem.fromJson(Map<String, dynamic> json) {
    return PsServicioItem(
      ids: (json['IDS']?.toString() ?? '').trim().toUpperCase(),
      dessv: (json['DESSV']?.toString() ?? '').trim(),
      tipo: (json['TIPO']?.toString() ?? '').trim().toUpperCase(),
    );
  }
}

class PsRefGastoItem {
  PsRefGastoItem({
    required this.idr,
    required this.refgasto,
  });

  final int idr;
  final String refgasto;

  factory PsRefGastoItem.fromJson(Map<String, dynamic> json) {
    return PsRefGastoItem(
      idr: _asInt(json['IDR']) ?? 0,
      refgasto: (json['REFGASTO']?.toString() ?? '').trim(),
    );
  }
}

class PsClienteItem {
  PsClienteItem({
    required this.idc,
    required this.razonSocialReceptor,
    required this.rfcReceptor,
    this.suc,
  });

  final int idc;
  final String razonSocialReceptor;
  final String rfcReceptor;
  final String? suc;

  factory PsClienteItem.fromJson(Map<String, dynamic> json) {
    return PsClienteItem(
      idc: _asInt(json['IDC']) ?? 0,
      razonSocialReceptor:
          _asText(json['RazonSocialReceptor']) ??
          _asText(json['RAZONSOCIALRECEPTOR']) ??
          '-',
      rfcReceptor:
          _asText(json['RfcReceptor']) ??
          _asText(json['RFCRECEPTOR']) ??
          '-',
      suc: _asText(json['SUC']),
    );
  }
}

class PsDetalleResponse {
  PsDetalleResponse({
    required this.header,
    required this.ticket,
    required this.servicios,
    required this.referenciasGasto,
  });

  final PsDetalleHeader header;
  final List<PsTicketLine> ticket;
  final List<PsServicioItem> servicios;
  final List<PsRefGastoItem> referenciasGasto;

  factory PsDetalleResponse.fromJson(Map<String, dynamic> json) {
    final headerRaw = Map<String, dynamic>.from(
      (json['header'] as Map?) ?? const {},
    );
    final ticketRaw = (json['ticket'] as List?) ?? const [];
    final serviciosRaw = (json['servicios'] as List?) ?? const [];
    final refsRaw = (json['referenciasGasto'] as List?) ?? const [];

    return PsDetalleResponse(
      header: PsDetalleHeader.fromJson(headerRaw),
      ticket: ticketRaw
          .map(
            (item) => PsTicketLine.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      servicios: serviciosRaw
          .map(
            (item) => PsServicioItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      referenciasGasto: refsRaw
          .map(
            (item) => PsRefGastoItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class PsAdeudosResponse {
  PsAdeudosResponse({
    required this.client,
    required this.adeudosR,
    required this.adeudosRes,
  });

  final int client;
  final List<Map<String, dynamic>> adeudosR;
  final List<Map<String, dynamic>> adeudosRes;

  factory PsAdeudosResponse.fromJson(Map<String, dynamic> json) {
    final adeudosR = (json['adeudosR'] as List?) ?? const [];
    final adeudosRes = (json['adeudosRes'] as List?) ?? const [];
    return PsAdeudosResponse(
      client: _asInt(json['client']) ?? 0,
      adeudosR: adeudosR
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      adeudosRes: adeudosRes
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}

class PsFormaCatalogItem {
  PsFormaCatalogItem({
    required this.idform,
    required this.aspel,
    required this.form,
    required this.nom,
    required this.estado,
  });

  final int? idform;
  final int? aspel;
  final String form;
  final String nom;
  final bool estado;

  factory PsFormaCatalogItem.fromJson(Map<String, dynamic> json) {
    return PsFormaCatalogItem(
      idform: _asInt(json['idform']),
      aspel: _asInt(json['aspel']),
      form: (json['form']?.toString() ?? '').trim().toUpperCase(),
      nom: (json['nom']?.toString() ?? '').trim(),
      estado: json['estado'] == true || _asInt(json['estado']) == 1,
    );
  }
}

class PsFormaPagoItem {
  PsFormaPagoItem({
    required this.idf,
    required this.idfol,
    required this.form,
    required this.impp,
    this.aut,
    this.fcn,
  });

  final String idf;
  final String idfol;
  final String form;
  final double impp;
  final String? aut;
  final DateTime? fcn;

  factory PsFormaPagoItem.fromJson(Map<String, dynamic> json) {
    return PsFormaPagoItem(
      idf: (json['IDF']?.toString() ?? '').trim(),
      idfol: (json['IDFOL']?.toString() ?? '').trim(),
      form: (json['FORM']?.toString() ?? '').trim().toUpperCase(),
      impp: _asDouble(json['IMPP']) ?? 0,
      aut: _asText(json['AUT']),
      fcn: _asDate(json['FCN']),
    );
  }
}

class PsFormaPagoDraftItem {
  PsFormaPagoDraftItem({
    required this.localId,
    required this.form,
    required this.impp,
    this.aut,
  });

  final String localId;
  final String form;
  final double impp;
  final String? aut;

  Map<String, dynamic> toFinalizeJson() {
    final normalizedAut = (aut ?? '').trim();
    return {
      'form': form.trim().toUpperCase(),
      'impp': impp,
      if (normalizedAut.isNotEmpty) 'aut': normalizedAut,
    };
  }
}

class PsPagoSummary {
  PsPagoSummary({
    required this.idfol,
    required this.suc,
    required this.esta,
    required this.total,
    required this.pagado,
    required this.restante,
    required this.cambio,
    required this.ivaIntegrado,
    required this.formas,
  });

  final String idfol;
  final String suc;
  final String esta;
  final double total;
  final double pagado;
  final double restante;
  final double cambio;
  final int? ivaIntegrado;
  final List<PsFormaPagoItem> formas;

  factory PsPagoSummary.fromJson(Map<String, dynamic> json) {
    final formasRaw = (json['formas'] as List?) ?? const [];
    return PsPagoSummary(
      idfol: (json['idfol']?.toString() ?? '').trim(),
      suc: (json['suc']?.toString() ?? '').trim(),
      esta: (json['esta']?.toString() ?? '').trim().toUpperCase(),
      total: _asDouble(json['total']) ?? 0,
      pagado: _asDouble(json['pagado']) ?? 0,
      restante: _asDouble(json['restante']) ?? 0,
      cambio: _asDouble(json['cambio']) ?? 0,
      ivaIntegrado: _asInt(json['ivaIntegrado']),
      formas: formasRaw
          .map(
            (item) => PsFormaPagoItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  PsPagoSummary copyWith({
    String? idfol,
    String? suc,
    String? esta,
    double? total,
    double? pagado,
    double? restante,
    double? cambio,
    int? ivaIntegrado,
    List<PsFormaPagoItem>? formas,
  }) {
    return PsPagoSummary(
      idfol: idfol ?? this.idfol,
      suc: suc ?? this.suc,
      esta: esta ?? this.esta,
      total: total ?? this.total,
      pagado: pagado ?? this.pagado,
      restante: restante ?? this.restante,
      cambio: cambio ?? this.cambio,
      ivaIntegrado: ivaIntegrado ?? this.ivaIntegrado,
      formas: formas ?? this.formas,
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

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _asText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

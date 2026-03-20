class DevolucionesPanelQuery {
  const DevolucionesPanelQuery({
    this.suc = '',
    this.opv = '',
    this.search = '',
  });

  final String suc;
  final String opv;
  final String search;

  DevolucionesPanelQuery copyWith({
    String? suc,
    String? opv,
    String? search,
  }) {
    return DevolucionesPanelQuery(
      suc: suc ?? this.suc,
      opv: opv ?? this.opv,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DevolucionesPanelQuery &&
        other.suc == suc &&
        other.opv == opv &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(suc, opv, search);
}

class DevolucionPanelItem {
  DevolucionPanelItem({
    required this.idfol,
    this.idfolorig,
    this.suc,
    this.opv,
    this.opvm,
    this.tra,
    this.aut,
    this.esta,
    this.clien,
    this.impt,
    this.fcn,
    this.fcnm,
    this.razonSocialReceptor,
    this.idfolinicial,
    this.origenAut,
  });

  final String idfol;
  final String? idfolorig;
  final String? suc;
  final String? opv;
  final String? opvm;
  final String? tra;
  final String? aut;
  final String? esta;
  final double? clien;
  final double? impt;
  final DateTime? fcn;
  final DateTime? fcnm;
  final String? razonSocialReceptor;
  final String? idfolinicial;
  final String? origenAut;

  factory DevolucionPanelItem.fromJson(Map<String, dynamic> json) {
    return DevolucionPanelItem(
      idfol: json['IDFOL']?.toString() ?? '',
      idfolorig: _asText(json['IDFOLORIG']),
      suc: _asText(json['SUC']),
      opv: _asText(json['OPV']),
      opvm: _asText(json['OPVM']),
      tra: _asText(json['TRA']),
      aut: _asText(json['AUT']),
      esta: _asText(json['ESTA']),
      clien: _asDouble(json['CLIEN']),
      impt: _asDouble(json['IMPT']),
      fcn: _asDate(json['FCN']),
      fcnm: _asDate(json['FCNM']),
      razonSocialReceptor: _asText(json['RazonSocialReceptor']),
      idfolinicial: _asText(json['IDFOLINICIAL']),
      origenAut: _asText(json['ORIGEN_AUT']),
    );
  }
}

class DevolucionDetalleHeader {
  DevolucionDetalleHeader({
    required this.idfolDev,
    required this.idfolOrig,
    required this.suc,
    required this.autDev,
    required this.autOrig,
    required this.tipotran,
    required this.rqfacDefault,
    this.clien,
    this.estaDev,
    this.opv,
    this.opvm,
    this.idfolInicial,
    this.origenAut,
  });

  final String idfolDev;
  final String idfolOrig;
  final String suc;
  final String autDev;
  final String autOrig;
  final String tipotran;
  final bool rqfacDefault;
  final double? clien;
  final String? estaDev;
  final String? opv;
  final String? opvm;
  final String? idfolInicial;
  final String? origenAut;

  factory DevolucionDetalleHeader.fromJson(Map<String, dynamic> json) {
    return DevolucionDetalleHeader(
      idfolDev: json['idfolDev']?.toString() ?? '',
      idfolOrig: json['idfolOrig']?.toString() ?? '',
      suc: json['suc']?.toString() ?? '',
      autDev: json['autDev']?.toString() ?? '',
      autOrig: json['autOrig']?.toString() ?? '',
      tipotran: (json['tipotran']?.toString() ?? 'VF').toUpperCase(),
      rqfacDefault: json['rqfacDefault'] == true,
      clien: _asDouble(json['clien']),
      estaDev: _asText(json['estaDev']),
      opv: _asText(json['opv']),
      opvm: _asText(json['opvm']),
      idfolInicial: _asText(json['idfolInicial']),
      origenAut: _asText(json['origenAut']),
    );
  }
}

class DevolucionDetalleLine {
  DevolucionDetalleLine({
    required this.id,
    required this.idfolDev,
    required this.idfolOrig,
    required this.ctd,
    required this.pvta,
    required this.pvtat,
    required this.ctddf,
    required this.difd,
    required this.ordBloqueante,
    this.idlineOrig,
    this.art,
    this.upc,
    this.des,
    this.ord,
    this.ctdd,
  });

  final String id;
  final String idfolDev;
  final String idfolOrig;
  final String? idlineOrig;
  final String? art;
  final String? upc;
  final String? des;
  final double ctd;
  final double pvta;
  final double pvtat;
  final String? ord;
  final double ctddf;
  final double difd;
  final double? ctdd;
  final bool ordBloqueante;

  factory DevolucionDetalleLine.fromJson(Map<String, dynamic> json) {
    return DevolucionDetalleLine(
      id: json['id']?.toString() ?? '',
      idfolDev: json['idfolDev']?.toString() ?? '',
      idfolOrig: json['idfolOrig']?.toString() ?? '',
      idlineOrig: _asText(json['idlineOrig']),
      art: _asText(json['art']),
      upc: _asText(json['upc']),
      des: _asText(json['des']),
      ctd: _asDouble(json['ctd']) ?? 0,
      pvta: _asDouble(json['pvta']) ?? 0,
      pvtat: _asDouble(json['pvtat']) ?? 0,
      ord: _asText(json['ord']),
      ctddf: _asDouble(json['ctddf']) ?? 0,
      difd: _asDouble(json['difd']) ?? 0,
      ctdd: _asDouble(json['ctdd']),
      ordBloqueante: json['ordBloqueante'] == true,
    );
  }
}

class DevolucionDetalleSummary {
  DevolucionDetalleSummary({
    required this.lines,
    required this.linesSelected,
    required this.totalSeleccion,
    required this.totalDisponible,
  });

  final int lines;
  final int linesSelected;
  final double totalSeleccion;
  final double totalDisponible;

  factory DevolucionDetalleSummary.fromJson(Map<String, dynamic> json) {
    return DevolucionDetalleSummary(
      lines: _asInt(json['lines']) ?? 0,
      linesSelected: _asInt(json['linesSelected']) ?? 0,
      totalSeleccion: _asDouble(json['totalSeleccion']) ?? 0,
      totalDisponible: _asDouble(json['totalDisponible']) ?? 0,
    );
  }
}

class DevolucionDetalleResponse {
  DevolucionDetalleResponse({
    required this.ok,
    required this.ordBlockThreshold,
    required this.header,
    required this.lines,
    required this.summary,
  });

  final bool ok;
  final int ordBlockThreshold;
  final DevolucionDetalleHeader header;
  final List<DevolucionDetalleLine> lines;
  final DevolucionDetalleSummary summary;

  factory DevolucionDetalleResponse.fromJson(Map<String, dynamic> json) {
    final linesRaw = (json['lines'] as List?) ?? const [];
    return DevolucionDetalleResponse(
      ok: json['ok'] == true,
      ordBlockThreshold: _asInt(json['ordBlockThreshold']) ?? 5,
      header: DevolucionDetalleHeader.fromJson(
        Map<String, dynamic>.from((json['header'] as Map?) ?? const {}),
      ),
      lines: linesRaw
          .map(
            (item) => DevolucionDetalleLine.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      summary: DevolucionDetalleSummary.fromJson(
        Map<String, dynamic>.from((json['summary'] as Map?) ?? const {}),
      ),
    );
  }
}

class DevolucionDetallePreparadoItem {
  DevolucionDetallePreparadoItem({
    required this.id,
    required this.idfol,
    required this.ctd,
    required this.pvta,
    required this.pvtat,
    required this.importe,
    this.upc,
    this.art,
    this.des,
    this.ord,
    this.iddev,
    this.updatedAt,
  });

  final String id;
  final String idfol;
  final String? upc;
  final String? art;
  final String? des;
  final double ctd;
  final double pvta;
  final double pvtat;
  final double importe;
  final String? ord;
  final String? iddev;
  final DateTime? updatedAt;

  factory DevolucionDetallePreparadoItem.fromJson(Map<String, dynamic> json) {
    return DevolucionDetallePreparadoItem(
      id: json['id']?.toString() ?? '',
      idfol: json['idfol']?.toString() ?? '',
      upc: _asText(json['upc']),
      art: _asText(json['art']),
      des: _asText(json['des']),
      ctd: _asDouble(json['ctd']) ?? 0,
      pvta: _asDouble(json['pvta']) ?? 0,
      pvtat: _asDouble(json['pvtat']) ?? 0,
      importe: _asDouble(json['importe']) ?? 0,
      ord: _asText(json['ord']),
      iddev: _asText(json['iddev']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }
}

class DevolucionDetallePreparadoSummary {
  DevolucionDetallePreparadoSummary({
    required this.lines,
    required this.total,
  });

  final int lines;
  final double total;

  factory DevolucionDetallePreparadoSummary.fromJson(Map<String, dynamic> json) {
    return DevolucionDetallePreparadoSummary(
      lines: _asInt(json['lines']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
    );
  }
}

class DevolucionDetallePreparadoResponse {
  DevolucionDetallePreparadoResponse({
    required this.ok,
    required this.ordBlockThreshold,
    required this.context,
    required this.items,
    required this.summary,
  });

  final bool ok;
  final int ordBlockThreshold;
  final DevolucionDetalleHeader context;
  final List<DevolucionDetallePreparadoItem> items;
  final DevolucionDetallePreparadoSummary summary;

  factory DevolucionDetallePreparadoResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final itemsRaw = (json['items'] as List?) ?? const [];
    return DevolucionDetallePreparadoResponse(
      ok: json['ok'] == true,
      ordBlockThreshold: _asInt(json['ordBlockThreshold']) ?? 5,
      context: DevolucionDetalleHeader.fromJson(
        Map<String, dynamic>.from((json['context'] as Map?) ?? const {}),
      ),
      items: itemsRaw
          .map(
            (item) => DevolucionDetallePreparadoItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      summary: DevolucionDetallePreparadoSummary.fromJson(
        Map<String, dynamic>.from((json['summary'] as Map?) ?? const {}),
      ),
    );
  }
}

class DevolucionPagoTotales {
  DevolucionPagoTotales({
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.totalBase,
    required this.rqfac,
    required this.tipotran,
    this.ivaIntegrado,
  });

  final double subtotal;
  final double iva;
  final double total;
  final double totalBase;
  final bool rqfac;
  final String tipotran;
  final int? ivaIntegrado;

  factory DevolucionPagoTotales.fromJson(Map<String, dynamic> json) {
    return DevolucionPagoTotales(
      subtotal: _asDouble(json['subtotal']) ?? 0,
      iva: _asDouble(json['iva']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
      totalBase: _asDouble(json['totalBase']) ?? 0,
      rqfac: json['rqfac'] == true,
      tipotran: (json['tipotran']?.toString() ?? 'VF').toUpperCase(),
      ivaIntegrado: _asInt(json['ivaIntegrado']),
    );
  }
}

class DevolucionFormaDraft {
  DevolucionFormaDraft({
    required this.id,
    required this.form,
    required this.impp,
    this.aut,
  });

  final String id;
  final String form;
  final double impp;
  final String? aut;

  DevolucionFormaDraft copyWith({
    String? id,
    String? form,
    double? impp,
    String? aut,
  }) {
    return DevolucionFormaDraft(
      id: id ?? this.id,
      form: form ?? this.form,
      impp: impp ?? this.impp,
      aut: aut ?? this.aut,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'form': form,
      'impp': impp,
      if ((aut ?? '').trim().isNotEmpty) 'aut': aut!.trim(),
    };
  }

  factory DevolucionFormaDraft.fromJson(Map<String, dynamic> json) {
    return DevolucionFormaDraft(
      id: _asText(json['id']) ?? _asText(json['form']) ?? '',
      form: (_asText(json['form']) ?? '').toUpperCase(),
      impp: _asDouble(json['impp']) ?? 0,
      aut: _asText(json['aut']),
    );
  }
}

class DevolucionPagoPreviewResponse {
  DevolucionPagoPreviewResponse({
    required this.ok,
    required this.context,
    required this.totals,
    required this.formasSugeridas,
    required this.linesSelected,
  });

  final bool ok;
  final DevolucionDetalleHeader context;
  final DevolucionPagoTotales totals;
  final List<DevolucionFormaDraft> formasSugeridas;
  final int linesSelected;

  factory DevolucionPagoPreviewResponse.fromJson(Map<String, dynamic> json) {
    final formasRaw = (json['formasSugeridas'] as List?) ?? const [];
    return DevolucionPagoPreviewResponse(
      ok: json['ok'] == true,
      context: DevolucionDetalleHeader.fromJson(
        Map<String, dynamic>.from((json['context'] as Map?) ?? const {}),
      ),
      totals: DevolucionPagoTotales.fromJson(
        Map<String, dynamic>.from((json['totals'] as Map?) ?? const {}),
      ),
      formasSugeridas: formasRaw
          .map(
            (item) => DevolucionFormaDraft.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      linesSelected: _asInt(json['linesSelected']) ?? 0,
    );
  }
}

class DevolucionPagoFinalizarResponse {
  DevolucionPagoFinalizarResponse({
    required this.ok,
    required this.idfolDev,
    required this.total,
    required this.cambio,
    required this.status,
    required this.aut,
    required this.totals,
    this.facturacionSync,
  });

  final bool ok;
  final String idfolDev;
  final double total;
  final double cambio;
  final String status;
  final String aut;
  final DevolucionPagoTotales totals;
  final DevolucionFacturacionSync? facturacionSync;

  factory DevolucionPagoFinalizarResponse.fromJson(Map<String, dynamic> json) {
    return DevolucionPagoFinalizarResponse(
      ok: json['ok'] == true,
      idfolDev: json['idfolDev']?.toString() ?? '',
      total: _asDouble(json['total']) ?? 0,
      cambio: _asDouble(json['cambio']) ?? 0,
      status: _asText(json['status']) ?? '',
      aut: _asText(json['aut']) ?? '',
      totals: DevolucionPagoTotales.fromJson(
        Map<String, dynamic>.from((json['totals'] as Map?) ?? const {}),
      ),
      facturacionSync: (json['facturacionSync'] is Map)
          ? DevolucionFacturacionSync.fromJson(
              Map<String, dynamic>.from(json['facturacionSync'] as Map),
            )
          : null,
    );
  }
}

class DevolucionFacturacionSync {
  DevolucionFacturacionSync({
    required this.idfol,
    required this.syncApplied,
    this.estatus,
    this.impt,
    this.detailRows,
    this.evento,
  });

  final String idfol;
  final bool syncApplied;
  final String? estatus;
  final double? impt;
  final int? detailRows;
  final String? evento;

  factory DevolucionFacturacionSync.fromJson(Map<String, dynamic> json) {
    return DevolucionFacturacionSync(
      idfol:
          _asText(json['idfol']) ?? _asText(json['IDFOL']) ?? _asText(json['idFol']) ?? '',
      syncApplied: json['syncApplied'] == true ||
          json['SYNC_APPLIED'] == 1 ||
          json['SYNC_APPLIED'] == true,
      estatus: _asText(json['estatus']) ?? _asText(json['ESTATUS']),
      impt: _asDouble(json['impt']) ?? _asDouble(json['IMPT']),
      detailRows: _asInt(json['detailRows']) ?? _asInt(json['DETAIL_ROWS']),
      evento: _asText(json['evento']) ?? _asText(json['EVENTO']),
    );
  }
}

class DevolucionPrintPreviewResponse {
  DevolucionPrintPreviewResponse({
    required this.ok,
    required this.idfolDev,
    required this.idfolOrig,
    required this.header,
    required this.items,
    required this.totals,
    required this.formas,
    required this.footer,
  });

  final bool ok;
  final String idfolDev;
  final String idfolOrig;
  final DevolucionPrintHeader header;
  final List<DevolucionPrintItem> items;
  final DevolucionPrintTotals totals;
  final List<DevolucionPrintForma> formas;
  final DevolucionPrintFooter footer;

  factory DevolucionPrintPreviewResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json['items'] as List?) ?? const [];
    final formasRaw = (json['formas'] as List?) ?? const [];
    return DevolucionPrintPreviewResponse(
      ok: json['ok'] == true,
      idfolDev: (json['idfolDev']?.toString() ?? '').trim(),
      idfolOrig: (json['idfolOrig']?.toString() ?? '').trim(),
      header: DevolucionPrintHeader.fromJson(
        Map<String, dynamic>.from((json['header'] as Map?) ?? const {}),
      ),
      items: itemsRaw
          .map(
            (item) => DevolucionPrintItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      totals: DevolucionPrintTotals.fromJson(
        Map<String, dynamic>.from((json['totals'] as Map?) ?? const {}),
      ),
      formas: formasRaw
          .map(
            (item) => DevolucionPrintForma.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      footer: DevolucionPrintFooter.fromJson(
        Map<String, dynamic>.from((json['footer'] as Map?) ?? const {}),
      ),
    );
  }
}

class DevolucionPrintHeader {
  DevolucionPrintHeader({
    required this.suc,
    required this.desc,
    required this.encar,
    required this.zona,
    required this.rfc,
    required this.direccion,
    required this.contacto,
  });

  final String suc;
  final String? desc;
  final String? encar;
  final String? zona;
  final String? rfc;
  final String? direccion;
  final String? contacto;

  factory DevolucionPrintHeader.fromJson(Map<String, dynamic> json) {
    return DevolucionPrintHeader(
      suc: (json['suc']?.toString() ?? '').trim(),
      desc: _asText(json['desc']),
      encar: _asText(json['encar']),
      zona: _asText(json['zona']),
      rfc: _asText(json['rfc']),
      direccion: _asText(json['direccion']),
      contacto: _asText(json['contacto']),
    );
  }
}

class DevolucionPrintItem {
  DevolucionPrintItem({
    required this.id,
    required this.art,
    required this.upc,
    required this.des,
    required this.ctd,
    required this.pvta,
    required this.importe,
    required this.ord,
    required this.iddev,
  });

  final String id;
  final String? art;
  final String? upc;
  final String? des;
  final double ctd;
  final double pvta;
  final double importe;
  final String? ord;
  final String? iddev;

  factory DevolucionPrintItem.fromJson(Map<String, dynamic> json) {
    return DevolucionPrintItem(
      id: (json['id']?.toString() ?? '').trim(),
      art: _asText(json['art']),
      upc: _asText(json['upc']),
      des: _asText(json['des']),
      ctd: _asDouble(json['ctd']) ?? 0,
      pvta: _asDouble(json['pvta']) ?? 0,
      importe: _asDouble(json['importe']) ?? 0,
      ord: _asText(json['ord']),
      iddev: _asText(json['iddev']),
    );
  }
}

class DevolucionPrintTotals {
  DevolucionPrintTotals({
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.totalBase,
    required this.ivaIntegrado,
    required this.tipotran,
    required this.rqfac,
    required this.sumPagos,
    required this.cambio,
  });

  final double subtotal;
  final double iva;
  final double total;
  final double totalBase;
  final int? ivaIntegrado;
  final String tipotran;
  final bool rqfac;
  final double sumPagos;
  final double cambio;

  double get faltante {
    final value = total - sumPagos;
    return value > 0 ? value : 0;
  }

  factory DevolucionPrintTotals.fromJson(Map<String, dynamic> json) {
    return DevolucionPrintTotals(
      subtotal: _asDouble(json['subtotal']) ?? 0,
      iva: _asDouble(json['iva']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
      totalBase: _asDouble(json['totalBase']) ?? 0,
      ivaIntegrado: _asInt(json['ivaIntegrado']),
      tipotran: (json['tipotran']?.toString() ?? 'VF').toUpperCase(),
      rqfac: json['rqfac'] == true,
      sumPagos: _asDouble(json['sumPagos']) ?? 0,
      cambio: _asDouble(json['cambio']) ?? 0,
    );
  }
}

class DevolucionPrintForma {
  DevolucionPrintForma({
    required this.idf,
    required this.form,
    required this.impp,
    required this.aut,
    required this.fcn,
  });

  final String idf;
  final String form;
  final double impp;
  final String? aut;
  final DateTime? fcn;

  factory DevolucionPrintForma.fromJson(Map<String, dynamic> json) {
    return DevolucionPrintForma(
      idf: (json['idf']?.toString() ?? '').trim(),
      form: (json['form']?.toString() ?? '').trim().toUpperCase(),
      impp: _asDouble(json['impp']) ?? 0,
      aut: _asText(json['aut']),
      fcn: _asDate(json['fcn']),
    );
  }
}

class DevolucionPrintFooter {
  DevolucionPrintFooter({
    required this.opv,
    required this.opvNombre,
    required this.idfolDev,
    required this.idfolOrig,
    required this.clienteId,
    required this.clienteNombre,
    required this.aut,
    required this.esta,
  });

  final String? opv;
  final String? opvNombre;
  final String idfolDev;
  final String idfolOrig;
  final double? clienteId;
  final String? clienteNombre;
  final String? aut;
  final String? esta;

  factory DevolucionPrintFooter.fromJson(Map<String, dynamic> json) {
    return DevolucionPrintFooter(
      opv: _asText(json['opv']),
      opvNombre: _asText(json['opvNombre']),
      idfolDev: (json['idfolDev']?.toString() ?? '').trim(),
      idfolOrig: (json['idfolOrig']?.toString() ?? '').trim(),
      clienteId: _asDouble(json['clienteId']),
      clienteNombre: _asText(json['clienteNombre']),
      aut: _asText(json['aut']),
      esta: _asText(json['esta']),
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


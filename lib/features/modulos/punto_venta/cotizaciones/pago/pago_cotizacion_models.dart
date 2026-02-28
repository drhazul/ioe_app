class PagoCierreContext {
  PagoCierreContext({
    required this.idfol,
    required this.suc,
    required this.clien,
    required this.esta,
    required this.rqfacDefault,
    required this.ivaIntegrado,
    required this.itemsCount,
    required this.totalBase,
  });

  final String idfol;
  final String suc;
  final int? clien;
  final String? esta;
  final bool rqfacDefault;
  final int? ivaIntegrado;
  final int itemsCount;
  final double totalBase;

  factory PagoCierreContext.fromJson(Map<String, dynamic> json) {
    return PagoCierreContext(
      idfol: json['idfol']?.toString() ?? '',
      suc: json['suc']?.toString() ?? '',
      clien: _asInt(json['clien']),
      esta: json['esta']?.toString(),
      rqfacDefault: json['rqfacDefault'] == true,
      ivaIntegrado: _asInt(json['ivaIntegrado']),
      itemsCount: _asInt(json['itemsCount']) ?? 0,
      totalBase: _asDouble(json['totalBase']) ?? 0,
    );
  }
}

class PagoCierreTotales {
  PagoCierreTotales({
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.totalBase,
    required this.ivaIntegrado,
    required this.tipotran,
    required this.rqfac,
  });

  final double subtotal;
  final double iva;
  final double total;
  final double totalBase;
  final int? ivaIntegrado;
  final String tipotran;
  final bool rqfac;

  factory PagoCierreTotales.fromJson(Map<String, dynamic> json) {
    return PagoCierreTotales(
      subtotal: _asDouble(json['subtotal']) ?? 0,
      iva: _asDouble(json['iva']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
      totalBase: _asDouble(json['totalBase']) ?? 0,
      ivaIntegrado: _asInt(json['ivaIntegrado']),
      tipotran: json['tipotran']?.toString().toUpperCase() ?? 'VF',
      rqfac: json['rqfac'] == true,
    );
  }
}

class PagoCierrePreviewResponse {
  PagoCierrePreviewResponse({
    required this.ok,
    required this.context,
    required this.totales,
  });

  final bool ok;
  final PagoCierreContext context;
  final PagoCierreTotales totales;

  factory PagoCierrePreviewResponse.fromJson(Map<String, dynamic> json) {
    return PagoCierrePreviewResponse(
      ok: json['ok'] == true,
      context: PagoCierreContext.fromJson(
        Map<String, dynamic>.from(json['context'] as Map),
      ),
      totales: PagoCierreTotales.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map),
      ),
    );
  }
}

class PagoCierreFormaDraft {
  PagoCierreFormaDraft({
    required this.id,
    required this.form,
    required this.impp,
    this.aut,
  });

  final String id;
  final String form;
  final double impp;
  final String? aut;

  PagoCierreFormaDraft copyWith({
    String? id,
    String? form,
    double? impp,
    String? aut,
  }) {
    return PagoCierreFormaDraft(
      id: id ?? this.id,
      form: form ?? this.form,
      impp: impp ?? this.impp,
      aut: aut ?? this.aut,
    );
  }

  Map<String, dynamic> toApiJson() => {
    'form': form,
    'impp': impp,
    if (aut != null && aut!.trim().isNotEmpty) 'aut': aut!.trim(),
  };
}

class PagoCierreResponse {
  PagoCierreResponse({
    required this.ok,
    required this.idfol,
    required this.tipotran,
    required this.rqfac,
    required this.totales,
    required this.sumPagos,
    required this.cambio,
  });

  final bool ok;
  final String idfol;
  final String tipotran;
  final bool rqfac;
  final PagoCierreTotales totales;
  final double sumPagos;
  final double cambio;

  factory PagoCierreResponse.fromJson(Map<String, dynamic> json) {
    return PagoCierreResponse(
      ok: json['ok'] == true,
      idfol: json['idfol']?.toString() ?? '',
      tipotran: json['tipotran']?.toString().toUpperCase() ?? 'VF',
      rqfac: json['rqfac'] == true,
      totales: PagoCierreTotales.fromJson(
        Map<String, dynamic>.from(json['totales'] as Map),
      ),
      sumPagos: _asDouble(json['sumPagos']) ?? 0,
      cambio: _asDouble(json['cambio']) ?? 0,
    );
  }
}

class PagoFormaCatalogItem {
  PagoFormaCatalogItem({
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

  factory PagoFormaCatalogItem.fromJson(Map<String, dynamic> json) {
    return PagoFormaCatalogItem(
      idform: _asInt(json['idform']),
      aspel: _asInt(json['aspel']),
      form: (json['form']?.toString() ?? '').trim().toUpperCase(),
      nom: (json['nom']?.toString() ?? '').trim(),
      estado: json['estado'] == true || _asInt(json['estado']) == 1,
    );
  }
}

class PagoCierrePrintPreviewResponse {
  PagoCierrePrintPreviewResponse({
    required this.ok,
    required this.idfol,
    required this.header,
    required this.items,
    required this.totals,
    required this.formas,
    required this.footer,
    required this.ords,
  });

  final bool ok;
  final String idfol;
  final PagoCierrePrintHeader header;
  final List<PagoCierrePrintItem> items;
  final PagoCierrePrintTotals totals;
  final List<PagoCierrePrintForma> formas;
  final PagoCierrePrintFooter footer;
  final List<PagoCierrePrintOrd> ords;

  factory PagoCierrePrintPreviewResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json['items'] as List?) ?? const [];
    final formasRaw = (json['formas'] as List?) ?? const [];
    final ordsRaw = (json['ords'] as List?) ?? const [];
    return PagoCierrePrintPreviewResponse(
      ok: json['ok'] == true,
      idfol: (json['idfol']?.toString() ?? '').trim(),
      header: PagoCierrePrintHeader.fromJson(
        Map<String, dynamic>.from((json['header'] as Map?) ?? const {}),
      ),
      items: itemsRaw
          .map(
            (e) => PagoCierrePrintItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      totals: PagoCierrePrintTotals.fromJson(
        Map<String, dynamic>.from((json['totals'] as Map?) ?? const {}),
      ),
      formas: formasRaw
          .map(
            (e) => PagoCierrePrintForma.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      footer: PagoCierrePrintFooter.fromJson(
        Map<String, dynamic>.from((json['footer'] as Map?) ?? const {}),
      ),
      ords: ordsRaw
          .map(
            (e) => PagoCierrePrintOrd.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class PagoCierrePrintHeader {
  PagoCierrePrintHeader({
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

  factory PagoCierrePrintHeader.fromJson(Map<String, dynamic> json) {
    return PagoCierrePrintHeader(
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

class PagoCierrePrintItem {
  PagoCierrePrintItem({
    required this.id,
    required this.art,
    required this.upc,
    required this.des,
    required this.ctd,
    required this.pvta,
    required this.importe,
    required this.ord,
  });

  final String id;
  final String? art;
  final String? upc;
  final String? des;
  final double ctd;
  final double pvta;
  final double importe;
  final String? ord;

  factory PagoCierrePrintItem.fromJson(Map<String, dynamic> json) {
    return PagoCierrePrintItem(
      id: (json['id']?.toString() ?? '').trim(),
      art: _asText(json['art']),
      upc: _asText(json['upc']),
      des: _asText(json['des']),
      ctd: _asDouble(json['ctd']) ?? 0,
      pvta: _asDouble(json['pvta']) ?? 0,
      importe: _asDouble(json['importe']) ?? 0,
      ord: _asText(json['ord']),
    );
  }
}

class PagoCierrePrintTotals {
  PagoCierrePrintTotals({
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.totalBase,
    required this.ivaIntegrado,
    required this.tipotran,
    required this.rqfac,
    required this.sumPagos,
    required this.faltante,
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
  final double faltante;
  final double cambio;

  factory PagoCierrePrintTotals.fromJson(Map<String, dynamic> json) {
    return PagoCierrePrintTotals(
      subtotal: _asDouble(json['subtotal']) ?? 0,
      iva: _asDouble(json['iva']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
      totalBase: _asDouble(json['totalBase']) ?? 0,
      ivaIntegrado: _asInt(json['ivaIntegrado']),
      tipotran: (json['tipotran']?.toString() ?? 'VF').toUpperCase(),
      rqfac: json['rqfac'] == true,
      sumPagos: _asDouble(json['sumPagos']) ?? 0,
      faltante: _asDouble(json['faltante']) ?? 0,
      cambio: _asDouble(json['cambio']) ?? 0,
    );
  }
}

class PagoCierrePrintForma {
  PagoCierrePrintForma({
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

  factory PagoCierrePrintForma.fromJson(Map<String, dynamic> json) {
    return PagoCierrePrintForma(
      idf: (json['idf']?.toString() ?? '').trim(),
      form: (json['form']?.toString() ?? '').trim().toUpperCase(),
      impp: _asDouble(json['impp']) ?? 0,
      aut: _asText(json['aut']),
      fcn: _asDate(json['fcn']),
    );
  }
}

class PagoCierrePrintFooter {
  PagoCierrePrintFooter({
    required this.opv,
    required this.opvNombre,
    required this.idfol,
    required this.fcnm,
    required this.clienteId,
    required this.clienteNombre,
  });

  final String? opv;
  final String? opvNombre;
  final String idfol;
  final DateTime? fcnm;
  final int? clienteId;
  final String? clienteNombre;

  factory PagoCierrePrintFooter.fromJson(Map<String, dynamic> json) {
    return PagoCierrePrintFooter(
      opv: _asText(json['opv']),
      opvNombre: _asText(json['opvNombre']),
      idfol: (json['idfol']?.toString() ?? '').trim(),
      fcnm: _asDate(json['fcnm']),
      clienteId: _asInt(json['clienteId']),
      clienteNombre: _asText(json['clienteNombre']),
    );
  }
}

class PagoCierrePrintOrd {
  PagoCierrePrintOrd({
    required this.iord,
    required this.tipo,
    required this.opv,
    required this.fcns,
    required this.fcnm,
    required this.estatus,
    required this.ncliente,
    required this.art,
    required this.desc,
    required this.ctd,
    required this.comad,
    required this.details,
  });

  final String iord;
  final String? tipo;
  final String? opv;
  final DateTime? fcns;
  final DateTime? fcnm;
  final int? estatus;
  final String? ncliente;
  final String? art;
  final String? desc;
  final double? ctd;
  final String? comad;
  final List<PagoCierrePrintOrdDetail> details;

  factory PagoCierrePrintOrd.fromJson(Map<String, dynamic> json) {
    final detailsRaw = (json['details'] as List?) ?? const [];
    return PagoCierrePrintOrd(
      iord: (json['iord']?.toString() ?? '').trim(),
      tipo: _asText(json['tipo']),
      opv: _asText(json['opv']),
      fcns: _asDate(json['fcns']),
      fcnm: _asDate(json['fcnm']),
      estatus: _asInt(json['estatus']),
      ncliente: _asText(json['ncliente']),
      art: _asText(json['art']),
      desc: _asText(json['desc']),
      ctd: _asDouble(json['ctd']),
      comad: _asText(json['comad']),
      details: detailsRaw
          .map(
            (e) => PagoCierrePrintOrdDetail.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class PagoCierrePrintOrdDetail {
  PagoCierrePrintOrdDetail({
    required this.iordp,
    required this.art,
    required this.job,
    required this.esf,
    required this.cil,
    required this.eje,
  });

  final String iordp;
  final String? art;
  final String? job;
  final String? esf;
  final String? cil;
  final String? eje;

  factory PagoCierrePrintOrdDetail.fromJson(Map<String, dynamic> json) {
    return PagoCierrePrintOrdDetail(
      iordp: (json['iordp']?.toString() ?? '').trim(),
      art: _asText(json['art']),
      job: _asText(json['job']),
      esf: _asText(json['esf']),
      cil: _asText(json['cil']),
      eje: _asText(json['eje']),
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
  final text = (value?.toString() ?? '').trim();
  return text.isEmpty ? null : text;
}

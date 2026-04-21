enum OrdenesTrabajoPanelMode {
  operativo('operativo'),
  anulados('anulados'),
  entregadas('entregadas');

  const OrdenesTrabajoPanelMode(this.apiValue);
  final String apiValue;

  static OrdenesTrabajoPanelMode fromApi(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw == anulados.apiValue) return anulados;
    if (raw == entregadas.apiValue) return entregadas;
    return operativo;
  }
}

enum OrdenesTrabajoInitialAction {
  enviar('enviar'),
  asignar('asignar'),
  regresarTienda('regresar-tienda'),
  recibir('recibir'),
  entregar('entregar');

  const OrdenesTrabajoInitialAction(this.routeSegment);

  final String routeSegment;
}

class OrdenesTrabajoFilter {
  const OrdenesTrabajoFilter({
    this.iord,
    this.idfol,
    this.client,
    this.art,
    this.tipo,
    this.labor,
    this.estatus,
    this.estsegu,
    this.fecIni,
    this.fecFin,
    this.asign,
    this.tipom,
    this.motr,
    this.suc,
    this.search,
    this.panelMode = OrdenesTrabajoPanelMode.operativo,
    this.page = 1,
    this.pageSize = 25,
  });

  final String? iord;
  final String? idfol;
  final String? client;
  final String? art;
  final String? tipo;
  final String? labor;
  final String? estatus;
  final String? estsegu;
  final DateTime? fecIni;
  final DateTime? fecFin;
  final String? asign;
  final String? tipom;
  final String? motr;
  final String? suc;
  final String? search;
  final OrdenesTrabajoPanelMode panelMode;
  final int page;
  final int pageSize;

  OrdenesTrabajoFilter copyWith({
    String? iord,
    String? idfol,
    String? client,
    String? art,
    String? tipo,
    String? labor,
    String? estatus,
    String? estsegu,
    DateTime? fecIni,
    DateTime? fecFin,
    bool clearFecIni = false,
    bool clearFecFin = false,
    String? asign,
    String? tipom,
    String? motr,
    String? suc,
    String? search,
    OrdenesTrabajoPanelMode? panelMode,
    int? page,
    int? pageSize,
  }) {
    return OrdenesTrabajoFilter(
      iord: iord ?? this.iord,
      idfol: idfol ?? this.idfol,
      client: client ?? this.client,
      art: art ?? this.art,
      tipo: tipo ?? this.tipo,
      labor: labor ?? this.labor,
      estatus: estatus ?? this.estatus,
      estsegu: estsegu ?? this.estsegu,
      fecIni: clearFecIni ? null : (fecIni ?? this.fecIni),
      fecFin: clearFecFin ? null : (fecFin ?? this.fecFin),
      asign: asign ?? this.asign,
      tipom: tipom ?? this.tipom,
      motr: motr ?? this.motr,
      suc: suc ?? this.suc,
      search: search ?? this.search,
      panelMode: panelMode ?? this.panelMode,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  static String? _normalize(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toQuery() {
    final iordValue = _normalize(iord);
    final idfolValue = _normalize(idfol);
    final clientValue = _normalize(client);
    final artValue = _normalize(art);
    final tipoValue = _normalize(tipo);
    final laborValue = _normalize(labor);
    final estatusValue = _normalize(estatus);
    final estseguValue = _normalize(estsegu);
    final fecIniValue = fecIni;
    final fecFinValue = fecFin;
    final asignValue = _normalize(asign);
    final tipomValue = _normalize(tipom);
    final motrValue = _normalize(motr);
    final sucValue = _normalize(suc);
    final searchValue = _normalize(search);

    return {
      if (iordValue != null) 'iord': iordValue,
      if (idfolValue != null) 'idfol': idfolValue,
      if (clientValue != null) 'client': clientValue,
      if (artValue != null) 'art': artValue,
      if (tipoValue != null) 'tipo': tipoValue,
      if (laborValue != null) 'labor': laborValue,
      if (estatusValue != null) 'estatus': estatusValue,
      if (estseguValue != null) 'estsegu': estseguValue,
      if (fecIniValue != null) 'fecIni': _formatDate(fecIniValue),
      if (fecFinValue != null) 'fecFin': _formatDate(fecFinValue),
      if (asignValue != null) 'asign': asignValue,
      if (tipomValue != null) 'tipom': tipomValue,
      if (motrValue != null) 'motr': motrValue,
      if (sucValue != null) 'suc': sucValue,
      if (searchValue != null) 'search': searchValue,
      'panelMode': panelMode.apiValue,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class OrdenTrabajoPanelResponse {
  OrdenTrabajoPanelResponse({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.roleCode,
    required this.panelMode,
    required this.allowedSucs,
    required this.allowedActions,
    required this.flowStatusOptions,
    required this.incidenciaOptions,
    required this.laboratorios,
    required this.items,
  });

  final int page;
  final int pageSize;
  final int total;
  final String roleCode;
  final OrdenesTrabajoPanelMode panelMode;
  final List<String> allowedSucs;
  final Set<String> allowedActions;
  final List<OrdenTrabajoFlowStatusOption> flowStatusOptions;
  final List<OrdenTrabajoIncidenciaOption> incidenciaOptions;
  final List<OrdenTrabajoLaboratorioOption> laboratorios;
  final List<OrdenTrabajoItem> items;

  factory OrdenTrabajoPanelResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final rawAllowedSucs = (json['allowedSucs'] as List?) ?? const [];
    final rawActions = (json['allowedActions'] as List?) ?? const [];
    final rawFlowStatus = (json['flowStatusOptions'] as List?) ?? const [];
    final rawIncidenciaOptions =
        (json['incidenciaOptions'] as List?) ?? const [];
    final rawLaboratorios = (json['laboratorios'] as List?) ?? const [];
    return OrdenTrabajoPanelResponse(
      page: _toInt(json['page']) ?? 1,
      pageSize: _toInt(json['pageSize']) ?? 25,
      total: _toInt(json['total']) ?? 0,
      roleCode: _toText(json['roleCode']) ?? '',
      panelMode: OrdenesTrabajoPanelMode.fromApi(_toText(json['panelMode'])),
      allowedSucs: rawAllowedSucs
          .map((item) => item?.toString().trim().toUpperCase() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      allowedActions: rawActions
          .map((item) => item?.toString().trim().toUpperCase() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet(),
      flowStatusOptions: rawFlowStatus
          .whereType<Map>()
          .map(
            (item) => OrdenTrabajoFlowStatusOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      incidenciaOptions: rawIncidenciaOptions
          .whereType<Map>()
          .map(
            (item) => OrdenTrabajoIncidenciaOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      laboratorios: rawLaboratorios
          .whereType<Map>()
          .map(
            (item) => OrdenTrabajoLaboratorioOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      items: rawItems
          .whereType<Map>()
          .map(
            (item) =>
                OrdenTrabajoItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class OrdenTrabajoFlowStatusOption {
  OrdenTrabajoFlowStatusOption({required this.value, required this.label});

  final String value;
  final String label;

  factory OrdenTrabajoFlowStatusOption.fromJson(Map<String, dynamic> json) {
    return OrdenTrabajoFlowStatusOption(
      value: _toText(json['value']) ?? '',
      label: _toText(json['label']) ?? '',
    );
  }
}

class OrdenTrabajoIncidenciaOption {
  OrdenTrabajoIncidenciaOption({required this.id, required this.label});

  final int id;
  final String label;

  factory OrdenTrabajoIncidenciaOption.fromJson(Map<String, dynamic> json) {
    return OrdenTrabajoIncidenciaOption(
      id: _toInt(json['id']) ?? 0,
      label: _toText(json['label']) ?? '',
    );
  }
}

class OrdenTrabajoMotivoMovimientoOption {
  OrdenTrabajoMotivoMovimientoOption({
    required this.id,
    required this.label,
    required this.tipo,
    required this.responsable,
  });

  final int id;
  final String label;
  final int tipo;
  final String responsable;

  factory OrdenTrabajoMotivoMovimientoOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrdenTrabajoMotivoMovimientoOption(
      id: _toInt(json['id']) ?? 0,
      label: _toText(json['label']) ?? '',
      tipo: _toInt(json['tipo']) ?? 0,
      responsable: _toText(json['responsable']) ?? '',
    );
  }
}

class OrdenTrabajoLaboratorioOption {
  OrdenTrabajoLaboratorioOption({
    required this.id,
    required this.lab,
    required this.tipoLab,
    required this.suc,
    required this.labSuc,
  });

  final int id;
  final String lab;
  final String tipoLab;
  final String suc;
  final String labSuc;

  factory OrdenTrabajoLaboratorioOption.fromJson(Map<String, dynamic> json) {
    return OrdenTrabajoLaboratorioOption(
      id: _toInt(json['id']) ?? 0,
      lab: _toText(json['lab']) ?? '',
      tipoLab: _toText(json['tipoLab']) ?? '',
      suc: _toText(json['suc']) ?? '',
      labSuc: _toText(json['labSuc']) ?? _toText(json['suc']) ?? '',
    );
  }
}

class OrdenTrabajoItem {
  OrdenTrabajoItem({
    required this.iord,
    required this.idfol,
    required this.suc,
    required this.art,
    required this.descArt,
    required this.tipo,
    required this.clien,
    required this.ncliente,
    required this.ctd,
    required this.estatus,
    required this.estsegu,
    required this.estseguDesc,
    required this.asign,
    required this.labor,
    required this.tipom,
    required this.motr,
    required this.fcns,
    required this.fcnm,
    required this.raw,
  });

  final String iord;
  final String idfol;
  final String suc;
  final String art;
  final String descArt;
  final String tipo;
  final String clien;
  final String ncliente;
  final double ctd;
  final String estatus;
  final String estsegu;
  final String estseguDesc;
  final String asign;
  final String labor;
  final String tipom;
  final String motr;
  final DateTime? fcns;
  final DateTime? fcnm;
  final Map<String, dynamic> raw;

  factory OrdenTrabajoItem.fromJson(Map<String, dynamic> json) {
    final asignLabel =
        _toText(json['ASIGN_LABEL']) ?? _toText(json['ASIGN']) ?? '';
    return OrdenTrabajoItem(
      iord: _toText(json['IORD']) ?? '',
      idfol: _toText(json['IDFOL']) ?? '',
      suc: _toText(json['SUC']) ?? '',
      art: _toText(json['ART']) ?? '',
      descArt: _toText(json['DESCART']) ?? '',
      tipo: _toText(json['TIPO']) ?? '',
      clien: _toText(json['CLIEN']) ?? '',
      ncliente: _toText(json['NCLIENTE']) ?? '',
      ctd: _toDouble(json['CTD']) ?? 0,
      estatus: _toText(json['ESTATUS']) ?? '',
      estsegu: _toText(json['ESTSEGU']) ?? '',
      estseguDesc: _toText(json['ESTSEGU_DESC']) ?? '',
      asign: asignLabel,
      labor: _toText(json['LABOR']) ?? '',
      tipom: _toText(json['TIPOM']) ?? '',
      motr: _toText(json['MOTR']) ?? '',
      fcns: _toDate(json['FCNS']),
      fcnm: _toDate(json['FCNM']),
      raw: json,
    );
  }
}

class OrdenTrabajoDetalleResponse {
  OrdenTrabajoDetalleResponse({required this.header, required this.details});

  final Map<String, dynamic> header;
  final List<Map<String, dynamic>> details;

  factory OrdenTrabajoDetalleResponse.fromJson(Map<String, dynamic> json) {
    final rawHeader = json['header'];
    final rawDetails = (json['details'] as List?) ?? const [];
    return OrdenTrabajoDetalleResponse(
      header: rawHeader is Map
          ? Map<String, dynamic>.from(rawHeader)
          : <String, dynamic>{},
      details: rawDetails
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
    );
  }
}

class OrdenTrabajoCambioMermaContext {
  OrdenTrabajoCambioMermaContext({
    required this.tipo,
    required this.selCtrlOrd,
    required this.hasStagingRecord,
    required this.hasCreatedOrd,
    required this.finalized,
    required this.editable,
    required this.blockedByAuthorization,
    required this.canCreateNewOrd,
    required this.canPrintFormato,
    required this.canPrintSaldo,
    required this.autoAutorizada,
    required this.message,
    required this.subtotalOriginal,
    required this.ivaOriginal,
    required this.totalOriginal,
    required this.subtotalNuevo,
    required this.ivaNuevo,
    required this.totalNuevo,
    required this.diferenciaEconomica,
    required this.generaAfectacionContable,
    required this.original,
    required this.draft,
  });

  final int tipo;
  final int? selCtrlOrd;
  final bool hasStagingRecord;
  final bool hasCreatedOrd;
  final bool finalized;
  final bool editable;
  final bool blockedByAuthorization;
  final bool canCreateNewOrd;
  final bool canPrintFormato;
  final bool canPrintSaldo;
  final bool autoAutorizada;
  final String message;
  final double subtotalOriginal;
  final double ivaOriginal;
  final double totalOriginal;
  final double subtotalNuevo;
  final double ivaNuevo;
  final double totalNuevo;
  final double diferenciaEconomica;
  final bool generaAfectacionContable;
  final Map<String, dynamic> original;
  final Map<String, dynamic> draft;

  factory OrdenTrabajoCambioMermaContext.fromJson(Map<String, dynamic> json) {
    final rawOriginal = json['original'];
    final rawDraft = json['draft'];
    return OrdenTrabajoCambioMermaContext(
      tipo: _toInt(json['tipo']) ?? 0,
      selCtrlOrd: _toInt(json['selCtrlOrd']),
      hasStagingRecord: json['hasStagingRecord'] == true,
      hasCreatedOrd: json['hasCreatedOrd'] == true,
      finalized: json['finalized'] == true,
      editable: json['editable'] == true,
      blockedByAuthorization: json['blockedByAuthorization'] == true,
      canCreateNewOrd: json['canCreateNewOrd'] == true,
      canPrintFormato: json['canPrintFormato'] == true,
      canPrintSaldo: json['canPrintSaldo'] == true,
      autoAutorizada: json['autoAutorizada'] == true,
      message: _toText(json['message']) ?? '',
      subtotalOriginal: _toDouble(json['subtotalOriginal']) ?? 0,
      ivaOriginal: _toDouble(json['ivaOriginal']) ?? 0,
      totalOriginal: _toDouble(json['totalOriginal']) ?? 0,
      subtotalNuevo: _toDouble(json['subtotalNuevo']) ?? 0,
      ivaNuevo: _toDouble(json['ivaNuevo']) ?? 0,
      totalNuevo: _toDouble(json['totalNuevo']) ?? 0,
      diferenciaEconomica: _toDouble(json['diferenciaEconomica']) ?? 0,
      generaAfectacionContable: json['generaAfectacionContable'] == true,
      original: rawOriginal is Map
          ? Map<String, dynamic>.from(rawOriginal)
          : <String, dynamic>{},
      draft: rawDraft is Map
          ? Map<String, dynamic>.from(rawDraft)
          : <String, dynamic>{},
    );
  }
}

class OrdenTrabajoActionResult {
  OrdenTrabajoActionResult({
    required this.ok,
    required this.message,
    required this.data,
  });

  final bool ok;
  final String message;
  final Map<String, dynamic> data;

  factory OrdenTrabajoActionResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return OrdenTrabajoActionResult(
      ok: json['ok'] == true,
      message: _toText(json['message']) ?? '',
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{},
    );
  }
}

class OrdenTrabajoEnviarRelacionItem {
  const OrdenTrabajoEnviarRelacionItem({
    required this.iord,
    required this.idfol,
    required this.suc,
    required this.labor,
    required this.clien,
    required this.ncliente,
    required this.art,
    required this.descArt,
    required this.ctd,
    required this.estsegu,
    required this.estseguDesc,
  });

  final String iord;
  final String idfol;
  final String suc;
  final String labor;
  final String clien;
  final String ncliente;
  final String art;
  final String descArt;
  final double ctd;
  final String estsegu;
  final String estseguDesc;

  factory OrdenTrabajoEnviarRelacionItem.fromJson(Map<String, dynamic> json) {
    return OrdenTrabajoEnviarRelacionItem(
      iord: _toText(json['IORD']) ?? '',
      idfol: _toText(json['IDFOL']) ?? '',
      suc: _toText(json['SUC']) ?? '',
      labor: _toText(json['LABOR']) ?? '',
      clien: _toText(json['CLIEN']) ?? '',
      ncliente: _toText(json['NCLIENTE']) ?? '',
      art: _toText(json['ART']) ?? '',
      descArt: _toText(json['DESCART']) ?? '',
      ctd: _toDouble(json['CTD']) ?? 0,
      estsegu: _toText(json['ESTSEGU']) ?? '',
      estseguDesc: _toText(json['ESTSEGU_DESC']) ?? '',
    );
  }
}

class OrdenTrabajoColaboradorOption {
  const OrdenTrabajoColaboradorOption({
    required this.idopv,
    required this.label,
    required this.nomb,
    required this.apelp,
    required this.apelm,
    required this.suc,
  });

  final String idopv;
  final String label;
  final String nomb;
  final String apelp;
  final String apelm;
  final String suc;

  factory OrdenTrabajoColaboradorOption.fromJson(Map<String, dynamic> json) {
    final nomb = _toText(json['nomb']) ?? '';
    final apelp = _toText(json['apelp']) ?? '';
    final apelm = _toText(json['apelm']) ?? '';
    final fallbackLabel = [
      nomb,
      apelp,
      apelm,
    ].where((item) => item.isNotEmpty).join(' ').trim();
    return OrdenTrabajoColaboradorOption(
      idopv: _toText(json['idopv']) ?? '',
      label:
          _toText(json['label']) ??
          (fallbackLabel.isEmpty ? '-' : fallbackLabel),
      nomb: nomb,
      apelp: apelp,
      apelm: apelm,
      suc: _toText(json['suc']) ?? '',
    );
  }
}

class OrdenTrabajoSucursalOption {
  const OrdenTrabajoSucursalOption({
    required this.suc,
    required this.label,
    required this.desc,
  });

  final String suc;
  final String label;
  final String desc;

  factory OrdenTrabajoSucursalOption.fromJson(Map<String, dynamic> json) {
    final suc = _toText(json['SUC']) ?? '';
    final desc = _toText(json['DESC']) ?? '';
    final label = [suc, desc]
        .where((item) => item.isNotEmpty)
        .join(' - ')
        .trim();
    return OrdenTrabajoSucursalOption(
      suc: suc,
      label: label.isEmpty ? suc : label,
      desc: desc,
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _toText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _toDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

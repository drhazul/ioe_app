class RetiroPanelItem {
  RetiroPanelItem({
    required this.idret,
    this.ter,
    this.opv,
    this.fcnr,
    required this.impr,
    required this.esta,
    required this.detCount,
    required this.detTotal,
  });

  final String idret;
  final String? ter;
  final String? opv;
  final DateTime? fcnr;
  final double impr;
  final String esta;
  final int detCount;
  final double detTotal;

  factory RetiroPanelItem.fromJson(Map<String, dynamic> json) {
    return RetiroPanelItem(
      idret: (json['idret'] ?? json['IDRET'] ?? '').toString().trim(),
      ter: _asText(json['ter'] ?? json['TER']),
      opv: _asText(json['opv'] ?? json['OPV']),
      fcnr: _asDate(json['fcnr'] ?? json['FCNR']),
      impr: _asDouble(json['impr'] ?? json['IMPR']) ?? 0,
      esta: (json['esta'] ?? json['ESTA'] ?? '').toString().trim().toUpperCase(),
      detCount: _asInt(json['detCount'] ?? json['DET_COUNT']) ?? 0,
      detTotal: _asDouble(json['detTotal'] ?? json['DET_TOTAL']) ?? 0,
    );
  }
}

class RetiroHeader {
  RetiroHeader({
    required this.idret,
    this.ter,
    this.opv,
    this.fcnr,
    required this.impr,
    required this.esta,
  });

  final String idret;
  final String? ter;
  final String? opv;
  final DateTime? fcnr;
  final double impr;
  final String esta;

  bool get isAbierto => esta.trim().toUpperCase() == 'ABIERTO';

  factory RetiroHeader.fromJson(Map<String, dynamic> json) {
    return RetiroHeader(
      idret: (json['idret'] ?? json['IDRET'] ?? '').toString().trim(),
      ter: _asText(json['ter'] ?? json['TER']),
      opv: _asText(json['opv'] ?? json['OPV']),
      fcnr: _asDate(json['fcnr'] ?? json['FCNR']),
      impr: _asDouble(json['impr'] ?? json['IMPR']) ?? 0,
      esta: (json['esta'] ?? json['ESTA'] ?? '').toString().trim().toUpperCase(),
    );
  }
}

class RetiroEfectivoItem {
  RetiroEfectivoItem({
    required this.id,
    required this.idfor,
    required this.deno,
    required this.ctda,
    required this.total,
  });

  final String id;
  final String idfor;
  final double deno;
  final double ctda;
  final double total;

  factory RetiroEfectivoItem.fromJson(Map<String, dynamic> json) {
    return RetiroEfectivoItem(
      id: (json['id'] ?? json['ID'] ?? '').toString().trim(),
      idfor: (json['idfor'] ?? json['IDFOR'] ?? '').toString().trim(),
      deno: _asDouble(json['deno'] ?? json['DENO']) ?? 0,
      ctda: _asDouble(json['ctda'] ?? json['CTDA']) ?? 0,
      total: _asDouble(json['total'] ?? json['TOTAL']) ?? 0,
    );
  }
}

class RetiroDetalleItem {
  RetiroDetalleItem({
    required this.id,
    required this.idret,
    required this.forma,
    required this.impf,
    required this.efectivo,
  });

  final String id;
  final String idret;
  final String forma;
  final double impf;
  final List<RetiroEfectivoItem> efectivo;

  bool get isEfectivo => forma.trim().toUpperCase() == 'EFECTIVO';

  factory RetiroDetalleItem.fromJson(Map<String, dynamic> json) {
    final rawEfectivo = (json['efectivo'] as List?) ?? const [];
    final efectivo = rawEfectivo
        .map(
          (row) =>
              RetiroEfectivoItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);

    efectivo.sort((a, b) => b.deno.compareTo(a.deno));

    return RetiroDetalleItem(
      id: (json['id'] ?? json['ID'] ?? '').toString().trim(),
      idret: (json['idret'] ?? json['IDRET'] ?? '').toString().trim(),
      forma: (json['forma'] ?? json['FORMA'] ?? '').toString().trim().toUpperCase(),
      impf: _asDouble(json['impf'] ?? json['IMPF']) ?? 0,
      efectivo: efectivo,
    );
  }
}

class RetiroDetailResponse {
  RetiroDetailResponse({
    required this.header,
    required this.detalles,
    required this.total,
  });

  final RetiroHeader header;
  final List<RetiroDetalleItem> detalles;
  final double total;

  factory RetiroDetailResponse.fromJson(Map<String, dynamic> json) {
    final headerRaw = Map<String, dynamic>.from(
      (json['header'] as Map?) ?? const {},
    );
    final detallesRaw = (json['detalles'] as List?) ?? const [];

    return RetiroDetailResponse(
      header: RetiroHeader.fromJson(headerRaw),
      detalles: detallesRaw
          .map(
            (row) =>
                RetiroDetalleItem.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false),
      total: _asDouble(json['total']) ?? 0,
    );
  }
}

class RetiroFormaCatalogItem {
  RetiroFormaCatalogItem({
    required this.form,
    required this.bloq,
  });

  final String form;
  final int bloq;

  bool get isBlocked => bloq != 0;

  factory RetiroFormaCatalogItem.fromJson(Map<String, dynamic> json) {
    return RetiroFormaCatalogItem(
      form: (json['form'] ?? json['FORM'] ?? '').toString().trim().toUpperCase(),
      bloq: _asInt(json['bloq'] ?? json['BLOQ']) ?? 0,
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


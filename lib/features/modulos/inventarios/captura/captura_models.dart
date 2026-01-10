class ConteoDisponible {
  final String tokenreg;
  final String? cont;
  final String? suc;
  final String? estado;
  final String? tipocont;
  final DateTime? fcnc;
  final int? totalItems;
  final String? fileName;

  const ConteoDisponible({
    required this.tokenreg,
    this.cont,
    this.suc,
    this.estado,
    this.tipocont,
    this.fcnc,
    this.totalItems,
    this.fileName,
  });

  factory ConteoDisponible.fromJson(Map<String, dynamic> json) {
    return ConteoDisponible(
      tokenreg: (json['TOKENREG'] ?? json['tokenreg'] ?? '') as String,
      cont: json['CONT'] as String?,
      suc: json['SUC'] as String?,
      estado: json['ESTA'] as String?,
      tipocont: json['TIPOCONT'] as String?,
      fcnc: _parseDate(json['FCNC']),
      totalItems: _parseInt(json['TOTAL_ITEMS'] ?? json['totalItems']),
      fileName: json['FILE_NAME'] as String?,
    );
  }
}

class CapturaResult {
  final int? id;
  final String cont;
  final String suc;
  final String art;
  final String? upc;
  final String almacen;
  final double cantidad;
  final String? tipoMov;
  final String capturaUuid;
  final DateTime? fcnr;
  final int? idUsuario;
  final bool idempotent;
  final String? estadoConteo;

  const CapturaResult({
    required this.id,
    required this.cont,
    required this.suc,
    required this.art,
    required this.almacen,
    required this.cantidad,
    required this.capturaUuid,
    required this.idempotent,
    this.upc,
    this.tipoMov,
    this.fcnr,
    this.idUsuario,
    this.estadoConteo,
  });

  factory CapturaResult.fromJson(Map<String, dynamic> json) => CapturaResult(
        id: _parseInt(json['id']),
        cont: json['cont'] as String? ?? '',
        suc: json['suc'] as String? ?? '',
        art: json['art'] as String? ?? '',
        upc: json['upc'] as String?,
        almacen: json['almacen'] as String? ?? '',
        cantidad: _parseDouble(json['cantidad']) ?? 0,
        tipoMov: json['tipoMov'] as String?,
        capturaUuid: json['capturaUuid'] as String? ?? '',
        fcnr: _parseDate(json['fcnr']),
        idUsuario: _parseInt(json['idUsuario']),
        idempotent: (json['idempotent'] as bool?) ?? false,
        estadoConteo: json['estadoConteo'] as String?,
      );
}

class CapturaRecord {
  final int id;
  final String cont;
  final String suc;
  final String art;
  final String? upc;
  final String almacen;
  final double cantidad;
  final String? tipoMov;
  final int? idUsuario;
  final DateTime? fcnr;

  const CapturaRecord({
    required this.id,
    required this.cont,
    required this.suc,
    required this.art,
    required this.almacen,
    required this.cantidad,
    this.upc,
    this.tipoMov,
    this.idUsuario,
    this.fcnr,
  });

  factory CapturaRecord.fromJson(Map<String, dynamic> json) {
    return CapturaRecord(
      id: _parseInt(json['ID']) ?? _parseInt(json['id']) ?? 0,
      cont: json['CONT'] as String? ?? json['cont'] as String? ?? '',
      suc: json['SUC'] as String? ?? json['suc'] as String? ?? '',
      art: json['ART'] as String? ?? json['art'] as String? ?? '',
      upc: json['UPC'] as String? ?? json['upc'] as String?,
      almacen: json['ALMACEN'] as String? ?? json['almacen'] as String? ?? '',
      cantidad: _parseDouble(json['CANT'] ?? json['cantidad']) ?? 0,
      tipoMov: json['TIPO_MOV'] as String? ?? json['tipoMov'] as String?,
      idUsuario: _parseInt(json['IDUSUARIO']),
      fcnr: _parseDate(json['FCNR']),
    );
  }
}

class CapturaListResponse {
  final List<CapturaRecord> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final String cont;
  final String suc;
  final double sumCant;

  const CapturaListResponse({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.cont,
    required this.suc,
    required this.sumCant,
  });

  factory CapturaListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? [])
        .map((e) => CapturaRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return CapturaListResponse(
      data: items,
      page: _parseInt(json['page']) ?? 1,
      limit: _parseInt(json['limit']) ?? items.length,
      total: _parseInt(json['total']) ?? items.length,
      totalPages: _parseInt(json['totalPages']) ?? 1,
      cont: json['cont'] as String? ?? '',
      suc: json['suc'] as String? ?? '',
      sumCant: _parseDouble(json['sumCant']) ?? 0,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  return (value as num?)?.toDouble();
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

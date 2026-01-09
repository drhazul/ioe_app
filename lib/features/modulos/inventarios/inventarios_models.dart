class DatContCtrlModel {
  final String tokenreg;
  final String? cont;
  final DateTime? fcnc;
  final String? esta;
  final String? suc;
  final DateTime? fcnaj;
  final double? artaj;
  final double? artcont;
  final String? tipocont;
  final int? totalItems;
  final String? fileName;
  final DateTime? creado;
  final String? creadoPor;
  final String? modificadoPor;

  const DatContCtrlModel({
    required this.tokenreg,
    this.cont,
    this.fcnc,
    this.esta,
    this.suc,
    this.fcnaj,
    this.artaj,
    this.artcont,
    this.tipocont,
    this.totalItems,
    this.fileName,
    this.creado,
    this.creadoPor,
    this.modificadoPor,
  });

  factory DatContCtrlModel.fromJson(Map<String, dynamic> json) {
    return DatContCtrlModel(
      tokenreg: json['TOKENREG'] as String,
      cont: json['CONT'] as String?,
      fcnc: _parseDate(json['FCNC']),
      esta: json['ESTA'] as String?,
      suc: json['SUC'] as String?,
      fcnaj: _parseDate(json['FCNAJ']),
      artaj: (json['ARTAJ'] as num?)?.toDouble(),
      artcont: (json['ARTCONT'] as num?)?.toDouble(),
      tipocont: json['TIPOCONT'] as String?,
      totalItems: _parseInt(json['TOTAL_ITEMS']),
      fileName: json['FILE_NAME'] as String?,
      creado: _parseDate(json['CREADO']),
      creadoPor: json['CREADO_POR'] as String?,
      modificadoPor: json['MODIFICADO_POR'] as String?,
    );
  }

  Map<String, dynamic> toPayload({bool includePk = true}) {
    return {
      if (includePk) 'TOKENREG': tokenreg,
      'CONT': cont,
      'FCNC': fcnc?.toIso8601String(),
      'ESTA': esta,
      'SUC': suc,
      'FCNAJ': fcnaj?.toIso8601String(),
      'ARTAJ': artaj,
      'ARTCONT': artcont,
      'TIPOCONT': tipocont,
      'TOTAL_ITEMS': totalItems,
      'FILE_NAME': fileName,
      'CREADO': creado?.toIso8601String(),
      'CREADO_POR': creadoPor,
      'MODIFICADO_POR': modificadoPor,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isEmpty) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class ConteoUploadResult {
  final String cont;
  final String suc;
  final String tipocont;
  final int? totalItems;
  final String? fileName;
  final String? status;

  const ConteoUploadResult({
    required this.cont,
    required this.suc,
    required this.tipocont,
    this.totalItems,
    this.fileName,
    this.status,
  });

  factory ConteoUploadResult.fromJson(Map<String, dynamic> json) {
    return ConteoUploadResult(
      cont: json['cont'] as String? ?? json['CONT'] as String? ?? '',
      suc: json['suc'] as String? ?? json['SUC'] as String? ?? '',
      tipocont: json['tipocont'] as String? ?? json['TIPOCONT'] as String? ?? '',
      totalItems: DatContCtrlModel._parseInt(json['totalItems'] ?? json['TOTAL_ITEMS']),
      fileName: json['fileName'] as String? ?? json['FILE_NAME'] as String?,
      status: json['status'] as String? ?? json['ESTA'] as String?,
    );
  }
}

class ConteoProcessResult {
  final String cont;
  final String suc;
  final DatContCtrlModel? ctrl;
  final int? totalDet;

  const ConteoProcessResult({
    required this.cont,
    required this.suc,
    this.ctrl,
    this.totalDet,
  });

  factory ConteoProcessResult.fromJson(Map<String, dynamic> json) {
    return ConteoProcessResult(
      cont: json['cont'] as String? ?? '',
      suc: json['suc'] as String? ?? '',
      ctrl: json['ctrl'] != null ? DatContCtrlModel.fromJson(Map<String, dynamic>.from(json['ctrl'] as Map)) : null,
      totalDet: DatContCtrlModel._parseInt(json['totalDet']),
    );
  }
}

class ConteoApplyAdjustmentResult {
  final String cont;
  final String suc;
  final String? docp701;
  final String? docp702;
  final int? movimientosInsertados;

  const ConteoApplyAdjustmentResult({
    required this.cont,
    required this.suc,
    this.docp701,
    this.docp702,
    this.movimientosInsertados,
  });

  factory ConteoApplyAdjustmentResult.fromJson(Map<String, dynamic> json) {
    String? parseString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    return ConteoApplyAdjustmentResult(
      cont: json['cont'] as String? ?? json['CONT'] as String? ?? '',
      suc: json['suc'] as String? ?? json['SUC'] as String? ?? '',
      docp701: parseString(json['docp701'] ?? json['DOCP701'] ?? json['DOC_P701']),
      docp702: parseString(json['docp702'] ?? json['DOCP702'] ?? json['DOC_P702']),
      movimientosInsertados: DatContCtrlModel._parseInt(
        json['movimientosInsertados'] ?? json['MOVIMIENTOSINSERTADOS'] ?? json['MOVIMIENTOS_INSERTADOS'],
      ),
    );
  }
}

class DatDetSvrModel {
  final int? id;
  final String? art;
  final String? upc;
  final String? cont;
  final String? descripcion;
  final double? ctop;
  final double? total;
  final double? mb52T;
  final double? difT;
  final double? difCtop;
  final double? depa;
  final double? subd;
  final double? clas;
  final int? ext;
  final double? uno;
  final double? dos;
  final double? m001;
  final double? t001;
  final double? mb52_01;
  final double? mb52_02;
  final double? mb52M1;
  final double? mb52T1;
  final double? dif01;
  final double? dif02;
  final double? difM1;
  final double? difT1;
  final String? suc;

  const DatDetSvrModel({
    this.id,
    this.art,
    this.upc,
    this.cont,
    this.descripcion,
    this.ctop,
    this.total,
    this.mb52T,
    this.difT,
    this.difCtop,
    this.depa,
    this.subd,
    this.clas,
    this.ext,
    this.uno,
    this.dos,
    this.m001,
    this.t001,
    this.mb52_01,
    this.mb52_02,
    this.mb52M1,
    this.mb52T1,
    this.dif01,
    this.dif02,
    this.difM1,
    this.difT1,
    this.suc,
  });

  factory DatDetSvrModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) => (value as num?)?.toDouble();
    int? parseInt(dynamic value) => value == null ? null : int.tryParse(value.toString());

    return DatDetSvrModel(
      id: parseInt(json['ID']),
      art: json['ART'] as String?,
      upc: json['UPC'] as String?,
      cont: json['CONT'] as String?,
      descripcion: json['DES'] as String?,
      ctop: parseDouble(json['CTOP']),
      total: parseDouble(json['TOTAL']),
      mb52T: parseDouble(json['MB52_T']),
      difT: parseDouble(json['DIF_T']),
      difCtop: parseDouble(json['DIF_CTOP']),
      depa: parseDouble(json['DEPA']),
      subd: parseDouble(json['SUBD']),
      clas: parseDouble(json['CLAS']),
      ext: parseInt(json['EXT']),
      uno: parseDouble(json['001']),
      dos: parseDouble(json['002']),
      m001: parseDouble(json['M001']),
      t001: parseDouble(json['T001']),
      mb52_01: parseDouble(json['MB52_01']),
      mb52_02: parseDouble(json['MB52_02']),
      mb52M1: parseDouble(json['MB52_M1']),
      mb52T1: parseDouble(json['MB52_T1']),
      dif01: parseDouble(json['DIF_01']),
      dif02: parseDouble(json['DIF_02']),
      difM1: parseDouble(json['DIF_M1']),
      difT1: parseDouble(json['DIF_T1']),
      suc: json['SUC'] as String?,
    );
  }
}

class ConteoDetResponse {
  final List<DatDetSvrModel> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const ConteoDetResponse({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory ConteoDetResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>? ?? [])
        .map((e) => DatDetSvrModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final page = DatContCtrlModel._parseInt(json['page']) ?? 1;
    final limit = DatContCtrlModel._parseInt(json['limit']) ?? data.length;
    final total = DatContCtrlModel._parseInt(json['total']) ?? data.length;
    final totalPagesParsed = DatContCtrlModel._parseInt(json['totalPages']) ?? 1;

    return ConteoDetResponse(
      data: data,
      page: page < 1 ? 1 : page,
      limit: limit < 1 ? data.length : limit,
      total: total < 0 ? 0 : total,
      totalPages: totalPagesParsed < 1 ? 1 : totalPagesParsed,
    );
  }
}

class ConteoSummaryModel {
  final String cont;
  final String suc;
  final String? esta;
  final int totalRecords;
  final double sumDifCtop;
  final double sumDifT;

  const ConteoSummaryModel({
    required this.cont,
    required this.suc,
    this.esta,
    required this.totalRecords,
    required this.sumDifCtop,
    required this.sumDifT,
  });

  factory ConteoSummaryModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int parseInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;

    return ConteoSummaryModel(
      cont: json['cont'] as String? ?? '',
      suc: json['suc'] as String? ?? '',
      esta: json['esta'] as String? ?? json['ESTA'] as String?,
      totalRecords: parseInt(json['totalRecords']),
      sumDifCtop: parseDouble(json['sumDifCtop']),
      sumDifT: parseDouble(json['sumDifT']),
    );
  }
}

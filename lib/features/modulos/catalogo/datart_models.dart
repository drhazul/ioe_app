class DatArtModel {
  DatArtModel({
    required this.suc,
    required this.art,
    required this.upc,
    this.tipo,
    this.clavesat,
    this.unimedsat,
    this.des,
    this.stock,
    this.stockMin,
    this.estatus,
    this.diaReabasto,
    this.pvta,
    this.ctop,
    this.prov1,
    this.ctoProv1,
    this.prov2,
    this.ctoProv2,
    this.prov3,
    this.ctoProv3,
    this.unComp,
    this.factComp,
    this.unVta,
    this.factVta,
    this.base,
    this.sph,
    this.cyl,
    this.adic,
    this.depa,
    this.subd,
    this.clas,
    this.scla,
    this.scla2,
    this.umue,
    this.utra,
    this.univ,
    this.ufre,
    this.bloq,
    this.marca,
    this.modelo,
  });

  final String suc;
  final String art;
  final String upc;
  final String? tipo;
  final double? clavesat;
  final String? unimedsat;
  final String? des;
  final double? stock;
  final double? stockMin;
  final String? estatus;
  final double? diaReabasto;
  final double? pvta;
  final double? ctop;
  final double? prov1;
  final double? ctoProv1;
  final double? prov2;
  final double? ctoProv2;
  final double? prov3;
  final double? ctoProv3;
  final String? unComp;
  final double? factComp;
  final String? unVta;
  final double? factVta;
  final String? base;
  final double? sph;
  final double? cyl;
  final double? adic;
  final double? depa;
  final double? subd;
  final double? clas;
  final double? scla;
  final double? scla2;
  final double? umue;
  final double? utra;
  final double? univ;
  final double? ufre;
  final int? bloq;
  final String? marca;
  final String? modelo;

  factory DatArtModel.fromJson(Map<String, dynamic> json) {
    return DatArtModel(
      suc: _asString(json['SUC']) ?? '',
      art: _asString(json['ART']) ?? '',
      upc: _asString(json['UPC']) ?? '',
      tipo: _asString(json['TIPO']),
      clavesat: _asDouble(json['CLAVESAT']),
      unimedsat: _asString(json['UNIMEDSAT']),
      des: _asString(json['DES']),
      stock: _asDouble(json['STOCK']),
      stockMin: _asDouble(json['STOCK_MIN']),
      estatus: _asString(json['ESTATUS']),
      diaReabasto: _asDouble(json['DIA_REABASTO']),
      pvta: _asDouble(json['PVTA']),
      ctop: _asDouble(json['CTOP']),
      prov1: _asDouble(json['PROV_1']),
      ctoProv1: _asDouble(json['CTO_PROV1']),
      prov2: _asDouble(json['PROV_2']),
      ctoProv2: _asDouble(json['CTO_PROV2']),
      prov3: _asDouble(json['PROV_3']),
      ctoProv3: _asDouble(json['CTO_PROV3']),
      unComp: _asString(json['UN_COMP']),
      factComp: _asDouble(json['FACT_COMP']),
      unVta: _asString(json['UN_VTA']),
      factVta: _asDouble(json['FACT_VTA']),
      base: _asString(json['BASE']),
      sph: _asDouble(json['SPH']),
      cyl: _asDouble(json['CYL']),
      adic: _asDouble(json['ADIC']),
      depa: _asDouble(json['DEPA']),
      subd: _asDouble(json['SUBD']),
      clas: _asDouble(json['CLAS']),
      scla: _asDouble(json['SCLA']),
      scla2: _asDouble(json['SCLA2']),
      umue: _asDouble(json['UMUE']),
      utra: _asDouble(json['UTRA']),
      univ: _asDouble(json['UNIV']),
      ufre: _asDouble(json['UFRE']),
      bloq: _asInt(json['BLOQ']),
      marca: _asString(json['MARCA']),
      modelo: _asString(json['MODELO']),
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class DatArtMassiveIssue {
  DatArtMassiveIssue({
    required this.renglon,
    this.suc,
    this.art,
    this.upc,
    this.mensaje,
  });

  final int renglon;
  final String? suc;
  final String? art;
  final String? upc;
  final String? mensaje;

  factory DatArtMassiveIssue.fromJson(Map<String, dynamic> json) {
    return DatArtMassiveIssue(
      renglon: DatArtModel._asInt(json['renglon']) ?? 0,
      suc: DatArtModel._asString(json['suc']),
      art: DatArtModel._asString(json['art']),
      upc: DatArtModel._asString(json['upc']),
      mensaje: DatArtModel._asString(json['mensaje']),
    );
  }
}

class DatArtMassiveUploadResult {
  DatArtMassiveUploadResult({
    required this.loteId,
    required this.totalCargados,
    required this.procesados,
    required this.invalidosUk,
    required this.noExistenCatalogo,
    required this.duplicados,
    required this.invalidos,
    required this.noExistentes,
  });

  final String loteId;
  final int totalCargados;
  final int procesados;
  final int invalidosUk;
  final int noExistenCatalogo;
  final int duplicados;
  final List<DatArtMassiveIssue> invalidos;
  final List<DatArtMassiveIssue> noExistentes;

  factory DatArtMassiveUploadResult.fromJson(Map<String, dynamic> json) {
    final invalidos = (json['invalidos'] as List<dynamic>? ?? [])
        .map(
          (e) =>
              DatArtMassiveIssue.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    final noExistentes = (json['noExistentes'] as List<dynamic>? ?? [])
        .map(
          (e) =>
              DatArtMassiveIssue.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return DatArtMassiveUploadResult(
      loteId: DatArtModel._asString(json['loteId']) ?? '',
      totalCargados: DatArtModel._asInt(json['totalCargados']) ?? 0,
      procesados: DatArtModel._asInt(json['procesados']) ?? 0,
      invalidosUk: DatArtModel._asInt(json['invalidosUk']) ?? 0,
      noExistenCatalogo: DatArtModel._asInt(json['noExistenCatalogo']) ?? 0,
      duplicados: DatArtModel._asInt(json['duplicados']) ?? 0,
      invalidos: invalidos,
      noExistentes: noExistentes,
    );
  }
}

class AltaMasivaUploadResult {
  AltaMasivaUploadResult({
    required this.batchId,
    required this.totalRows,
  });

  final String batchId;
  final int totalRows;

  factory AltaMasivaUploadResult.fromJson(Map<String, dynamic> json) {
    return AltaMasivaUploadResult(
      batchId: DatArtModel._asString(json['batchId']) ?? '',
      totalRows: DatArtModel._asInt(json['totalRows']) ?? 0,
    );
  }
}

class AltaMasivaValidationError {
  AltaMasivaValidationError({
    required this.rowNum,
    this.suc,
    this.art,
    this.upc,
    this.errorMsg,
  });

  final int rowNum;
  final String? suc;
  final String? art;
  final String? upc;
  final String? errorMsg;

  factory AltaMasivaValidationError.fromJson(Map<String, dynamic> json) {
    return AltaMasivaValidationError(
      rowNum: DatArtModel._asInt(json['rowNum']) ?? 0,
      suc: DatArtModel._asString(json['suc']),
      art: DatArtModel._asString(json['art']),
      upc: DatArtModel._asString(json['upc']),
      errorMsg: DatArtModel._asString(json['errorMsg']),
    );
  }
}

class AltaMasivaValidationResult {
  AltaMasivaValidationResult({
    required this.batchId,
    required this.totalRows,
    required this.validRows,
    required this.errorRows,
    required this.errors,
  });

  final String batchId;
  final int totalRows;
  final int validRows;
  final int errorRows;
  final List<AltaMasivaValidationError> errors;

  factory AltaMasivaValidationResult.fromJson(Map<String, dynamic> json) {
    final errors = (json['errors'] as List<dynamic>? ?? [])
        .map(
          (e) => AltaMasivaValidationError.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    return AltaMasivaValidationResult(
      batchId: DatArtModel._asString(json['batchId']) ?? '',
      totalRows: DatArtModel._asInt(json['totalRows']) ?? 0,
      validRows: DatArtModel._asInt(json['validRows']) ?? 0,
      errorRows: DatArtModel._asInt(json['errorRows']) ?? 0,
      errors: errors,
    );
  }
}

class AltaMasivaCommitRow {
  AltaMasivaCommitRow({
    required this.art,
    required this.upc,
    this.suc,
    this.des,
    this.tipo,
  });

  final String art;
  final String upc;
  final String? suc;
  final String? des;
  final String? tipo;

  factory AltaMasivaCommitRow.fromJson(Map<String, dynamic> json) {
    return AltaMasivaCommitRow(
      art: DatArtModel._asString(json['art']) ?? '',
      upc: DatArtModel._asString(json['upc']) ?? '',
      suc: DatArtModel._asString(json['suc']),
      des: DatArtModel._asString(json['des']),
      tipo: DatArtModel._asString(json['tipo']),
    );
  }
}

class AltaMasivaCommitResult {
  AltaMasivaCommitResult({
    required this.batchId,
    required this.insertedRows,
    required this.inserted,
  });

  final String batchId;
  final int insertedRows;
  final List<AltaMasivaCommitRow> inserted;

  factory AltaMasivaCommitResult.fromJson(Map<String, dynamic> json) {
    final inserted = (json['inserted'] as List<dynamic>? ?? [])
        .map(
          (e) => AltaMasivaCommitRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    return AltaMasivaCommitResult(
      batchId: DatArtModel._asString(json['batchId']) ?? '',
      insertedRows: DatArtModel._asInt(json['insertedRows']) ?? 0,
      inserted: inserted,
    );
  }
}

class AltaMasivaPreviewResult {
  AltaMasivaPreviewResult({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;

  factory AltaMasivaPreviewResult.fromJson(Map<String, dynamic> json) {
    final headers = (json['headers'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final rows = (json['rows'] as List<dynamic>? ?? [])
        .map(
          (row) => (row as List<dynamic>).map((e) => e.toString()).toList(),
        )
        .toList();
    return AltaMasivaPreviewResult(headers: headers, rows: rows);
  }
}

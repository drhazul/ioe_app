class TransferenciaPagedResult<T> {
  TransferenciaPagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
}

class TransferenciaDocModel {
  const TransferenciaDocModel({
    required this.doc,
    required this.estatus,
    required this.sucEnt,
    required this.sucSal,
    required this.usr,
    required this.ctd,
    required this.imp,
    required this.mtv,
    required this.prio,
    this.fcnd,
    this.fcnc,
    this.mtvDesc,
    this.txt,
    this.usrL,
    this.usrR,
    this.usrE,
    this.docMb51Sal,
    this.docMb51Ent,
    this.detalleActivo = 0,
    this.detalle = const [],
    this.paqueteria,
  });

  final String doc;
  final String estatus;
  final String sucEnt;
  final String sucSal;
  final String usr;
  final double ctd;
  final double imp;
  final String mtv;
  final String prio;
  final DateTime? fcnd;
  final DateTime? fcnc;
  final String? mtvDesc;
  final String? txt;
  final String? usrL;
  final String? usrR;
  final String? usrE;
  final String? docMb51Sal;
  final String? docMb51Ent;
  final int detalleActivo;
  final List<TransferenciaDetalleModel> detalle;
  final TransferenciaPaqModel? paqueteria;

  factory TransferenciaDocModel.fromJson(Map<String, dynamic> json) {
    final detalleRaw = json['detalle'];
    return TransferenciaDocModel(
      doc: _txt(json['doc']),
      estatus: _txt(json['estatus']).toUpperCase(),
      sucEnt: _txt(json['sucEnt']),
      sucSal: _txt(json['sucSal']),
      usr: _txt(json['usr']),
      ctd: _toDouble(json['ctd']),
      imp: _toDouble(json['imp']),
      mtv: _txt(json['mtv']),
      prio: _txt(json['prio']),
      fcnd: _toDate(json['fcnd']),
      fcnc: _toDate(json['fcnc']),
      mtvDesc: _txtNullable(json['mtvDesc']),
      txt: _txtNullable(json['txt']),
      usrL: _txtNullable(json['usrL']),
      usrR: _txtNullable(json['usrR']),
      usrE: _txtNullable(json['usrE']),
      docMb51Sal: _txtNullable(json['docMb51Sal']),
      docMb51Ent: _txtNullable(json['docMb51Ent']),
      detalleActivo: _toInt(json['detalleActivo']),
      detalle: detalleRaw is List
          ? detalleRaw
                .map(
                  (row) => TransferenciaDetalleModel.fromJson(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
      paqueteria: json['paqueteria'] is Map
          ? TransferenciaPaqModel.fromJson(
              Map<String, dynamic>.from(json['paqueteria'] as Map),
            )
          : null,
    );
  }
}

class TransferenciaDetalleModel {
  const TransferenciaDetalleModel({
    required this.idpd,
    required this.art,
    required this.des,
    required this.exisS,
    required this.exisD,
    required this.ctd,
    required this.ctdLib,
    required this.ctotal,
    required this.ctolib,
    required this.ctdR,
    required this.ctoR,
    required this.difR,
    required this.difctoR,
    required this.ctop,
    this.txt,
  });

  final String idpd;
  final String art;
  final String des;
  final double exisS;
  final double exisD;
  final double ctd;
  final double ctdLib;
  final double ctotal;
  final double ctolib;
  final double ctdR;
  final double ctoR;
  final double difR;
  final double difctoR;
  final double ctop;
  final String? txt;

  factory TransferenciaDetalleModel.fromJson(Map<String, dynamic> json) {
    return TransferenciaDetalleModel(
      idpd: _txt(json['idpd']),
      art: _txt(json['art']),
      des: _txt(json['des']),
      exisS: _toDouble(json['exisS']),
      exisD: _toDouble(json['exisD']),
      ctd: _toDouble(json['ctd']),
      ctdLib: _toDouble(json['ctdLib']),
      ctotal: _toDouble(json['ctotal']),
      ctolib: _toDouble(json['ctolib']),
      ctdR: _toDouble(json['ctdR']),
      ctoR: _toDouble(json['ctoR']),
      difR: _toDouble(json['difR']),
      difctoR: _toDouble(json['difctoR']),
      ctop: _toDouble(json['ctop']),
      txt: _txtNullable(json['txt']),
    );
  }
}

class TransferenciaPaqModel {
  const TransferenciaPaqModel({
    this.emp,
    this.numGuia,
    this.fenv,
    this.resp,
    this.txt,
    this.usr,
  });

  final String? emp;
  final String? numGuia;
  final DateTime? fenv;
  final String? resp;
  final String? txt;
  final String? usr;

  factory TransferenciaPaqModel.fromJson(Map<String, dynamic> json) {
    return TransferenciaPaqModel(
      emp: _txtNullable(json['emp']),
      numGuia: _txtNullable(json['numGuia']),
      fenv: _toDate(json['fenv']),
      resp: _txtNullable(json['resp']),
      txt: _txtNullable(json['txt']),
      usr: _txtNullable(json['usr']),
    );
  }
}

class TransferenciaCatalogOptionModel {
  const TransferenciaCatalogOptionModel({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  factory TransferenciaCatalogOptionModel.fromJson(
    Map<String, dynamic> json, {
    String valueKey = 'clave',
    String labelKey = 'desc',
  }) {
    final value = _txt(json[valueKey]);
    final label = _txt(json[labelKey]);
    return TransferenciaCatalogOptionModel(
      value: value.isEmpty ? label : value,
      label: label.isEmpty ? value : label,
    );
  }
}

class TransferenciaArticuloModel {
  const TransferenciaArticuloModel({
    required this.art,
    required this.upc,
    required this.des,
    required this.stockSal,
    required this.stockEnt,
    required this.stockMin,
    required this.ctop,
  });

  final String art;
  final String upc;
  final String des;
  final double stockSal;
  final double stockEnt;
  final double stockMin;
  final double ctop;

  factory TransferenciaArticuloModel.fromJson(Map<String, dynamic> json) {
    return TransferenciaArticuloModel(
      art: _txt(json['art']),
      upc: _txt(json['upc']),
      des: _txt(json['des']),
      stockSal: _toDouble(json['stockSal']),
      stockEnt: _toDouble(json['stockEnt']),
      stockMin: _toDouble(json['stockMin']),
      ctop: _toDouble(json['ctop']),
    );
  }
}

String _txt(dynamic value) => (value ?? '').toString().trim();
String? _txtNullable(dynamic value) {
  final text = _txt(value);
  return text.isEmpty ? null : text;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

DateTime? _toDate(dynamic value) {
  final text = _txt(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

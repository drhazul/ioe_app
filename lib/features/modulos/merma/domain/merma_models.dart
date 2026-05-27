class MermaPagedResult<T> {
  MermaPagedResult({
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

class MermaGestionCabeceraModel {
  const MermaGestionCabeceraModel({
    required this.docmer,
    required this.fcnd,
    required this.estats,
    required this.suc,
  });

  final String docmer;
  final DateTime? fcnd;
  final String estats;
  final String suc;

  factory MermaGestionCabeceraModel.fromJson(Map<String, dynamic> json) {
    return MermaGestionCabeceraModel(
      docmer: _txt(json['docmer']),
      fcnd: _toDate(json['fcnd']),
      estats: _txt(json['estats']).toUpperCase(),
      suc: _txt(json['suc']),
    );
  }
}

class MermaDocModel {
  MermaDocModel({
    required this.docmer,
    required this.suc,
    required this.user,
    required this.estatus,
    required this.idEstatus,
    required this.narts,
    required this.total,
    this.fcnd,
    this.fcnc,
    this.areaM,
    this.txt,
    this.docMb51,
    this.userAud,
    this.obsAudit,
    this.fcnAud,
    this.detalle = const [],
  });

  final String docmer;
  final String suc;
  final String user;
  final String estatus;
  final int idEstatus;
  final double narts;
  final double total;
  final DateTime? fcnd;
  final DateTime? fcnc;
  final String? areaM;
  final String? txt;
  final String? docMb51;
  final String? userAud;
  final String? obsAudit;
  final DateTime? fcnAud;
  final List<MermaDetalleModel> detalle;

  factory MermaDocModel.fromJson(Map<String, dynamic> json) {
    final detalleRaw = json['detalle'];
    return MermaDocModel(
      docmer: _txt(json['docmer']),
      suc: _txt(json['suc']),
      user: _txt(json['user']),
      estatus: _txt(json['estatus']).toUpperCase(),
      idEstatus: _toInt(json['idEstatus']),
      narts: _toDouble(json['narts']),
      total: _toDouble(json['total']),
      fcnd: _toDate(json['fcnd']),
      fcnc: _toDate(json['fcnc']),
      areaM: _txtNullable(json['areaM']),
      txt: _txtNullable(json['txt']),
      docMb51: _txtNullable(json['docMb51']),
      userAud: _txtNullable(json['userAud']),
      obsAudit: _txtNullable(json['obsAudit']),
      fcnAud: _toDate(json['fcnAud']),
      detalle: detalleRaw is List
          ? detalleRaw
                .map(
                  (row) => MermaDetalleModel.fromJson(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class MermaDetalleModel {
  MermaDetalleModel({
    required this.idpd,
    required this.art,
    this.des,
    required this.ctd,
    required this.cto,
    required this.ctot,
    this.motM,
    this.motivo,
    this.areaM,
    this.respM,
    this.obsM,
    this.evidencias = 0,
    this.evidenciaUrl,
    this.evidenciaMime,
  });

  final String idpd;
  final String art;
  final String? des;
  final double ctd;
  final double cto;
  final double ctot;
  final int? motM;
  final String? motivo;
  final String? areaM;
  final String? respM;
  final String? obsM;
  final int evidencias;
  final String? evidenciaUrl;
  final String? evidenciaMime;

  factory MermaDetalleModel.fromJson(Map<String, dynamic> json) {
    return MermaDetalleModel(
      idpd: _txt(json['idpd']),
      art: _txt(json['art']),
      des: _txtNullable(json['des']),
      ctd: _toDouble(json['ctd']),
      cto: _toDouble(json['cto']),
      ctot: _toDouble(json['ctot']),
      motM: _toNullableInt(json['motM']),
      motivo: _txtNullable(json['motivo']),
      areaM: _txtNullable(json['areaM']),
      respM: _txtNullable(json['respM']),
      obsM: _txtNullable(json['obsM']),
      evidencias: _toInt(json['evidencias']),
      evidenciaUrl: _txtNullable(json['evidenciaUrl']),
      evidenciaMime: _txtNullable(json['evidenciaMime']),
    );
  }
}

class MermaCatalogOptionModel {
  const MermaCatalogOptionModel({
    required this.id,
    required this.desc,
    this.meta = const {},
  });

  final int id;
  final String desc;
  final Map<String, dynamic> meta;

  factory MermaCatalogOptionModel.fromJson(Map<String, dynamic> json) {
    return MermaCatalogOptionModel(
      id: _toInt(json['id']),
      desc: _txt(json['desc']),
      meta: Map<String, dynamic>.from(json),
    );
  }
}

class MermaArticuloModel {
  const MermaArticuloModel({
    required this.art,
    required this.upc,
    required this.des,
    required this.stock,
    required this.ctop,
  });

  final String art;
  final String upc;
  final String des;
  final double stock;
  final double ctop;

  factory MermaArticuloModel.fromJson(Map<String, dynamic> json) {
    return MermaArticuloModel(
      art: _txt(json['art']),
      upc: _txt(json['upc']),
      des: _txt(json['des']),
      stock: _toDouble(json['stock']),
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

int? _toNullableInt(dynamic value) {
  final parsed = int.tryParse('${value ?? ''}');
  return parsed;
}

DateTime? _toDate(dynamic value) {
  final text = _txt(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

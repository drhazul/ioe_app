class PvCtrFolAsvrModel {
  PvCtrFolAsvrModel({
    required this.idfol,
    this.clien,
    this.doc,
    this.fcn,
    this.suc,
    this.ter,
    this.tra,
    this.opv,
    this.esta,
    this.impt,
    this.fpgo,
    this.impp,
    this.aut,
    this.reqf,
    this.fcnm,
    this.opvm,
    this.mod,
    this.idfolorig,
  });

  final String idfol;
  final int? clien;
  final String? doc;
  final DateTime? fcn;
  final String? suc;
  final String? ter;
  final String? tra;
  final String? opv;
  final String? esta;
  final double? impt;
  final String? fpgo;
  final double? impp;
  final String? aut;
  final int? reqf;
  final DateTime? fcnm;
  final String? opvm;
  final int? mod;
  final String? idfolorig;

  factory PvCtrFolAsvrModel.fromJson(Map<String, dynamic> json) {
    return PvCtrFolAsvrModel(
      idfol: json['IDFOL']?.toString() ?? '',
      clien: _asInt(json['CLIEN']),
      doc: json['DOC']?.toString(),
      fcn: _asDate(json['FCN']),
      suc: json['SUC']?.toString(),
      ter: json['TER']?.toString(),
      tra: json['TRA']?.toString(),
      opv: json['OPV']?.toString(),
      esta: json['ESTA']?.toString(),
      impt: _asDouble(json['IMPT']),
      fpgo: json['FPGO']?.toString(),
      impp: _asDouble(json['IMPP']),
      aut: json['AUT']?.toString(),
      reqf: _asInt(json['REQF']),
      fcnm: _asDate(json['FCNM']),
      opvm: json['OPVM']?.toString(),
      mod: _asInt(json['MOD']),
      idfolorig: json['IDFOLORIG']?.toString(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

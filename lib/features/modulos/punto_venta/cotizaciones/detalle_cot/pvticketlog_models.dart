class PvTicketLogItem {
  PvTicketLogItem({
    required this.id,
    this.idfol,
    this.upc,
    this.art,
    this.des,
    this.ctd,
    this.pvta,
    this.pvtat,
    this.ord,
    this.iddev,
    this.ctdd,
    this.ctddf,
    this.updatedAt,
  });

  final String id;
  final String? idfol;
  final String? upc;
  final String? art;
  final String? des;
  final double? ctd;
  final double? pvta;
  final double? pvtat;
  final String? ord;
  final String? iddev;
  final double? ctdd;
  final double? ctddf;
  final DateTime? updatedAt;

  factory PvTicketLogItem.fromJson(Map<String, dynamic> json) {
    return PvTicketLogItem(
      id: json['ID']?.toString() ?? '',
      idfol: json['IDFOL']?.toString(),
      upc: json['UPC']?.toString(),
      art: json['ART']?.toString(),
      des: json['DES']?.toString(),
      ctd: _asDouble(json['CTD']),
      pvta: _asDouble(json['PVTA']),
      pvtat: _asDouble(json['PVTAT']),
      ord: json['ORD']?.toString(),
      iddev: json['IDDEV']?.toString(),
      ctdd: _asDouble(json['CTDD']),
      ctddf: _asDouble(json['CTDDF']),
      updatedAt: _asDate(json['UPDATED_AT']),
    );
  }

  Map<String, dynamic> toJson() => {
        'ID': id,
        'IDFOL': idfol,
        'UPC': upc,
        'ART': art,
        'DES': des,
        'CTD': ctd,
        'PVTA': pvta,
        'PVTAT': pvtat,
        'ORD': ord,
        'IDDEV': iddev,
        'CTDD': ctdd,
        'CTDDF': ctddf,
        'UPDATED_AT': updatedAt?.toIso8601String(),
      };

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

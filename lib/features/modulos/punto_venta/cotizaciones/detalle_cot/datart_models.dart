class DatArtModel {
  DatArtModel({
    required this.suc,
    required this.art,
    required this.upc,
    this.des,
    this.stock,
    this.pvta,
    this.bloq,
  });

  final String suc;
  final String art;
  final String upc;
  final String? des;
  final double? stock;
  final double? pvta;
  final double? bloq;

  factory DatArtModel.fromJson(Map<String, dynamic> json) {
    return DatArtModel(
      suc: json['SUC']?.toString() ?? '',
      art: json['ART']?.toString() ?? '',
      upc: json['UPC']?.toString() ?? '',
      des: json['DES']?.toString(),
      stock: _asDouble(json['STOCK']),
      pvta: _asDouble(json['PVTA']),
      bloq: _asDouble(json['BLOQ'] ?? json['bloq']),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

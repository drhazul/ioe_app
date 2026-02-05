class DatCatUsoModel {
  final String usoCfdi;
  final String? descripcion;

  const DatCatUsoModel({required this.usoCfdi, this.descripcion});

  factory DatCatUsoModel.fromJson(Map<String, dynamic> json) {
    return DatCatUsoModel(
      usoCfdi: json['UsoCFDI'] as String? ?? json['USOCFDI'] as String,
      descripcion: json['Descripcion'] as String? ?? json['DESCRIPCION'] as String?,
    );
  }
}

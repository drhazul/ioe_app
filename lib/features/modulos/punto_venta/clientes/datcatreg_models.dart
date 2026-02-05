class DatCatRegModel {
  final int codigo;
  final String? descripcion;

  const DatCatRegModel({required this.codigo, this.descripcion});

  factory DatCatRegModel.fromJson(Map<String, dynamic> json) {
    final raw = json['C_RegimenFiscal'] ?? json['C_REGIMENFISCAL'];
    return DatCatRegModel(
      codigo: (raw as num).toInt(),
      descripcion: json['Descripcion'] as String? ?? json['DESCRIPCION'] as String?,
    );
  }
}

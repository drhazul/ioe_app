class DatModuloModel {
  final int id;
  final String codigo;
  final String nombre;
  final String? depto;
  final bool activo;
  final DateTime? fcrn;

  const DatModuloModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.depto,
    required this.activo,
    required this.fcrn,
  });

  factory DatModuloModel.fromJson(Map<String, dynamic> json) {
    final activoRaw = json['ACTIVO'];
    return DatModuloModel(
      id: (json['IDMOD_FRONT'] as num?)?.toInt() ?? 0,
      codigo: json['CODIGO'] as String,
      nombre: json['NOMBRE'] as String,
      depto: json['DEPTO'] as String?,
      activo: activoRaw == true || activoRaw == 1,
      fcrn: json['FCNR'] != null ? DateTime.tryParse(json['FCNR'] as String) : null,
    );
  }

  Map<String, dynamic> toPayload({bool includeCodigo = true}) {
    return {
      if (includeCodigo) 'CODIGO': codigo,
      'NOMBRE': nombre,
      'DEPTO': depto,
      'ACTIVO': activo,
      if (fcrn != null) 'FCNR': fcrn!.toIso8601String(),
    };
  }
}

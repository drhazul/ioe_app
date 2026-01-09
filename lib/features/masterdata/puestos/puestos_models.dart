class PuestoModel {
  final int id;
  final int idDepto;
  final String nombre;
  final bool activo;
  final String? deptoNombre;

  const PuestoModel({
    required this.id,
    required this.idDepto,
    required this.nombre,
    required this.activo,
    this.deptoNombre,
  });

  factory PuestoModel.fromJson(Map<String, dynamic> json) {
    final depto = json['DEPARTAMENTO'] as Map<String, dynamic>?;
    return PuestoModel(
      id: json['IDPUESTO'] as int,
      idDepto: json['IDDEPTO'] as int,
      nombre: json['NOMBRE'] as String,
      activo: json['ACTIVO'] == true,
      deptoNombre: depto?['NOMBRE'] as String?,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'IDDEPTO': idDepto,
      'NOMBRE': nombre,
      'ACTIVO': activo,
    };
  }
}

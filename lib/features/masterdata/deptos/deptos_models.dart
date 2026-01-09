class DeptoModel {
  final int id;
  final String nombre;
  final bool activo;

  const DeptoModel({
    required this.id,
    required this.nombre,
    required this.activo,
  });

  factory DeptoModel.fromJson(Map<String, dynamic> json) {
    return DeptoModel(
      id: json['IDDEPTO'] as int,
      nombre: json['NOMBRE'] as String,
      activo: json['ACTIVO'] == true,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'NOMBRE': nombre,
      'ACTIVO': activo,
    };
  }
}

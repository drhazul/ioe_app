class RoleModel {
  final int id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final int? iddepartamento;
  final bool activo;

  const RoleModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.iddepartamento,
    required this.activo,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['IDROL'] as int,
      codigo: json['CODIGO'] as String,
      nombre: json['NOMBRE'] as String,
      descripcion: json['DESCRIPCION'] as String?,
      iddepartamento: json['IDDEPTO'] as int?,
      activo: json['ACTIVO'] == true,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'CODIGO': codigo,
      'NOMBRE': nombre,
      if (descripcion != null) 'DESCRIPCION': descripcion,
      if (iddepartamento != null) 'IDDEPTO': iddepartamento,
      'ACTIVO': activo,
    };
  }

  RoleModel copyWith({
    int? id,
    String? codigo,
    String? nombre,
    String? descripcion,
    int? iddepartamento,
    bool? activo,
  }) {
    return RoleModel(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      iddepartamento: iddepartamento ?? this.iddepartamento,
      activo: activo ?? this.activo,
    );
  }
}

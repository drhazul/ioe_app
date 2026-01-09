class UserModel {
  final int id;
  final String username;
  final String? nombre;
  final String? apellidos;
  final String mail;
  final String estatus;
  final int nivel;
  final int idRol;
  final int? idDepto;
  final int? idPuesto;
  final String? suc;
  final String? rolNombre;
  final String? deptoNombre;
  final String? puestoNombre;

  const UserModel({
    required this.id,
    required this.username,
    required this.nombre,
    required this.apellidos,
    required this.mail,
    required this.estatus,
    required this.nivel,
    required this.idRol,
    required this.idDepto,
    required this.idPuesto,
    required this.suc,
    required this.rolNombre,
    required this.deptoNombre,
    required this.puestoNombre,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rol = json['ROL'] as Map<String, dynamic>?;
    final depto = json['DEPARTAMENTO'] as Map<String, dynamic>?;
    final puesto = json['PUESTO'] as Map<String, dynamic>?;

    return UserModel(
      id: json['IDUSUARIO'] as int,
      username: json['USERNAME'] as String,
      nombre: json['NOMBRE'] as String?,
      apellidos: json['APELLIDOS'] as String?,
      mail: json['MAIL'] as String,
      estatus: json['ESTATUS'] as String,
      nivel: (json['NIVEL'] as num).toInt(),
      idRol: json['IDROL'] as int,
      idDepto: json['IDDEPTO'] as int?,
      idPuesto: json['IDPUESTO'] as int?,
      suc: json['SUC'] as String?,
      rolNombre: rol != null ? (rol['NOMBRE'] as String? ?? rol['CODIGO'] as String?) : null,
      deptoNombre: depto?['NOMBRE'] as String?,
      puestoNombre: puesto?['NOMBRE'] as String?,
    );
  }

  String get displayName {
    if ((nombre ?? '').isEmpty && (apellidos ?? '').isEmpty) return username;
    return [nombre, apellidos].where((p) => p != null && p.isNotEmpty).join(' ');
  }
}

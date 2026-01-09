class AccessModulo {
  final int id;
  final String codigo;
  final String nombre;
  final bool activo;

  const AccessModulo({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.activo,
  });

  factory AccessModulo.fromJson(Map<String, dynamic> json) => AccessModulo(
        id: (json['IDMODULO'] as num).toInt(),
        codigo: json['CODIGO'] as String,
        nombre: json['NOMBRE'] as String,
        activo: json['ACTIVO'] == true || json['ACTIVO'] == 1,
      );
}

class AccessGrupoModulo {
  final int id;
  final String nombre;
  final bool activo;

  const AccessGrupoModulo({
    required this.id,
    required this.nombre,
    required this.activo,
  });

  factory AccessGrupoModulo.fromJson(Map<String, dynamic> json) => AccessGrupoModulo(
        id: (json['IDGRUP_MODULO'] as num).toInt(),
        nombre: json['NOMBRE'] as String,
        activo: json['ACTIVO'] == true || json['ACTIVO'] == 1,
      );
}

class AccessModuloFront {
  final int id;
  final String codigo;
  final String nombre;
  final String? depto;
  final bool activo;

  const AccessModuloFront({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.depto,
    required this.activo,
  });

  factory AccessModuloFront.fromJson(Map<String, dynamic> json) => AccessModuloFront(
        id: (json['IDMOD_FRONT'] as num).toInt(),
        codigo: json['CODIGO'] as String,
        nombre: json['NOMBRE'] as String,
        depto: json['DEPTO'] as String?,
        activo: json['ACTIVO'] == true || json['ACTIVO'] == 1,
      );
}

class AccessGrupoFront {
  final int id;
  final String nombre;
  final bool activo;

  const AccessGrupoFront({
    required this.id,
    required this.nombre,
    required this.activo,
  });

  factory AccessGrupoFront.fromJson(Map<String, dynamic> json) => AccessGrupoFront(
        id: (json['IDGRUPMOD_FRONT'] as num).toInt(),
        nombre: json['NOMBRE'] as String,
        activo: json['ACTIVO'] == true || json['ACTIVO'] == 1,
      );
}

class AccessRole {
  final int id;
  final String codigo;
  final String nombre;
  final bool activo;

  const AccessRole({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.activo,
  });

  factory AccessRole.fromJson(Map<String, dynamic> json) => AccessRole(
        id: (json['IDROL'] as num).toInt(),
        codigo: json['CODIGO'] as String,
        nombre: json['NOMBRE'] as String,
        activo: json['ACTIVO'] == true || json['ACTIVO'] == 1,
      );
}

class BackendModuloRef {
  final int id;
  final String codigo;
  final String nombre;

  const BackendModuloRef({
    required this.id,
    required this.codigo,
    required this.nombre,
  });

  factory BackendModuloRef.fromJson(Map<String, dynamic> json) => BackendModuloRef(
        id: (json['idModulo'] as num).toInt(),
        codigo: json['codigo'] as String,
        nombre: json['nombre'] as String,
      );
}

class BackendGroupPerm {
  final int idGrupModulo;
  final String grupoNombre;
  final bool canRead;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;
  final bool activo;
  final List<BackendModuloRef> modulos;

  const BackendGroupPerm({
    required this.idGrupModulo,
    required this.grupoNombre,
    required this.canRead,
    required this.canCreate,
    required this.canUpdate,
    required this.canDelete,
    required this.activo,
    required this.modulos,
  });

  factory BackendGroupPerm.fromJson(Map<String, dynamic> json) => BackendGroupPerm(
        idGrupModulo: (json['idGrupModulo'] as num).toInt(),
        grupoNombre: json['grupoNombre'] as String,
        canRead: json['canRead'] == true || json['canRead'] == 1,
        canCreate: json['canCreate'] == true || json['canCreate'] == 1,
        canUpdate: json['canUpdate'] == true || json['canUpdate'] == 1,
        canDelete: json['canDelete'] == true || json['canDelete'] == 1,
        activo: json['activo'] == true || json['activo'] == 1,
        modulos: (json['modulos'] as List<dynamic>)
            .map((e) => BackendModuloRef.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  BackendGroupPerm copyWith({
    bool? canRead,
    bool? canCreate,
    bool? canUpdate,
    bool? canDelete,
    bool? activo,
  }) {
    return BackendGroupPerm(
      idGrupModulo: idGrupModulo,
      grupoNombre: grupoNombre,
      canRead: canRead ?? this.canRead,
      canCreate: canCreate ?? this.canCreate,
      canUpdate: canUpdate ?? this.canUpdate,
      canDelete: canDelete ?? this.canDelete,
      activo: activo ?? this.activo,
      modulos: modulos,
    );
  }
}

class FrontModuloRef {
  final int id;
  final String codigo;
  final String nombre;
  final String? depto;

  const FrontModuloRef({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.depto,
  });

  factory FrontModuloRef.fromJson(Map<String, dynamic> json) => FrontModuloRef(
        id: (json['idModFront'] as num).toInt(),
        codigo: json['codigo'] as String,
        nombre: json['nombre'] as String,
        depto: json['depto'] as String?,
      );
}

class FrontGroupEnrollment {
  final int idGrupmodFront;
  final String grupoNombre;
  final bool activo;
  final List<FrontModuloRef> mods;

  const FrontGroupEnrollment({
    required this.idGrupmodFront,
    required this.grupoNombre,
    required this.activo,
    required this.mods,
  });

  factory FrontGroupEnrollment.fromJson(Map<String, dynamic> json) => FrontGroupEnrollment(
        idGrupmodFront: (json['idGrupmodFront'] as num).toInt(),
        grupoNombre: json['grupoNombre'] as String,
        activo: json['activo'] == true || json['activo'] == 1,
        mods: (json['mods'] as List<dynamic>)
            .map((e) => FrontModuloRef.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

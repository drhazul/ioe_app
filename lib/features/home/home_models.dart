class HomeModule {
  final String codigo;
  final String nombre;
  final String? depto;
  final bool activo;

  const HomeModule({
    required this.codigo,
    required this.nombre,
    required this.depto,
    required this.activo,
  });

  factory HomeModule.fromJson(Map<String, dynamic> json) {
    final activoRaw = json['activo'];
    return HomeModule(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      depto: json['depto'] as String?,
      activo: activoRaw == null ? true : (activoRaw == true || activoRaw == 1),
    );
  }
}

class HomeModulesResponse {
  final int roleId;
  final bool accesoTotal;
  final List<HomeModule> modulos;

  const HomeModulesResponse({
    required this.roleId,
    required this.accesoTotal,
    required this.modulos,
  });

  factory HomeModulesResponse.fromJson(Map<String, dynamic> json) => HomeModulesResponse(
        roleId: (json['roleId'] as num).toInt(),
        accesoTotal: json['accesoTotal'] as bool,
        modulos: (json['modulos'] as List<dynamic>)
            .map((e) => HomeModule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  factory HomeModulesResponse.fromMenu(List<dynamic> list) => HomeModulesResponse(
        roleId: 0,
        accesoTotal: false,
        modulos: list.map((e) => HomeModule.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

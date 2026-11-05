class EmpresaCreditosConfig {
  EmpresaCreditosConfig.fromJson(Map<String, dynamic> json)
    : modo = (json['credito'] as Map)['MODO'] as String,
      permitir = (json['credito'] as Map)['permitir'] == true,
      version = (json['credito'] as Map)['version'] as String,
      sucursales = (json['sucursales'] as List)
          .map(
            (row) => SucursalCreditosConfig.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

  final String modo;
  final bool permitir;
  final String version;
  final List<SucursalCreditosConfig> sucursales;
}

class SucursalCreditosConfig {
  SucursalCreditosConfig.fromJson(Map<String, dynamic> json)
    : suc = json['suc'] as String,
      descripcion = json['descripcion']?.toString() ?? '',
      permitir = json['permitir'] as bool?,
      efectivo = json['efectivo'] == true,
      version = json['version'] as String;

  final String suc;
  final String descripcion;
  final bool? permitir;
  final bool efectivo;
  final String version;
}

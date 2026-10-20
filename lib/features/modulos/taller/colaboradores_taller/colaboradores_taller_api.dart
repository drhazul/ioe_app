import 'package:dio/dio.dart';

class ColaboradorTaller {
  const ColaboradorTaller({
    required this.idopv,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.apellidos,
    required this.suc,
    required this.departamento,
    required this.estatus,
  });

  final String idopv;
  final String nombre;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String apellidos;
  final String suc;
  final String departamento;
  final String estatus;

  factory ColaboradorTaller.fromJson(Map<String, dynamic> json) {
    String text(String key) =>
        (json[key] ?? json[key.toUpperCase()] ?? '').toString().trim();
    return ColaboradorTaller(
      idopv: text('idopv'),
      nombre: text('nomb'),
      apellidoPaterno: text('apelp'),
      apellidoMaterno: text('apelm'),
      apellidos: '${text('apelp')} ${text('apelm')}'.trim(),
      suc: text('suc'),
      departamento: text('depto'),
      estatus: text('estatus').isEmpty ? 'INACTIVO' : text('estatus'),
    );
  }
}

class ColaboradoresTallerApi {
  ColaboradoresTallerApi(this.dio);
  final Dio dio;

  Future<ColaboradoresTallerResultado> listar() async {
    final response = await dio.get('/ordenes-trabajo/taller-colaboradores');
    final data = Map<String, dynamic>.from(response.data as Map);
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ColaboradorTaller.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    final sucursales = (data['sucursales'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => SucursalTaller.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.codigo.isNotEmpty)
        .toList(growable: false);
    return ColaboradoresTallerResultado(items: items, sucursales: sucursales);
  }

  Future<void> crear({
    required String nombre,
    required String apelp,
    required String apelM,
    required String suc,
    required String departamento,
  }) async {
    await dio.post(
      '/ordenes-trabajo/taller-colaboradores',
      data: {
        'nomb': nombre,
        'apelp': apelp,
        'apelm': apelM,
        'suc': suc,
        'depto': departamento,
      },
    );
  }

  Future<void> actualizar({
    required String idopv,
    required String nombre,
    required String apelp,
    required String apelM,
    required String suc,
    required String departamento,
  }) async {
    await dio.patch(
      '/ordenes-trabajo/taller-colaboradores/${Uri.encodeComponent(idopv)}',
      data: {
        'nomb': nombre,
        'apelp': apelp,
        'apelm': apelM,
        'suc': suc,
        'depto': departamento,
      },
    );
  }

  Future<void> cambiarEstatus(String idopv, bool activo) async {
    await dio.patch(
      '/ordenes-trabajo/taller-colaboradores/${Uri.encodeComponent(idopv)}/estatus',
      data: {'estatus': activo ? 'ACTIVO' : 'INACTIVO'},
    );
  }
}

class ColaboradoresTallerResultado {
  const ColaboradoresTallerResultado({
    required this.items,
    required this.sucursales,
  });
  final List<ColaboradorTaller> items;
  final List<SucursalTaller> sucursales;
}

class SucursalTaller {
  const SucursalTaller({required this.codigo, required this.nombre});
  final String codigo;
  final String nombre;

  factory SucursalTaller.fromJson(Map<String, dynamic> json) {
    String text(String key) =>
        (json[key] ?? json[key.toUpperCase()] ?? '').toString().trim();
    return SucursalTaller(codigo: text('suc'), nombre: text('desc'));
  }
}

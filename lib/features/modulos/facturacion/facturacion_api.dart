import 'package:dio/dio.dart';

class FacturacionApi {
  FacturacionApi(this.dio);

  final Dio dio;

  Future<List<Map<String, dynamic>>> fetchPendientes() async {
    final res = await dio.get('/facturacion/pendientes');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> validar(int idFol) async {
    final res = await dio.get('/facturacion/$idFol/validar');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> emitir(int idFol) async {
    final res = await dio.post('/facturacion/$idFol/emitir', data: const {});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> reenviarEmail(int idFol, {String? email}) async {
    final res = await dio.post('/facturacion/$idFol/reenviar-email', data: {
      if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> cancelar(int idFol, {String? motivo}) async {
    final res = await dio.post('/facturacion/$idFol/cancelar', data: {
      if ((motivo ?? '').trim().isNotEmpty) 'motivo': motivo!.trim(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}

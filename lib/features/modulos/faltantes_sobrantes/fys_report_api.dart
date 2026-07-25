import 'package:dio/dio.dart';

class FysReportApi {
  FysReportApi(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> catalogos() async {
    final response = await dio.get('/faltantes-sobrantes/reportes/catalogos');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>?> ajustes({
    required int suc,
    required String qna,
  }) async {
    final response = await dio.get(
      '/faltantes-sobrantes/reportes/ajustes',
      queryParameters: {'suc': suc, 'qna': qna},
    );
    if (response.data == null) return null;
    return Map<String, dynamic>.from(response.data as Map);
  }
}

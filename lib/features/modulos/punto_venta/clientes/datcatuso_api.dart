import 'package:dio/dio.dart';
import 'package:ioe_app/core/storage.dart';

import 'datcatuso_models.dart';

class DatCatUsoApi {
  final Dio dio;
  final Storage storage;
  DatCatUsoApi(this.dio, this.storage);

  Future<List<DatCatUsoModel>> fetchUsos() async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/datcatuso',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (res.data as List<dynamic>)
        .map((e) => DatCatUsoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }
}

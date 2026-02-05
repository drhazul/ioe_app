import 'package:dio/dio.dart';
import 'package:ioe_app/core/storage.dart';

import 'datcatreg_models.dart';

class DatCatRegApi {
  final Dio dio;
  final Storage storage;
  DatCatRegApi(this.dio, this.storage);

  Future<List<DatCatRegModel>> fetchRegimenes() async {
    final token = await storage.getAccessToken();
    final res = await dio.get(
      '/datcatreg',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (res.data as List<dynamic>)
        .map((e) => DatCatRegModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }
}

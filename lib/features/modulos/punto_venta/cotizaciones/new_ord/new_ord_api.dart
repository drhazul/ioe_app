import 'package:dio/dio.dart';

import 'new_ord_models.dart';

class NewOrdApi {
  NewOrdApi(this.dio);

  final Dio dio;

  Future<CreateOrdFromQuoteLineResponse> createFromQuoteLine(
    CreateOrdFromQuoteLineRequest payload,
  ) async {
    final res = await dio.post(
      '/pvctrords/create-from-quote-line',
      data: payload.toJson(),
    );
    return CreateOrdFromQuoteLineResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<Map<String, dynamic>> fetchOrd(String iord) async {
    final res = await dio.get('/pvctrords/$iord');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<DeleteOrdFromQuoteLineResponse> deleteFromQuoteLine(
    DeleteOrdFromQuoteLineRequest payload,
  ) async {
    final res = await dio.post(
      '/pvctrords/delete-from-quote-line',
      data: payload.toJson(),
    );
    return DeleteOrdFromQuoteLineResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }
}

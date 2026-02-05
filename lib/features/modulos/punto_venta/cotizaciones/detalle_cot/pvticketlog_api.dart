import 'package:dio/dio.dart';

import 'pvticketlog_models.dart';

class PvTicketLogApi {
  PvTicketLogApi(this.dio);

  final Dio dio;

  Future<List<PvTicketLogItem>> fetchByIdfol(String idfol) async {
    final res = await dio.get(
      '/pvticketlog',
      queryParameters: {
        'idfol': idfol,
        '_': DateTime.now().millisecondsSinceEpoch,
      },
    );
    final list = (res.data as List<dynamic>)
        .map((e) => PvTicketLogItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }

  Future<PvTicketLogItem> create(PvTicketLogItem item) async {
    final res = await dio.post('/pvticketlog', data: item.toJson());
    return PvTicketLogItem.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PvTicketLogItem> update(String id, Map<String, dynamic> data) async {
    final res = await dio.patch('/pvticketlog/$id', data: data);
    return PvTicketLogItem.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> remove(String id) async {
    await dio.delete('/pvticketlog/$id');
  }
}

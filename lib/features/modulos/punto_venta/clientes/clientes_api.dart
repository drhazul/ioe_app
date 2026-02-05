import 'package:dio/dio.dart';

import 'clientes_models.dart';

class ClientesApi {
  final Dio dio;
  ClientesApi(this.dio);

  Future<List<FactClientShpModel>> fetchClientes() async {
    final res = await dio.get('/factclientshp', queryParameters: {'_': DateTime.now().millisecondsSinceEpoch});
    final list = (res.data as List<dynamic>)
        .map((e) => FactClientShpModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<FactClientShpModel> fetchCliente(String id) async {
    final res = await dio.get('/factclientshp/$id', queryParameters: {'_': DateTime.now().millisecondsSinceEpoch});
    return FactClientShpModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<FactClientShpModel> createCliente(Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.post('/factclientshp', data: body);
    return FactClientShpModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<FactClientShpModel> updateCliente(String id, Map<String, dynamic> payload) async {
    final body = _clean(payload);
    final res = await dio.patch('/factclientshp/$id', data: body);
    return FactClientShpModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Map<String, dynamic> _clean(Map<String, dynamic> payload) {
    return Map<String, dynamic>.from(payload);
  }
}

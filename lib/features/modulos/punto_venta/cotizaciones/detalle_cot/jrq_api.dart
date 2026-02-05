import 'package:dio/dio.dart';

import 'jrq_models.dart';

class JrqApi {
  JrqApi(this.dio);

  final Dio dio;

  Future<List<JrqDepaModel>> fetchDepa() async {
    final res = await dio.get('/jrqdepa');
    return (res.data as List<dynamic>)
        .map((e) => JrqDepaModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<JrqSubdModel>> fetchSubd({double? depa}) async {
    final query = <String, dynamic>{};
    if (depa != null) query['depa'] = depa;
    final res = await dio.get('/jrqsubd', queryParameters: query);
    return (res.data as List<dynamic>)
        .map((e) => JrqSubdModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<JrqClasModel>> fetchClas({double? subd}) async {
    final query = <String, dynamic>{};
    if (subd != null) query['subd'] = subd;
    final res = await dio.get('/jrqclas', queryParameters: query);
    return (res.data as List<dynamic>)
        .map((e) => JrqClasModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<JrqSclaModel>> fetchScla({double? clas}) async {
    final query = <String, dynamic>{};
    if (clas != null) query['clas'] = clas;
    final res = await dio.get('/jrqscla', queryParameters: query);
    return (res.data as List<dynamic>)
        .map((e) => JrqSclaModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<JrqScla2Model>> fetchScla2({double? scla}) async {
    final query = <String, dynamic>{};
    if (scla != null) query['scla'] = scla;
    final res = await dio.get('/jrqscla2', queryParameters: query);
    return (res.data as List<dynamic>)
        .map((e) => JrqScla2Model.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<JrqGuiaModel>> fetchGuia({double? scla2}) async {
    final query = <String, dynamic>{};
    if (scla2 != null) query['scla2'] = scla2;
    final res = await dio.get('/jrqguia', queryParameters: query);
    return (res.data as List<dynamic>)
        .map((e) => JrqGuiaModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

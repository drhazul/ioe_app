import 'package:dio/dio.dart';

import 'datart_models.dart';

class DatArtApi {
  DatArtApi(this.dio);

  final Dio dio;

  Future<List<DatArtModel>> fetchArticulos({
    required String suc,
    String? art,
    String? upc,
    String? des,
    String? modelo,
    String? view,
    double? depa,
    double? subd,
    double? clas,
    double? scla,
    double? scla2,
    double? sph,
    double? cyl,
    double? adic,
    int? page,
    int? limit,
  }) async {
    final query = <String, dynamic>{'suc': suc};
    final artTrim = (art ?? '').trim();
    final upcTrim = (upc ?? '').trim();
    final desTrim = (des ?? '').trim();
    final modeloTrim = (modelo ?? '').trim();
    if (artTrim.isNotEmpty) query['art'] = artTrim;
    if (upcTrim.isNotEmpty) query['upc'] = upcTrim;
    if (desTrim.isNotEmpty) query['des'] = desTrim;
    if (modeloTrim.isNotEmpty) query['modelo'] = modeloTrim;
    if (depa != null) query['depa'] = depa;
    if (subd != null) query['subd'] = subd;
    if (clas != null) query['clas'] = clas;
    if (scla != null) query['scla'] = scla;
    if (scla2 != null) query['scla2'] = scla2;
    if (sph != null) query['sph'] = sph;
    if (cyl != null) query['cyl'] = cyl;
    if (adic != null) query['adic'] = adic;
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (view != null && view.trim().isNotEmpty) query['view'] = view.trim();
    final res = await dio.get('/datart', queryParameters: query);
    final list = (res.data as List<dynamic>)
        .map((e) => DatArtModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }
}

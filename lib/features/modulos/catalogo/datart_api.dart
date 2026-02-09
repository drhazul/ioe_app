import 'package:dio/dio.dart';

import 'datart_models.dart';

class DatArtApi {
  DatArtApi(this.dio);

  final Dio dio;

  Future<List<DatArtModel>> fetchArticulos({
    String? suc,
    String? loteId,
    String? art,
    String? upc,
    String? des,
    String? tipo,
    String? modelo,
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
    bool? withTotal,
    String? view,
  }) async {
    final query = <String, dynamic>{};
    void addIfNotEmpty(String key, String? value) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) query[key] = trimmed;
    }

    addIfNotEmpty('suc', suc);
    addIfNotEmpty('loteId', loteId);
    addIfNotEmpty('art', art);
    addIfNotEmpty('upc', upc);
    addIfNotEmpty('des', des);
    addIfNotEmpty('tipo', tipo);
    addIfNotEmpty('modelo', modelo);
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
    if (withTotal == true) query['withTotal'] = 1;
    if (view != null && view.trim().isNotEmpty) query['view'] = view.trim();

    final res = await dio.get(
      '/datart',
      queryParameters: query.isEmpty ? null : query,
    );
    if (res.data is List<dynamic>) {
      return (res.data as List<dynamic>)
          .map((e) => DatArtModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (res.data is Map<String, dynamic>) {
      final map = Map<String, dynamic>.from(res.data as Map);
      final items = (map['items'] as List<dynamic>? ?? [])
          .map((e) => DatArtModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return items;
    }
    return [];
  }

  Future<DatArtPagedResult> fetchArticulosPaged({
    String? suc,
    String? loteId,
    String? art,
    String? upc,
    String? des,
    String? tipo,
    String? modelo,
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
    String? view,
  }) async {
    final query = <String, dynamic>{};
    void addIfNotEmpty(String key, String? value) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) query[key] = trimmed;
    }

    addIfNotEmpty('suc', suc);
    addIfNotEmpty('loteId', loteId);
    addIfNotEmpty('art', art);
    addIfNotEmpty('upc', upc);
    addIfNotEmpty('des', des);
    addIfNotEmpty('tipo', tipo);
    addIfNotEmpty('modelo', modelo);
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
    query['withTotal'] = 1;
    if (view != null && view.trim().isNotEmpty) query['view'] = view.trim();

    final res = await dio.get('/datart', queryParameters: query);
    final data = Map<String, dynamic>.from(res.data as Map);
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => DatArtModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final total = (data['total'] as num?)?.toInt() ?? items.length;
    final pageNum = (data['page'] as num?)?.toInt() ?? (page ?? 1);
    final limitNum =
        (data['limit'] as num?)?.toInt() ?? (limit ?? items.length);
    return DatArtPagedResult(
      items: items,
      total: total,
      page: pageNum,
      limit: limitNum,
    );
  }

  Future<DatArtModel> fetchArticulo(String suc, String art, String upc) async {
    final res = await dio.get('/datart/$suc/$art/$upc');
    return DatArtModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatArtModel> createArticulo(Map<String, dynamic> payload) async {
    final res = await dio.post('/datart', data: _clean(payload));
    return DatArtModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatArtModel> updateArticulo(
    String suc,
    String art,
    String upc,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.patch(
      '/datart/$suc/$art/$upc',
      data: _clean(payload),
    );
    return DatArtModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteArticulo(String suc, String art, String upc) async {
    await dio.delete('/datart/$suc/$art/$upc');
  }

  Future<DatArtMassiveUploadResult> uploadModificacionMasiva({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final res = await dio.post(
      '/datart/massive-upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return DatArtMassiveUploadResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<AltaMasivaUploadResult> uploadAltaMasiva({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final res = await dio.post(
      '/articulos/alta-masiva/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return AltaMasivaUploadResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<AltaMasivaPreviewResult> previewAltaMasiva({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final res = await dio.post(
      '/articulos/alta-masiva/preview',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return AltaMasivaPreviewResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<AltaMasivaValidationResult> validateAltaMasiva({
    required String batchId,
  }) async {
    final res = await dio.post(
      '/articulos/alta-masiva/validate',
      data: {'batchId': batchId},
    );
    return AltaMasivaValidationResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<AltaMasivaCommitResult> commitAltaMasiva({
    required String batchId,
  }) async {
    final res = await dio.post(
      '/articulos/alta-masiva/commit',
      data: {'batchId': batchId},
    );
    return AltaMasivaCommitResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Map<String, dynamic> _clean(Map<String, dynamic> payload) =>
      Map<String, dynamic>.from(payload);
}

class DatArtPagedResult {
  DatArtPagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<DatArtModel> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;
}

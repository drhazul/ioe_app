import 'package:dio/dio.dart';

import 'inventarios_models.dart';

class InventariosApi {
  final Dio dio;
  InventariosApi(this.dio);

  Future<List<DatContCtrlModel>> fetchAll({String? suc}) async {
    final query = <String, dynamic>{};
    final normalizedSuc = suc?.trim();
    if (normalizedSuc != null && normalizedSuc.isNotEmpty) {
      query['suc'] = normalizedSuc;
    }
    final res = await dio.get('/conteos', queryParameters: query.isEmpty ? null : query);
    return (res.data as List<dynamic>)
        .map((e) => DatContCtrlModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DatContCtrlModel> fetchOne(String tokenreg) async {
    final res = await dio.get('/datcontctrl/${Uri.encodeComponent(tokenreg)}');
    return DatContCtrlModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatContCtrlModel> create(Map<String, dynamic> payload) async {
    final res = await dio.post('/datcontctrl', data: Map<String, dynamic>.from(payload));
    return DatContCtrlModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatContCtrlModel> update(String tokenreg, Map<String, dynamic> payload) async {
    final res = await dio.patch('/datcontctrl/${Uri.encodeComponent(tokenreg)}', data: Map<String, dynamic>.from(payload));
    return DatContCtrlModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> delete(String tokenreg) async {
    await dio.delete('/datcontctrl/${Uri.encodeComponent(tokenreg)}');
  }

  Future<ConteoUploadResult> uploadItems({
    required String cont,
    required List<int> bytes,
    required String filename,
    String? suc,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final query = <String, dynamic>{};
    final normalizedSuc = suc?.trim();
    if (normalizedSuc != null && normalizedSuc.isNotEmpty) {
      query['suc'] = normalizedSuc;
    }

    final res = await dio.post(
      '/conteos/${Uri.encodeComponent(cont)}/upload-items',
      data: form,
      queryParameters: query.isEmpty ? null : query,
      options: Options(contentType: 'multipart/form-data'),
    );

    return ConteoUploadResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ConteoProcessResult> processConteo(String cont, {String? suc}) async {
    final query = <String, dynamic>{};
    final normalizedSuc = suc?.trim();
    if (normalizedSuc != null && normalizedSuc.isNotEmpty) {
      query['suc'] = normalizedSuc;
    }
    final res = await dio.post(
      '/conteos/${Uri.encodeComponent(cont)}/process',
      queryParameters: query.isEmpty ? null : query,
    );
    return ConteoProcessResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ConteoApplyAdjustmentResult> applyAdjustment(String cont, {String? suc}) async {
    final query = <String, dynamic>{};
    final normalizedSuc = suc?.trim();
    if (normalizedSuc != null && normalizedSuc.isNotEmpty) {
      query['suc'] = normalizedSuc;
    }

    final res = await dio.post(
      '/conteos/${Uri.encodeComponent(cont)}/apply-adjustment',
      queryParameters: query.isEmpty ? null : query,
    );
    return ConteoApplyAdjustmentResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ConteoDetResponse> fetchDetalles(String cont, {int page = 1, int limit = 50, String? suc}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    final normalizedSuc = suc?.trim();
    if (normalizedSuc != null && normalizedSuc.isNotEmpty) {
      query['suc'] = normalizedSuc;
    }
    final res = await dio.get('/conteos/${Uri.encodeComponent(cont)}/det', queryParameters: query);
    return ConteoDetResponse.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatDetSvrModel> updateDetalleExt({required int id, required bool value}) async {
    final res = await dio.patch('/datdetsvr/$id', data: {'EXT': value ? 1 : 0});
    return DatDetSvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ConteoSummaryModel> fetchDetalleSummary(String cont, {String? suc}) async {
    final query = <String, dynamic>{};
    final normalizedSuc = suc?.trim();
    if (normalizedSuc != null && normalizedSuc.isNotEmpty) {
      query['suc'] = normalizedSuc;
    }
    final res = await dio.get(
      '/conteos/${Uri.encodeComponent(cont)}/summary',
      queryParameters: query.isEmpty ? null : query,
    );
    return ConteoSummaryModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}

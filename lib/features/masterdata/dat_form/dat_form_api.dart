import 'package:dio/dio.dart';

import 'dat_form_models.dart';

class DatFormApi {
  DatFormApi(this.dio);

  final Dio dio;

  Future<List<DatFormModel>> fetchDatForms({
    String? form,
    String? nom,
    bool includeInactive = true,
    bool? estado,
  }) async {
    final query = <String, dynamic>{};
    if (includeInactive) query['includeInactive'] = 'true';
    if (form != null && form.trim().isNotEmpty) query['form'] = form.trim();
    if (nom != null && nom.trim().isNotEmpty) query['nom'] = nom.trim();
    if (estado != null) query['estado'] = estado.toString();

    final res = await dio.get(
      '/dat-form',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data is! List) return const [];

    return data
        .map(
          (row) => DatFormModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .where((item) => item.idform > 0 && item.form.isNotEmpty)
        .toList();
  }

  Future<DatFormModel> fetchDatForm(int idform) async {
    final res = await dio.get('/dat-form/$idform');
    return DatFormModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatFormModel> createDatForm(Map<String, dynamic> payload) async {
    final res = await dio.post('/dat-form', data: _cleanPayload(payload));
    return DatFormModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DatFormModel> updateDatForm(
    int idform,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.patch(
      '/dat-form/$idform',
      data: _cleanPayload(payload),
    );
    return DatFormModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> updateDatFormEstado(int idform, bool estado) async {
    await dio.patch('/dat-form/$idform/estado', data: {'estado': estado});
  }

  Future<void> deleteDatForm(int idform) async {
    await dio.delete('/dat-form/$idform');
  }

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> payload) {
    final body = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (entry.key.trim().isEmpty) continue;
      body[entry.key] = entry.value;
    }
    return body;
  }
}

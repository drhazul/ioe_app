import 'package:dio/dio.dart';

import 'reloj_checador_app_models.dart';

class RelojChecadorAppApi {
  RelojChecadorAppApi(this.dio);

  final Dio dio;

  Future<RelojChecadorContext> getContext({String? suc}) async {
    final query = <String, dynamic>{};
    final sucNorm = (suc ?? '').trim();
    if (sucNorm.isNotEmpty) query['suc'] = sucNorm;

    final res = await dio.get(
      '/reloj-checador/context',
      queryParameters: query.isEmpty ? null : query,
    );

    if (res.data is Map) {
      return RelojChecadorContext.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      error: 'Respuesta invalida de contexto reloj-checador',
      type: DioExceptionType.badResponse,
    );
  }

  Future<TimelogCreateResponse> createTimelog(
    TimelogCreateRequest payload,
  ) async {
    final res = await dio.post(
      '/reloj-checador/timelog',
      data: payload.toJson(),
    );

    if (res.data is Map) {
      return TimelogCreateResponse.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      error: 'Respuesta invalida al crear marcaje',
      type: DioExceptionType.badResponse,
    );
  }
}

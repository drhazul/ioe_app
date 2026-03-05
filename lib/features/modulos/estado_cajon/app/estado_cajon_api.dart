import 'package:dio/dio.dart';

import 'estado_cajon_models.dart';

class EstadoCajonApi {
  EstadoCajonApi(this.dio);

  final Dio dio;

  Future<EstadoCajonAuthorizationSession> autorizarSupervisor({
    required String passwordSupervisor,
  }) async {
    final password = passwordSupervisor.trim();
    final res = await dio.post(
      '/cajon-estado/autorizar',
      data: {'passwordSupervisor': password},
    );
    final data = _toMap(res.data);
    final session = EstadoCajonAuthorizationSession.fromJson(data);
    if (session.authorizationToken.isEmpty) {
      throw Exception('No se recibió authorizationToken de supervisor.');
    }
    return session;
  }

  Future<List<EstadoCajonResumenRow>> fetchResumen({
    required DateTime fecha,
    required String authorizationToken,
  }) async {
    final token = authorizationToken.trim();
    if (token.isEmpty) {
      throw Exception('Falta token de autorización de supervisor.');
    }

    final fechaParam = _formatSqlDate(fecha);
    final res = await dio.get(
      '/cajon-estado/resumen',
      queryParameters: {'fecha': fechaParam},
      options: Options(
        headers: {'X-Cajon-Estado-Token': token},
      ),
    );

    final raw = res.data;
    final List items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = (raw['items'] as List?) ?? const [];
    } else {
      items = const [];
    }

    return items
        .map(
          (row) => EstadoCajonResumenRow.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  String _formatSqlDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final y = normalized.year.toString().padLeft(4, '0');
    final m = normalized.month.toString().padLeft(2, '0');
    final d = normalized.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}

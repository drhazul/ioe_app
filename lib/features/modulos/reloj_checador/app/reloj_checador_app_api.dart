import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/env.dart';
import 'attendance_security_service.dart';
import 'attendance_signature.dart';
import 'reloj_checador_app_models.dart';

class RelojChecadorAppApi {
  RelojChecadorAppApi(this.dio);

  final Dio dio;
  late final AttendanceSecurityService _securityService = AttendanceSecurityService();
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static const _kEssToken = 'ess_last_token';
  static const _kEssUserJson = 'ess_last_user_json';

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
    throw _badResponse(res, 'Respuesta invalida de contexto reloj-checador');
  }

  Future<TimelogCreateResponse> createTimelog(
    TimelogCreateRequest payload,
  ) async {
    final body = payload.toJson();
    final deviceId = (payload.deviceId ?? '').trim();
    if (deviceId.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/reloj-checador/timelog'),
        type: DioExceptionType.badResponse,
        error: 'DEVICE_ID_REQUIRED',
        message: 'No se puede marcar sin device_id.',
      );
    }

    final signature = buildAttendanceSignature(
      deviceId: deviceId,
      body: body,
      secret: Env.attendanceHmacSecret,
    );
    final res = await _requestWithBackoff(
      () => dio.post(
        '/reloj-checador/timelog',
        data: body,
        options: Options(
          headers: {
            'X-Device-Id': deviceId,
            'X-Client-Timestamp': DateTime.now().toIso8601String(),
            'X-Signature': signature,
          },
        ),
      ),
      retryLabel: 'createTimelog',
    );

    if (res.data is Map) {
      return TimelogCreateResponse.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    }
    throw _badResponse(res, 'Respuesta invalida al crear marcaje');
  }

  Future<List<MarcajeSqlModel>> getMarcajesHistorialByUsuario(
    int idUsuario,
  ) async {
    final res = await dio.get('/reloj-checador/historial/$idUsuario');
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta inválida historial de marcajes');
    }
    return (res.data as List)
        .whereType<Map>()
        .map((row) => MarcajeSqlModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> createTimelogQueued(
    Map<String, dynamic> payload,
    Map<String, dynamic> headers,
  ) async {
    final deviceId =
        (headers['X-Device-Id'] ??
                payload['device_id'] ??
                payload['DEVICE_ID'] ??
                '')
        .toString()
        .trim();
    final signature = buildAttendanceSignature(
      deviceId: deviceId,
      body: payload,
      secret: Env.attendanceHmacSecret,
    );

    await _requestWithBackoff(
      () => dio.post(
        '/reloj-checador/timelog',
        data: payload,
        options: Options(
          headers: {
            ...headers,
            'X-Device-Id': deviceId,
            'X-Client-Timestamp': DateTime.now().toIso8601String(),
            'X-Signature': signature,
          },
        ),
      ),
      retryLabel: 'createTimelogQueued',
    );
  }

  Future<void> createAuditLogQueued(
    Map<String, dynamic> payload,
    Map<String, dynamic> headers,
  ) async {
    final deviceId = (headers['X-Device-Id'] ?? payload['DEVICE_ID'] ?? '')
        .toString()
        .trim();
    final signature = buildAttendanceSignature(
      deviceId: deviceId,
      body: payload,
      secret: Env.attendanceHmacSecret,
    );

    await _requestWithBackoff(
      () => dio.post(
        '/reloj-checador/auditoria',
        data: payload,
        options: Options(
          headers: {
            ...headers,
            'X-Device-Id': deviceId,
            'X-Client-Timestamp': DateTime.now().toIso8601String(),
            'X-Signature': signature,
          },
        ),
      ),
      retryLabel: 'createAuditLogQueued',
    );
  }

  Future<Map<String, dynamic>> uploadAsistenciaFoto({
    required int idUsuario,
    required String suc,
    required String fotoBase64,
    required String deviceId,
    int? idTimelog,
  }) async {
    final body = <String, dynamic>{
      'idUsuario': idUsuario,
      'suc': suc.trim().toUpperCase(),
      'fotoBase64': fotoBase64.trim(),
      if (idTimelog != null) 'idTimelog': idTimelog,
    };
    final signature = buildAttendanceSignature(
      deviceId: deviceId,
      body: body,
      secret: Env.attendanceHmacSecret,
    );
    final res = await _requestWithBackoff(
      () => dio.post(
        '/sucursales/asistencia/foto',
        data: body,
        options: Options(
          headers: {
            'X-Device-Id': deviceId,
            'X-Client-Timestamp': DateTime.now().toIso8601String(),
            'X-Signature': signature,
          },
        ),
      ),
      retryLabel: 'uploadAsistenciaFoto',
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida upload foto asistencia');
  }

  Future<SucursalGeofenceConfig> getSucursalGeofence(String codigo) async {
    final res = await dio.get(
      '/sucursales/${Uri.encodeComponent(codigo)}/geofence',
    );

    if (res.data is Map) {
      return SucursalGeofenceConfig.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    }
    throw _badResponse(res, 'Respuesta invalida geocerca sucursal');
  }

  Future<List<SucursalOptionModel>> getSucursalesCatalog() async {
    final res = await dio.get('/sucursales');
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida listado sucursales');
    }

    return (res.data as List)
        .whereType<Map>()
        .map(
          (row) => SucursalOptionModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<HorarioModel>> getHorarios() async {
    final res = await dio.get('/horarios');
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida listado horarios');
    }

    return (res.data as List)
        .whereType<Map>()
        .map((row) => HorarioModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<TurnoCatalogoModel>> getTurnosCatalogo() async {
    final res = await dio.get('/horarios/turnos-catalogo');
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida catálogo turnos');
    }

    return (res.data as List)
        .whereType<Map>()
        .map(
          (row) => TurnoCatalogoModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<TurnoCatalogoModel> createTurnoCatalogo({
    required String nombre,
    required String hrEntrada,
    required String hrSalidaComida,
    required String hrRegresoComida,
    required String hrSalida,
  }) async {
    final res = await dio.post(
      '/horarios/turnos-catalogo',
      data: {
        'nombre': nombre.trim(),
        'hr_entrada': _normalizeTime(hrEntrada),
        'hr_salida_comida': _normalizeTime(hrSalidaComida),
        'hr_regreso_comida': _normalizeTime(hrRegresoComida),
        'hr_salida': _normalizeTime(hrSalida),
      },
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida alta turno');
    }
    return TurnoCatalogoModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<HorarioSemanalModel> getHorarioSemanal({
    required DateTime weekStart,
    String? sucursal,
    String? departamento,
  }) async {
    final res = await dio.get(
      '/horarios/semana',
      queryParameters: {
        'week_start': _dateOnly(weekStart),
        if ((sucursal ?? '').trim().isNotEmpty) 'sucursal': sucursal!.trim(),
        if ((departamento ?? '').trim().isNotEmpty)
          'departamento': departamento!.trim(),
      },
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida horario semanal');
    }
    return HorarioSemanalModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<Map<String, dynamic>> setHorarioConfirmacion({
    required String sucursal,
    required String departamento,
    required DateTime semana,
    required String estatus,
  }) async {
    final res = await dio.post(
      '/horarios/confirmacion',
      data: {
        'sucursal': sucursal.trim().toUpperCase(),
        'departamento': departamento.trim().toUpperCase(),
        'semana': _dateOnly(semana),
        'estatus': estatus.trim().toUpperCase(),
      },
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida confirmación de horarios');
  }

  Future<Map<String, dynamic>> generarHorariosSiguienteSemana() async {
    final res = await dio.post('/horarios/semana/generar');
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida generación semanal');
  }

  Future<HorarioModel> createHorario(HorarioUpsertRequest payload) async {
    final res = await dio.post('/horarios', data: payload.toJson());
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida creación horario');
    }

    return HorarioModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<HorarioModel> updateHorario(
    int id,
    HorarioUpsertRequest payload,
  ) async {
    final res = await dio.patch('/horarios/$id', data: payload.toJson());
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida actualización horario');
    }

    return HorarioModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteHorario(int id) async {
    await dio.delete('/horarios/$id');
  }

  Future<List<ColaboradorGestionModel>> getColaboradores({
    int? sucursalId,
    String? departamento,
    String? cargo,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (sucursalId != null) params['sucursal_id'] = sucursalId.toString();
    if ((departamento ?? '').trim().isNotEmpty) params['departamento'] = departamento!.trim();
    if ((cargo ?? '').trim().isNotEmpty) params['cargo'] = cargo!.trim();
    if ((search ?? '').trim().isNotEmpty) params['search'] = search!.trim();

    final res = await dio.get('/colaboradores', queryParameters: params.isNotEmpty ? params : null);
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida listado colaboradores');
    }

    return (res.data as List)
        .whereType<Map>()
        .map(
          (row) =>
              ColaboradorGestionModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDeptos() async {
    try {
      final res = await dio.get('/deptos');
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getRoles({int? iddepto}) async {
    try {
      final params = <String, dynamic>{};
      if (iddepto != null) params['iddepo'] = iddepto.toString();
      final res = await dio.get('/roles', queryParameters: params.isNotEmpty ? params : null);
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String> getNextIdEmpleado({required String sucursalCodigo}) async {
    final rawCode = sucursalCodigo.trim();
    final prefix = _normalizeSucursalPrefix(rawCode);
    try {
      final res = await dio.get(
        '/colaboradores/next-id-empleado',
        queryParameters: {'sucursal_codigo': rawCode},
      );
      if (res.data is Map) {
        final map = Map<String, dynamic>.from(res.data as Map);
        final fromApi =
            (map['id_empleado'] ?? map['next_id_empleado'] ?? map['next'])
                ?.toString()
                .trim() ??
            '';
        if (fromApi.isNotEmpty) return fromApi;
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404 && status != 400 && status != 501) {
        rethrow;
      }
    }

    final rows = await getColaboradores();
    var maxSeq = 0;
    for (final row in rows) {
      final idEmpleado = row.idEmpleado.trim().toUpperCase();
      if (!idEmpleado.startsWith('$prefix-')) continue;
      final tail = idEmpleado.substring(prefix.length + 1);
      final seq = int.tryParse(tail) ?? 0;
      if (seq > maxSeq) maxSeq = seq;
    }
    final next = (maxSeq + 1).toString().padLeft(3, '0');
    return '$prefix-$next';
  }

  Future<ColaboradorGestionModel> createColaborador(
    ColaboradorCreateRequest payload,
  ) async {
    final nombre = payload.nombre.trim();
    final apellido = payload.apellido.trim();
    final idEmpleado = (payload.idEmpleado ?? '').trim().toString();
    final pin = payload.pin.trim().toString();
    final departamento = payload.departamento.trim();
    final cargo = payload.cargo.trim();

    final sucursalNorm = _normalizeScalarId(
      payload.sucursalId,
      field: 'sucursal_id',
      colaboradorId: 0,
    );
    final horarioNorm = _normalizeScalarId(
      payload.horarioId ?? 1,
      field: 'horario_id',
      colaboradorId: 0,
    );

    final clean = <String, dynamic>{
      'nombre': nombre,
      'apellido': apellido,
      'id_empleado': idEmpleado,
      'pin': pin,
      'departamento': departamento,
      'cargo': cargo,
      'sucursal_id': (sucursalNorm ?? '').toString(),
      'horario_id': ((horarioNorm ?? 1)).toString(),
      'rol': payload.privilegio == 14 ? 'ADMIN' : 'TRABAJADOR',
    };

    const requiredKeys = <String>[
      'nombre',
      'apellido',
      'id_empleado',
      'pin',
      'sucursal_id',
      'departamento',
    ];
    for (final key in requiredKeys) {
      final value = clean[key];
      if (value == null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/colaboradores'),
          message: '$key es requerido para crear colaborador',
          type: DioExceptionType.badResponse,
        );
      }
      if (value is String && value.trim().isEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: '/colaboradores'),
          message: '$key es requerido para crear colaborador',
          type: DioExceptionType.badResponse,
        );
      }
    }

    debugPrint('PAYLOAD FINAL: ${jsonEncode(clean)}');
    Response<dynamic> res;
    try {
      res = await dio.post('/colaboradores', data: clean);
    } on DioException catch (e) {
      _rethrowFriendlyDio(e);
    }
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida creación colaborador');
    }

    return ColaboradorGestionModel.fromJson(
      Map<String, dynamic>.from(res.data as Map<dynamic, dynamic>),
    );
  }

  Future<Map<String, dynamic>> updateColaborador(
    int colaboradorId,
    Map<String, dynamic> payload,
  ) async {
    final rawPayload = Map<String, dynamic>.from(payload);
    if (!rawPayload.containsKey('id_empleado')) {
      final idEmpleadoAlias =
          rawPayload['id_matricula'] ??
          rawPayload['ID_MATRICULA'] ??
          rawPayload['ID_EMPLEADO'] ??
          rawPayload['idEmpleado'];
      if (idEmpleadoAlias != null) {
        rawPayload['id_empleado'] = idEmpleadoAlias;
      }
    }
    if (!rawPayload.containsKey('pin') &&
        rawPayload.containsKey('contrasena')) {
      rawPayload['pin'] = rawPayload['contrasena'];
    }
    if (!rawPayload.containsKey('pin') &&
        rawPayload.containsKey('contraseña')) {
      rawPayload['pin'] = rawPayload['contraseña'];
    }
    if (!rawPayload.containsKey('pin') && rawPayload.containsKey('PIN')) {
      rawPayload['pin'] = rawPayload['PIN'];
    }
    final clean = <String, dynamic>{};
    for (final entry in rawPayload.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (key == 'sucursal_id') {
        if (value is List || value is Map) {
          throw DioException(
            requestOptions: RequestOptions(
              path: '/colaboradores/$colaboradorId',
            ),
            message: 'sucursal_id inválido: no se permiten objetos o listas',
            type: DioExceptionType.badResponse,
          );
        }
        final normalized = _normalizeSucursalId(
          value,
          colaboradorId: colaboradorId,
        );
        if (normalized != null) {
          clean[key] = normalized;
        }
        continue;
      }
      if (key == 'horario_id') {
        if (value is int) {
          clean[key] = value > 0 ? value : 1;
          continue;
        }
        if (value is String) {
          final trimmed = value.trim();
          clean[key] = trimmed.isEmpty ? 1 : (int.tryParse(trimmed) ?? 1);
          continue;
        }
        clean[key] = 1;
        continue;
      }
      if (key == 'departamento_id' || key == 'id_departamento') {
        if (value is List || value is Map) {
          throw DioException(
            requestOptions: RequestOptions(
              path: '/colaboradores/$colaboradorId',
            ),
            message:
                '$key inválido: no se permiten objetos o listas en campo único',
            type: DioExceptionType.badResponse,
          );
        }
        final normalized = _normalizeScalarId(
          value,
          field: key,
          colaboradorId: colaboradorId,
        );
        if (normalized != null) clean[key] = normalized;
        continue;
      }
      if (key == 'sucursales_ids' && value is List) {
        final ids = value
            .map((it) => _normalizeSucursalId(it, colaboradorId: colaboradorId))
            .where((it) => it != null)
            .cast<Object>()
            .toList();
        if (ids.isNotEmpty) {
          clean[key] = ids;
        }
        continue;
      }
      if (value is List) {
        if (value.isEmpty) continue;
        final filtered = value.where((it) {
          if (it == null) return false;
          if (it is String) return it.trim().isNotEmpty;
          return true;
        }).toList();
        if (filtered.isEmpty) continue;
        clean[key] = filtered;
        continue;
      }
      if (value is Map) {
        if (value.isEmpty) continue;
        clean[key] = value;
        continue;
      }
      if (value is String) {
        final trimmed = value.trim();
        if (key == 'pin') {
          final masked = trimmed == '••••';
          final bcryptLike = trimmed.startsWith(r'$2a$') ||
              trimmed.startsWith(r'$2b$') ||
              trimmed.startsWith(r'$2y$');
          if (trimmed.isEmpty || masked || bcryptLike) {
            continue;
          }
          clean[key] = trimmed;
          continue;
        }
        if (key == 'id_empleado') {
          if (trimmed.isEmpty) {
            throw DioException(
              requestOptions: RequestOptions(
                path: '/colaboradores/$colaboradorId',
              ),
              message: '$key no puede enviarse vacío',
              type: DioExceptionType.badResponse,
            );
          }
          clean[key] = trimmed;
          continue;
        }
        if (trimmed.isEmpty) continue;
        clean[key] = trimmed;
        continue;
      }
      clean[key] = value;
    }
    Response<dynamic> res;
    try {
      res = await dio.patch('/colaboradores/$colaboradorId', data: clean);
    } on DioException catch (e) {
      _rethrowFriendlyDio(e);
    }
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida actualización colaborador');
  }

  Object? _normalizeSucursalId(Object value, {required int colaboradorId}) {
    if (value is int) {
      if (value <= 0) return null;
      return value;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null && asInt > 0) return asInt;
      if (_uuidRegex.hasMatch(trimmed)) return trimmed;
      throw DioException(
        requestOptions: RequestOptions(path: '/colaboradores/$colaboradorId'),
        message: 'sucursal_id inválido: se esperaba UUID o entero positivo',
        type: DioExceptionType.badResponse,
      );
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/colaboradores/$colaboradorId'),
      message: 'sucursal_id inválido: tipo no soportado',
      type: DioExceptionType.badResponse,
    );
  }

  Object? _normalizeScalarId(
    Object value, {
    required String field,
    required int colaboradorId,
  }) {
    if (value is int) return value > 0 ? value : null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null && asInt > 0) return asInt;
      if (_uuidRegex.hasMatch(trimmed)) return trimmed;
      throw DioException(
        requestOptions: RequestOptions(path: '/colaboradores/$colaboradorId'),
        message: '$field inválido: se esperaba UUID o entero positivo',
        type: DioExceptionType.badResponse,
      );
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/colaboradores/$colaboradorId'),
      message: '$field inválido: tipo no soportado',
      type: DioExceptionType.badResponse,
    );
  }

  Future<Map<String, dynamic>> deleteColaborador(
    int colaboradorId, {
    bool hard = false,
  }) async {
    final res = await dio.delete(
      '/colaboradores/$colaboradorId',
      queryParameters: {'hard': hard},
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida eliminación colaborador');
  }

  Future<Map<String, dynamic>> resetBiometriaColaborador(
    int colaboradorId, {
    bool resetFace = true,
    bool resetFingerprint = true,
  }) async {
    final res = await dio.post(
      '/colaboradores/$colaboradorId/reset-biometria',
      data: {'reset_face': resetFace, 'reset_fingerprint': resetFingerprint},
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida reset biometría');
  }

  Future<Map<String, dynamic>> mantenimientoBiometriaColaborador(
    int colaboradorId,
    Map<String, dynamic> payload,
  ) async {
    final clean = <String, dynamic>{};
    for (final entry in payload.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      clean[entry.key] = value;
    }
    final res = await dio.post(
      '/colaboradores/$colaboradorId/biometria-mantenimiento',
      data: clean,
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida mantenimiento biometría');
  }

  Future<Map<String, dynamic>> solicitarEnrolamiento(
    int colaboradorId, {
    required String tipo,
  }) async {
    final normalized = tipo.trim().toUpperCase();
    final res = await dio.post(
      '/colaboradores/$colaboradorId/enrolar',
      data: {'tipo': normalized},
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida enrolamiento');
  }

  Future<Map<String, dynamic>> saveNom035Respuestas({
    required int colaboradorId,
    required SaveNom035Request payload,
  }) async {
    final res = await dio.post(
      '/colaboradores/$colaboradorId/nom035-respuestas',
      data: payload.toJson(),
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida NOM-035');
  }

  Future<Map<String, dynamic>> saveNom035RespuestasSelfService({
    required String token,
    required SaveNom035Request payload,
  }) async {
    final colaboradorId = await _resolveColaboradorIdFromToken(token);
    final res = await dio.post(
      '/colaboradores/$colaboradorId/nom035-respuestas',
      data: payload.toJson(),
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida NOM-035 auto-servicio');
  }

  Future<List<Nom035RespuestaModel>> getNom035Respuestas(
    int colaboradorId, {
    int limit = 30,
  }) async {
    final res = await dio.get(
      '/colaboradores/$colaboradorId/nom035-respuestas',
      queryParameters: {'limit': limit},
    );

    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida listado NOM-035');
    }

    final map = Map<String, dynamic>.from(res.data as Map);
    final rows = (map['rows'] is List) ? (map['rows'] as List) : const [];

    return rows
        .whereType<Map>()
        .map(
          (row) =>
              Nom035RespuestaModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<ColaboradorDocumentoModel>> getColaboradorDocumentos(
    int colaboradorId,
  ) async {
    final res = await dio.get('/colaboradores/$colaboradorId/documentos');
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida documentos colaborador');
    }

    final map = Map<String, dynamic>.from(res.data as Map);
    final rows = (map['rows'] is List) ? (map['rows'] as List) : const [];

    return rows
        .whereType<Map>()
        .map(
          (row) => ColaboradorDocumentoModel.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> uploadColaboradorDocumento({
    required int colaboradorId,
    required String tipoDoc,
    required List<int> bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'tipo_doc': tipoDoc.trim().toUpperCase(),
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final res = await dio.post(
      '/colaboradores/$colaboradorId/documentos',
      data: formData,
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida upload documento colaborador');
  }

  Future<ColaboradorQrCredential> getColaboradorQrCredential(
    int colaboradorId,
  ) async {
    final res = await dio.get('/colaboradores/$colaboradorId/credencial-qr');
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida credencial QR');
    }

    return ColaboradorQrCredential.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<ColaboradorHorarioCalendarModel> getColaboradorHorariosRotativos(
    int colaboradorId,
  ) async {
    final res = await dio.get(
      '/colaboradores/$colaboradorId/horarios-rotativos',
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida horarios rotativos');
    }

    return ColaboradorHorarioCalendarModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<SelfServiceSession> qrLogin(String token) async {
    final res = await dio.post(
      '/colaboradores/qr-login',
      data: {'token': token},
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida login QR');
    }

    final map = Map<String, dynamic>.from(res.data as Map);
    await _saveSession(token, map);
    return SelfServiceSession.fromJson(
      Map<String, dynamic>.from(res.data as Map),
      token: token,
    );
  }

  Future<SelfServiceSession?> restoreCachedSession() async {
    final sp = await SharedPreferences.getInstance();
    final token = (sp.getString(_kEssToken) ?? '').trim();
    final userJson = (sp.getString(_kEssUserJson) ?? '').trim();
    if (token.isEmpty || userJson.isEmpty) return null;
    try {
      final raw = json.decode(userJson);
      if (raw is! Map) return null;
      return SelfServiceSession.fromJson(
        Map<String, dynamic>.from(raw),
        token: token,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kEssToken);
    await sp.remove(_kEssUserJson);
  }

  Future<TerminalColaboradorProfile> getTerminalColaboradorProfile({
    int? id,
    String? pin,
    String? qrToken,
  }) async {
    final query = <String, dynamic>{};
    if (id != null && id > 0) query['id'] = id;
    if ((pin ?? '').trim().isNotEmpty) query['pin'] = pin!.trim();
    if ((qrToken ?? '').trim().isNotEmpty) query['qr_token'] = qrToken!.trim();

    final res = await dio.get(
      '/colaboradores/terminal-profile',
      queryParameters: query,
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida perfil terminal');
    }
    return TerminalColaboradorProfile.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<TerminalColaboradorProfile?> validatePin(
    String pin, {
    String? deviceId,
  }) async {
    final normalized = pin.trim();
    if (normalized.isEmpty) return null;
    final normalizedDeviceId = (deviceId ?? '').trim();
    final res = await dio.get(
      '/colaboradores/validate-pin/$normalized',
      options: normalizedDeviceId.isEmpty
          ? null
          : Options(headers: {'X-Device-Id': normalizedDeviceId}),
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida validate-pin');
    }
    final map = Map<String, dynamic>.from(res.data as Map);
    if (map['exists'] != true) return null;
    return TerminalColaboradorProfile.fromJson(map);
  }

  Future<Map<String, dynamic>> marcarAsistenciaSelfService({
    required String token,
    required String tipo,
    required double lat,
    required double lon,
    int? accuracyM,
  }) async {
    final res = await _requestWithBackoff(
      () => dio.post(
        '/colaboradores/marcar',
        data: {
          'token': token,
          'tipo': tipo.trim().toUpperCase(),
          'lat': 0.0,
          'lon': 0.0,
        },
      ),
      retryLabel: 'marcarAsistenciaSelfService',
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida marcar asistencia');
  }

  Future<Map<String, dynamic>> registrarVisitaKiosco({
    required String qr,
    required String eventPhoto,
    required String terminalId,
    required String suc,
    DateTime? punchTime,
    double? bodyTemp,
    String? gpsCoordinates,
    bool isOffline = false,
    int verifyMode = 3,
  }) async {
    final res = await _requestWithBackoff(
      () => dio.post(
        '/sucursales/kiosco/visita',
        data: {
          'qr': qr.trim(),
          'event_photo': eventPhoto.trim(),
          'terminal_id': terminalId.trim(),
          'suc': suc.trim().toUpperCase(),
          if (punchTime != null) 'punch_time': _dateIso(punchTime),
          if (bodyTemp != null) 'body_temp': bodyTemp,
          if ((gpsCoordinates ?? '').trim().isNotEmpty)
            'gps_coordinates': gpsCoordinates!.trim(),
          'is_offline': isOffline,
          'verify_mode': verifyMode,
        },
      ),
      retryLabel: 'registrarVisitaKiosco',
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida visita kiosco');
  }

  Future<List<PermisoTipoModel>> getPermisosTipos() async {
    final res = await dio.get('/incidencias/tipos');
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida tipos de permisos');
    }

    return (res.data as List)
        .whereType<Map>()
        .map((row) => PermisoTipoModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<PermisoTipoModel>> getEssPermisosTipos() async {
    final res = await dio.get('/incidencias/tipos');
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida tipos de permisos ESS');
    }

    return (res.data as List)
        .whereType<Map>()
        .map((row) => PermisoTipoModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<SolicitudIncidenciaModel> createSolicitudIncidencia(
    SolicitudIncidenciaCreateRequest payload,
  ) async {
    final res = await _requestWithBackoff(
      () => dio.post('/incidencias/solicitudes', data: payload.toJson()),
      retryLabel: 'createSolicitudIncidencia',
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida creación solicitud');
    }

    return SolicitudIncidenciaModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<List<SolicitudIncidenciaModel>> getSolicitudesIncidencias({
    int? colaboradorId,
    String? estatus,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final query = <String, dynamic>{};
    if (colaboradorId != null) query['colaborador_id'] = colaboradorId;
    if ((estatus ?? '').trim().isNotEmpty) query['estatus'] = estatus!.trim();
    if (fechaInicio != null) query['fecha_inicio'] = _dateIso(fechaInicio);
    if (fechaFin != null) query['fecha_fin'] = _dateIso(fechaFin);

    final res = await dio.get(
      '/incidencias/solicitudes',
      queryParameters: query.isEmpty ? null : query,
    );
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida listado solicitudes');
    }

    return (res.data as List)
        .whereType<Map>()
        .map(
          (row) =>
              SolicitudIncidenciaModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<SolicitudIncidenciaModel> updateSolicitudIncidenciaEstatus({
    required int solicitudId,
    required String estatus,
    String? motivoResolucion,
  }) async {
    final id = solicitudId > 0 ? solicitudId : 0;
    final estatusNorm = estatus.trim().toUpperCase();
    if (id <= 0) {
      throw DioException(
        requestOptions: RequestOptions(path: '/incidencias/solicitudes'),
        type: DioExceptionType.badResponse,
        message: 'ID de solicitud inválido',
      );
    }
    if (estatusNorm != 'APROBADO' && estatusNorm != 'RECHAZADO') {
      throw DioException(
        requestOptions: RequestOptions(path: '/incidencias/solicitudes/$id/estatus'),
        type: DioExceptionType.badResponse,
        message: 'Estatus inválido',
      );
    }
    final res = await dio.patch(
      '/incidencias/solicitudes/$id/estatus',
      data: {
        'estatus': estatusNorm,
        if ((motivoResolucion ?? '').trim().isNotEmpty)
          'motivo_resolucion': motivoResolucion!.trim(),
      },
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida actualización estatus');
    }
    return SolicitudIncidenciaModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<List<AusenciaCalendarioItem>> getAusenciasCalendario({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int? sucursalId,
  }) async {
    final res = await dio.get(
      '/incidencias/calendario',
      queryParameters: {
        'fecha_inicio': _dateIso(fechaInicio),
        'fecha_fin': _dateIso(fechaFin),
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida calendario de ausencias');
    }
    final map = Map<String, dynamic>.from(res.data as Map);
    final rows = (map['rows'] is List) ? map['rows'] as List : const [];
    return rows
        .whereType<Map>()
        .map(
          (row) =>
              AusenciaCalendarioItem.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<VacacionesDashboardModel> getVacacionesDashboard(
    int colaboradorId, {
    int? anio,
  }) async {
    final res = await dio.get(
      '/incidencias/dashboard/$colaboradorId',
      queryParameters: {if (anio != null) 'anio': anio},
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida dashboard vacaciones');
    }

    return VacacionesDashboardModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<VacacionesDashboardModel> getEssVacacionesDashboard({
    required String token,
    int? anio,
  }) async {
    final colaboradorId = await _resolveColaboradorIdFromToken(token);
    final res = await dio.get(
      '/incidencias/dashboard/$colaboradorId',
      queryParameters: {if (anio != null) 'anio': anio},
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida dashboard ESS');
    }
    return VacacionesDashboardModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<List<SolicitudIncidenciaModel>> getEssSolicitudes({
    required String token,
    String? estatus,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final colaboradorId = await _resolveColaboradorIdFromToken(token);
    final res = await dio.get(
      '/incidencias/solicitudes',
      queryParameters: {
        'colaborador_id': colaboradorId,
        if ((estatus ?? '').trim().isNotEmpty) 'estatus': estatus!.trim(),
        if (fechaInicio != null) 'fecha_inicio': _dateIso(fechaInicio),
        if (fechaFin != null) 'fecha_fin': _dateIso(fechaFin),
      },
    );
    if (res.data is! List) {
      throw _badResponse(res, 'Respuesta invalida solicitudes ESS');
    }

    return (res.data as List)
        .whereType<Map>()
        .map(
          (row) =>
              SolicitudIncidenciaModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<SolicitudIncidenciaModel> createEssSolicitudIncidencia({
    required String token,
    required int tipoId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? motivo,
    String? evidenciaUrl,
  }) async {
    final colaboradorId = await _resolveColaboradorIdFromToken(token);
    final res = await dio.post(
      '/incidencias/solicitudes',
      data: {
        'colaborador_id': colaboradorId,
        'tipo_id': tipoId,
        'fecha_inicio': _dateIso(fechaInicio),
        'fecha_fin': _dateIso(fechaFin),
        if ((motivo ?? '').trim().isNotEmpty) 'motivo': motivo!.trim(),
        if ((evidenciaUrl ?? '').trim().isNotEmpty)
          'evidencia_url': evidenciaUrl!.trim(),
      },
    );
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida crear solicitud ESS');
    }
    return SolicitudIncidenciaModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<String> uploadEvidenciaIncidencia({
    String? filePath,
    List<int>? bytes,
    String? fileName,
  }) async {
    MultipartFile? filePart;
    final safeFileName = (fileName ?? '').trim();

    if ((filePath ?? '').trim().isNotEmpty) {
      final normalizedPath = filePath!.trim();
      final pathParts = normalizedPath
          .split(RegExp(r'[\\/]'))
          .where((part) => part.trim().isNotEmpty)
          .toList();
      final fallbackName = pathParts.isEmpty ? null : pathParts.last;
      filePart = await MultipartFile.fromFile(
        normalizedPath,
        filename: safeFileName.isNotEmpty ? safeFileName : fallbackName,
      );
    } else if (bytes != null && bytes.isNotEmpty) {
      filePart = MultipartFile.fromBytes(
        bytes,
        filename: safeFileName.isNotEmpty ? safeFileName : 'evidencia.bin',
      );
    }

    if (filePart == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/incidencias/evidencia'),
        error: 'Archivo de evidencia requerido',
        type: DioExceptionType.unknown,
      );
    }

    final formData = FormData.fromMap({'file': filePart});
    final res = await dio.post('/incidencias/evidencia', data: formData);
    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida upload evidencia');
    }

    final map = Map<String, dynamic>.from(res.data as Map);
    final url = map['evidencia_url']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw _badResponse(res, 'Evidencia sin URL pública');
    }
    return url;
  }

  Future<List<AsistenciaReporteRow>> getAsistenciaReporte(
    AsistenciaReporteQuery query,
  ) async {
    final res = await dio.get(
      '/asistencia/reporte',
      queryParameters: query.toQueryParams(),
    );

    if (res.data is! Map) {
      throw _badResponse(res, 'Respuesta invalida reporte asistencia');
    }

    final map = Map<String, dynamic>.from(res.data as Map);
    final rows = (map['rows'] is List) ? map['rows'] as List : const [];

    return rows
        .whereType<Map>()
        .map(
          (row) =>
              AsistenciaReporteRow.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<int>> exportAsistenciaPdf(AsistenciaReporteQuery query) async {
    final res = await dio.get<List<int>>(
      '/asistencia/reporte/export/pdf',
      queryParameters: query.toQueryParams(),
      options: Options(responseType: ResponseType.bytes),
    );

    return _normalizeBytes(res);
  }

  Future<List<int>> exportAsistenciaExcel(AsistenciaReporteQuery query) async {
    final res = await dio.get<List<int>>(
      '/asistencia/reporte/export/excel',
      queryParameters: query.toQueryParams(),
      options: Options(responseType: ResponseType.bytes),
    );

    return _normalizeBytes(res);
  }

  Future<List<int>> exportNominaLayout({
    required AsistenciaReporteQuery query,
    required List<String> columns,
    required bool excel,
  }) async {
    final res = await dio.get<List<int>>(
      '/asistencia/reporte/export/nomina',
      queryParameters: {
        ...query.toQueryParams(),
        'format': excel ? 'excel' : 'csv',
        if (columns.isNotEmpty) 'columns': columns.join(','),
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return _normalizeBytes(res);
  }

  Future<Map<String, dynamic>> setPeriodoCierre({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required bool cerrado,
    String? motivo,
  }) async {
    final endpoint = cerrado
        ? '/asistencia/periodo/cerrar'
        : '/asistencia/periodo/abrir';
    final res = await dio.post(
      endpoint,
      data: {
        'fecha_inicio': _dateIso(fechaInicio),
        'fecha_fin': _dateIso(fechaFin),
        if ((motivo ?? '').trim().isNotEmpty) 'motivo': motivo!.trim(),
      },
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw _badResponse(res, 'Respuesta invalida al cambiar cierre de periodo');
  }

  List<int> _normalizeBytes(Response<List<int>> res) {
    final data = res.data;
    if (data != null && data.isNotEmpty) {
      return data;
    }

    final dynamicRaw = res.data;
    if (dynamicRaw is List<int>) {
      return dynamicRaw;
    }

    throw _badResponse(res, 'Respuesta binaria inválida');
  }

  Future<int> _resolveColaboradorIdFromToken(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/colaboradores/qr-login'),
        type: DioExceptionType.badResponse,
        error: 'Token ESS requerido',
      );
    }

    final session = await qrLogin(clean);
    if (session.colaboradorId <= 0) {
      throw DioException(
        requestOptions: RequestOptions(path: '/colaboradores/qr-login'),
        type: DioExceptionType.badResponse,
        error: 'Token ESS inválido',
      );
    }
    return session.colaboradorId;
  }

  DioException _badResponse(Response<dynamic> res, String message) {
    return DioException(
      requestOptions: res.requestOptions,
      response: res,
      error: message,
      type: DioExceptionType.badResponse,
    );
  }

  Future<void> _saveSession(String token, Map user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kEssToken, token.trim());
    await sp.setString(_kEssUserJson, json.encode(user));
  }

  Never _rethrowFriendlyDio(DioException e) {
    final status = e.response?.statusCode;
    if (status == 400) {
      dynamic serverMessage;
      final data = e.response?.data;
      if (data is Map) {
        serverMessage = data['message'];
      }
      final msg = (serverMessage is String && serverMessage.trim().isNotEmpty)
          ? serverMessage.trim()
          : e.message;
      throw DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: e.error,
        message: msg,
      );
    }
    if (status == 409) {
      throw DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: e.error,
        message: 'Error: La Matrícula/ID ya está registrada en el sistema',
      );
    }
    if (status == 500) {
      throw DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: e.error,
        message: 'Error 500: Conflicto en el formato del PIN o datos duplicados',
      );
    }
    throw e;
  }

  Future<Response<T>> _requestWithBackoff<T>(
    Future<Response<T>> Function() call, {
    required String retryLabel,
    int attempts = 3,
  }) async {
    DioException? lastError;

    for (var i = 0; i < attempts; i++) {
      try {
        return await call();
      } on DioException catch (e) {
        lastError = e;
        final status = e.response?.statusCode ?? 0;
        final retriable =
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.unknown ||
            status == 422 ||
            status == 429 ||
            status >= 500;

        if (!retriable || i == attempts - 1) {
          rethrow;
        }

        final delay = Duration(milliseconds: 350 * (1 << i));
        // ignore: avoid_print
        print(
          'Retry $retryLabel intento ${i + 1}/$attempts status=$status en ${delay.inMilliseconds}ms',
        );
        await Future<void>.delayed(delay);
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: retryLabel),
          type: DioExceptionType.unknown,
          error: 'Error desconocido en _requestWithBackoff',
        );
  }

  AttendanceSecurityService getSecurityService() {
    return _securityService;
  }
}

String _normalizeSucursalPrefix(String code) {
  final upper = code.trim().toUpperCase();
  if (upper.isEmpty) return 'SUC';
  final tokens = upper.split(RegExp(r'[-_\s]+'));
  for (final token in tokens) {
    final clean = token.trim();
    if (clean.isNotEmpty) {
      return clean;
    }
  }
  return 'SUC';
}

String _dateIso(DateTime value) {
  return value.toIso8601String();
}

String _dateOnly(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _normalizeTime(String value) {
  final text = value.trim();
  if (RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) {
    return '$text:00';
  }
  return text;
}

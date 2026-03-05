import 'package:dio/dio.dart';

import 'cambio_forma_pago_models.dart';

class CambioFormaPagoApi {
  CambioFormaPagoApi(this.dio);

  final Dio dio;

  Future<CambioFormaPagoOverrideSession> authorizeSupervisor({
    required String pin,
  }) async {
    final pinValue = pin.trim();
    final res = await dio.post(
      '/pvticketlog/precio/authorize',
      data: {'AUTH_PASSWORD': pinValue},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final authorized = data['authorized'] == true;
    if (!authorized) {
      throw Exception('Autorización SUPERPV inválida');
    }

    final supervisorId =
        (data['username'] ?? data['idUsuario'] ?? '').toString().trim();
    return CambioFormaPagoOverrideSession(
      overrideToken: '',
      supervisorId: supervisorId.isEmpty ? 'SUPERPV' : supervisorId,
      authPassword: pinValue,
    );
  }

  Future<List<CambioFormaPagoItem>> fetchToday({
    String? idfol,
    String? clien,
  }) async {
    final idfolNorm = (idfol ?? '').trim();
    final clienNorm = (clien ?? '').trim();
    final res = await dio.get(
      '/formas-pago/cambios/today',
      queryParameters: {
        if (idfolNorm.isNotEmpty) 'idfol': idfolNorm,
        if (clienNorm.isNotEmpty) 'clien': clienNorm,
      },
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
          (row) => CambioFormaPagoItem.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CambioFormaPagoCatalogItem>> fetchCatalog() async {
    final res = await dio.get('/catalogos/formas-pago');
    final data = res.data;
    if (data is! List) return const [];
    final parsed = data
        .map(
          (row) => CambioFormaPagoCatalogItem.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((row) => row.form.isNotEmpty)
        .toList(growable: false);

    final byForm = <String, CambioFormaPagoCatalogItem>{};
    for (final item in parsed) {
      final current = byForm[item.form];
      if (current == null || item.bloq < current.bloq) {
        byForm[item.form] = item;
      }
    }
    return byForm.values.toList(growable: false);
  }

  Future<CambioFormaPagoUpdateResult> updateForma({
    required String idf,
    required String newForm,
    String? aut,
    bool clearAut = false,
    String? overrideToken,
    String? authPassword,
  }) async {
    final encodedIdf = Uri.encodeComponent(idf.trim());
    final nextForm = newForm.trim().toUpperCase();
    final overrideTokenNorm = (overrideToken ?? '').trim();
    final authPasswordNorm = (authPassword ?? '').trim();
    final autNorm = (aut ?? '').trim();
    final res = await dio.put(
      '/formas-pago/cambios/$encodedIdf',
      data: {
        'newForm': nextForm,
        'FORM': nextForm,
        if (autNorm.isNotEmpty) 'AUT': autNorm,
        if (clearAut) 'clearAut': true,
        if (authPasswordNorm.isNotEmpty) 'AUTH_PASSWORD': authPasswordNorm,
      },
      options: Options(
        headers: {
          if (overrideTokenNorm.isNotEmpty)
            'X-Override-Token': overrideTokenNorm,
        },
      ),
    );
    final data = res.data;
    if (data is Map) {
      return CambioFormaPagoUpdateResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return CambioFormaPagoUpdateResult.fromJson(
        Map<String, dynamic>.from(data.first as Map),
      );
    }
    throw Exception('Respuesta invalida al actualizar forma de pago.');
  }
}

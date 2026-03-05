import 'package:dio/dio.dart';

import 'cotizaciones_models.dart';

class CotizacionesApi {
  CotizacionesApi(this.dio);

  final Dio dio;

  Future<List<PvCtrFolAsvrModel>> fetchCotizaciones({
    String? suc,
    String? opv,
    String? search,
  }) async {
    final normalizedSuc = (suc ?? '').trim();
    final normalizedOpv = (opv ?? '').trim();
    final normalizedSearch = (search ?? '').trim();

    final parsed = await _fetchCotizacionesRaw(
      suc: normalizedSuc,
      opv: normalizedOpv,
      search: normalizedSearch,
    );
    final scoped = parsed.where((item) {
      return _matchesExactFilter(item.suc, normalizedSuc) &&
          _matchesExactFilter(item.opv, normalizedOpv);
    });
    final visible = scoped.where(_isVisiblePanelItem).toList();

    if (normalizedSearch.isEmpty) {
      return visible;
    }

    final searchedId = _normalize(normalizedSearch);
    final alreadyIncluded = visible.any((item) => _normalize(item.idfol) == searchedId);
    if (alreadyIncluded) {
      return visible;
    }
    if (!_looksLikeIdFolSearch(normalizedSearch)) {
      return visible;
    }

    final fallbackItem = await _fetchByIdForSearch(
      idfol: normalizedSearch,
      suc: normalizedSuc,
    );
    if (fallbackItem == null) {
      return visible;
    }

    return [fallbackItem, ...visible];
  }

  Future<PvCtrFolAsvrModel> fetchCotizacion(String idfol) async {
    final res = await dio.get('/pvctrfolasvr/$idfol');
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PvCtrFolAsvrModel> createCotizacion(Map<String, dynamic> payload) async {
    final res = await dio.post('/pvctrfolasvr', data: payload);
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PvCtrFolAsvrModel> createCotizacionAuto({String? ter}) async {
    final payload = <String, dynamic>{};
    final terTrim = (ter ?? '').trim();
    if (terTrim.isNotEmpty) payload['TER'] = terTrim;
    final res = await dio.post('/pvctrfolasvr/auto', data: payload);
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PvCtrFolAsvrModel> updateCotizacion(String idfol, Map<String, dynamic> payload) async {
    final res = await dio.patch('/pvctrfolasvr/$idfol', data: payload);
    return PvCtrFolAsvrModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteCotizacion(String idfol) async {
    await dio.delete('/pvctrfolasvr/$idfol');
  }

  Future<List<PvCtrFolAsvrModel>> _fetchCotizacionesRaw({
    required String suc,
    required String opv,
    required String search,
  }) async {
    final res = await dio.get(
      '/pvctrfolasvr',
      queryParameters: {
        if (suc.isNotEmpty) 'suc': suc,
        if (opv.isNotEmpty) 'opv': opv,
        if (search.isNotEmpty) 'search': search,
      },
    );

    final raw = res.data;
    final List rows;
    if (raw is List) {
      rows = raw;
    } else if (raw is Map) {
      rows = (raw['items'] as List?) ?? const [];
    } else {
      rows = const [];
    }

    return rows
        .map(
          (e) => PvCtrFolAsvrModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<PvCtrFolAsvrModel?> _fetchByIdForSearch({
    required String idfol,
    required String suc,
  }) async {
    final id = idfol.trim().toUpperCase();
    if (id.isEmpty) return null;

    try {
      final item = await fetchCotizacion(id);
      if (!_isSearchOverrideEstado(item.esta) || !_isVisibleAut(item.aut)) {
        return null;
      }
      if (suc.isNotEmpty && _normalize(item.suc) != _normalize(suc)) {
        return null;
      }
      return item;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      if (statusCode == 400 || statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  bool _isVisiblePanelItem(PvCtrFolAsvrModel item) {
    return _isVisibleEstado(item.esta) && _isVisibleAut(item.aut);
  }

  bool _isVisibleEstado(String? value) {
    final estado = _normalize(value);
    return estado == 'PENDIENTE' ||
        estado == 'PAGADO' ||
        estado == 'EDITADO' ||
        estado == 'EDITANDO';
  }

  bool _isVisibleAut(String? value) {
    final aut = _normalize(value);
    return aut == 'VF' || aut == 'CA' || aut == 'CP';
  }

  bool _isSearchOverrideEstado(String? value) {
    final estado = _normalize(value);
    return estado == 'PENDIENTE' || estado == 'EDITADO';
  }

  bool _matchesExactFilter(String? rowValue, String filterValue) {
    if (filterValue.isEmpty) return true;
    return _normalize(rowValue) == _normalize(filterValue);
  }

  bool _looksLikeIdFolSearch(String value) {
    final text = value.trim();
    if (text.length < 6 || text.contains(' ')) return false;
    final hasValidChars = RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(text);
    final hasDigit = RegExp(r'\d').hasMatch(text);
    return hasValidChars && hasDigit;
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toUpperCase();
  }
}

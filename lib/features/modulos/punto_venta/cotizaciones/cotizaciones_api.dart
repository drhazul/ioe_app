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

    final visibleIds = visible.map((item) => _normalize(item.idfol)).toSet();
    final crossUserMatches = await _fetchCrossUserSearchMatches(
      suc: normalizedSuc,
      currentOpv: normalizedOpv,
      search: normalizedSearch,
      excludedIds: visibleIds,
    );
    if (crossUserMatches.isEmpty) {
      return visible;
    }
    return [...visible, ...crossUserMatches];
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

  Future<List<PvCtrFolAsvrModel>> _fetchCrossUserSearchMatches({
    required String suc,
    required String currentOpv,
    required String search,
    required Set<String> excludedIds,
  }) async {
    final opvCriterion = _looksLikeOpvSearch(search);
    final parsed = await _fetchCotizacionesRaw(
      suc: suc,
      opv: opvCriterion ? search.trim() : '',
      search: opvCriterion ? '' : search,
    );
    final currentOpvNormalized = _normalize(currentOpv);
    return parsed.where((item) {
      final idNormalized = _normalize(item.idfol);
      if (excludedIds.contains(idNormalized)) return false;
      if (!_matchesExactFilter(item.suc, suc)) return false;
      if (!opvCriterion &&
          currentOpvNormalized.isNotEmpty &&
          _normalize(item.opv) == currentOpvNormalized) {
        return false;
      }
      if (!_isCrossUserSearchAllowed(item)) return false;
      return _matchesSearchCriterion(item, search);
    }).toList();
  }

  bool _isVisiblePanelItem(PvCtrFolAsvrModel item) {
    return _isVisibleEstado(item.esta) && _isVisibleAut(item.aut);
  }

  bool _isVisibleEstado(String? value) {
    final estado = _normalize(value);
    return estado == 'PENDIENTE' ||
        estado == 'EDITANDO' ||
        estado == 'PAGADO';
  }

  bool _isVisibleAut(String? value) {
    final aut = _normalize(value);
    return aut == 'VF' || aut == 'CA' || aut == 'CP';
  }

  bool _isCrossUserSearchAllowed(PvCtrFolAsvrModel item) {
    final aut = _normalize(item.aut);
    final estado = _normalize(item.esta);
    return aut == 'CP' && estado == 'PENDIENTE';
  }

  bool _matchesSearchCriterion(PvCtrFolAsvrModel item, String search) {
    final term = search.trim();
    if (term.isEmpty) return true;
    final normalizedTerm = _normalize(term);

    if (_looksLikeOpvSearch(term)) {
      return _normalize(item.opv) == normalizedTerm;
    }
    if (_looksLikeIdFolSearch(term)) {
      return _normalize(item.idfol) == normalizedTerm ||
          _normalize(item.idfolinicial) == normalizedTerm;
    }
    if (_looksLikeClientSearch(term)) {
      return _normalizeNumericText(item.clien?.toString()) ==
          _normalizeNumericText(term);
    }

    final razon = (item.razonSocialReceptor ?? '').trim().toLowerCase();
    return razon.contains(term.toLowerCase());
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

  bool _looksLikeClientSearch(String value) {
    final text = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(text)) return false;
    return text.length != 4;
  }

  bool _looksLikeOpvSearch(String value) {
    final text = value.trim();
    if (text.contains(' ')) return false;
    return RegExp(r'^\d{4}$').hasMatch(text);
  }

  String _normalizeNumericText(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '';
    final parsed = num.tryParse(text);
    if (parsed == null) return text;
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }
    return parsed.toString();
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toUpperCase();
  }
}


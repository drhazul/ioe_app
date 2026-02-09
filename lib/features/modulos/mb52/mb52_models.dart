class Mb52Filtros {
  final List<String>? sucs;
  final List<String>? almacenes;
  final List<String>? arts;

  const Mb52Filtros({
    this.sucs,
    this.almacenes,
    this.arts,
  });

  Mb52Filtros copyWith({
    List<String>? sucs,
    List<String>? almacenes,
    List<String>? arts,
  }) {
    return Mb52Filtros(
      sucs: sucs ?? this.sucs,
      almacenes: almacenes ?? this.almacenes,
      arts: arts ?? this.arts,
    );
  }

  bool get isEmpty => _isBlankList(sucs) && _isBlankList(almacenes) && _isBlankList(arts);

  Map<String, dynamic> toApiJson() {
    final data = <String, dynamic>{};
    if (!_isBlankList(sucs)) data['sucs'] = sucs;
    if (!_isBlankList(almacenes)) data['almacenes'] = almacenes;
    if (!_isBlankList(arts)) data['arts'] = arts;
    return data;
  }

  Map<String, dynamic> toJson() => toApiJson();

  factory Mb52Filtros.fromJson(Map<String, dynamic> json) {
    return Mb52Filtros(
      sucs: _asStringList(json['sucs']),
      almacenes: _asStringList(json['almacenes']),
      arts: _asStringList(json['arts']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mb52Filtros &&
        _listEq(sucs, other.sucs) &&
        _listEq(almacenes, other.almacenes) &&
        _listEq(arts, other.arts);
  }

  @override
  int get hashCode => Object.hash(_listHash(sucs), _listHash(almacenes), _listHash(arts));
}

class DatMb52ResumenModel {
  final String? suc;
  final String? art;
  final String? des;
  final String? almacen;
  final double? ctdaSum;
  final double? stockTotalCtda;
  final double? costoTotalCtot;

  DatMb52ResumenModel({
    this.suc,
    this.art,
    this.des,
    this.almacen,
    this.ctdaSum,
    this.stockTotalCtda,
    this.costoTotalCtot,
  });

  factory DatMb52ResumenModel.fromJson(Map<String, dynamic> json) {
    return DatMb52ResumenModel(
      suc: _asString(json['SUC'] ?? json['suc']),
      art: _asString(json['ART'] ?? json['art']),
      des: _asString(json['DES'] ?? json['des']),
      almacen: _asString(json['ALMACEN'] ?? json['almacen']),
      ctdaSum: _asDouble(json['CTDA_SUM'] ?? json['ctda_sum']),
      stockTotalCtda: _asDouble(json['STOCK_TOTAL_CTDA'] ?? json['stock_total_ctda']),
      costoTotalCtot: _asDouble(json['COSTO_TOTAL_CTOT'] ?? json['costo_total_ctot']),
    );
  }
}

class DatAlmacenModel {
  final String almacen;
  final String? descripcion;
  final bool? activo;
  final DateTime? fcnr;

  DatAlmacenModel({
    required this.almacen,
    this.descripcion,
    this.activo,
    this.fcnr,
  });

  factory DatAlmacenModel.fromJson(Map<String, dynamic> json) {
    return DatAlmacenModel(
      almacen: _asString(json['ALMACEN']) ?? '',
      descripcion: _asString(json['DESCRIPCION']),
      activo: _asBool(json['ACTIVO']),
      fcnr: _asDate(json['FCNR']),
    );
  }

  String get label {
    final desc = (descripcion ?? '').trim();
    return desc.isEmpty ? almacen : '$almacen - $desc';
  }
}

bool _isBlankList(List<String>? values) => values == null || values.isEmpty;

bool _listEq(List<String>? a, List<String>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _listHash(List<String>? values) {
  if (values == null) return 0;
  return Object.hashAll(values);
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String>? _asStringList(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    final list = value
        .map((e) => _asString(e))
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return list.isEmpty ? null : list;
  }
  final single = _asString(value);
  return single == null ? null : [single];
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'si' || text == 'sí') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

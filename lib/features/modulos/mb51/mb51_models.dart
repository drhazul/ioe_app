class Mb51Filtros {
  final DateTime? fechaDocDesde;
  final DateTime? fechaDocHasta;
  final DateTime? fechaContDesde;
  final DateTime? fechaContHasta;
  final String? art;
  final List<String>? arts;
  final String? docp;
  final String? almacen;
  final List<String>? almacenes;
  final String? suc;
  final List<String>? sucs;
  final double? clsm;
  final List<double>? clsms;
  final int? vtaesp;
  final String? user;
  final String? txt;
  final int? page;
  final int? limit;

  const Mb51Filtros({
    this.fechaDocDesde,
    this.fechaDocHasta,
    this.fechaContDesde,
    this.fechaContHasta,
    this.art,
    this.arts,
    this.docp,
    this.almacen,
    this.almacenes,
    this.suc,
    this.sucs,
    this.clsm,
    this.clsms,
    this.vtaesp,
    this.user,
    this.txt,
    this.page,
    this.limit,
  });

  Mb51Filtros copyWith({
    DateTime? fechaDocDesde,
    DateTime? fechaDocHasta,
    DateTime? fechaContDesde,
    DateTime? fechaContHasta,
    String? art,
    List<String>? arts,
    String? docp,
    String? almacen,
    List<String>? almacenes,
    String? suc,
    List<String>? sucs,
    double? clsm,
    List<double>? clsms,
    int? vtaesp,
    String? user,
    String? txt,
    int? page,
    int? limit,
  }) {
    return Mb51Filtros(
      fechaDocDesde: fechaDocDesde ?? this.fechaDocDesde,
      fechaDocHasta: fechaDocHasta ?? this.fechaDocHasta,
      fechaContDesde: fechaContDesde ?? this.fechaContDesde,
      fechaContHasta: fechaContHasta ?? this.fechaContHasta,
      art: art ?? this.art,
      arts: arts ?? this.arts,
      docp: docp ?? this.docp,
      almacen: almacen ?? this.almacen,
      almacenes: almacenes ?? this.almacenes,
      suc: suc ?? this.suc,
      sucs: sucs ?? this.sucs,
      clsm: clsm ?? this.clsm,
      clsms: clsms ?? this.clsms,
      vtaesp: vtaesp ?? this.vtaesp,
      user: user ?? this.user,
      txt: txt ?? this.txt,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  bool get isEmpty {
    return fechaDocDesde == null &&
        fechaDocHasta == null &&
        fechaContDesde == null &&
        fechaContHasta == null &&
        _isBlank(art) &&
        _isBlankList(arts) &&
        _isBlank(docp) &&
        _isBlank(almacen) &&
        _isBlankList(almacenes) &&
        _isBlank(suc) &&
        _isBlankList(sucs) &&
        clsm == null &&
        _isBlankNumList(clsms) &&
        vtaesp == null &&
        _isBlank(user) &&
        _isBlank(txt);
  }

  Map<String, dynamic> toApiJson() {
    final data = <String, dynamic>{};
    if (fechaDocDesde != null) data['fechaDocDesde'] = fechaDocDesde!.toIso8601String();
    if (fechaDocHasta != null) data['fechaDocHasta'] = fechaDocHasta!.toIso8601String();
    if (fechaContDesde != null) data['fechaContDesde'] = fechaContDesde!.toIso8601String();
    if (fechaContHasta != null) data['fechaContHasta'] = fechaContHasta!.toIso8601String();
    if (!_isBlank(art)) data['art'] = art!.trim();
    if (!_isBlankList(arts)) data['arts'] = arts;
    if (!_isBlank(docp)) data['docp'] = docp!.trim();
    if (!_isBlank(almacen)) data['almacen'] = almacen!.trim();
    if (!_isBlankList(almacenes)) data['almacenes'] = almacenes;
    if (!_isBlank(suc)) data['suc'] = suc!.trim();
    if (!_isBlankList(sucs)) data['sucs'] = sucs;
    if (clsm != null) data['clsm'] = clsm;
    if (!_isBlankNumList(clsms)) data['clsms'] = clsms;
    if (vtaesp != null) data['vtaesp'] = vtaesp;
    if (!_isBlank(user)) data['user'] = user!.trim();
    if (!_isBlank(txt)) data['txt'] = txt!.trim();
    if (page != null) data['page'] = page;
    if (limit != null) data['limit'] = limit;
    return data;
  }

  Map<String, dynamic> toJson() => toApiJson();

  factory Mb51Filtros.fromJson(Map<String, dynamic> json) {
    return Mb51Filtros(
      fechaDocDesde: _asDate(json['fechaDocDesde']),
      fechaDocHasta: _asDate(json['fechaDocHasta']),
      fechaContDesde: _asDate(json['fechaContDesde']),
      fechaContHasta: _asDate(json['fechaContHasta']),
      art: _asString(json['art']),
      arts: _asStringList(json['arts']),
      docp: _asString(json['docp']),
      almacen: _asString(json['almacen']),
      almacenes: _asStringList(json['almacenes']),
      suc: _asString(json['suc']),
      sucs: _asStringList(json['sucs']),
      clsm: _asDouble(json['clsm']),
      clsms: _asDoubleList(json['clsms']),
      vtaesp: _asInt(json['vtaesp']),
      user: _asString(json['user']),
      txt: _asString(json['txt']),
      page: _asInt(json['page']),
      limit: _asInt(json['limit']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mb51Filtros &&
        _dateEq(fechaDocDesde, other.fechaDocDesde) &&
        _dateEq(fechaDocHasta, other.fechaDocHasta) &&
        _dateEq(fechaContDesde, other.fechaContDesde) &&
        _dateEq(fechaContHasta, other.fechaContHasta) &&
        art == other.art &&
        _listEq(arts, other.arts) &&
        docp == other.docp &&
        almacen == other.almacen &&
        _listEq(almacenes, other.almacenes) &&
        suc == other.suc &&
        _listEq(sucs, other.sucs) &&
        clsm == other.clsm &&
        _numListEq(clsms, other.clsms) &&
        vtaesp == other.vtaesp &&
        user == other.user &&
        txt == other.txt &&
        page == other.page &&
        limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(
        _dateHash(fechaDocDesde),
        _dateHash(fechaDocHasta),
        _dateHash(fechaContDesde),
        _dateHash(fechaContHasta),
        art,
        _listHash(arts),
        docp,
        almacen,
        _listHash(almacenes),
        suc,
        _listHash(sucs),
        clsm,
        _numListHash(clsms),
        vtaesp,
        user,
        txt,
        page,
        limit,
      );
}

class Mb51SearchResult {
  final List<DatMb51Model> items;
  final int total;
  final int page;
  final int limit;

  Mb51SearchResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory Mb51SearchResult.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .map((e) => DatMb51Model.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <DatMb51Model>[];
    return Mb51SearchResult(
      items: items,
      total: (_asInt(json['total']) ?? items.length).toInt(),
      page: (_asInt(json['page']) ?? 1).toInt(),
      limit: (_asInt(json['limit']) ?? items.length).toInt(),
    );
  }
}

class DatMb51Model {
  final String idpd;
  final String? user;
  final double? clsm;
  final String? docp;
  final String? art;
  final String? des;
  final double? ctda;
  final double? ctot;
  final DateTime? fcnd;
  final DateTime? fcnc;
  final String? txt;
  final String? almacen;
  final int? vtaesp;
  final String? suc;

  DatMb51Model({
    required this.idpd,
    this.user,
    this.clsm,
    this.docp,
    this.art,
    this.des,
    this.ctda,
    this.ctot,
    this.fcnd,
    this.fcnc,
    this.txt,
    this.almacen,
    this.vtaesp,
    this.suc,
  });

  factory DatMb51Model.fromJson(Map<String, dynamic> json) {
    return DatMb51Model(
      idpd: _asString(json['IDPD']) ?? '',
      user: _asString(json['USER']),
      clsm: _asDouble(json['CLSM']),
      docp: _asString(json['DOCP']),
      art: _asString(json['ART']),
      des: _asString(json['DES'] ?? json['des']),
      ctda: _asDouble(json['CTDA']),
      ctot: _asDouble(json['CTOT']),
      fcnd: _asDate(json['FCND']),
      fcnc: _asDate(json['FCNC']),
      txt: _asString(json['TXT']),
      almacen: _asString(json['ALMACEN']),
      vtaesp: _asInt(json['VTAESP']),
      suc: _asString(json['SUC']),
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

class DatCmovModel {
  final double? clsm;
  final String? descripcion;

  DatCmovModel({
    required this.clsm,
    this.descripcion,
  });

  factory DatCmovModel.fromJson(Map<String, dynamic> json) {
    return DatCmovModel(
      clsm: _asDouble(json['CLSM']),
      descripcion: _firstString(json, ['DESCRIPCION', 'DES', 'TXT', 'NOMBRE']),
    );
  }

  String get label {
    final code = clsm?.toString() ?? '';
    final desc = (descripcion ?? '').trim();
    if (code.isEmpty) return desc.isEmpty ? '-' : desc;
    return desc.isEmpty ? code : '$code - $desc';
  }
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;
bool _isBlankList(List<String>? values) => values == null || values.isEmpty;
bool _isBlankNumList(List<double>? values) => values == null || values.isEmpty;

bool _dateEq(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
}

int _dateHash(DateTime? value) => value?.millisecondsSinceEpoch ?? 0;

bool _listEq(List<String>? a, List<String>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _numListEq(List<double>? a, List<double>? b) {
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

int _numListHash(List<double>? values) {
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

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _asString(json[key]);
    if (value != null) return value;
  }
  return null;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<double>? _asDoubleList(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    final list = value
        .map((e) => _asDouble(e))
        .whereType<double>()
        .toList();
    return list.isEmpty ? null : list;
  }
  final single = _asDouble(value);
  return single == null ? null : [single];
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

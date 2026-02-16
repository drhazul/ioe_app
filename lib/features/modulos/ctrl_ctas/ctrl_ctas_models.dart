class CtrlCatalogParams {
  final String? search;
  final List<String>? sucs;
  final int limit;

  const CtrlCatalogParams({
    this.search,
    this.sucs,
    this.limit = 200,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CtrlCatalogParams &&
        other.search == search &&
        _listEq(other.sucs, sucs) &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(search, _listHash(sucs), limit);
}

class CtrlCtasConfig {
  final bool hasIdopv;
  final bool isAdmin;
  final String? forcedSuc;
  final List<String> allowedSucs;
  final bool canSelectSucs;

  const CtrlCtasConfig({
    required this.hasIdopv,
    required this.isAdmin,
    this.forcedSuc,
    this.allowedSucs = const [],
    this.canSelectSucs = false,
  });

  factory CtrlCtasConfig.fromJson(Map<String, dynamic> json) {
    final isAdmin = _asBool(json['isAdmin']) ?? false;
    final allowedSucs = _asStringList(json['allowedSucs']) ?? const <String>[];
    return CtrlCtasConfig(
      hasIdopv: _asBool(json['hasIdopv']) ?? false,
      isAdmin: isAdmin,
      forcedSuc: _asString(json['forcedSuc']),
      allowedSucs: allowedSucs,
      canSelectSucs:
          _asBool(json['canSelectSucs']) ?? (isAdmin || allowedSucs.length > 1),
    );
  }
}

class CtrlCtasFiltros {
  final List<String> sucs;
  final List<String> ctas;
  final List<String> clients;
  final List<String> clsds;
  final List<String> idfols;
  final List<String> opvs;
  final DateTime? fecIni;
  final DateTime? fecFin;

  const CtrlCtasFiltros({
    this.sucs = const [],
    this.ctas = const [],
    this.clients = const [],
    this.clsds = const [],
    this.idfols = const [],
    this.opvs = const [],
    this.fecIni,
    this.fecFin,
  });

  CtrlCtasFiltros copyWith({
    List<String>? sucs,
    List<String>? ctas,
    List<String>? clients,
    List<String>? clsds,
    List<String>? idfols,
    List<String>? opvs,
    DateTime? fecIni,
    DateTime? fecFin,
    bool clearFecIni = false,
    bool clearFecFin = false,
  }) {
    return CtrlCtasFiltros(
      sucs: sucs ?? this.sucs,
      ctas: ctas ?? this.ctas,
      clients: clients ?? this.clients,
      clsds: clsds ?? this.clsds,
      idfols: idfols ?? this.idfols,
      opvs: opvs ?? this.opvs,
      fecIni: clearFecIni ? null : (fecIni ?? this.fecIni),
      fecFin: clearFecFin ? null : (fecFin ?? this.fecFin),
    );
  }

  Map<String, dynamic> toApiJson() {
    final map = <String, dynamic>{};
    if (sucs.isNotEmpty) map['sucs'] = sucs;
    if (ctas.isNotEmpty) map['ctas'] = ctas;
    if (clients.isNotEmpty) map['clients'] = clients;
    if (clsds.isNotEmpty) map['clsds'] = clsds;
    if (idfols.isNotEmpty) map['idfols'] = idfols;
    if (opvs.isNotEmpty) map['opvs'] = opvs;
    if (fecIni != null) map['fecIni'] = _fmtDateIso(fecIni!);
    if (fecFin != null) map['fecFin'] = _fmtDateIso(fecFin!);
    return map;
  }

  Map<String, dynamic> toJson() => toApiJson();

  factory CtrlCtasFiltros.fromJson(Map<String, dynamic> json) {
    return CtrlCtasFiltros(
      sucs: _asStringList(json['sucs']) ?? const [],
      ctas: _asStringList(json['ctas']) ?? const [],
      clients: _asStringList(json['clients']) ?? const [],
      clsds: _asStringList(json['clsds']) ?? const [],
      idfols: _asStringList(json['idfols']) ?? const [],
      opvs: _asStringList(json['opvs']) ?? const [],
      fecIni: _asDate(json['fecIni']),
      fecFin: _asDate(json['fecFin']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CtrlCtasFiltros &&
        _listEq(other.sucs, sucs) &&
        _listEq(other.ctas, ctas) &&
        _listEq(other.clients, clients) &&
        _listEq(other.clsds, clsds) &&
        _listEq(other.idfols, idfols) &&
        _listEq(other.opvs, opvs) &&
        _dateEq(other.fecIni, fecIni) &&
        _dateEq(other.fecFin, fecFin);
  }

  @override
  int get hashCode => Object.hash(
        _listHash(sucs),
        _listHash(ctas),
        _listHash(clients),
        _listHash(clsds),
        _listHash(idfols),
        _listHash(opvs),
        _dateHash(fecIni),
        _dateHash(fecFin),
      );
}

class CtrlCtaOption {
  final String cta;
  final String? dcta;
  final String? relacion;
  final String? suc;

  const CtrlCtaOption({
    required this.cta,
    this.dcta,
    this.relacion,
    this.suc,
  });

  factory CtrlCtaOption.fromJson(Map<String, dynamic> json) {
    return CtrlCtaOption(
      cta: _asString(json['CTA']) ?? '',
      dcta: _asString(json['DCTA']),
      relacion: _asString(json['RELACION']),
      suc: _asString(json['SUC']),
    );
  }

  String get label {
    final desc = (dcta ?? '').trim();
    return desc.isEmpty ? cta : '$cta - $desc';
  }
}

class CtrlClienteOption {
  final String client;
  final String? razonSocial;
  final String? suc;

  const CtrlClienteOption({
    required this.client,
    this.razonSocial,
    this.suc,
  });

  factory CtrlClienteOption.fromJson(Map<String, dynamic> json) {
    return CtrlClienteOption(
      client: _asString(json['IDC_TEXT'] ?? json['IDC']) ?? '',
      razonSocial: _asString(json['RazonSocialReceptor']),
      suc: _asString(json['SUC']),
    );
  }

  String get label {
    final name = (razonSocial ?? '').trim();
    return name.isEmpty ? client : '$client - $name';
  }
}

class CtrlOpvOption {
  final String idopv;
  final String? nombre;
  final String? suc;

  const CtrlOpvOption({
    required this.idopv,
    this.nombre,
    this.suc,
  });

  factory CtrlOpvOption.fromJson(Map<String, dynamic> json) {
    return CtrlOpvOption(
      idopv: _asString(json['IDOPV']) ?? '',
      nombre: _asString(json['NOMBRE_COMPLETO']),
      suc: _asString(json['SUC']),
    );
  }

  String get label {
    final name = (nombre ?? '').trim();
    return name.isEmpty ? idopv : '$idopv - $name';
  }
}

class CtrlCtasResumenClienteItem {
  final String client;
  final String? razonSocial;
  final double total;

  const CtrlCtasResumenClienteItem({
    required this.client,
    this.razonSocial,
    required this.total,
  });

  factory CtrlCtasResumenClienteItem.fromJson(Map<String, dynamic> json) {
    return CtrlCtasResumenClienteItem(
      client: _asString(json['CLIENT']) ?? '',
      razonSocial: _asString(json['RazonSocialReceptor']),
      total: _asDouble(json['TOTAL']) ?? 0,
    );
  }
}

class CtrlCtasResumenTransItem {
  final String client;
  final String? razonSocial;
  final String? cta;
  final String? idfol;
  final double total;

  const CtrlCtasResumenTransItem({
    required this.client,
    this.razonSocial,
    this.cta,
    this.idfol,
    required this.total,
  });

  factory CtrlCtasResumenTransItem.fromJson(Map<String, dynamic> json) {
    return CtrlCtasResumenTransItem(
      client: _asString(json['CLIENT']) ?? '',
      razonSocial: _asString(json['RazonSocialReceptor']),
      cta: _asString(json['CTA']),
      idfol: _asString(json['IDFOL']),
      total: _asDouble(json['TOTAL']) ?? 0,
    );
  }
}

class CtrlCtasDetalleItem {
  final String? ndoc;
  final String? suc;
  final DateTime? fcnd;
  final String? client;
  final String? razonSocial;
  final String? cta;
  final String? clsd;
  final String? idfol;
  final String? rtxt;
  final double impt;
  final String? idopv;

  const CtrlCtasDetalleItem({
    this.ndoc,
    this.suc,
    this.fcnd,
    this.client,
    this.razonSocial,
    this.cta,
    this.clsd,
    this.idfol,
    this.rtxt,
    required this.impt,
    this.idopv,
  });

  factory CtrlCtasDetalleItem.fromJson(Map<String, dynamic> json) {
    return CtrlCtasDetalleItem(
      ndoc: _asString(json['NDOC']),
      suc: _asString(json['SUC']),
      fcnd: _asDate(json['FCND']),
      client: _asString(json['CLIENT']),
      razonSocial: _asString(json['RazonSocialReceptor']),
      cta: _asString(json['CTA']),
      clsd: _asString(json['CLSD']),
      idfol: _asString(json['IDFOL']),
      rtxt: _asString(json['RTXT']),
      impt: _asDouble(json['IMPT']) ?? 0,
      idopv: _asString(json['IDOPV']),
    );
  }
}

String _fmtDateIso(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
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
        .map((item) => _asString(item))
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList();
    return list.isEmpty ? null : list;
  }
  final single = _asString(value);
  return single == null ? null : [single];
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
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

bool _dateEq(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
}

int _dateHash(DateTime? value) => value?.millisecondsSinceEpoch ?? 0;

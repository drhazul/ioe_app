class SugeridosPagedResult<T> {
  const SugeridosPagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
}

class SugeridoCalculoModel {
  const SugeridoCalculoModel({
    required this.jerarquiaLarga,
    required this.suc,
    required this.art,
    required this.des,
    required this.base,
    required this.sph,
    required this.cyl,
    required this.adic,
    required this.stock,
    required this.stockMin,
    required this.estatus,
    required this.diaReabasto,
    required this.nprov,
    required this.nivelProv,
    required this.cto,
    required this.unComp,
    required this.factComp,
    required this.vta90,
    required this.factVtaPD,
    required this.diasInv,
    required this.facReab,
    required this.sug,
    required this.pedido,
    required this.ped,
    required this.cantFinalCompra,
    required this.importe,
    this.tipo,
    this.upc,
  });

  final String jerarquiaLarga;
  final String suc;
  final String art;
  final String des;
  final String base;
  final double sph;
  final double cyl;
  final double adic;
  final double stock;
  final double stockMin;
  final String estatus;
  final double diaReabasto;
  final int nprov;
  final int nivelProv;
  final double cto;
  final String unComp;
  final double factComp;
  final double vta90;
  final double factVtaPD;
  final double diasInv;
  final double facReab;
  final double sug;
  final double pedido;
  final double ped;
  final double cantFinalCompra;
  final double importe;
  final String? tipo;
  final String? upc;

  factory SugeridoCalculoModel.fromJson(Map<String, dynamic> json) {
    return SugeridoCalculoModel(
      jerarquiaLarga: _txt(json['jerarquiaLarga']),
      suc: _txt(json['suc']),
      tipo: _txtNullable(json['tipo']),
      art: _txt(json['art']),
      upc: _txtNullable(json['upc']),
      des: _txt(json['des']),
      base: _txt(json['base']),
      sph: _toDouble(json['sph']),
      cyl: _toDouble(json['cyl']),
      adic: _toDouble(json['adic']),
      stock: _toDouble(json['stock']),
      stockMin: _toDouble(json['stockMin']),
      estatus: _txt(json['estatus']),
      diaReabasto: _toDouble(json['diaReabasto']),
      nprov: _toInt(json['nprov']),
      nivelProv: _toInt(json['nivelProv']),
      cto: _toDouble(json['cto']),
      unComp: _txt(json['unComp']),
      factComp: _toDouble(json['factComp']),
      vta90: _toDouble(json['vta90']),
      factVtaPD: _toDouble(json['factVtaPD']),
      diasInv: _toDouble(json['diasInv']),
      facReab: _toDouble(json['facReab']),
      sug: _toDouble(json['sug']),
      pedido: _toDouble(json['pedido']),
      ped: _toDouble(json['ped']),
      cantFinalCompra: _toDouble(json['cantFinalCompra']),
      importe: _toDouble(json['importe']),
    );
  }
}

class SugeridoOrdenModel {
  const SugeridoOrdenModel({
    required this.nped,
    required this.suc,
    required this.tipo,
    required this.nprov,
    required this.usr,
    required this.impp,
    required this.nart,
    required this.estatus,
    required this.sug,
    required this.detalleActivo,
    this.fcnp,
    this.fcnc,
    this.alias,
    this.rsoc,
    this.detalle = const [],
  });

  final String nped;
  final String suc;
  final String tipo;
  final int nprov;
  final String usr;
  final double impp;
  final int nart;
  final String estatus;
  final bool sug;
  final int detalleActivo;
  final DateTime? fcnp;
  final DateTime? fcnc;
  final String? alias;
  final String? rsoc;
  final List<SugeridoDetalleModel> detalle;

  factory SugeridoOrdenModel.fromJson(Map<String, dynamic> json) {
    final rawDetalle = json['detalle'];
    return SugeridoOrdenModel(
      nped: _txt(json['nped']),
      suc: _txt(json['suc']),
      tipo: _txt(json['tipo']),
      nprov: _toInt(json['nprov']),
      usr: _txt(json['usr']),
      fcnp: _toDate(json['fcnp']),
      fcnc: _toDate(json['fcnc']),
      impp: _toDouble(json['impp']),
      nart: _toInt(json['nart']),
      estatus: _txt(json['estatus']).toUpperCase(),
      sug: _toBool(json['sug']),
      alias: _txtNullable(json['alias']),
      rsoc: _txtNullable(json['rsoc']),
      detalleActivo: _toInt(json['detalleActivo']),
      detalle: rawDetalle is List
          ? rawDetalle
                .map(
                  (row) => SugeridoDetalleModel.fromJson(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class SugeridoDetalleModel {
  const SugeridoDetalleModel({
    required this.idped,
    required this.pos,
    required this.art,
    required this.cto,
    required this.ctdped,
    required this.uncom,
    required this.ctot,
    this.des,
    this.upc,
    this.bloq = 0,
  });

  final String idped;
  final int pos;
  final String art;
  final double cto;
  final double ctdped;
  final String uncom;
  final double ctot;
  final String? des;
  final String? upc;
  final int bloq;

  factory SugeridoDetalleModel.fromJson(Map<String, dynamic> json) {
    return SugeridoDetalleModel(
      idped: _txt(json['idped']),
      pos: _toInt(json['pos']),
      art: _txt(json['art']),
      cto: _toDouble(json['cto']),
      ctdped: _toDouble(json['ctdped']),
      uncom: _txt(json['uncom']),
      ctot: _toDouble(json['ctot']),
      des: _txtNullable(json['des']),
      upc: _txtNullable(json['upc']),
      bloq: _toInt(json['bloq']),
    );
  }
}

class SugeridoOrdenDraftItem {
  const SugeridoOrdenDraftItem({
    required this.art,
    required this.ctdped,
    required this.cto,
    required this.uncom,
  });

  final String art;
  final double ctdped;
  final double cto;
  final String uncom;

  Map<String, dynamic> toJson() => {
    'art': art,
    'ctdped': ctdped,
    'cto': cto,
    'uncom': uncom,
  };
}

class SugeridoArticuloProveedorModel {
  const SugeridoArticuloProveedorModel({
    required this.art,
    required this.des,
    required this.cto,
    required this.unComp,
    this.upc,
  });

  final String art;
  final String des;
  final double cto;
  final String unComp;
  final String? upc;

  SugeridoOrdenDraftItem toDraft(double cantidad) => SugeridoOrdenDraftItem(
    art: art,
    ctdped: cantidad,
    cto: cto,
    uncom: unComp,
  );

  factory SugeridoArticuloProveedorModel.fromJson(Map<String, dynamic> json) {
    return SugeridoArticuloProveedorModel(
      art: _txt(json['art']),
      des: _txt(json['des']),
      upc: _txtNullable(json['upc']),
      cto: _toDouble(json['cto']),
      unComp: _txt(json['unComp']),
    );
  }
}

class SugeridoProveedorModel {
  const SugeridoProveedorModel({
    required this.id,
    required this.alias,
    required this.rsoc,
  });

  final int id;
  final String alias;
  final String rsoc;

  String get label {
    final name = alias.trim().isNotEmpty ? alias : rsoc;
    return name.trim().isEmpty ? '$id' : '$id - $name';
  }

  factory SugeridoProveedorModel.fromJson(Map<String, dynamic> json) {
    return SugeridoProveedorModel(
      id: _toInt(json['id']),
      alias: _txt(json['alias']),
      rsoc: _txt(json['rsoc']),
    );
  }
}

String _txt(dynamic value) => '${value ?? ''}'.trim();

String? _txtNullable(dynamic value) {
  final text = _txt(value);
  return text.isEmpty ? null : text;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _txt(value).toLowerCase();
  return text == 'true' || text == '1' || text == '-1';
}

DateTime? _toDate(dynamic value) {
  final text = _txt(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

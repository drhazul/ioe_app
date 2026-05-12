class PromocionModel {
  const PromocionModel({
    required this.idProm,
    required this.suc,
    required this.tProm,
    required this.tipoDesc,
    required this.descPromo,
    required this.est,
    required this.prioridad,
    this.acumulable,
    this.combinable,
    this.fcnIni,
    this.fcnTer,
    this.prcDesc,
    this.impDesc,
    this.impCom,
  });

  final int idProm;
  final String? suc;
  final String? tProm;
  final String? tipoDesc;
  final String? descPromo;
  final int? est;
  final int? prioridad;
  final int? acumulable;
  final int? combinable;
  final DateTime? fcnIni;
  final DateTime? fcnTer;
  final double? prcDesc;
  final double? impDesc;
  final double? impCom;

  bool get isActive => (est ?? 0) == 1 || (est ?? 0) == -1;

  factory PromocionModel.fromJson(Map<String, dynamic> json) {
    return PromocionModel(
      idProm: _asInt(json['idProm'] ?? json['ID_PROM']) ?? 0,
      suc: _asText(json['suc'] ?? json['SUC']),
      tProm: _asText(json['tProm'] ?? json['T_PROM']),
      tipoDesc: _asText(json['tipoDesc'] ?? json['TIPO_DESC']),
      descPromo: _asText(json['descPromo'] ?? json['DESC_PROMO']),
      est: _asInt(json['est'] ?? json['EST']),
      prioridad: _asInt(json['prioridad'] ?? json['PRIORIDAD']),
      acumulable: _asInt(json['acumulable'] ?? json['ACUMULABLE']),
      combinable: _asInt(json['combinable'] ?? json['COMBINABLE']),
      fcnIni: _asDate(json['fcnIni'] ?? json['FCN_INI']),
      fcnTer: _asDate(json['fcnTer'] ?? json['FCN_TER']),
      prcDesc: _asDouble(json['prcDesc'] ?? json['PRC_DESC']),
      impDesc: _asDouble(json['impDesc'] ?? json['IMP_DESC']),
      impCom: _asDouble(json['impCom'] ?? json['IMP_COM']),
    );
  }
}

class PromocionCriterioModel {
  const PromocionCriterioModel({
    required this.idCriterio,
    required this.idProm,
    this.suc,
    this.cliente,
    this.depa,
    this.subd,
    this.clas,
    this.scla,
    this.scla2,
    this.guia,
    this.art,
    this.upc,
    this.est,
  });

  final int idCriterio;
  final int idProm;
  final String? suc;
  final double? cliente;
  final double? depa;
  final double? subd;
  final double? clas;
  final double? scla;
  final double? scla2;
  final String? guia;
  final String? art;
  final String? upc;
  final int? est;

  factory PromocionCriterioModel.fromJson(Map<String, dynamic> json) {
    return PromocionCriterioModel(
      idCriterio: _asInt(json['ID_CRITERIO'] ?? json['idCriterio']) ?? 0,
      idProm: _asInt(json['ID_PROM'] ?? json['idProm']) ?? 0,
      suc: _asText(json['SUC'] ?? json['suc']),
      cliente: _asDouble(json['CLIENTE'] ?? json['cliente']),
      depa: _asDouble(json['DEPA'] ?? json['depa']),
      subd: _asDouble(json['SUBD'] ?? json['subd']),
      clas: _asDouble(json['CLAS'] ?? json['clas']),
      scla: _asDouble(json['SCLA'] ?? json['scla']),
      scla2: _asDouble(json['SCLA2'] ?? json['scla2']),
      guia: _asText(json['GUIA'] ?? json['guia']),
      art: _asText(json['ART'] ?? json['art']),
      upc: _asText(json['UPC'] ?? json['upc']),
      est: _asInt(json['EST'] ?? json['est']),
    );
  }
}

class PromocionBeneficioModel {
  const PromocionBeneficioModel({
    required this.idBeneficio,
    required this.idProm,
    this.tBeneficio,
    this.prcDesc,
    this.impDesc,
    this.artGratis,
    this.upcGratis,
    this.cantGratis,
    this.precioGratis,
    this.prioridad,
    this.acumulable,
    this.est,
  });

  final int idBeneficio;
  final int idProm;
  final String? tBeneficio;
  final double? prcDesc;
  final double? impDesc;
  final String? artGratis;
  final String? upcGratis;
  final double? cantGratis;
  final double? precioGratis;
  final int? prioridad;
  final int? acumulable;
  final int? est;

  factory PromocionBeneficioModel.fromJson(Map<String, dynamic> json) {
    return PromocionBeneficioModel(
      idBeneficio: _asInt(json['ID_BENEFICIO'] ?? json['idBeneficio']) ?? 0,
      idProm: _asInt(json['ID_PROM'] ?? json['idProm']) ?? 0,
      tBeneficio: _asText(json['T_BENEFICIO'] ?? json['tBeneficio']),
      prcDesc: _asDouble(json['PRC_DESC'] ?? json['prcDesc']),
      impDesc: _asDouble(json['IMP_DESC'] ?? json['impDesc']),
      artGratis: _asText(json['ART_GRATIS'] ?? json['artGratis']),
      upcGratis: _asText(json['UPC_GRATIS'] ?? json['upcGratis']),
      cantGratis: _asDouble(json['CANT_GRATIS'] ?? json['cantGratis']),
      precioGratis: _asDouble(json['PRECIO_GRATIS'] ?? json['precioGratis']),
      prioridad: _asInt(json['PRIORIDAD'] ?? json['prioridad']),
      acumulable: _asInt(json['ACUMULABLE'] ?? json['acumulable']),
      est: _asInt(json['EST'] ?? json['est']),
    );
  }
}

class CatalogOptionModel {
  const CatalogOptionModel({required this.clave, required this.descripcion});

  final String clave;
  final String descripcion;

  factory CatalogOptionModel.fromJson(Map<String, dynamic> json) {
    final clave = _asText(json['clave'] ?? json['CLAVE']) ?? '';
    final descripcion =
        _asText(json['descripcion'] ?? json['DESCRIPCION']) ?? clave;
    return CatalogOptionModel(clave: clave, descripcion: descripcion);
  }
}

class CatalogNumOptionModel {
  const CatalogNumOptionModel({required this.valor, required this.descripcion});

  final int valor;
  final String descripcion;

  factory CatalogNumOptionModel.fromJson(Map<String, dynamic> json) {
    return CatalogNumOptionModel(
      valor: _asInt(json['valor'] ?? json['VALOR']) ?? 0,
      descripcion: _asText(json['descripcion'] ?? json['DESCRIPCION']) ?? '',
    );
  }
}

class CatalogTextOptionModel {
  const CatalogTextOptionModel({
    required this.valor,
    required this.descripcion,
  });

  final String valor;
  final String descripcion;

  factory CatalogTextOptionModel.fromJson(Map<String, dynamic> json) {
    final valor =
        _asText(
          json['valor'] ??
              json['VALOR'] ??
              json['suc'] ??
              json['SUC'] ??
              json['clave'] ??
              json['CLAVE'],
        ) ??
        '';
    final descripcion =
        _asText(
          json['descripcion'] ??
              json['DESCRIPCION'] ??
              json['desc'] ??
              json['DESC'],
        ) ??
        valor;
    return CatalogTextOptionModel(valor: valor, descripcion: descripcion);
  }
}

class PromoArticuloOptionModel {
  const PromoArticuloOptionModel({
    required this.art,
    required this.upc,
    required this.descripcion,
  });

  final String art;
  final String upc;
  final String descripcion;

  factory PromoArticuloOptionModel.fromJson(Map<String, dynamic> json) {
    return PromoArticuloOptionModel(
      art: _asText(json['art'] ?? json['ART']) ?? '',
      upc: _asText(json['upc'] ?? json['UPC']) ?? '',
      descripcion: _asText(json['descripcion'] ?? json['DESCRIPCION']) ?? '',
    );
  }
}

class PromoConfigModel {
  const PromoConfigModel({
    this.idConfig,
    this.idProm,
    this.tBeneficio,
    this.prcDesc,
    this.impDesc,
    this.precioGratis,
    this.sucTodas = true,
    this.sucList = const [],
    this.cliente,
    this.depaList = const [],
    this.subdList = const [],
    this.clasList = const [],
    this.sclaList = const [],
    this.scla2List = const [],
    this.guiaList = const [],
    this.artList = const [],
    this.upcList = const [],
    this.activo = 1,
  });

  final int? idConfig;
  final int? idProm;
  final String? tBeneficio;
  final double? prcDesc;
  final double? impDesc;
  final double? precioGratis;
  final bool sucTodas;
  final List<String> sucList;
  final int? cliente;
  final List<int> depaList;
  final List<int> subdList;
  final List<int> clasList;
  final List<int> sclaList;
  final List<int> scla2List;
  final List<String> guiaList;
  final List<String> artList;
  final List<String> upcList;
  final int activo;

  factory PromoConfigModel.fromJson(Map<String, dynamic> json) {
    List<String> parseTextList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((x) => _asText(x) ?? '')
            .where((x) => x.trim().isNotEmpty)
            .toList();
      }
      return const [];
    }

    List<int> parseIntList(dynamic raw) {
      if (raw is List) {
        return raw.map((x) => _asInt(x) ?? 0).where((x) => x > 0).toList();
      }
      return const [];
    }

    return PromoConfigModel(
      idConfig: _asInt(json['idConfig'] ?? json['ID_CONFIG']),
      idProm: _asInt(json['idProm'] ?? json['ID_PROM']),
      tBeneficio: _asText(json['tBeneficio'] ?? json['T_BENEFICIO']),
      prcDesc: _asDouble(json['prcDesc'] ?? json['PRC_DESC']),
      impDesc: _asDouble(json['impDesc'] ?? json['IMP_DESC']),
      precioGratis: _asDouble(json['precioGratis'] ?? json['PRECIO_GRATIS']),
      sucTodas:
          (json['sucTodas'] ?? json['SUC_TODAS']) == true ||
          (_asInt(json['sucTodas'] ?? json['SUC_TODAS']) ?? 0) == 1,
      sucList: parseTextList(json['sucList'] ?? json['SUC_LIST']),
      cliente: _positiveInt(json['cliente'] ?? json['CLIENTE']),
      depaList: parseIntList(json['depaList'] ?? json['DEPA_LIST']),
      subdList: parseIntList(json['subdList'] ?? json['SUBD_LIST']),
      clasList: parseIntList(json['clasList'] ?? json['CLAS_LIST']),
      sclaList: parseIntList(json['sclaList'] ?? json['SCLA_LIST']),
      scla2List: parseIntList(json['scla2List'] ?? json['SCLA2_LIST']),
      guiaList: parseTextList(json['guiaList'] ?? json['GUIA_LIST']),
      artList: parseTextList(json['artList'] ?? json['ART_LIST']),
      upcList: parseTextList(json['upcList'] ?? json['UPC_LIST']),
      activo: _asInt(json['activo'] ?? json['ACTIVO']) ?? 1,
    );
  }
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
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _positiveInt(dynamic value) {
  final n = _asInt(value);
  return (n != null && n > 0) ? n : null;
}

String? _asText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

class PagoCierreContext {
  PagoCierreContext({
    required this.idfol,
    required this.suc,
    required this.clien,
    required this.esta,
    required this.rqfacDefault,
    required this.ivaIntegrado,
    required this.itemsCount,
    required this.totalBase,
  });

  final String idfol;
  final String suc;
  final int? clien;
  final String? esta;
  final bool rqfacDefault;
  final int? ivaIntegrado;
  final int itemsCount;
  final double totalBase;

  factory PagoCierreContext.fromJson(Map<String, dynamic> json) {
    return PagoCierreContext(
      idfol: json['idfol']?.toString() ?? '',
      suc: json['suc']?.toString() ?? '',
      clien: _asInt(json['clien']),
      esta: json['esta']?.toString(),
      rqfacDefault: json['rqfacDefault'] == true,
      ivaIntegrado: _asInt(json['ivaIntegrado']),
      itemsCount: _asInt(json['itemsCount']) ?? 0,
      totalBase: _asDouble(json['totalBase']) ?? 0,
    );
  }
}

class PagoCierreTotales {
  PagoCierreTotales({
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.totalBase,
    required this.ivaIntegrado,
    required this.tipotran,
    required this.rqfac,
  });

  final double subtotal;
  final double iva;
  final double total;
  final double totalBase;
  final int? ivaIntegrado;
  final String tipotran;
  final bool rqfac;

  factory PagoCierreTotales.fromJson(Map<String, dynamic> json) {
    return PagoCierreTotales(
      subtotal: _asDouble(json['subtotal']) ?? 0,
      iva: _asDouble(json['iva']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
      totalBase: _asDouble(json['totalBase']) ?? 0,
      ivaIntegrado: _asInt(json['ivaIntegrado']),
      tipotran: json['tipotran']?.toString().toUpperCase() ?? 'VF',
      rqfac: json['rqfac'] == true,
    );
  }
}

class PagoCierrePreviewResponse {
  PagoCierrePreviewResponse({
    required this.ok,
    required this.context,
    required this.totales,
  });

  final bool ok;
  final PagoCierreContext context;
  final PagoCierreTotales totales;

  factory PagoCierrePreviewResponse.fromJson(Map<String, dynamic> json) {
    return PagoCierrePreviewResponse(
      ok: json['ok'] == true,
      context: PagoCierreContext.fromJson(
        Map<String, dynamic>.from(json['context'] as Map),
      ),
      totales: PagoCierreTotales.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map),
      ),
    );
  }
}

class PagoCierreFormaDraft {
  PagoCierreFormaDraft({
    required this.id,
    required this.form,
    required this.impp,
    this.aut,
  });

  final String id;
  final String form;
  final double impp;
  final String? aut;

  PagoCierreFormaDraft copyWith({
    String? id,
    String? form,
    double? impp,
    String? aut,
  }) {
    return PagoCierreFormaDraft(
      id: id ?? this.id,
      form: form ?? this.form,
      impp: impp ?? this.impp,
      aut: aut ?? this.aut,
    );
  }

  Map<String, dynamic> toApiJson() => {
        'form': form,
        'impp': impp,
        if (aut != null && aut!.trim().isNotEmpty) 'aut': aut!.trim(),
      };
}

class PagoCierreResponse {
  PagoCierreResponse({
    required this.ok,
    required this.idfol,
    required this.tipotran,
    required this.rqfac,
    required this.totales,
    required this.sumPagos,
    required this.cambio,
  });

  final bool ok;
  final String idfol;
  final String tipotran;
  final bool rqfac;
  final PagoCierreTotales totales;
  final double sumPagos;
  final double cambio;

  factory PagoCierreResponse.fromJson(Map<String, dynamic> json) {
    return PagoCierreResponse(
      ok: json['ok'] == true,
      idfol: json['idfol']?.toString() ?? '',
      tipotran: json['tipotran']?.toString().toUpperCase() ?? 'VF',
      rqfac: json['rqfac'] == true,
      totales: PagoCierreTotales.fromJson(
        Map<String, dynamic>.from(json['totales'] as Map),
      ),
      sumPagos: _asDouble(json['sumPagos']) ?? 0,
      cambio: _asDouble(json['cambio']) ?? 0,
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

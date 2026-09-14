class DevPaged<T> {
  const DevPaged({
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

class DevOption {
  const DevOption({
    required this.id,
    required this.code,
    required this.label,
    this.requiresEvidence = false,
    this.requiresDocument = false,
  });
  final int id;
  final String code;
  final String label;
  final bool requiresEvidence;
  final bool requiresDocument;
  factory DevOption.fromJson(Map<String, dynamic> json) => DevOption(
    id: _i(json['id']),
    code: _s(json['clave'] ?? json['codigo']),
    label: _s(json['descripcion'] ?? json['nombre']),
    requiresEvidence: _b(json['requiereEvidencia']),
    requiresDocument: _b(json['requiereDocumento']),
  );
}

class DevBranch {
  const DevBranch({required this.suc, required this.name});
  final String suc;
  final String name;
  factory DevBranch.fromJson(Map<String, dynamic> json) =>
      DevBranch(suc: _s(json['suc']), name: _s(json['nombre']));
}

class DevProvider {
  const DevProvider({required this.id, required this.name});
  final int id;
  final String name;
  factory DevProvider.fromJson(Map<String, dynamic> json) =>
      DevProvider(id: _i(json['id']), name: _s(json['nombre']));
}

class DevArticle {
  const DevArticle({
    required this.art,
    required this.upc,
    required this.description,
    required this.cost,
    required this.stock,
    required this.available,
    required this.unit,
  });
  final String art;
  final String upc;
  final String description;
  final double cost;
  final double stock;
  final double available;
  final String unit;
  factory DevArticle.fromJson(Map<String, dynamic> json) => DevArticle(
    art: _s(json['art']),
    upc: _s(json['upc']),
    description: _s(json['descripcion']),
    cost: _d(json['costo']),
    stock: _d(json['stock']),
    available: _d(json['disponible']),
    unit: _s(json['unidad']),
  );
}

class DevSourceDocument {
  const DevSourceDocument({
    required this.kind,
    required this.document,
    required this.suc,
    required this.provider,
    required this.warehouse,
    required this.date,
    required this.items,
  });

  final String kind;
  final String document;
  final String suc;
  final String provider;
  final String warehouse;
  final DateTime? date;
  final List<DevSourceItem> items;

  factory DevSourceDocument.fromJson(
    Map<String, dynamic> json, {
    required String kind,
    required String document,
  }) {
    final raw = json['detalle'];
    return DevSourceDocument(
      kind: kind,
      document: document,
      suc: _s(json['suc']),
      provider: _s(json['proveedor'] ?? json['alias'] ?? json['rsoc']),
      warehouse: _s(json['almacen']).isEmpty ? '002' : _s(json['almacen']),
      date: _date(json['fechaFisica'] ?? json['fcnp'] ?? json['fcnc']),
      items: raw is List
          ? raw
                .map(
                  (item) => DevSourceItem.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class DevSourceItem {
  const DevSourceItem({
    required this.art,
    required this.upc,
    required this.description,
    required this.ordered,
    required this.received,
    required this.pending,
    required this.cost,
  });

  final String art;
  final String upc;
  final String description;
  final double ordered;
  final double received;
  final double pending;
  final double cost;

  factory DevSourceItem.fromJson(Map<String, dynamic> json) {
    final ordered = _d(
      json['solicitado'] ?? json['ctdped'] ?? json['cantidadSolicitada'],
    );
    final received = _d(
      json['recibido'] ??
          json['ctdrec'] ??
          json['cantidadRecibida'] ??
          json['cantidadAceptada'],
    );
    final pending = _d(json['pendiente']) > 0
        ? _d(json['pendiente'])
        : (ordered - received).clamp(0, double.infinity).toDouble();
    return DevSourceItem(
      art: _s(json['art']),
      upc: _s(json['upc']),
      description: _s(json['des'] ?? json['descripcion']),
      ordered: ordered,
      received: received,
      pending: pending,
      cost: _d(json['costo'] ?? json['cto']),
    );
  }

  DevArticle toArticle() => DevArticle(
    art: art,
    upc: upc,
    description: description,
    cost: cost,
    stock: received > 0 ? received : ordered,
    available: received > 0 ? received : ordered,
    unit: '',
  );
}

class DevDetail {
  const DevDetail({
    required this.idpd,
    required this.art,
    required this.upc,
    required this.description,
    required this.quantity,
    required this.blocked,
    required this.cost,
    required this.amount,
    required this.reason,
    required this.reasonCode,
    required this.reasonDescription,
    required this.requiresEvidence,
    required this.requiresDocument,
    required this.evidenceCount,
    required this.available,
    required this.obs,
    required this.lot,
    this.expiration,
    this.capturedAt,
  });
  final int idpd;
  final String art;
  final String upc;
  final String description;
  final double quantity;
  final double blocked;
  final double cost;
  final double amount;
  final int reason;
  final String reasonCode;
  final String reasonDescription;
  final bool requiresEvidence;
  final bool requiresDocument;
  final int evidenceCount;
  final double available;
  final String obs;
  final String lot;
  final DateTime? expiration;
  final DateTime? capturedAt;
  factory DevDetail.fromJson(Map<String, dynamic> json) => DevDetail(
    idpd: _i(json['idpd']),
    art: _s(json['art']),
    upc: _s(json['upc']),
    description: _s(json['descripcion']),
    quantity: _d(json['cantidad']),
    blocked: _d(json['cantidadBloqueada']),
    cost: _d(json['costo']),
    amount: _d(json['importe']),
    reason: _i(json['motivo']),
    reasonCode: _s(json['motivoCodigo']),
    reasonDescription: _s(json['motivoDescripcion']),
    requiresEvidence: _b(json['requiereEvidencia']),
    requiresDocument: _b(json['requiereDocumento']),
    evidenceCount: _i(json['evidencias']),
    available: _d(json['disponible']),
    obs: _s(json['obs']),
    lot: _s(json['lote']),
    expiration: _date(json['caducidad']),
    capturedAt: _date(json['fechaCaptura'] ?? json['fcnr']),
  );
}

class DevEvidence {
  const DevEvidence({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.content,
    this.createdAt,
  });

  final String id;
  final String name;
  final String mimeType;
  final String content;
  final DateTime? createdAt;

  factory DevEvidence.fromJson(Map<String, dynamic> json) => DevEvidence(
    id: _s(json['id']),
    name: _s(json['nombreArchivo']),
    mimeType: _s(json['mimeType']),
    content: _s(json['contenido']),
    createdAt: _date(json['fecha']),
  );
}

class DevDocument {
  const DevDocument({
    required this.doc,
    required this.suc,
    required this.warehouse,
    required this.providerId,
    required this.provider,
    required this.typeId,
    required this.typeDescription,
    required this.status,
    required this.obs,
    required this.oc,
    required this.receipt,
    required this.lines,
    required this.quantity,
    required this.amount,
    required this.details,
    this.date,
    this.requestDate,
    this.authorizationDate,
    this.requestUser = '',
    this.authorizationUser = '',
    this.rejectionReason = '',
  });
  final String doc;
  final String suc;
  final String warehouse;
  final int providerId;
  final String provider;
  final int typeId;
  final String typeDescription;
  final String status;
  final String obs;
  final String oc;
  final String receipt;
  final int lines;
  final double quantity;
  final double amount;
  final DateTime? date;
  final DateTime? requestDate;
  final DateTime? authorizationDate;
  final String requestUser;
  final String authorizationUser;
  final String rejectionReason;
  final List<DevDetail> details;
  bool get editable => status == 'BORRADOR';
  factory DevDocument.fromJson(Map<String, dynamic> json) {
    final raw = json['detalle'];
    return DevDocument(
      doc: _s(json['doc']),
      suc: _s(json['suc']),
      warehouse: _s(json['almacen']),
      providerId: _i(json['provd']),
      provider: _s(json['proveedor']),
      typeId: _i(json['tipoDev']),
      typeDescription: _s(json['tipoDescripcion']),
      status: _s(json['estatus']).toUpperCase(),
      obs: _s(json['obs']),
      oc: _s(json['docOc']),
      receipt: _s(json['docRec']),
      lines: _i(json['renglones']),
      quantity: _d(json['cantidad']),
      amount: _d(json['importe']),
      date: _date(json['fecha']),
      requestDate: _date(json['fechaSolicita']),
      authorizationDate: _date(json['fechaAutoriza']),
      requestUser: _s(json['usuarioSolicita']),
      authorizationUser: _s(json['usuarioAutoriza']),
      rejectionReason: _s(json['motivoRechazo']),
      details: raw is List
          ? raw
                .map(
                  (e) =>
                      DevDetail.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : const [],
    );
  }
}

String devDocumentFolio(String document) {
  final value = document.trim();
  final separator = value.lastIndexOf('-');
  return separator < 0 ? value : value.substring(separator + 1);
}

String _s(dynamic value) => '${value ?? ''}'.trim();
int _i(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;
double _d(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(_s(value)) ?? 0;
bool _b(dynamic value) =>
    value == true || value == 1 || _s(value).toLowerCase() == 'true';
DateTime? _date(dynamic value) => DateTime.tryParse(_s(value));

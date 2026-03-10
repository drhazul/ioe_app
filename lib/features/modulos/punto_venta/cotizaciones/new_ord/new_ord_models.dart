class CreateOrdFromQuoteLineRequest {
  CreateOrdFromQuoteLineRequest({
    required this.idfol,
    required this.ticketId,
    required this.art,
    required this.descArt,
    required this.ctd,
    required this.clien,
    required this.estado,
    required this.tipo,
    required this.suc,
    required this.opv,
    this.fechaEntrega,
    this.comad,
    this.ordExistente,
  });

  final String idfol;
  final String ticketId;
  final String art;
  final String descArt;
  final double ctd;
  final int clien;
  final String estado;
  final String tipo;
  final String suc;
  final String opv;
  final DateTime? fechaEntrega;
  final String? comad;
  final String? ordExistente;

  Map<String, dynamic> toJson() => {
        'idfol': idfol,
        'ticketId': ticketId,
        'art': art,
        'descArt': descArt,
        'ctd': ctd,
        'clien': clien,
        'estado': estado,
        'tipo': tipo,
        'suc': suc,
        'opv': opv,
        'fechaEntrega': fechaEntrega?.toIso8601String(),
        'comad': comad,
        'ordExistente': ordExistente,
      };
}

class CreateOrdFromQuoteLineResponse {
  CreateOrdFromQuoteLineResponse({
    required this.created,
    required this.code,
    required this.iord,
    required this.header,
    required this.details,
    required this.message,
  });

  final bool created;
  final String? code;
  final String? iord;
  final Map<String, dynamic>? header;
  final List<Map<String, dynamic>> details;
  final String message;

  factory CreateOrdFromQuoteLineResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrdFromQuoteLineResponse(
      created: json['created'] == true,
      code: _asString(json['code']),
      iord: _asString(json['iord']),
      header: _asMap(json['header']),
      details: _asListOfMaps(json['details']),
      message: _asString(json['message']) ?? '',
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class NewOrdDialogPayload {
  NewOrdDialogPayload({
    required this.idfol,
    required this.art,
    required this.descArt,
    required this.ctd,
    required this.clien,
    required this.ncliente,
    required this.estado,
    required this.suc,
    required this.opv,
    this.ordExistente,
    this.tipoInicial = kOrdTipoTallado,
    this.fechaEntregaInicial,
    this.comadInicial,
  });

  final String idfol;
  final String art;
  final String descArt;
  final double ctd;
  final int clien;
  final String ncliente;
  final String estado;
  final String suc;
  final String opv;
  final String? ordExistente;
  final String tipoInicial;
  final DateTime? fechaEntregaInicial;
  final String? comadInicial;
}

enum NewOrdDialogAction { save, delete }

class NewOrdDialogResult {
  NewOrdDialogResult({
    required this.action,
    required this.tipo,
    required this.descArt,
    required this.fechaEntrega,
    required this.comad,
  });

  final NewOrdDialogAction action;
  final String tipo;
  final String descArt;
  final DateTime? fechaEntrega;
  final String? comad;
}

class DeleteOrdFromQuoteLineRequest {
  DeleteOrdFromQuoteLineRequest({
    required this.iord,
    required this.ticketId,
    this.idfol,
    this.art,
  });

  final String iord;
  final String ticketId;
  final String? idfol;
  final String? art;

  Map<String, dynamic> toJson() => {
        'iord': iord,
        'ticketId': ticketId,
        'idfol': idfol,
        'art': art,
      };
}

class DeleteOrdFromQuoteLineResponse {
  DeleteOrdFromQuoteLineResponse({
    required this.deleted,
    required this.iord,
    required this.message,
  });

  final bool deleted;
  final String? iord;
  final String message;

  factory DeleteOrdFromQuoteLineResponse.fromJson(Map<String, dynamic> json) {
    return DeleteOrdFromQuoteLineResponse(
      deleted: json['deleted'] == true,
      iord: CreateOrdFromQuoteLineResponse._asString(json['iord']),
      message: CreateOrdFromQuoteLineResponse._asString(json['message']) ?? '',
    );
  }
}

const String kOrdTipoTallado = 'TALLADO';
const String kOrdTipoBiselado = 'BISELADO';
const List<String> kOrdTipos = <String>[
  kOrdTipoTallado,
  kOrdTipoBiselado,
];

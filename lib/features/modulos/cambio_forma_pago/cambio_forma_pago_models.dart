class CambioFormaPagoOverrideSession {
  const CambioFormaPagoOverrideSession({
    required this.overrideToken,
    required this.supervisorId,
    this.authPassword,
  });

  final String overrideToken;
  final String supervisorId;
  final String? authPassword;
  bool get hasOverrideToken => overrideToken.trim().isNotEmpty;
  bool get hasAuthPassword => (authPassword ?? '').trim().isNotEmpty;

  factory CambioFormaPagoOverrideSession.fromJson(Map<String, dynamic> json) {
    return CambioFormaPagoOverrideSession(
      overrideToken: _asText(
            json['overrideToken'] ??
                json['OVERRIDE_TOKEN'] ??
                json['override_token'],
          ) ??
          '',
      supervisorId: _asText(
            json['supervisorId'] ??
                json['SUPERVISOR_ID'] ??
            json['supervisor_id'],
          ) ??
          '',
      authPassword: _asText(
        json['AUTH_PASSWORD'] ?? json['authPassword'] ?? json['auth_password'],
      ),
    );
  }
}

class CambioFormaPagoItem {
  const CambioFormaPagoItem({
    required this.fcn,
    required this.idfol,
    required this.autAsvr,
    required this.tra,
    required this.opvm,
    required this.idf,
    required this.form,
    required this.impd,
    required this.autForm,
    required this.suc,
    required this.clien,
  });

  final DateTime? fcn;
  final String idfol;
  final String autAsvr;
  final String tra;
  final String opvm;
  final String idf;
  final String form;
  final double impd;
  final String autForm;
  final String suc;
  final int? clien;

  CambioFormaPagoItem copyWith({
    DateTime? fcn,
    String? idfol,
    String? autAsvr,
    String? tra,
    String? opvm,
    String? idf,
    String? form,
    double? impd,
    String? autForm,
    String? suc,
    int? clien,
  }) {
    return CambioFormaPagoItem(
      fcn: fcn ?? this.fcn,
      idfol: idfol ?? this.idfol,
      autAsvr: autAsvr ?? this.autAsvr,
      tra: tra ?? this.tra,
      opvm: opvm ?? this.opvm,
      idf: idf ?? this.idf,
      form: form ?? this.form,
      impd: impd ?? this.impd,
      autForm: autForm ?? this.autForm,
      suc: suc ?? this.suc,
      clien: clien ?? this.clien,
    );
  }

  factory CambioFormaPagoItem.fromJson(Map<String, dynamic> json) {
    return CambioFormaPagoItem(
      fcn: _asDate(json['FCN'] ?? json['fcn']),
      idfol: (_asText(json['IDFOL'] ?? json['idfol']) ?? '').trim(),
      autAsvr: (_asText(
            json['AUT_ASVR'] ?? json['autAsvr'] ?? json['AUT'] ?? json['aut'],
          ) ??
          '')
          .trim()
          .toUpperCase(),
      tra: (_asText(json['TRA'] ?? json['tra']) ?? '').trim(),
      opvm: (_asText(json['OPVM'] ?? json['opvm']) ?? '').trim(),
      idf: (_asText(json['IDF'] ?? json['idf']) ?? '').trim(),
      form: (_asText(json['FORM'] ?? json['form']) ?? '').trim().toUpperCase(),
      impd: _asDouble(json['IMPD'] ?? json['impd']) ?? 0,
      autForm: (_asText(json['AUT_FORM'] ?? json['autForm']) ?? '').trim(),
      suc: (_asText(json['SUC'] ?? json['suc']) ?? '').trim(),
      clien: _asInt(json['CLIEN'] ?? json['clien']),
    );
  }
}

class CambioFormaPagoCatalogItem {
  const CambioFormaPagoCatalogItem({
    required this.form,
    required this.tipotran,
    required this.bloq,
  });

  final String form;
  final String tipotran;
  final int bloq;

  bool get isBlocked => bloq != 0;

  factory CambioFormaPagoCatalogItem.fromJson(Map<String, dynamic> json) {
    return CambioFormaPagoCatalogItem(
      form: (_asText(json['FORM'] ?? json['form']) ?? '').trim().toUpperCase(),
      tipotran: (_asText(json['TIPOTRAN'] ?? json['tipotran']) ?? '')
          .trim()
          .toUpperCase(),
      bloq: _asInt(json['BLOQ'] ?? json['bloq']) ?? 0,
    );
  }
}

class CambioFormaPagoUpdateResult {
  const CambioFormaPagoUpdateResult({
    required this.idf,
    required this.idfol,
    required this.beforeForm,
    required this.afterForm,
    required this.beforeAut,
    required this.afterAut,
  });

  final String idf;
  final String idfol;
  final String beforeForm;
  final String afterForm;
  final String beforeAut;
  final String afterAut;

  factory CambioFormaPagoUpdateResult.fromJson(Map<String, dynamic> json) {
    return CambioFormaPagoUpdateResult(
      idf: (_asText(json['IDF'] ?? json['idf']) ?? '').trim(),
      idfol: (_asText(json['IDFOL'] ?? json['idfol']) ?? '').trim(),
      beforeForm: (_asText(json['BEFORE_FORM'] ?? json['beforeForm']) ?? '')
          .trim()
          .toUpperCase(),
      afterForm: (_asText(
            json['AFTER_FORM'] ?? json['afterForm'] ?? json['FORM'] ?? json['form'],
          ) ??
          '')
          .trim()
          .toUpperCase(),
      beforeAut: (_asText(json['BEFORE_AUT'] ?? json['beforeAut']) ?? '').trim(),
      afterAut: (_asText(json['AFTER_AUT'] ?? json['afterAut']) ?? '').trim(),
    );
  }
}

String? _asText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString().trim();
  final asInt = int.tryParse(text);
  if (asInt != null) return asInt;
  final asDouble = double.tryParse(text);
  if (asDouble != null) return asDouble.toInt();
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

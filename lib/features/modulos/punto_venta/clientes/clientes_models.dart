class FactClientShpModel {
  final double idc;
  final double? clientUni;
  final String? tipo;
  final DateTime? fcnr;
  final String razonSocialReceptor;
  final String? domicilio;
  final String rfcReceptor;
  final String? ncel;
  final String? ntjt;
  final String emailReceptor;
  final String rfcEmisor;
  final String? optica;
  final String usoCfdi;
  final String codigoPostalReceptor;
  final double regimenFiscalReceptor;
  final double? iCred;
  final double? vf;
  final double? estatus;
  final int? datval;
  final int? mod;
  final String? suc;
  final double? descuentoApli;

  const FactClientShpModel({
    required this.idc,
    required this.razonSocialReceptor,
    required this.rfcReceptor,
    required this.emailReceptor,
    required this.rfcEmisor,
    required this.usoCfdi,
    required this.codigoPostalReceptor,
    required this.regimenFiscalReceptor,
    this.clientUni,
    this.tipo,
    this.fcnr,
    this.domicilio,
    this.ncel,
    this.ntjt,
    this.optica,
    this.iCred,
    this.vf,
    this.estatus,
    this.datval,
    this.mod,
    this.suc,
    this.descuentoApli,
  });

  factory FactClientShpModel.fromJson(Map<String, dynamic> json) {
    return FactClientShpModel(
      idc: (json['IDC'] as num?)?.toDouble() ?? 0,
      clientUni: (json['CLIEN_UNI'] as num?)?.toDouble(),
      tipo: json['TIPO'] as String?,
      fcnr: json['FCNR'] != null ? DateTime.tryParse(json['FCNR'] as String) : null,
      razonSocialReceptor: json['RazonSocialReceptor'] as String? ?? json['RAZONSOCIALRECEPTOR'] as String,
      domicilio: json['DOMI'] as String?,
      rfcReceptor: json['RfcReceptor'] as String? ?? json['RFCRECEPTOR'] as String,
      ncel: json['NCEL'] as String?,
      ntjt: json['NTJT'] as String?,
      emailReceptor: json['EmailReceptor'] as String? ?? json['EMAILRECEPTOR'] as String,
      rfcEmisor: json['RfcEmisor'] as String? ?? json['RFCEMISOR'] as String,
      optica: json['OPTICA'] as String?,
      usoCfdi: json['UsoCfdi'] as String? ?? json['USOCFDI'] as String,
      codigoPostalReceptor: json['CodigoPostalReceptor'] as String? ?? json['CODIGOPOSTALRECEPTOR'] as String,
      regimenFiscalReceptor: (json['RegimenFiscalReceptor'] as num?)?.toDouble() ??
          (json['REGIMENFISCALRECEPTOR'] as num?)?.toDouble() ??
          0,
      iCred: (json['I_CRED'] as num?)?.toDouble(),
      vf: (json['VF'] as num?)?.toDouble(),
      estatus: (json['ESTATUS'] as num?)?.toDouble(),
      datval: (json['DATVAL'] as num?)?.toInt(),
      mod: (json['MOD'] as num?)?.toInt(),
      suc: json['SUC'] as String?,
      descuentoApli: (json['descuentoApli'] as num?)?.toDouble() ?? (json['DESCUENTOAPLI'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toPayload({bool includeId = true}) {
    return {
      if (includeId) 'IDC': idc,
      'CLIEN_UNI': clientUni,
      'TIPO': tipo,
      if (fcnr != null) 'FCNR': fcnr!.toIso8601String(),
      'RAZONSOCIALRECEPTOR': razonSocialReceptor,
      'DOMI': domicilio,
      'RFCRECEPTOR': rfcReceptor,
      'NCEL': ncel,
      'NTJT': ntjt,
      'EMAILRECEPTOR': emailReceptor,
      'RFCEMISOR': rfcEmisor,
      'OPTICA': optica,
      'USOCFDI': usoCfdi,
      'CODIGOPOSTALRECEPTOR': codigoPostalReceptor,
      'REGIMENFISCALRECEPTOR': regimenFiscalReceptor,
      'I_CRED': iCred,
      'VF': vf,
      'ESTATUS': estatus,
      'DATVAL': datval,
      'MOD': mod,
      'SUC': suc,
      'DESCUENTOAPLI': descuentoApli,
    };
  }
}

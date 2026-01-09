class SucursalModel {
  final String suc;
  final String? desc;
  final String? encar;
  final String? zona;
  final String? rfc;
  final String? direccion;
  final String? contacto;
  final int? ivaIntegrado;

  const SucursalModel({
    required this.suc,
    this.desc,
    this.encar,
    this.zona,
    this.rfc,
    this.direccion,
    this.contacto,
    this.ivaIntegrado,
  });

  factory SucursalModel.fromJson(Map<String, dynamic> json) {
    final iva = json['IVA_INTEGRADO'];
    return SucursalModel(
      suc: json['SUC'] as String,
      desc: json['DESC'] as String?,
      encar: json['ENCAR'] as String?,
      zona: json['ZONA'] as String?,
      rfc: json['RFC'] as String?,
      direccion: json['DIRECCION'] as String?,
      contacto: json['CONTACTO'] as String?,
      ivaIntegrado: iva == null ? null : (iva as num).toInt(),
    );
  }

  Map<String, dynamic> toPayload({bool includeSuc = true}) {
    return {
      if (includeSuc) 'SUC': suc,
      'DESC': desc,
      'ENCAR': encar,
      'ZONA': zona,
      'RFC': rfc,
      'DIRECCION': direccion,
      'CONTACTO': contacto,
      'IVA_INTEGRADO': ivaIntegrado,
    };
  }
}

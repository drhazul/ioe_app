class EntidadFiscalSucursalModel {
  const EntidadFiscalSucursalModel({
    required this.idRelacion,
    required this.suc,
    required this.descripcion,
    required this.vigenteDesde,
    required this.vigenteHasta,
    required this.estadoValidacion,
    required this.origen,
    required this.referenciaValidacion,
  });

  final int idRelacion;
  final String suc;
  final String? descripcion;
  final String? vigenteDesde;
  final String? vigenteHasta;
  final String estadoValidacion;
  final String? origen;
  final String? referenciaValidacion;

  factory EntidadFiscalSucursalModel.fromJson(Map<String, dynamic> json) {
    return EntidadFiscalSucursalModel(
      idRelacion: _asInt(json['idRelacion'] ?? json['ID_RELACION']) ?? 0,
      suc: (json['suc'] ?? json['SUC'] ?? '').toString().trim(),
      descripcion: _asNullable(json['descripcion'] ?? json['DESC']),
      vigenteDesde: _asNullable(json['vigenteDesde'] ?? json['VIGENTE_DESDE']),
      vigenteHasta: _asNullable(json['vigenteHasta'] ?? json['VIGENTE_HASTA']),
      estadoValidacion:
          (json['estadoValidacion'] ?? json['ESTADO_VALIDACION'] ?? 'PENDIENTE')
              .toString(),
      origen: _asNullable(json['origen'] ?? json['ORIGEN']),
      referenciaValidacion: _asNullable(
        json['referenciaValidacion'] ?? json['REFERENCIA_VALIDACION'],
      ),
    );
  }
}

class EntidadFiscalModel {
  const EntidadFiscalModel({
    required this.idEntidadFiscal,
    required this.rfc,
    required this.tipoPersona,
    required this.nombreLegal,
    required this.nombreComercial,
    required this.regimenFiscal,
    required this.cpFiscal,
    required this.domicilioFiscal,
    required this.estadoValidacion,
    required this.referenciaValidacion,
    required this.origenCandidato,
    required this.sucursales,
  });

  final int idEntidadFiscal;
  final String rfc;
  final String tipoPersona;
  final String? nombreLegal;
  final String? nombreComercial;
  final String? regimenFiscal;
  final String? cpFiscal;
  final String? domicilioFiscal;
  final String estadoValidacion;
  final String? referenciaValidacion;
  final String? origenCandidato;
  final List<EntidadFiscalSucursalModel> sucursales;

  factory EntidadFiscalModel.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['sucursales'];
    return EntidadFiscalModel(
      idEntidadFiscal:
          _asInt(json['idEntidadFiscal'] ?? json['ID_ENTIDAD_FISCAL']) ?? 0,
      rfc: (json['rfc'] ?? json['RFC'] ?? '').toString().trim().toUpperCase(),
      tipoPersona: (json['tipoPersona'] ?? json['TIPO_PERSONA'] ?? 'FISICA')
          .toString()
          .trim(),
      nombreLegal: _asNullable(json['nombreLegal'] ?? json['NOMBRE_LEGAL']),
      nombreComercial: _asNullable(
        json['nombreComercial'] ?? json['NOMBRE_COMERCIAL'],
      ),
      regimenFiscal: _asNullable(
        json['regimenFiscal'] ?? json['REGIMEN_FISCAL'],
      ),
      cpFiscal: _asNullable(json['cpFiscal'] ?? json['CP_FISCAL']),
      domicilioFiscal: _asNullable(
        json['domicilioFiscal'] ?? json['DOMICILIO_FISCAL'],
      ),
      estadoValidacion:
          (json['estadoValidacion'] ?? json['ESTADO_VALIDACION'] ?? 'PENDIENTE')
              .toString(),
      referenciaValidacion: _asNullable(
        json['referenciaValidacion'] ?? json['REFERENCIA_VALIDACION'],
      ),
      origenCandidato: _asNullable(
        json['origenCandidato'] ?? json['ORIGEN_CANDIDATO'],
      ),
      sucursales: rawLinks is List
          ? rawLinks
                .map(
                  (row) => EntidadFiscalSucursalModel.fromJson(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class SucursalFiscalOption {
  const SucursalFiscalOption({required this.suc, required this.descripcion});

  final String suc;
  final String? descripcion;

  factory SucursalFiscalOption.fromJson(Map<String, dynamic> json) {
    return SucursalFiscalOption(
      suc: (json['suc'] ?? json['SUC'] ?? '').toString().trim(),
      descripcion: _asNullable(json['descripcion'] ?? json['DESC']),
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asNullable(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

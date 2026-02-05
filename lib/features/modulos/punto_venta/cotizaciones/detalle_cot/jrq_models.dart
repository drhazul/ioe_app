class JrqDepaModel {
  JrqDepaModel({required this.depa, this.ddepa});

  final double depa;
  final String? ddepa;

  factory JrqDepaModel.fromJson(Map<String, dynamic> json) {
    return JrqDepaModel(
      depa: _asDouble(json['DEPA']) ?? 0,
      ddepa: json['DDEPA']?.toString(),
    );
  }
}

class JrqSubdModel {
  JrqSubdModel({required this.subd, this.dsubd, this.depa});

  final double subd;
  final String? dsubd;
  final double? depa;

  factory JrqSubdModel.fromJson(Map<String, dynamic> json) {
    return JrqSubdModel(
      subd: _asDouble(json['SUBD']) ?? 0,
      dsubd: json['DSUBD']?.toString(),
      depa: _asDouble(json['DEPA']),
    );
  }
}

class JrqClasModel {
  JrqClasModel({required this.clas, this.dclas, this.subd});

  final double clas;
  final String? dclas;
  final double? subd;

  factory JrqClasModel.fromJson(Map<String, dynamic> json) {
    return JrqClasModel(
      clas: _asDouble(json['CLAS']) ?? 0,
      dclas: json['DCLAS']?.toString(),
      subd: _asDouble(json['SUBD']),
    );
  }
}

class JrqSclaModel {
  JrqSclaModel({required this.scla, this.dscla, this.clas});

  final double scla;
  final String? dscla;
  final double? clas;

  factory JrqSclaModel.fromJson(Map<String, dynamic> json) {
    return JrqSclaModel(
      scla: _asDouble(json['SCLA']) ?? 0,
      dscla: json['DSCLA']?.toString(),
      clas: _asDouble(json['CLAS']),
    );
  }
}

class JrqScla2Model {
  JrqScla2Model({required this.scla2, this.dscla2, this.scla});

  final double scla2;
  final String? dscla2;
  final double? scla;

  factory JrqScla2Model.fromJson(Map<String, dynamic> json) {
    return JrqScla2Model(
      scla2: _asDouble(json['SCLA2']) ?? 0,
      dscla2: json['DSCLA2']?.toString(),
      scla: _asDouble(json['SCLA']),
    );
  }
}

class JrqGuiaModel {
  JrqGuiaModel({required this.guia, this.descort, this.scla2});

  final String guia;
  final String? descort;
  final double? scla2;

  factory JrqGuiaModel.fromJson(Map<String, dynamic> json) {
    return JrqGuiaModel(
      guia: json['GUIA']?.toString() ?? '',
      descort: json['DESCORT']?.toString(),
      scla2: _asDouble(json['SCLA2']),
    );
  }
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

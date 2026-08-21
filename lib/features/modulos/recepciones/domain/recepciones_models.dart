class RecepcionesPageResult<T> {
  const RecepcionesPageResult({
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

class RecepcionOrden {
  const RecepcionOrden({
    required this.nped,
    required this.suc,
    required this.proveedor,
    required this.estatus,
    required this.solicitado,
    required this.recibido,
    required this.pendiente,
    this.nprov = 0,
    this.nart = 0,
    this.fecha,
    this.importe,
    this.docrecActivo,
    this.estatusRecepcion,
    this.detalle = const [],
    this.recepciones = const [],
    this.puedeAutorizar = false,
    this.puedeVerFinanciero = false,
  });
  final String nped;
  final String suc;
  final int nprov;
  final String proveedor;
  final String estatus;
  final int nart;
  final DateTime? fecha;
  final double solicitado;
  final double recibido;
  final double pendiente;
  final double? importe;
  final String? docrecActivo;
  final String? estatusRecepcion;
  final List<RecepcionOrdenDetalle> detalle;
  final List<RecepcionResumen> recepciones;
  final bool puedeAutorizar;
  final bool puedeVerFinanciero;

  factory RecepcionOrden.fromJson(Map<String, dynamic> json) {
    final permisos = _map(json['permisos']);
    return RecepcionOrden(
      nped: _text(json['nped']),
      suc: _text(json['suc']),
      nprov: _int(json['nprov']),
      proveedor: _text(json['proveedor']),
      estatus: _text(json['estatus']).toUpperCase(),
      nart: _int(json['nart']),
      fecha: _date(json['fcnp']),
      solicitado: _double(json['solicitado']),
      recibido: _double(json['recibido']),
      pendiente: _double(json['pendiente']),
      importe: json.containsKey('impp') ? _double(json['impp']) : null,
      docrecActivo: _nullable(json['docrecActivo']),
      estatusRecepcion: _nullable(json['estatusRecepcion']),
      detalle: _list(
        json['detalle'],
      ).map(RecepcionOrdenDetalle.fromJson).toList(),
      recepciones: _list(
        json['recepciones'],
      ).map(RecepcionResumen.fromJson).toList(),
      puedeAutorizar: _bool(permisos['autorizar']),
      puedeVerFinanciero: _bool(permisos['verInformacionFinanciera']),
    );
  }
}

class RecepcionOrdenDetalle {
  const RecepcionOrdenDetalle({
    required this.idped,
    required this.pos,
    required this.art,
    required this.descripcion,
    required this.unidad,
    required this.solicitado,
    required this.recibido,
    required this.pendiente,
    this.upc,
    this.costo,
    this.tipo,
    this.depa,
    this.subd,
    this.clas,
    this.scla,
    this.scla2,
    this.base,
    this.sph,
    this.cyl,
    this.adic,
    this.jerarquiaNombre = 'SIN JERARQUIA',
  });
  final String idped;
  final int pos;
  final String art;
  final String? upc;
  final String descripcion;
  final String unidad;
  final double solicitado;
  final double recibido;
  final double pendiente;
  final double? costo;
  final String? tipo;
  final double? depa;
  final double? subd;
  final double? clas;
  final double? scla;
  final double? scla2;
  final double? base;
  final double? sph;
  final double? cyl;
  final double? adic;
  final String jerarquiaNombre;
  factory RecepcionOrdenDetalle.fromJson(Map<String, dynamic> json) =>
      RecepcionOrdenDetalle(
        idped: _text(json['idped']),
        pos: _int(json['pos']),
        art: _text(json['art']),
        upc: _nullable(json['upc']),
        descripcion: _text(json['des']),
        unidad: _text(json['uncom']),
        solicitado: _double(json['solicitado']),
        recibido: _double(json['recibido']),
        pendiente: _double(json['pendiente']),
        costo: json.containsKey('costo') ? _double(json['costo']) : null,
        tipo: _nullable(json['tipo']),
        depa: _nullableDouble(json['depa']),
        subd: _nullableDouble(json['subd']),
        clas: _nullableDouble(json['clas']),
        scla: _nullableDouble(json['scla']),
        scla2: _nullableDouble(json['scla2']),
        base: _nullableDouble(json['base']),
        sph: _nullableDouble(json['sph']),
        cyl: _nullableDouble(json['cyl']),
        adic: _nullableDouble(json['adic']),
        jerarquiaNombre: _text(json['jerarquiaNombre']).trim().isEmpty
            ? 'SIN JERARQUIA'
            : _text(json['jerarquiaNombre']).trim(),
      );
}

class RecepcionResumen {
  const RecepcionResumen({
    required this.docrec,
    required this.nped,
    required this.estatus,
    required this.tipoRecepcion,
    this.fechaFisica,
    this.fechaAutorizacion,
    this.importe,
    this.tipoDocumento,
    this.folioDocumento,
    this.observaciones,
  });
  final String docrec;
  final String nped;
  final String estatus;
  final String tipoRecepcion;
  final DateTime? fechaFisica;
  final DateTime? fechaAutorizacion;
  final double? importe;
  final String? tipoDocumento;
  final String? folioDocumento;
  final String? observaciones;
  factory RecepcionResumen.fromJson(Map<String, dynamic> json) =>
      RecepcionResumen(
        docrec: _text(json['docrec']),
        nped: _text(json['nped']),
        estatus: _text(json['estatus']).toUpperCase(),
        tipoRecepcion: _text(json['tipoRecepcion']),
        fechaFisica: _date(json['fechaFisica']),
        fechaAutorizacion: _date(json['fechaAutorizacion']),
        importe: json.containsKey('importe') ? _double(json['importe']) : null,
        tipoDocumento: _nullable(json['tipoDocumento']),
        folioDocumento: _nullable(json['folioDocumento']),
        observaciones: _nullable(json['observaciones']),
      );
}

class RecepcionDocumento {
  const RecepcionDocumento({
    required this.resumen,
    required this.suc,
    required this.proveedor,
    required this.detalle,
    required this.guias,
    required this.incidencias,
    required this.puedeAutorizar,
  });
  final RecepcionResumen resumen;
  final String suc;
  final String proveedor;
  final List<Map<String, dynamic>> detalle;
  final List<Map<String, dynamic>> guias;
  final List<Map<String, dynamic>> incidencias;
  final bool puedeAutorizar;
  factory RecepcionDocumento.fromJson(Map<String, dynamic> json) {
    final permisos = _map(json['permisos']);
    return RecepcionDocumento(
      resumen: RecepcionResumen.fromJson(json),
      suc: _text(json['suc']),
      proveedor: _text(json['proveedor']),
      detalle: _list(json['detalle']),
      guias: _list(json['guias']),
      incidencias: _list(json['incidencias']),
      puedeAutorizar: _bool(permisos['autorizar']),
    );
  }
}

class RecepcionIndicadores {
  const RecepcionIndicadores({
    required this.recepciones,
    required this.pedidos,
    required this.cumplimiento,
    required this.exactitud,
    required this.incidencias,
    required this.minutosPromedio,
  });
  final int recepciones;
  final int pedidos;
  final double cumplimiento;
  final double exactitud;
  final int incidencias;
  final double minutosPromedio;
  factory RecepcionIndicadores.fromJson(Map<String, dynamic> json) =>
      RecepcionIndicadores(
        recepciones: _int(json['recepciones']),
        pedidos: _int(json['pedidos']),
        cumplimiento: _double(json['cumplimientoProveedor']),
        exactitud: _double(json['exactitudRecepcion']),
        incidencias: _int(json['incidencias']),
        minutosPromedio: _double(json['minutosPromedioRecepcion']),
      );
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : const [];
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
String _text(dynamic value) => '${value ?? ''}'.trim();
String? _nullable(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;
double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(_text(value)) ?? 0;
double? _nullableDouble(dynamic value) {
  if (value == null || _text(value).isEmpty) return null;
  return value is num ? value.toDouble() : double.tryParse(_text(value));
}

bool _bool(dynamic value) =>
    value == true || value == 1 || _text(value).toLowerCase() == 'true';
DateTime? _date(dynamic value) => DateTime.tryParse(_text(value));

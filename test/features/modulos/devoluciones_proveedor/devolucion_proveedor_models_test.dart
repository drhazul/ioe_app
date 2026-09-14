import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/devoluciones_proveedor/domain/devolucion_proveedor_models.dart';
import 'package:ioe_app/features/modulos/devoluciones_proveedor/presentation/pdf/devolucion_proveedor_pdf.dart';

void main() {
  test('interpreta cabecera y detalle DEV_PROVD', () {
    final document = DevDocument.fromJson({
      'doc': 'DEV-DF01-00000001',
      'suc': 'DF01',
      'almacen': '002',
      'provd': 7,
      'proveedor': 'Proveedor prueba',
      'tipoDev': 1,
      'tipoDescripcion': 'Defecto de fabrica',
      'estatus': 'PENDIENTE',
      'renglones': 1,
      'cantidad': 2,
      'importe': 50,
      'detalle': [
        {
          'idpd': 10,
          'art': 'ART-1',
          'cantidad': 2,
          'cantidadBloqueada': 2,
          'costo': 25,
          'importe': 50,
          'motivo': 1,
          'motivoCodigo': 'DEV-01',
          'motivoDescripcion': 'Defecto de material',
          'requiereEvidencia': true,
          'evidencias': 1,
        },
      ],
    });
    expect(document.doc, 'DEV-DF01-00000001');
    expect(document.status, 'PENDIENTE');
    expect(document.details.single.blocked, 2);
    expect(document.details.single.requiresEvidence, isTrue);
    expect(
      devolucionReasonDescription(document.details.single),
      'Defecto de material',
    );
    expect(document.editable, isFalse);
  });

  test('muestra solo el consecutivo y conserva un nombre PDF estable', () {
    const document = 'DEV-DF01-00000001';

    expect(devDocumentFolio(document), '00000001');
    expect(devolucionDocumentNumber(document), '00000001');
    expect(
      devolucionPdfFileName(document),
      'devolucion_proveedor_00000001.pdf',
    );
  });

  test('genera nombre estable para la impresión de varios documentos', () {
    final documents = [
      _document('DEV-DF01-00000001'),
      _document('DEV-DF04-00000002'),
    ];

    expect(
      devolucionesProveedorPdfFileName(documents),
      'devoluciones_proveedor_2_documentos.pdf',
    );
  });

  test('construye un solo PDF para varios documentos', () async {
    final bytes = await buildDevolucionesProveedorPdf([
      _document('DEV-DF01-00000001'),
      _document('DEV-DF04-00000002'),
    ]);

    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}

DevDocument _document(String doc) => DevDocument(
  doc: doc,
  suc: 'DF01',
  warehouse: '002',
  providerId: 15,
  provider: 'Proveedor prueba',
  typeId: 1,
  typeDescription: 'Defecto',
  status: 'AUTORIZADA',
  obs: '',
  oc: '',
  receipt: '',
  lines: 0,
  quantity: 0,
  amount: 0,
  details: const [],
);

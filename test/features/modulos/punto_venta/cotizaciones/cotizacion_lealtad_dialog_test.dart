import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/cotizacion_lealtad_dialog.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/cotizacion_lealtad_error.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/cotizaciones_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/cotizaciones_date.dart';

void main() {
  for (final participa in [true, false]) {
    testWidgets('muestra participación $participa', (tester) async {
      final result = CotizacionLealtadParticipacionModel(
        idfol: 'existing',
        clienteId: '50007',
        participante: participa,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CotizacionLealtadDialog(
            clienteId: 50007,
            resultadoInicial: result,
            consultar: () async => result,
          ),
        ),
      );
      expect(
        find.text(
          'El cliente 50007 ${participa ? 'participa' : 'no participa'} en el programa de lealtad.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('sin confirmar'), findsNothing);
    });
  }
  testWidgets(
    'un fallo conserva estado desconocido y reintenta solo la consulta',
    (tester) async {
      var consultas = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CotizacionLealtadDialog(
            clienteId: 50007,
            errorInicial: const CotizacionLealtadError(
              'LEALTAD_URL_NO_CONFIGURADA',
            ),
            consultar: () async {
              consultas++;
              return const CotizacionLealtadParticipacionModel(
                idfol: 'existing',
                clienteId: '50007',
                participante: true,
              );
            },
          ),
        ),
      );
      expect(find.textContaining('sin confirmar'), findsOneWidget);
      expect(find.textContaining('no participa en'), findsNothing);
      await tester.tap(find.text('Volver a consultar'));
      await tester.pumpAndSettle();
      expect(consultas, 1);
      expect(
        find.text('El cliente 50007 participa en el programa de lealtad.'),
        findsOneWidget,
      );
    },
  );
  test('fecha de proceso usa día local cuando API devuelve instante UTC', () {
    final local = DateTime(2026, 10, 23, 22, 27, 55);
    expect(formatCotizacionDate(local.toUtc()), '23/10/2026');
    expect(formatCotizacionDate(local), '23/10/2026');
    expect(formatCotizacionDate(null), '-');
  });
}

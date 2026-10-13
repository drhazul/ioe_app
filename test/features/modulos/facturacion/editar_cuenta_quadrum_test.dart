import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/facturacion/csd/csd_api.dart';
import 'package:ioe_app/features/modulos/facturacion/csd/csd_models.dart';
import 'package:ioe_app/features/modulos/facturacion/csd/csd_providers.dart';
import 'package:ioe_app/features/modulos/facturacion/csd/editar_cuenta_quadrum_dialog.dart';

class _ApiFalsa extends CsdApi {
  _ApiFalsa() : super(Dio());
  int llamadas = 0;
  String? ultimoRfc;
  String? ultimoPassword;
  @override
  Future<void> actualizarCuentaQuadrum({
    required String rfc,
    required String usuario,
    String? password,
  }) async {
    llamadas++;
    ultimoRfc = rfc;
    ultimoPassword = password;
  }
}

const _csd = CsdModel(
  rfc: 'JIFJ4704238T5',
  nombre: 'EMISOR DE PRUEBA',
  noCertificado: 'cert-ficticio',
  regimenFiscal: '612',
  codigoPostal: '91700',
  validoDesde: null,
  validoHasta: null,
  activo: true,
  quadrumUsuario: 'anterior@example.invalid',
);

Future<void> _abrir(WidgetTester tester, _ApiFalsa api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [csdApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => const EditarCuentaQuadrumDialog(csd: _csd),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'contraseña actual no se precarga y usuario cambiado exige nueva',
    (tester) async {
      final api = _ApiFalsa();
      await _abrir(tester, api);
      final passwordField = find.byType(TextFormField).at(1);
      final editable = tester.widget<EditableText>(
        find.descendant(of: passwordField, matching: find.byType(EditableText)),
      );
      expect(editable.controller.text, isEmpty);
      expect(editable.obscureText, isTrue);
      await tester.enterText(
        find.byType(TextFormField).first,
        'nuevo@example.invalid',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Captura contraseña de esa cuenta'), findsOneWidget);
      expect(api.llamadas, 0);
      await tester.enterText(passwordField, 'password-ficticio');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(api.ultimoRfc, _csd.rfc);
      expect(api.ultimoPassword, 'password-ficticio');
      expect(find.byType(EditarCuentaQuadrumDialog), findsNothing);
    },
  );
  testWidgets('vacío con mismo usuario omite contraseña y cancelar no guarda', (
    tester,
  ) async {
    final api = _ApiFalsa();
    await _abrir(tester, api);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.llamadas, 0);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.llamadas, 1);
    expect(api.ultimoPassword, isNull);
  });
}

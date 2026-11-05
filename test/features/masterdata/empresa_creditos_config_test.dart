import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';
import 'package:ioe_app/core/auth/auth_state.dart';
import 'package:ioe_app/core/storage.dart';
import 'package:ioe_app/features/masterdata/empresas/empresa_configuracion_page.dart';
import 'package:ioe_app/features/masterdata/empresas/empresa_creditos_config.dart';
import 'package:ioe_app/features/masterdata/empresas/empresas_api.dart';
import 'package:ioe_app/features/masterdata/empresas/empresas_models.dart';
import 'package:ioe_app/features/masterdata/empresas/empresas_providers.dart';
import 'package:ioe_app/features/masterdata/empresas/empresas_page.dart';

class _Storage extends Storage {
  @override
  Future<DateTime?> getLastActivityAt() => Completer<DateTime?>().future;
}

class _Auth extends AuthController {
  _Auth(super.ref, int role) {
    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      userId: 7,
      username: 'QA',
      suc: 'DF01',
      roleId: role,
      mustChangePassword: false,
    );
  }
}

class _Api extends EmpresasApi {
  _Api() : super(Dio());
  String modo = 'EMPRESA';
  bool permitir = true;
  int revision = 1;
  bool conflict = false;
  int writes = 0;
  String? sentVersion;
  bool? overrideValue;
  @override
  Future<EmpresaCreditosConfig> fetchCreditosConfig(int id) async =>
      EmpresaCreditosConfig.fromJson({
        'credito': {
          'MODO': modo,
          'permitir': permitir,
          'version': revision.toString().padLeft(16, '0'),
        },
        'sucursales': [
          {
            'suc': 'DF01',
            'descripcion': 'Sucursal prueba',
            'permitir': overrideValue,
            'efectivo': modo == 'EMPRESA'
                ? permitir
                : overrideValue ?? permitir,
            'version': '000000000000000A',
          },
        ],
      });
  @override
  Future<void> saveCreditosConfig(
    int id, {
    required String modo,
    required bool permitir,
    required String version,
  }) async {
    writes++;
    sentVersion = version;
    if (conflict) {
      throw DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 409,
          data: {'message': 'Recargue antes de guardar'},
        ),
      );
    }
    this.modo = modo;
    this.permitir = permitir;
    revision++;
  }

  @override
  Future<void> saveCreditosSucursal(
    int id,
    String suc, {
    required bool? permitir,
    required String version,
  }) async {
    overrideValue = permitir;
    writes++;
    sentVersion = version;
  }
}

Future<void> _open(WidgetTester tester, _Api api, {int role = 1}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(_Storage()),
        authControllerProvider.overrideWith((ref) => _Auth(ref, role)),
        empresasApiProvider.overrideWithValue(api),
        empresaProvider(1).overrideWith(
          (ref) async => EmpresaModel.fromJson({
            'idempresa': 1,
            'razonSocial': 'IOE TEST',
            'correo': '@test.mx',
          }),
        ),
      ],
      child: const MaterialApp(home: EmpresaConfiguracionPage(idempresa: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recargar descarta borrador aunque versión guardada no cambie', (
    tester,
  ) async {
    await _open(tester, _Api());
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Recargar configuración guardada'), 200);
    await tester.tap(find.text('Recargar configuración guardada'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('card empresa muestra engrane ADMIN sin desborde en 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(_Storage()),
          authControllerProvider.overrideWith((ref) => _Auth(ref, 1)),
          empresasListProvider.overrideWith(
            (ref) async => [
              EmpresaModel.fromJson({
                'idempresa': 1,
                'razonSocial': 'IOE BUSINESS',
                'correo': '@ioebusiness.com.mx',
              }),
            ],
          ),
        ],
        child: const MaterialApp(home: EmpresasPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Configuración de empresa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operador no consulta configuración ni muestra controles', (
    tester,
  ) async {
    await _open(tester, _Api(), role: 4);
    expect(find.text('Acceso exclusivo de ADMIN'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets(
    'guardar false envía versión y recarga configuración persistida',
    (tester) async {
      final api = _Api();
      await _open(tester, api);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.text('Guardar regla de empresa'));
      await tester.pumpAndSettle();
      expect(api.permitir, isFalse);
      expect(api.sentVersion, '0000000000000001');
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(find.textContaining('Efectivo: exige pago total'), findsOneWidget);
    },
  );

  testWidgets('conflicto conserva borrador y muestra recarga requerida', (
    tester,
  ) async {
    final api = _Api()..conflict = true;
    await _open(tester, api);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.tap(find.text('Guardar regla de empresa'));
    await tester.pumpAndSettle();
    expect(api.permitir, isTrue);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text('Recargue antes de guardar'), findsOneWidget);
  });

  testWidgets('sucursal permite heredar null y envía versión propia', (
    tester,
  ) async {
    final api = _Api()
      ..modo = 'SUCURSAL'
      ..overrideValue = false;
    await _open(tester, api);
    await tester.ensureVisible(find.byTooltip('Configurar sucursal'));
    await tester.tap(find.byTooltip('Configurar sucursal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heredar valor de empresa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar').last);
    await tester.pumpAndSettle();
    expect(api.overrideValue, isNull);
    expect(api.sentVersion, '000000000000000A');
    expect(find.textContaining('Hereda empresa'), findsOneWidget);
  });

  test(
    'API conserva false y null en payload sin convertirlos a ausencia',
    () async {
      final dio = Dio();
      final payloads = <dynamic>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            payloads.add(o.data);
            h.resolve(
              Response(requestOptions: o, data: {'ok': true}, statusCode: 200),
            );
          },
        ),
      );
      final api = EmpresasApi(dio);
      await api.saveCreditosConfig(
        1,
        modo: 'EMPRESA',
        permitir: false,
        version: '0000000000000001',
      );
      await api.saveCreditosSucursal(
        1,
        'DF01',
        permitir: null,
        version: '000000000000000A',
      );
      expect(payloads[0]['permitir'], isFalse);
      expect((payloads[1] as Map).containsKey('permitir'), isTrue);
      expect(payloads[1]['permitir'], isNull);
    },
  );
}

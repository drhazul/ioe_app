import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/login/login_page.dart';
import '../features/login/force_change_password_page.dart';
import '../features/home/home_page.dart';
import '../features/home/home_models.dart';
import '../features/home/home_providers.dart';
import '../features/masterdata/masterdata_page.dart';
import '../features/masterdata/access/access_page.dart';
import '../features/masterdata/access/modulos_backend_page.dart';
import '../features/masterdata/access/grupos_backend_page.dart';
import '../features/masterdata/access/permisos_rol_backend_page.dart';
import '../features/masterdata/access/mod_front_page.dart';
import '../features/masterdata/access/grupos_front_page.dart';
import '../features/masterdata/access/enrolamiento_front_page.dart';
import '../features/masterdata/roles/roles_page.dart';
import '../features/masterdata/roles/role_form_page.dart';
import '../features/masterdata/deptos/deptos_page.dart';
import '../features/masterdata/deptos/depto_form_page.dart';
import '../features/masterdata/users/users_page.dart';
import '../features/masterdata/users/user_form_page.dart';
import '../features/masterdata/sucursales/sucursales_page.dart';
import '../features/masterdata/sucursales/sucursal_form_page.dart';
import '../features/masterdata/puestos/puestos_page.dart';
import '../features/masterdata/puestos/puesto_form_page.dart';
import '../features/masterdata/datmodulos/datmodulos_page.dart';
import '../features/masterdata/datmodulos/datmodulo_form_page.dart';
import '../features/masterdata/access_reg_suc/access_reg_suc_page.dart';
import '../features/masterdata/access_reg_suc/access_reg_suc_form_page.dart';
import '../features/masterdata/cat_ctas/presentation/cat_ctas_list_page.dart';
import '../features/masterdata/cat_ctas/presentation/cat_ctas_form_page.dart';
import '../features/masterdata/dat_form/dat_form_page.dart';
import '../features/masterdata/dat_form/dat_form_form_page.dart';
import '../features/modulos/inventarios/inventarios_page.dart';
import '../features/modulos/inventarios/inventario_form_page.dart';
import '../features/modulos/inventarios/inventario_det_page.dart';
import '../features/modulos/inventarios/captura/captura_page.dart';
import '../features/modulos/inventarios/captura/detalle_captura_page.dart';
import '../features/modulos/catalogo/datart_page.dart';
import '../features/modulos/mb51/mb51_consultas_page.dart';
import '../features/modulos/mb51/mb51_resultados_page.dart';
import '../features/modulos/mb51/mb51_models.dart';
import '../features/modulos/mb52/mb52_consultas_page.dart';
import '../features/modulos/mb52/mb52_resultados_page.dart';
import '../features/modulos/mb52/mb52_models.dart';
import '../features/modulos/ctrl_ctas/ctrl_ctas_models.dart';
import '../features/modulos/ctrl_ctas/ctrl_ctas_consulta_page.dart';
import '../features/modulos/ctrl_ctas/ctrl_ctas_resumen_cliente_page.dart';
import '../features/modulos/pagos_servicios/ps_panel_page.dart';
import '../features/modulos/pagos_servicios/ps_detalle_page.dart';
import '../features/modulos/pagos_servicios/ps_pago_page.dart';
import '../features/modulos/cambio_forma_pago/cambio_forma_pago_auth_page.dart';
import '../features/modulos/cambio_forma_pago/cambio_forma_pago_panel_page.dart';
import '../features/modulos/retiros/retiros_panel_page.dart';
import '../features/modulos/retiros/retiro_detalle_page.dart';
import '../features/modulos/retiros/retiro_efectivo_page.dart';
import '../features/modulos/reloj_checador/app/reloj_checador_app_page.dart';
import '../features/modulos/reloj_checador/consultas/reloj_checador_consultas_page.dart';
import '../features/modulos/taller/ordenes_trabajo/ordenes_trabajo_action_page.dart';
import '../features/modulos/taller/ordenes_trabajo/ordenes_trabajo_models.dart';
import '../features/modulos/taller/ordenes_trabajo/ordenes_trabajo_page.dart';
import '../features/modulos/facturacion/facturacion_page.dart';
import '../features/modulos/facturacion/facturacionview_page.dart';
import '../features/modulos/facturacion/facturacion_sreqf_page.dart';
import '../features/modulos/facturacion/factura_mtto_cliente_page.dart';
import '../features/modulos/estado_cajon/app/estado_cajon_page.dart';
import '../features/modulos/caja_general/app/caja_general_page.dart';
import '../features/modulos/caja_general/app/entrega_opv_page.dart';
import '../features/modulos/caja_general/app/entrega_global_page.dart';
import '../features/modulos/punto_venta/punto_venta_home_page.dart';
import '../features/modulos/punto_venta/clientes/clientes_page.dart';
import '../features/modulos/punto_venta/clientes/cliente_form_page.dart';
import '../features/modulos/punto_venta/cotizaciones/cotizaciones_page.dart';
import '../features/modulos/punto_venta/cotizaciones/cotizacion_form_page.dart';
import '../features/modulos/punto_venta/cotizaciones/detalle_cot/detalle_cot_page.dart';
import '../features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_page.dart';
import '../features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_models.dart';
import '../features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_page.dart';
import '../features/modulos/punto_venta/devoluciones/devoluciones_page.dart';
import '../features/modulos/punto_venta/devoluciones/detalle/detalle_devolucion_page.dart';
import '../features/modulos/punto_venta/devoluciones/detalle/detalle_devolucion_resumen_page.dart';
import '../features/modulos/punto_venta/devoluciones/pago/pago_devolucion_page.dart';
import '../features/modulos/punto_venta/reimprticket/reimpresion_page.dart';

import 'auth/auth_controller.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final homeModulesAsync = ref.watch(homeModulesProvider);

  List<GoRoute> accessRoutes() => [
    GoRoute(
      path: 'modulos-back',
      builder: (c, s) => const ModulosBackendPage(),
    ),
    GoRoute(path: 'grupos-back', builder: (c, s) => const GruposBackendPage()),
    GoRoute(
      path: 'permisos-rol-back',
      builder: (c, s) => const PermisosRolBackendPage(),
    ),
    GoRoute(path: 'mod-front', builder: (c, s) => const ModFrontPage()),
    GoRoute(path: 'grupos-front', builder: (c, s) => const GruposFrontPage()),
    GoRoute(
      path: 'enrolamiento-front',
      builder: (c, s) => const EnrolamientoFrontPage(),
    ),
  ];

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authControllerProvider.notifier).stream,
    ),
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final changingPassword =
          state.matchedLocation == '/auth/change-password';
      if (auth.isLoading) return null;

      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (auth.mustChangePassword && !changingPassword) {
        return '/auth/change-password';
      }
      if (!auth.mustChangePassword && changingPassword) {
        return '/';
      }
      if (auth.isAuthenticated && loggingIn) return '/';

      if (_isFacturacionRoute(state.matchedLocation)) {
        final isAdmin = (auth.roleId ?? 0) == 1 ||
            (auth.username ?? '').trim().toUpperCase() == 'ADMIN';
        if (!isAdmin) {
          if (homeModulesAsync.isLoading) return null;
          if (homeModulesAsync.hasError) return '/';
          final modules = homeModulesAsync.asData?.value.modulos ?? const <HomeModule>[];
          if (!_hasFacturacionRouteAccess(state.matchedLocation, modules)) {
            return '/';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(
        path: '/auth/change-password',
        builder: (c, s) => const ForceChangePasswordPage(),
      ),
      GoRoute(
        path: '/',
        builder: (c, s) => const HomePage(),
        routes: [
          GoRoute(
            path: 'masterdata',
            builder: (c, s) => const MasterDataPage(),
            routes: [
              GoRoute(
                path: 'access',
                builder: (c, s) => const AccessPage(),
                routes: accessRoutes(),
              ),
              GoRoute(
                path: 'roles',
                builder: (c, s) => const RolesPage(),
                routes: [
                  GoRoute(path: 'new', builder: (c, s) => const RoleFormPage()),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => RoleFormPage(
                      roleId: int.tryParse(s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'datmodulos',
                builder: (c, s) => const DatmodulosPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const DatModuloFormPage(),
                  ),
                  GoRoute(
                    path: ':modulo',
                    builder: (c, s) =>
                        DatModuloFormPage(modulo: s.pathParameters['modulo']),
                  ),
                ],
              ),
              GoRoute(
                path: 'deptos',
                builder: (c, s) => const DeptosPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const DeptoFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => DeptoFormPage(
                      deptoId: int.tryParse(s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'users',
                builder: (c, s) => const UsersPage(),
                routes: [
                  GoRoute(path: 'new', builder: (c, s) => const UserFormPage()),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => UserFormPage(
                      userId: int.tryParse(s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'access-reg-suc',
                builder: (c, s) => const AccessRegSucPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const AccessRegSucFormPage(),
                  ),
                  GoRoute(
                    path: ':modulo/:usuario/:suc',
                    builder: (c, s) {
                      final rawModulo = s.pathParameters['modulo'];
                      final rawUsuario = s.pathParameters['usuario'];
                      final rawSuc = s.pathParameters['suc'];
                      return AccessRegSucFormPage(
                        modulo: rawModulo == null
                            ? null
                            : Uri.decodeComponent(rawModulo),
                        usuario: rawUsuario == null
                            ? null
                            : Uri.decodeComponent(rawUsuario),
                        suc: rawSuc == null
                            ? null
                            : Uri.decodeComponent(rawSuc),
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'sucursales',
                builder: (c, s) => const SucursalesPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const SucursalFormPage(),
                  ),
                  GoRoute(
                    path: ':suc',
                    builder: (c, s) =>
                        SucursalFormPage(suc: s.pathParameters['suc']),
                  ),
                ],
              ),
              GoRoute(
                path: 'puestos',
                builder: (c, s) => const PuestosPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const PuestoFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => PuestoFormPage(
                      puestoId: int.tryParse(s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'cat-ctas',
                builder: (c, s) => const CatCtasListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const CatCtasFormPage(),
                  ),
                  GoRoute(
                    path: ':cta',
                    builder: (c, s) => CatCtasFormPage(
                      cta: s.pathParameters['cta'] == null
                          ? null
                          : Uri.decodeComponent(s.pathParameters['cta']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'dat-form',
                builder: (c, s) => const DatFormPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const DatFormFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) => DatFormFormPage(
                      idform: int.tryParse(s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'estado-cajon',
            builder: (c, s) => const EstadoCajonPage(),
          ),
          GoRoute(
            path: 'caja-general',
            builder: (c, s) => const CajaGeneralPage(),
            routes: [
              GoRoute(
                path: 'opv',
                builder: (c, s) {
                  final now = DateTime.now();
                  final suc = (s.uri.queryParameters['suc'] ?? '').trim();
                  final opv = (s.uri.queryParameters['opv'] ?? '').trim();
                  final tipo = (s.uri.queryParameters['tipo'] ?? 'GLOBAL')
                      .trim()
                      .toUpperCase();
                  final fcn = (s.uri.queryParameters['fcn'] ?? '').trim();
                  final fecha = _parseSqlDateOrNow(fcn, now);
                  return EntregaOpvPage(
                    suc: suc,
                    opv: opv,
                    fecha: fecha,
                    tipo: tipo.isEmpty ? 'GLOBAL' : tipo,
                  );
                },
              ),
              GoRoute(
                path: 'global',
                builder: (c, s) {
                  final now = DateTime.now();
                  final suc = (s.uri.queryParameters['suc'] ?? '').trim();
                  final tipo = (s.uri.queryParameters['tipo'] ?? 'GLOBAL')
                      .trim()
                      .toUpperCase();
                  final fcn = (s.uri.queryParameters['fcn'] ?? '').trim();
                  final fecha = _parseSqlDateOrNow(fcn, now);
                  return EntregaGlobalPage(
                    suc: suc,
                    fecha: fecha,
                    tipo: tipo.isEmpty ? 'GLOBAL' : tipo,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'inventarios',
            builder: (c, s) => const InventariosPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (c, s) => const InventarioFormPage(),
              ),
              GoRoute(
                path: 'captura',
                builder: (c, s) => const CapturaInventarioPage(),
              ),
              GoRoute(
                path: ':cont/captura/detalle',
                builder: (c, s) =>
                    DetalleCapturaPage(cont: s.pathParameters['cont']),
              ),
              GoRoute(
                path: 'captura/detalle',
                builder: (c, s) => const DetalleCapturaPage(),
              ),
              GoRoute(
                path: ':cont/det',
                builder: (c, s) =>
                    InventarioDetallePage(cont: s.pathParameters['cont'] ?? ''),
              ),
            ],
          ),
          GoRoute(path: 'catalogo', builder: (c, s) => const DatArtPage()),
          GoRoute(
            path: 'mb51',
            builder: (c, s) => const Mb51ConsultasPage(),
            routes: [
              GoRoute(
                path: 'resultados',
                builder: (c, s) {
                  final extra = s.extra;
                  Mb51Filtros? filtros;
                  if (extra is Mb51Filtros) {
                    filtros = extra;
                  } else if (extra is Map) {
                    filtros = Mb51Filtros.fromJson(
                      Map<String, dynamic>.from(extra),
                    );
                  }
                  return Mb51ResultadosPage(filtros: filtros);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'mb52',
            builder: (c, s) => const Mb52ConsultasPage(),
            routes: [
              GoRoute(
                path: 'resultados',
                builder: (c, s) {
                  final extra = s.extra;
                  Mb52Filtros? filtros;
                  if (extra is Mb52Filtros) {
                    filtros = extra;
                  } else if (extra is Map) {
                    filtros = Mb52Filtros.fromJson(
                      Map<String, dynamic>.from(extra),
                    );
                  }
                  return Mb52ResultadosPage(filtros: filtros);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'ctrl-ctas',
            builder: (c, s) => const CtrlCtasConsultaPage(),
            routes: [
              GoRoute(
                path: 'resumen-cliente',
                builder: (c, s) {
                  final extra = s.extra;
                  CtrlCtasFiltros filtros = const CtrlCtasFiltros();
                  if (extra is CtrlCtasFiltros) {
                    filtros = extra;
                  } else if (extra is Map) {
                    filtros = CtrlCtasFiltros.fromJson(
                      Map<String, dynamic>.from(extra),
                    );
                  }
                  return CtrlCtasResumenClientePage(filtros: filtros);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'ps',
            builder: (c, s) => const PsPanelPage(),
            routes: [
              GoRoute(
                path: ':idFol/pago',
                builder: (c, s) => PsPagoPage(
                  idFol: s.pathParameters['idFol'] ?? '',
                ),
              ),
              GoRoute(
                path: ':idFol',
                builder: (c, s) => PsDetallePage(
                  idFol: s.pathParameters['idFol'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'retiros',
            builder: (c, s) => const RetirosPanelPage(),
            routes: [
              GoRoute(
                path: 'efectivo/:idfor',
                builder: (c, s) => RetiroEfectivoPage(
                  idfor: s.pathParameters['idfor'] ?? '',
                  idret: (s.uri.queryParameters['idret'] ?? '').trim(),
                ),
              ),
              GoRoute(
                path: ':idret',
                builder: (c, s) => RetiroDetallePage(
                  idret: s.pathParameters['idret'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'cambio-forma-pago/auth',
            builder: (c, s) => const CambioFormaPagoAuthPage(),
          ),
          GoRoute(
            path: 'cambio-forma-pago',
            builder: (c, s) => const CambioFormaPagoPanelPage(),
          ),
          GoRoute(
            path: 'punto-venta',
            builder: (c, s) => const PuntoVentaHomePage(),
            routes: [
              GoRoute(
                path: 'clientes',
                builder: (c, s) => const ClientesPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const ClienteFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (c, s) =>
                        ClienteFormPage(id: s.pathParameters['id']),
                  ),
                ],
              ),
              GoRoute(
                path: 'cotizaciones',
                builder: (c, s) => const CotizacionesPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (c, s) => const CotizacionFormPage(),
                  ),
                  GoRoute(
                    path: ':idfol/detalle',
                    builder: (c, s) =>
                        DetalleCotPage(idfol: s.pathParameters['idfol'] ?? ''),
                  ),
                  GoRoute(
                    path: ':idfol/pago',
                    builder: (c, s) {
                      final idfol = s.pathParameters['idfol'] ?? '';
                      final tipotran =
                          (s.uri.queryParameters['tipotran'] ?? 'VF').trim();
                      final rawRqfac = (s.uri.queryParameters['rqfac'] ?? '')
                          .trim()
                          .toLowerCase();
                      final rqfac = rawRqfac == '1' || rawRqfac == 'true';
                      return PagoCotizacionPage(
                        idfol: idfol,
                        initialTipoTran: tipotran,
                        initialRqfac: rqfac,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':idfol/ref-detalle',
                    builder: (c, s) {
                      final idfol = s.pathParameters['idfol'] ?? '';
                      final extra = s.extra;
                      RefDetallePageArgs? args;
                      if (extra is RefDetallePageArgs) {
                        args = extra;
                      } else if (extra is Map) {
                        args = RefDetallePageArgs.fromMap(
                          Map<String, dynamic>.from(extra),
                        );
                      }

                      if (args == null) {
                        return const Scaffold(
                          body: Center(
                            child: Text(
                              'No se recibieron datos para REF_DETALLE',
                            ),
                          ),
                        );
                      }
                      return RefDetallePage(args: args.copyWith(idfol: idfol));
                    },
                  ),
                  GoRoute(
                    path: ':idfol',
                    builder: (c, s) =>
                        CotizacionFormPage(idfol: s.pathParameters['idfol']),
                  ),
                ],
              ),
              GoRoute(
                path: 'devoluciones',
                builder: (c, s) => const DevolucionesPage(),
                routes: [
                  GoRoute(
                    path: ':idfolDev/detalle',
                    builder: (c, s) => DetalleDevolucionResumenPage(
                      idfolDev: s.pathParameters['idfolDev'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: ':idfolDev/pago',
                    builder: (c, s) => PagoDevolucionPage(
                      idfolDev: s.pathParameters['idfolDev'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: ':idfolDev',
                    builder: (c, s) => DetalleDevolucionPage(
                      idfolDev: s.pathParameters['idfolDev'] ?? '',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'reimpresion-ticket',
                builder: (c, s) => const ReimpresionPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'reloj-checador/app',
            builder: (c, s) => const RelojChecadorAppPage(),
          ),
          GoRoute(
            path: 'reloj-checador/consultas',
            builder: (c, s) => const RelojChecadorConsultasPage(),
          ),
          GoRoute(
            path: 'facturacion',
            builder: (c, s) => const FacturacionPage(),
          ),
          GoRoute(
            path: 'facturacion/mtto-clientes',
            builder: (c, s) => const FacturaMttoClientePage(),
          ),
          GoRoute(
            path: 'facturacion-view',
            builder: (c, s) => const FacturacionViewPage(),
          ),
          GoRoute(
            path: 'facturacion-sreqf',
            builder: (c, s) => const FacturacionSREQFPage(),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo',
            builder: (c, s) => const OrdenesTrabajoPage(
              panelMode: OrdenesTrabajoPanelMode.operativo,
            ),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo/enviar',
            builder: (c, s) => const OrdenesTrabajoActionPage(
              action: OrdenesTrabajoInitialAction.enviar,
            ),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo/asignar',
            builder: (c, s) => const OrdenesTrabajoActionPage(
              action: OrdenesTrabajoInitialAction.asignar,
            ),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo/regresar-tienda',
            builder: (c, s) => const OrdenesTrabajoActionPage(
              action: OrdenesTrabajoInitialAction.regresarTienda,
            ),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo/recibir',
            builder: (c, s) => const OrdenesTrabajoActionPage(
              action: OrdenesTrabajoInitialAction.recibir,
            ),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo/entregar',
            builder: (c, s) => const OrdenesTrabajoActionPage(
              action: OrdenesTrabajoInitialAction.entregar,
            ),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo/anulados',
            builder: (c, s) => const OrdenesTrabajoPage(
              panelMode: OrdenesTrabajoPanelMode.anulados,
            ),
          ),
          GoRoute(
            path: 'taller/ordenes-trabajo/entregadas',
            builder: (c, s) => const OrdenesTrabajoPage(
              panelMode: OrdenesTrabajoPanelMode.entregadas,
            ),
          ),
        ],
      ),
    ],
  );
});

const Set<String> _facturaManageModuleCodes = <String>{
  'FACTURA',
  'FACTURACION',
  'PV_FACTURACION',
  'FACT_IOE',
  'FACTURA_MTTOCLIENTE',
};

const Set<String> _facturaViewModuleCodes = <String>{
  'FACTURA_VIEW',
};

const Set<String> _facturaReqfModuleCodes = <String>{
  'REG_SINREQF',
};

bool _isFacturacionRoute(String location) {
  return location == '/facturacion' ||
      location.startsWith('/facturacion/') ||
      location == '/facturacion/mtto-clientes' ||
      location.startsWith('/facturacion/mtto-clientes/') ||
      location == '/facturacion-view' ||
      location.startsWith('/facturacion-view/') ||
      location == '/facturacion-sreqf' ||
      location.startsWith('/facturacion-sreqf/');
}

bool _hasFacturacionRouteAccess(String location, List<HomeModule> modules) {
  final codes = modules
      .map((module) => module.codigo.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .toSet();

  if (location == '/facturacion-view' || location.startsWith('/facturacion-view/')) {
    return codes.any(_facturaViewModuleCodes.contains) ||
        codes.any(_facturaManageModuleCodes.contains);
  }

  if (location == '/facturacion' || location.startsWith('/facturacion/')) {
    return codes.any(_facturaManageModuleCodes.contains);
  }

  if (location == '/facturacion-sreqf' ||
      location.startsWith('/facturacion-sreqf/')) {
    return codes.any(_facturaReqfModuleCodes.contains) ||
        codes.any(_facturaManageModuleCodes.contains);
  }

  return true;
}

/// Helper para refrescar go_router desde Riverpod (stream)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

DateTime _parseSqlDateOrNow(String raw, DateTime now) {
  final text = raw.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return DateTime(now.year, now.month, now.day);
  }
  final parts = text.split('-').map(int.parse).toList(growable: false);
  final parsed = DateTime(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    return DateTime(now.year, now.month, now.day);
  }
  return parsed;
}

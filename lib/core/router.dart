import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/login/login_page.dart';
import '../features/home/home_page.dart';
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
import '../features/modulos/punto_venta/punto_venta_home_page.dart';
import '../features/modulos/punto_venta/clientes/clientes_page.dart';
import '../features/modulos/punto_venta/clientes/cliente_form_page.dart';
import '../features/modulos/punto_venta/cotizaciones/cotizaciones_page.dart';
import '../features/modulos/punto_venta/cotizaciones/cotizacion_form_page.dart';
import '../features/modulos/punto_venta/cotizaciones/detalle_cot/detalle_cot_page.dart';

import 'auth/auth_controller.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  List<GoRoute> accessRoutes() => [
        GoRoute(path: 'modulos-back', builder: (c, s) => const ModulosBackendPage()),
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
      if (auth.isLoading) return null;

      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (auth.isAuthenticated && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(
        path: '/',
        builder: (c, s) => const HomePage(),
        routes: [
          GoRoute(path: 'masterdata', builder: (c, s) => const MasterDataPage(), routes: [
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
                  builder: (c, s) => RoleFormPage(roleId: int.tryParse(s.pathParameters['id'] ?? '')),
                ),
              ],
            ),
            GoRoute(
              path: 'datmodulos',
              builder: (c, s) => const DatmodulosPage(),
              routes: [
                GoRoute(path: 'new', builder: (c, s) => const DatModuloFormPage()),
                GoRoute(
                  path: ':modulo',
                  builder: (c, s) => DatModuloFormPage(modulo: s.pathParameters['modulo']),
                ),
              ],
            ),
            GoRoute(
              path: 'deptos',
              builder: (c, s) => const DeptosPage(),
              routes: [
                GoRoute(path: 'new', builder: (c, s) => const DeptoFormPage()),
                GoRoute(
                  path: ':id',
                  builder: (c, s) => DeptoFormPage(deptoId: int.tryParse(s.pathParameters['id'] ?? '')),
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
                  builder: (c, s) => UserFormPage(userId: int.tryParse(s.pathParameters['id'] ?? '')),
                ),
              ],
            ),
            GoRoute(
              path: 'access-reg-suc',
              builder: (c, s) => const AccessRegSucPage(),
              routes: [
                GoRoute(path: 'new', builder: (c, s) => const AccessRegSucFormPage()),
                GoRoute(
                  path: ':modulo/:usuario/:suc',
                  builder: (c, s) {
                    final rawModulo = s.pathParameters['modulo'];
                    final rawUsuario = s.pathParameters['usuario'];
                    final rawSuc = s.pathParameters['suc'];
                    return AccessRegSucFormPage(
                      modulo: rawModulo == null ? null : Uri.decodeComponent(rawModulo),
                      usuario: rawUsuario == null ? null : Uri.decodeComponent(rawUsuario),
                      suc: rawSuc == null ? null : Uri.decodeComponent(rawSuc),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'sucursales',
              builder: (c, s) => const SucursalesPage(),
              routes: [
                GoRoute(path: 'new', builder: (c, s) => const SucursalFormPage()),
                GoRoute(
                  path: ':suc',
                  builder: (c, s) => SucursalFormPage(suc: s.pathParameters['suc']),
                ),
              ],
            ),
            GoRoute(
              path: 'puestos',
              builder: (c, s) => const PuestosPage(),
              routes: [
                GoRoute(path: 'new', builder: (c, s) => const PuestoFormPage()),
                GoRoute(
                  path: ':id',
                  builder: (c, s) => PuestoFormPage(puestoId: int.tryParse(s.pathParameters['id'] ?? '')),
                ),
              ],
            ),
          ]),
          GoRoute(
            path: 'inventarios',
            builder: (c, s) => const InventariosPage(),
            routes: [
              GoRoute(path: 'new', builder: (c, s) => const InventarioFormPage()),
              GoRoute(path: 'captura', builder: (c, s) => const CapturaInventarioPage()),
              GoRoute(
                path: ':cont/captura/detalle',
                builder: (c, s) => DetalleCapturaPage(cont: s.pathParameters['cont']),
              ),
              GoRoute(
                path: 'captura/detalle',
                builder: (c, s) => const DetalleCapturaPage(),
              ),
              GoRoute(
                path: ':cont/det',
                builder: (c, s) => InventarioDetallePage(cont: s.pathParameters['cont'] ?? ''),
              ),
            ],
          ),
          GoRoute(
            path: 'catalogo',
            builder: (c, s) => const DatArtPage(),
          ),
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
                    filtros = Mb51Filtros.fromJson(Map<String, dynamic>.from(extra));
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
                    filtros = Mb52Filtros.fromJson(Map<String, dynamic>.from(extra));
                  }
                  return Mb52ResultadosPage(filtros: filtros);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'punto-venta',
            builder: (c, s) => const PuntoVentaHomePage(),
            routes: [
              GoRoute(path: 'clientes', builder: (c, s) => const ClientesPage(), routes: [
                GoRoute(path: 'new', builder: (c, s) => const ClienteFormPage()),
                GoRoute(
                  path: ':id',
                  builder: (c, s) => ClienteFormPage(id: s.pathParameters['id']),
                ),
              ]),
              GoRoute(path: 'cotizaciones', builder: (c, s) => const CotizacionesPage(), routes: [
                GoRoute(path: 'new', builder: (c, s) => const CotizacionFormPage()),
                GoRoute(
                  path: ':idfol/detalle',
                  builder: (c, s) => DetalleCotPage(idfol: s.pathParameters['idfol'] ?? ''),
                ),
                GoRoute(
                  path: ':idfol',
                  builder: (c, s) => CotizacionFormPage(idfol: s.pathParameters['idfol']),
                ),
              ]),
            ],
          ),
        ],
      ),
    ],
  );
});

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

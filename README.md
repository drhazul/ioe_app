# IOE App

Aplicacion Flutter del sistema IOE. Este frontend consume `ioe-api` y cubre
autenticacion, datos maestros, inventarios, control de cuentas y punto de venta.

## Planteamiento funcional
- Centralizar operacion administrativa (maestros y permisos) y operativa
  (inventarios, catalogos, cotizaciones y consultas).
- Mantener una capa de UI desacoplada de persistencia, usando contratos HTTP
  definidos por `ioe-api`.
- Garantizar navegacion protegida por sesion JWT con renovacion de token.

## Arquitectura
- Enfoque feature-based en `lib/features`.
- Estado con Riverpod.
- Enrutamiento con go_router y guard en `lib/core/router.dart`.
- Cliente HTTP con Dio en `lib/core/dio_provider.dart`.
- Sesion y tokens en `lib/core/auth/auth_controller.dart` y `lib/core/storage.dart`.
- Configuracion de conexion en `lib/core/env.dart`.

## Estructura del proyecto
- `lib/main.dart`: bootstrap, carga de `.env` en release, health check `/health`.
- `lib/core/`: auth, router, env, cliente Dio, storage y utilidades compartidas.
- `lib/features/home/`: carga de menu por perfil.
- `lib/features/login/`: pantalla de login.
- `lib/features/masterdata/`: roles, deptos, puestos, usuarios, sucursales,
  datmodulos, accesos, `usr-mod-suc`, `cat-ctas`.
- `lib/features/modulos/`: inventarios, captura, catalogo `datart`, MB51, MB52,
  control de cuentas y punto de venta.
- `assets/`: `assets/.env`.
- `test/`: pruebas de widget.

## Modulos, endpoints y datos (app -> api -> tablas)
- Home:
- `GET /access/me/front-menu`.
- tablas: `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Auth:
- `POST /auth/login`, `POST /auth/refresh`.
- tablas: `USUARIO`, `USUARIO_TOKEN`.
- Maestros:
- `/roles` -> `ROL` (`IDROL`, `CODIGO`, `NOMBRE`, `ACTIVO`).
- `/deptos` -> `DEPARTAMENTO` (`IDDEPTO`, `NOMBRE`, `ACTIVO`).
- `/puestos` -> `PUESTO` (`IDPUESTO`, `IDDEPTO`, `NOMBRE`, `ACTIVO`).
- `/users` -> `USUARIO` (`IDUSUARIO`, `USERNAME`, `IDROL`, `IDDEPTO`, `IDPUESTO`, `SUC`, `ESTATUS`).
- `/datmodulos` -> `MOD_FRONT` (`CODIGO`, `NOMBRE`, `DEPTO`, `ACTIVO`).
- `/usr-mod-suc` -> `USR_MOD_SUC` (`MODULO`, `USUARIO`, `SUC`, `ACTIVO`).
- `/cat-ctas` -> `DAT_CAT_CTAS` (`CTA`, `DCTA`, `RELACION`, `SUC`).
- `/access/*` -> `MODULO`, `GRUP_MODULO`, `GRUPMOD_MODULO`, `ROL_GRUP_MODULO_PERM`,
  `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Inventarios:
- `/conteos`, `/conteos/:cont/upload-items`, `/conteos/:cont/process`,
  `/conteos/:cont/apply-adjustment`, `/conteos/:cont/sync-capturas`,
  `/conteos/:cont/det`, `/conteos/:cont/summary`.
- `/capturas`, `/capturas/conteos-disponibles`, `/capturas/summary`.
- tablas: `DAT_CONT_CTRL`, `DAT_DET_SVR`, `DAT_CONT_CAPTURA`, `USR_MOD_SUC`.
- campos clave: `CONT`, `SUC`, `ESTA`, `TIPOCONT`, `TOTAL_ITEMS`, `EXT`,
  `ALMACEN`, `CANT`, `CAPTURA_UUID`.
- Catalogo articulos:
- `/datart`, `/datart/:suc/:art/:upc`, `/datart/massive-upload`,
  `/articulos/alta-masiva/upload|preview|validate|commit`.
- tablas: `DAT_ART`, `DAT_ART_MASIVA_TMP`.
- MB51/MB52:
- `/dat-mb51/search`, `/dat-mb52/resumen`, `/dat-almacen`, `/dat-cmov`.
- tablas/fuentes: `DAT_MB51`, `DAT_ART`, `DAT_ALMACEN`, `DAT_CMOV`.
- Control de cuentas:
- `/ctrl-ctas/config`, `/ctrl-ctas/catalog/ctas`, `/ctrl-ctas/catalog/clientes`,
  `/ctrl-ctas/catalog/opvs`, `/ctrl-ctas/consulta/resumen-cliente`,
  `/ctrl-ctas/consulta/resumen-transaccion`, `/ctrl-ctas/consulta/detalle`.
- fuentes: `DAT_CTRL_CTAS`, `DAT_CAT_CTAS`, `FACT_CLIENT_SHP`, `PV_OPV`, `USR_MOD_SUC`.
- Regla UI de exportacion (pantalla `Resumen por Deudor`):
- se habilita exportar si hay exactamente una CTA en criterios, o si el usuario selecciona un CLIENT.
- si CTA esta en `Todas` o multiples CTA, exportar permanece deshabilitado hasta seleccionar un CLIENT.
- El AppBar de resumen muestra el detalle de CTA(s) activas tomadas de criterios.
- Si hay CTA unica y no se selecciona CLIENT, el archivo exporta `RESUMEN_TRANS` y `DETALLE` para todos los CLIENT que cumplan esa CTA.
- La carga de `DETALLE` para exportacion se ejecuta por cliente y por bloques de `IDFOL` para reducir fallas de red por demasiadas llamadas simultaneas.
- Durante exportacion se muestra una ventana emergente de progreso (no cerrable) y se cierra automaticamente al terminar o fallar.
- En la vista de resumen, el filtro `!= 0` inicia activo por defecto (cliente, transaccion y detalle).
- Punto de venta:
- `/factclientshp` -> `FACT_CLIENT_SHP`.
- `/pvctrfolasvr` -> `PV_CTR_FOL_ASVR`.
- `/pvticketlog` -> `PV_TICKET_LOG`.
- `/pvctrords` -> `PV_CTR_ORDS`, `PV_CTR_ORDS_DET`.
- `/refdetalle` -> `REF_DETALLE`.
- `/jrqdepa|jrqsubd|jrqclas|jrqscla|jrqscla2|jrqguia` ->
  `JRQ_DEPA`, `JRQ_SUBD`, `JRQ_CLAS`, `JRQ_SCLA`, `JRQ_SCLA2`, `JRQ_GUIA`.

## Flujo de cierre de cotizacion (PV)
- Pantalla: `PagoCotizacionPage` en `lib/features/modulos/punto_venta/cotizaciones/pago_cotizacion_page.dart`.
- Ruta: `/punto-venta/cotizaciones/:idfol/pago`.
- Entrada: desde `DetalleCotPage`, con modal previo para elegir tipo de cierre `CA` o `VF`.
- Providers/API del flujo:
- `pago_cotizacion_providers.dart`
- `pago_cotizacion_api.dart`
- `pago_cotizacion_models.dart`
- Endpoints backend usados:
- `GET /pv/cotizaciones/:idfol/cierre/context`
- `POST /pv/cotizaciones/:idfol/cierre/preview`
- `POST /pv/cotizaciones/:idfol/cierre`
- Tablas involucradas en el cierre (via API):
- `PV_CTR_FOL_ASVR` (estado e importe final, `ESTA='TRANSMITIR'`, `IMPT`)
- `PV_TICKET_LOG` (base de calculo `SUM(CTD * PVTA)`)
- `PV_CTR_FOL_FORM` (formas definitivas y cambio)
- `DAT_SUC` (`IVA_INTEGRADO` para regla de total)
- El frontend solo presenta y captura formas; el calculo final y validaciones de negocio son autoritativos en backend.

## Conexion y entorno
- Variables de entorno:
- `API_BASE_URL`
- `API_BASE_URL_WEB`
- Resolucion de base URL (`lib/core/env.dart`):
- debug: `http://localhost:3001`.
- release web: `API_BASE_URL_WEB` y fallback `/api`.
- release mobile: `API_BASE_URL` y fallback hardcoded actual.
- En `main.dart`, el health check inicial consulta `/health`.

## Sesion, seguridad y navegacion
- `AuthController`:
- login con `/auth/login`.
- refresh proactivo y en demanda con `/auth/refresh`.
- timeout por inactividad (15 min) y registro de actividad por eventos de UI.
- `dio_provider`:
- agrega `Authorization` en requests protegidos.
- reintenta en 401 con refresh (si aplica).
- `router.dart` redirige segun `AuthState`.

## Tecnologias
- Flutter / Dart
- flutter_riverpod
- go_router
- dio
- shared_preferences
- flutter_dotenv
- file_picker, mobile_scanner, uuid, excel, pdf, printing

## Ejecucion
```bash
flutter pub get
flutter run
```

Web:
```bash
flutter run -d chrome
```

Testing:
```bash
flutter test
```

## Documentacion viva obligatoria
- Cada cambio funcional o tecnico que afecte modulos, rutas, providers,
  endpoints, tablas, campos o consultas debe actualizar en el mismo trabajo:
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\README.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\README.md`
- Esta actualizacion es obligatoria para retroalimentacion y trazabilidad.

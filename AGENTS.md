# Instrucciones de agente para ioe_app

## Contexto del proyecto
- Aplicacion Flutter del ecosistema IOE.
- Frontend feature-based en `lib/features` con Riverpod, go_router y Dio.
- Consume `ioe-api` (NestJS + MSSQL) para auth, maestros, inventarios, control de cuentas y punto de venta.
- Configuracion de entorno en `lib/core/env.dart` y `assets/.env` (solo release).

## Arquitectura y estructura real
- `lib/main.dart`: bootstrap, carga opcional de `.env` en release, health check a `/health`, `ProviderScope`.
- `lib/core/`:
- `auth/auth_controller.dart`: login, refresh, idle timeout, actividad de usuario.
- `dio_provider.dart`: cliente HTTP global, bearer token, retry en 401 con refresh.
- `router.dart`: rutas + guard por estado de autenticacion.
- `env.dart`: seleccion de base URL por plataforma/modo.
- `storage.dart`: persistencia de `access_token`, `refresh_token`, `last_activity_epoch_ms`.
- `lib/features/masterdata/`: catalogos y seguridad administrativa.
- `lib/features/modulos/`: inventarios, catalogo, mb51, mb52, ctrl-ctas y punto-venta.

## Mapa funcional (feature -> API -> tablas/campos)
- Home/Menu: `/access/me/front-menu` -> `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Auth:
- `/auth/login`, `/auth/refresh` -> `USUARIO`, `USUARIO_TOKEN`.
- payload JWT esperado: `sub`, `username`, `roleId`, `nivel`, `suc`.
- Maestros:
- Roles `/roles` -> `ROL`: `IDROL`, `CODIGO`, `NOMBRE`, `DESCRIPCION`, `ACTIVO`, `FCNR`.
- Deptos `/deptos` -> `DEPARTAMENTO`: `IDDEPTO`, `NOMBRE`, `ACTIVO`, `FCNR`.
- Puestos `/puestos` -> `PUESTO`: `IDPUESTO`, `IDDEPTO`, `NOMBRE`, `ACTIVO`, `FCNR`.
- Usuarios `/users` -> `USUARIO`: `IDUSUARIO`, `USERNAME`, `NOMBRE`, `APELLIDOS`, `MAIL`, `ESTATUS`, `NIVEL`, `IDROL`, `IDDEPTO`, `IDPUESTO`, `SUC`.
- Sucursales `/dat-suc` (en backend) -> `DAT_SUC`: `SUC`, `DESC`, `ENCAR`, `ZONA`, `RFC`, `DIRECCION`, `CONTACTO`, `IVA_INTEGRADO`.
- Datmodulos `/datmodulos` -> `MOD_FRONT`: `IDMOD_FRONT`, `CODIGO`, `NOMBRE`, `DEPTO`, `ACTIVO`, `FCNR`.
- Accesos `/access/*` -> `MODULO`, `GRUP_MODULO`, `GRUPMOD_MODULO`, `ROL_GRUP_MODULO_PERM`, `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Acceso regional por sucursal `/usr-mod-suc` -> `USR_MOD_SUC`: `MODULO`, `USUARIO`, `SUC`, `ACTIVO`, `FCNR`.
- Cat. cuentas `/cat-ctas` -> `DAT_CAT_CTAS`: `CTA`, `DCTA`, `RELACION`, `SUC`.
- Inventarios:
- `/conteos`, `/conteos/:cont/*`, `/datcontctrl`, `/datdetsvr/:id`, `/capturas*`.
- tablas: `DAT_CONT_CTRL`, `DAT_DET_SVR`, `DAT_CONT_CAPTURA`, `USR_MOD_SUC`.
- campos clave: `CONT`, `SUC`, `ESTA`, `TIPOCONT`, `TOTAL_ITEMS`, `EXT`, `ALMACEN`, `CANT`, `CAPTURA_UUID`.
- Catalogo articulos:
- `/datart`, `/datart/massive-upload`, `/articulos/alta-masiva/*`.
- tablas: `DAT_ART`, `DAT_ART_MASIVA_TMP`.
- campos clave: `SUC`, `ART`, `UPC`, `DES`, `TIPO`, `PVTA`, `CTOP`, `DEPA`, `SUBD`, `CLAS`, `SCLA`, `SCLA2`.
- MB51/MB52:
- `/dat-mb51/search`, `/dat-mb52/resumen`, `/dat-almacen`, `/dat-cmov`.
- tablas/fuentes: `DAT_MB51`, `DAT_ALMACEN`, `DAT_CMOV`, `DAT_ART`.
- Control de cuentas:
- `/ctrl-ctas/config`, `/ctrl-ctas/catalog/*`, `/ctrl-ctas/consulta/*`.
- tablas/fuentes: `DAT_CTRL_CTAS`, `DAT_CAT_CTAS`, `FACT_CLIENT_SHP`, `PV_OPV`, `USR_MOD_SUC`.
- Punto de venta:
- Clientes `/factclientshp` -> `FACT_CLIENT_SHP`.
- Cotizaciones `/pvctrfolasvr` -> `PV_CTR_FOL_ASVR`.
- Tickets `/pvticketlog` -> `PV_TICKET_LOG`.
- Ordenes `/pvctrords` -> `PV_CTR_ORDS`, `PV_CTR_ORDS_DET`.
- Referencias `/refdetalle` -> `REF_DETALLE`.
- Clasificadores `/jrq*` -> `JRQ_DEPA`, `JRQ_SUBD`, `JRQ_CLAS`, `JRQ_SCLA`, `JRQ_SCLA2`, `JRQ_GUIA`.

## Punto de venta: cierre de cotizacion (implementado)
- Ruta UI: `/punto-venta/cotizaciones/:idfol/pago`.
- Entrada desde `DetalleCotPage`: boton "Pago y cierre", validacion de contexto y modal obligatorio para seleccionar `CA` o `VF`.
- Archivos frontend:
- `lib/features/modulos/punto_venta/cotizaciones/pago_cotizacion_page.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago_cotizacion_providers.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago_cotizacion_api.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago_cotizacion_models.dart`
- Endpoints consumidos:
- `GET /pv/cotizaciones/:idfol/cierre/context`
- `POST /pv/cotizaciones/:idfol/cierre/preview`
- `POST /pv/cotizaciones/:idfol/cierre`
- Totales y validaciones criticas siempre se confirman en backend (no confiar en calculo frontend).
- Al finalizar exitosamente se refrescan providers de cotizacion/ticket y se regresa al listado de cotizaciones.

## Conexiones y consultas
- Base URL por `Env.apiBaseUrl`:
- debug: `http://localhost:3001`.
- release web: `API_BASE_URL_WEB` o fallback `/api`.
- release mobile: `API_BASE_URL` o fallback hardcoded actual.
- `dio_provider` aplica:
- header `Authorization: Bearer`.
- refresh automatizado en 401 (excepto rutas auth).
- tracking de requests protegidos para idle timeout.
- Consultas del frontend siempre via APIs de feature (`*_api.dart`).

## Reglas estrictas
- No modificar logica de negocio ni flujos de autenticacion sin confirmacion.
- No cambiar versiones de dependencias ni agregar nuevas sin permiso.
- No eliminar pantallas, rutas o providers sin confirmacion explicita.
- No editar archivos generados (`build/`) ni plataformas (`android/`, `ios/`, etc.) salvo pedido.
- No modificar `assets/.env` ni exponer secretos.
- Evitar comandos destructivos.

## Refactors
- Incrementales y por feature.
- Mantener convenciones: `*_api.dart`, `*_models.dart`, `*_providers.dart`, `*_page.dart`.
- Mantener estructura de `lib/core` para utilidades compartidas.

## Cambios estructurales
- Mover features o renombrar rutas requiere aprobacion previa.
- Actualizar `lib/core/router.dart` cuando se agreguen rutas.
- Mantener `AuthController` y el guard de rutas coherentes.

## Cambios de dependencias
- Requieren aprobacion previa y justificacion tecnica.
- No actualizar versiones por iniciativa propia.

## Logica critica
- AuthController, token refresh, storage y router guard son criticos.
- Consultar antes de modificar interceptores Dio o reglas de redireccion.

## Inventarios: autorizacion por sucursal
- El filtro de sucursal en Inventarios se basa en `USR_MOD_SUC` para el modulo `DAT_JAA_ALM`.
- Los componentes de filtro (sucursal, nombre, fecha, filtrar/limpiar) deben mostrarse para todos los usuarios, incluido admin.
- La seleccion/cambio de sucursal en UI solo debe habilitarse cuando el usuario este autorizado por rol/listado (`USR_MOD_SUC`).
- Las acciones sensibles (ej. aplicar ajuste) deben usar la sucursal seleccionada y confiar en validacion backend de autorizacion.

## Control de Cuentas: autorizacion por sucursal
- El modulo de Home que navega a `/ctrl-ctas` puede llegar como `DAT_CONS_CTAS`, `DAT_CTRL_CTAS` o `DAT_CTRL_CUENTAS`.
- En `CtrlCtasConsultaPage`, la sucursal no debe quedar bloqueada por defecto para no-admin; debe depender de `ctrl-ctas/config` (`allowedSucs`, `canSelectSucs`, `forcedSuc`).
- Para no-admin, mostrar y permitir elegir solo sucursales autorizadas por backend (`allowedSucs`); para admin, mantener lista completa.
- Si `canSelectSucs` es `false`, la UI puede mostrar la sucursal forzada; si es `true`, habilitar dropdown/multiseleccion.
- No usar la sucursal del perfil/JWT como unica fuente en frontend; la autorizacion efectiva debe venir de `USR_MOD_SUC` via API.
- En `CtrlCtasResumenClientePage`, la exportacion Excel debe habilitarse cuando hay una sola CTA seleccionada en criterios, o cuando existe un CLIENT seleccionado en la grilla.
- Si CTA queda en `Todas` (sin CTA) o se seleccionan multiples CTA, la exportacion debe permanecer deshabilitada hasta seleccionar un CLIENT.
- El AppBar de `Resumen por Deudor` debe mostrar el resumen de CTA(s) enviadas desde criterios (`CTA: Todas`, una CTA, o multiples con contador).
- En exportacion con CTA unica y sin CLIENT seleccionado, `RESUMEN_TRANS` y `DETALLE` deben incluir todos los CLIENT de la consulta (filtrados por la CTA seleccionada).
- Para evitar errores de conexion, la consulta de `DETALLE` en exportacion debe enviarse por cliente y por bloques de `IDFOL` (secuencial), no con N llamadas concurrentes por folio.
- La exportacion en `CtrlCtasResumenClientePage` debe mostrar modal de progreso no cerrable manualmente, con avance por etapas, y cerrarse solo al finalizar o en error.
- En `CtrlCtasResumenClientePage` el filtro `!= 0` debe iniciar activo por defecto en resumen cliente, resumen transaccion y detalle de transaccion.

## Documentacion viva obligatoria
- Cada nueva implementacion que cambie modulos, rutas, providers, endpoints, tablas, campos o consultas debe actualizar en el mismo trabajo:
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\README.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\README.md`
- No cerrar una tarea funcional sin dejar trazabilidad documental sincronizada entre app y api.

# IOE App

Frontend Flutter del ecosistema IOE. Consume `ioe-api` para autenticación, maestros, inventarios, control de cuentas y punto de venta.

> Consulta otros README/AGENTS solo si la tarea lo exige; evita cargar contexto extra innecesario.

## Planteamiento funcional
- Centralizar operación administrativa (maestros y permisos) y operativa (inventarios, catálogos, cotizaciones y consultas).
- Mantener UI desacoplada de persistencia usando contratos HTTP definidos por `ioe-api`.
- Garantizar navegación protegida con sesión JWT y refresh.
- Regla principal para módulos nuevos: cada módulo nuevo debe operar con regla legacy de acceso (`admin` acceso total; resto de usuarios por sucursal autorizada según `USUARIO.SUC` y/o `USR_MOD_SUC`). La definición/consumo de rutas y endpoints debe construirse bajo esa regla desde el inicio.
- Punto de venta / Pago de Servicios (2026-04): la salida operativa de folios pagados utiliza `ESTA='CERRADO_PS'` (con lectura compatible de históricos en `TRANSMITIR`).
- Punto de venta / Pago de Servicios (2026-05-06): en detalle de adeudos PS, `Ver registros` y `Asignar referencia` se muestran en una sola línea para evitar superposición visual.
- Punto de venta / Pago de Servicios (2026-05-22): en voucher PS (pantalla de pago y reimpresión), el renglón `IMPD` usa importe por comprobante en vez del total de transacción.
- Punto de venta / Cotizaciones cierre mixto (2026-05-14): en pago de cotizaciones, `CREDITO` y `DEUDOR` no se mezclan con otras formas; formas no `EFECTIVO` no pueden exceder pendiente en orden de captura y solo `EFECTIVO` puede exceder para calcular cambio.
- Punto de venta / Cotizaciones rehidratacion de pago pagado (2026-06-18): al reabrir `/punto-venta/cotizaciones/:idfol/pago` con folio `PAGADO/MB51PROCES`, la UI rehidrata formas persistidas desde `GET /pv/cotizaciones/:idfol/cierre/print-preview` para mostrar `Pagos/Faltante/Cambio` correctos.
- Punto de venta / Devoluciones regla simplificada (2026-05-22): devolución parcial solo cuando el ticket origen es `EFECTIVO` único; si origen es mixto o no-efectivo, la devolución debe ser total y respetar cada forma de pago origen.
- Facturación / Mantenimiento y validación cliente (2026-04-06): al editar datos fiscales de cliente se conserva la `SUC` original del registro; el frontend ya no envía `SUC` en la edición desde validación.
- Ordenes de trabajo / Asignar (2026-04-21): el catálogo de colaboradores se consulta por `DAT_LAB.SUC` del laboratorio asignado a la ORD; tanto la selección en grilla como el modal de relación rechazan mezclar ORDs con laboratorios de sucursales distintas.
- Ordenes de trabajo / Consulta estado (2026-04-23): el panel conserva filtros aplicados por modo, añade columna `OPV` con nombre tomado de `USUARIO`, expone nuevo módulo solo lectura `/taller/ordenes-trabajo/estado` para `admin`/`jefe taller`/`analista`, captura `HR_ENT` en máscara `HH:MM` dentro del detalle y refuerza la etiqueta (`FCNS`, cliente grande y QR con más padding).
- Ordenes de trabajo / Consulta estado (2026-06-18): en el detalle de ORDs con `ESTSEGU=11`, el modal agrega `Imprimir evidencia` para generar PDF con cabecera, detalle, folio de entrega y firma capturada en el folio.
- Ordenes de trabajo / Incidencia (2026-04-07): el flujo de regreso por incidencia valida `ESTSEGU=8` con colaborador asignado y confirma transición a `ESTSEGU=9` (pendiente recibir en analista); la recepción en tienda resuelve `9.1/9.2` según `TIPOM`.
- Ordenes de trabajo / Cambio material y Merma (2026-04-08): el modal opera con semáforo interno `selCtrlOrd` (`NULL/0/13/14/15`) y flujo `Crear Nueva ORD -> Solicitar autorización -> Retrabajo (opcional) -> Autorizar` como cierre final; muestra resumen enriquecido de origen + captura derivada con `Subtotal/IVA/Total`, `Diferencia económica` y `CTD_C_M` (`1|0.5`).
- Ordenes de trabajo / Cambio material y Merma (2026-04-09): el cálculo mostrado en captura toma fiscalidad del folio origen (`REQF/RQFAC`, `AUT/ORIGEN_AUT`) además de `DAT_SUC.IVA_INTEGRADO`, corrigiendo casos donde `PV_CTR_ORDS.RQFAC` está `NULL`.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): se agrega botón `Crear Nueva ORD` para insertar staging de preparación; mientras no exista ese registro temporal se ocultan campos/botones de captura.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): la captura temporal puede recapturarse también con `selCtrlOrd=15` antes de volver a solicitar autorización.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): la captura muestra costo de artículo igual al de la ORD original para evitar diferencias de precio contra la nueva ORD.
- Ordenes de trabajo / Cambio material y Merma (2026-04-21): `Solicitar autorización` solo mueve a `selCtrlOrd=14`; `Retrabajo` devuelve a `15`; `Autorizar` queda visible solo para `admin`, `ANALISTA_INV` e `INVJEF` y ejecuta el cierre final del proceso.
- Ordenes de trabajo / Cambio material y Merma (2026-04-22): la captura de `Nueva ORD` vuelve a mostrar `Diferencia` y leyenda `Saldo a favor/en contra` según el artículo seleccionado y el cálculo homologado del backend.
- Ordenes de trabajo / Cambio material y Merma (2026-06-17): `Subtotal` e `IVA` de la ORD original se calculan desde `PVTAT base` y la impresión deja ese campo con la misma etiqueta.
- Ordenes de trabajo / Cambio material y Merma (2026-06-17): `CTD_C_M` depende de `CTD` original (`1` -> `1|0.5`, `0.5` -> `0.5`) y la diferencia económica compara el total original prorrateado contra el total de la nueva ORD.
- Ordenes de trabajo / Panel ORDs (2026-04-21): `ANALISTA_INV` e `INVJEF` participan en revisión de cambio/merma (`selCtrlOrd=14`); la visibilidad efectiva del panel queda gobernada por matriz de flujos en backend.
- Ordenes de trabajo / Garantía (2026-04-29): se restituye el módulo de entregadas/garantía en Home; en ese panel solo se habilita `Ver detalle` para `admin` y `JEF_TALLER`, el detalle mantiene `Guardar cambios` para comentario y `Garantía` confirma transición `11 -> 9.3`. En `9.3` aparece solo el botón `Aplicar merma o cambio` para elegir `TIPOM` (1/2) y `MOTR`, continuando el flujo existente de `9.1/9.2`.
- Ordenes de trabajo / Recepción laboratorio externo (2026-05-01): `Recibir en taller` permite a `ANALISTA_ORD/ANALISTA` recibir únicamente ORDs de laboratorio externo; en ese caso la transición es `ESTSEGU 5 -> 10` (pendiente entrega cliente), mientras laboratorio interno conserva `5 -> 7`.
- Ordenes de trabajo / Envío y recepción laboratorio externo (2026-05-03): `Enviar a taller` ahora mueve ORDs con `DAT_LAB.UBILAB='EXTERNO'` a `ESTSEGU=9` (pendiente recibir en analista), manteniendo `3 -> 5` para interno; `Recibir en taller` para `ANALISTA_ORD/ANALISTA` valida flujo `9` en externo y aplica `9 -> 10`.
- Ordenes de trabajo / Matriz persistente de visibilidad (2026-05-03): la visibilidad por flujo/rol en panel ORDs se controla desde backend con `dbo.DAT_JAO_ORD_FLUJO_VIS` para módulo `DAT_JAO_ORD`.
- Datos Maestros / Visualización por ROLL en ORD (2026-05-03): menú en maestros `Visualizacion por ROLL en ORD` con filtros por `ROLL` y `ESTSEGU`; formulario usa combos desde `ROL` y `DAT_EST_ORD`, `MODULO` bloqueado y `ORDEN` automático.
- Datos Maestros / Módulos Front unificado (2026-05-04): se retira el acceso directo `/#/masterdata/datmodulos` del menú de maestros y el mantenimiento de módulos se atiende desde `/#/masterdata/access/mod-front` usando el mismo CRUD de `datmodulos`.
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): nuevo acceso `/#/masterdata/access/enrolamiento-front-usr`; la visualización de módulos en Home prioriza reglas activas por usuario (`USR_GRUPMOD_FRONT`) y usa rol (`ROL_GRUPMOD_FRONT`) solo cuando usuario no tiene asignaciones.
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): el formulario incorpora filtros por `Sucursal` y `Departamento` para acotar la lista de usuarios disponibles en el dropdown.
- Datos Maestros / Acceso por sucursal (2026-05-04): en `/#/masterdata/access-reg-suc` se agregan dropdowns `Sucursal (usuario)` y `Departamento` tanto en el filtro del CRUD como en el popup de vinculación para acotar módulos front/usuarios y el listado de registros.
- Datos Maestros / Acceso por sucursal (2026-05-06): el filtro `Departamento` en `/#/masterdata/access-reg-suc` opera por coincidencia de `departamento de usuario OR departamento del módulo`; el dropdown usa unión de departamentos en lugar de intersección.
- Ordenes de trabajo / Panel ORDs (2026-05-06): `ANALISTA_INV` e `INVJEF` ya no reciben bloqueo al cargar catálogo de asignados del panel.
- Ordenes de trabajo / Panel ORDs (2026-05-06): el listado operativo de inventarios vuelve a depender de la cola backend `selCtrlOrd=14` en `sp_ordenes_trabajo_panel`.
- Ordenes de trabajo / Panel ORDs multi-sucursal analista (2026-05-22): al seleccionar una sucursal explícita permitida (ej. `DF14`), usuarios `ANALISTA_ORD/ANALISTA` con acceso multi-sucursal deben visualizar ORDs recientes de esa sucursal; backend evita recorte adicional por `HOME_SUC`.
- Ordenes de trabajo / Validación y edición multi-sucursal por IORD (2026-05-29): validaciones por código (`*/validar`) y guardado de detalle envían `suc` de contexto cuando existe; evita bloqueo falso de acceso al operar ORDs de sucursal alterna permitida (ej. `DF14`) con usuario de home `DF04`.
- Ordenes de trabajo / Cambio-merma integridad artículo-descripción (2026-05-29): la UI de captura evita fallback de descripción original cuando el artículo nuevo es diferente; la nueva ORD debe reflejar el artículo/descripción solicitados desde UI y no heredar datos de merma/cambio en la ORD derivada.
- Ordenes de trabajo / Contexto sucursal en validaciones por código (2026-05-30): la UI de acciones directas y panel ya no envía por defecto `USUARIO.SUC` cuando no existe sucursal operativa explícita; evita rechazos falsos en ORDs de sucursales permitidas por `USR_MOD_SUC`.
- Ordenes de trabajo / ORDs derivadas cambio-merma (2026-05-22): al `Recibir en tienda`, una ORD nueva derivada de cambio/merma debe continuar flujo normal `9 -> 10` (pendiente entrega cliente); el remapeo a `9.1/9.2` queda reservado para incidencias de la ORD original.
- Datos Maestros / Puestos migrado a ROL (2026-05-05): el formulario de usuarios ya no envía `IDPUESTO`, `/#/masterdata/puestos` opera como acceso de compatibilidad hacia `roles`, y los catálogos de cargos toman datos desde `ROL`.
- Entorno dev API (2026-05-14): para ejecución local en web/desktop, la base URL de desarrollo usa `http://127.0.0.1:3000` y en Android emulator `http://10.0.2.2:3000`.
- Merma / Admin full acciones (2026-05-27): en `DAT_JAA_MERM`, el perfil admin (`IDROL 0/1` o `username=ADMIN`) debe mostrar acciones completas de gestión/detalle para validaciones (`Nuevo`, `Revisar`, `Contabilizar`, `Anular`, `Detalle documento`, `Imprimir etiqueta`) y no quedar restringido al modo solo impresión en documentos contabilizados.
- Merma / Botón detalle en abiertos-pendientes (2026-05-27): en la vista `Gestión de merma`, documentos en estado `ABIERTO` o `PENDIENTE` muestran acción `Detalle documento` para abrir captura completa y poder agregar/eliminar artículos.
- Merma / Retiro botón consulta (2026-05-27): se retira acción `Ver en consulta` en pantalla de `Gestión de merma` y en la vista de `detalle documento`.
- Punto de venta / Gestión de promociones (actualizado 2026-05-13): acceso principal desde Home con módulo front `PV_PROMO_GES` hacia `/#/promociones` (se mantiene compatibilidad de redirección desde `/#/punto-venta/promociones`). Pantalla en `lib/features/modulos/punto_venta/promociones/*` con CRUD/configuración y filtros por estado, sucursal y tipo de promoción.
- Punto de venta / Gestión de promociones (2026-05-26): sin cambios de payload en frontend; backend de `GET/PUT /promociones/:idProm/configuracion` tolera JWT legacy (`idusuario/userid` y fallback por `username`) y reconoce admin por `roleId/IDROL/idRol` (default `0,1`) para evitar `403 Usuario inválido para resolver sucursales`.
- Punto de venta / Gestión de promociones (2026-05-26): la UI agrega señalización de obligatorios y mensajes de error en formularios del módulo (promoción, tipo-beneficio y configuración), corrige crash de dropdown por duplicados y reemplaza selección de cliente por modal con buscador y selección única.
- Punto de venta / Gestión de promociones (2026-05-26): el selector de cliente usa catálogo completo por sucursal desde backend (base `FACT_CLIENT_SHP` con `ESTATUS=0`, `IDC` como `CLIENTE`) y deduplica por `CLIENTE`.
- Punto de venta / Cotizaciones precio manual vs promoción (2026-05-23): en detalle de cotización, cuando un renglón está en sincronización remota se muestra texto neutro (`Sincronizando ticket...` / `Sincronizando...`) para reflejar proceso general de guardado y no reasignación automática de promoción en UI.
- Punto de venta / Cotizaciones ORD vs precio manual (2026-05-23): en detalle cotización, la asignación/liberación de `ORD` conserva el `PVTA` manual del renglón (sin regreso automático a precio catálogo).
- Notas de documentación viva: este README solo debe cambiarse cuando se agreguen/modifiquen módulos, rutas o datos de arquitectura/base (no para ajustes locales de pantalla). Otros cambios funcionales van al README/AGENTS del módulo afectado.

## Arquitectura general
- Enfoque feature-based en `lib/features`.
- Estado con Riverpod.
- Enrutamiento con go_router y guard en `lib/core/router.dart`.
- Cliente HTTP con Dio (`lib/core/dio_provider.dart`).
- Sesión y tokens en `lib/core/auth/auth_controller.dart` y `lib/core/storage.dart`.
- Configuración de conexión en `lib/core/env.dart`.

## Estructura general
- `lib/main.dart`: bootstrap, carga opcional de `.env` en release, health check `/health`, `ProviderScope`.
- `lib/core/`: auth, router, env, cliente Dio, storage y utilidades compartidas.
- `lib/features/home/`: carga de menú por perfil.
- `lib/features/login/`: pantalla de login.
- `lib/features/masterdata/`: roles, deptos, puestos, usuarios, sucursales, datmodulos, accesos, `usr-mod-suc`, `cat-ctas`, `dat_form`.
- `lib/features/modulos/`: inventarios, catálogo `datart`, MB51/MB52, control de cuentas, taller y punto de venta.
- `assets/.env`: variables de entorno para release.
- `test/`: pruebas de widget.

## Documentación por módulos
- Base de módulos: `docs/modules/base_modulos/README.md` (instrucciones: `docs/modules/base_modulos/AGENTS.md`)
- Core y seguridad: `docs/modules/core_seguridad/README.md` (instrucciones: `docs/modules/core_seguridad/AGENTS.md`)
- Punto de venta: `docs/modules/punto_venta/README.md` (instrucciones: `docs/modules/punto_venta/AGENTS.md`)
- Ordenes de trabajo: `docs/modules/ordenes_trabajo/README.md` (instrucciones: `docs/modules/ordenes_trabajo/AGENTS.md`)
- Reloj checador: `docs/modules/reloj_checador/README.md` (instrucciones: `docs/modules/reloj_checador/AGENTS.md`)

## Tecnologias
- Flutter / Dart
- Riverpod, go_router, Dio

## Pruebas obligatorias
- Antes de entregar cambios ejecutar `flutter analyze` y `flutter test`.
- Si hay cambios coordinados con `ioe-api`, ejecutar también las pruebas del backend (`npm test` en IOE API).

## Ejecucion
- `flutter test`
- `flutter run -d chrome`
- `powershell -ExecutionPolicy Bypass -File .\scripts\build-web-release-safe.ps1`
- `powershell -ExecutionPolicy Bypass -File .\scripts\serve-web-release-local.ps1 -Port 8088`
- `powershell -ExecutionPolicy Bypass -File .\scripts\serve-web-release-local.ps1 -Port 8088 -ApiBaseUrlWeb http://192.168.10.234:8085/api`

## Login web: debug vs release
- Si abres en `localhost:<puerto-aleatorio>` desde `flutter run -d chrome`, estás en modo debug (DDC): es normal ver cientos/miles de requests (`ddc_module_loader.js`, `dart_sdk.js`, `*.dart.lib.js`).
- En producción/release (`flutter build web --release`) no debe aparecer esa cascada; deben verse pocos archivos iniciales (`index.html`, `flutter_bootstrap.js`, `main.dart.js`, `canvaskit.*`, fuentes/assets).
- Si pruebas release en `127.0.0.1:8088`, por defecto no existe proxy `/api`; para login real apunta API explícita con `-ApiBaseUrlWeb` al backend (ejemplo arriba).
- La pantalla de login dispara `GET /health` durante el bootstrap de conectividad.
- Al presionar `Entrar`, la pantalla de login dispara `POST /auth/login`.

- Punto de venta / Cambio forma de pago REQF (2026-06-18): al cambiar forma de pago, si el `IDFOL` tiene `REQF=1` y `AUT=VF`, backend re-sincroniza `FAC_SVR_SHAP/FACT_TICKET_SHP` vía `sp_fact_sync_folio_vf`; frontend muestra trazabilidad `facturacionSync` en el aviso.

## Documentacion viva
- Mantén este índice y los README/AGENTS de módulo actualizados cuando cambien flujos o contratos.
- Cambio material / Merma (2026-04-22): la nueva ORD derivada debe quedar sin colaborador asignado y la UI/PDF deben mostrar la diferencia contable real basada en `CTD_C_M`/importe sellado, no la diferencia por `CTD` completa.

# IOE App

Frontend Flutter del ecosistema IOE. Consume `ioe-api` para autenticación, maestros, inventarios, control de cuentas y punto de venta.

> Consulta otros README/AGENTS solo si la tarea lo exige; evita cargar contexto extra innecesario.

## Planteamiento funcional
- Centralizar operación administrativa (maestros y permisos) y operativa (inventarios, catálogos, cotizaciones y consultas).
- Mantener UI desacoplada de persistencia usando contratos HTTP definidos por `ioe-api`.
- Garantizar navegación protegida con sesión JWT y refresh.
- Punto de venta / Pago de Servicios (2026-04): la salida operativa de folios pagados utiliza `ESTA='CERRADO_PS'` (con lectura compatible de históricos en `TRANSMITIR`).
- Facturación / Mantenimiento y validación cliente (2026-04-06): al editar datos fiscales de cliente se conserva la `SUC` original del registro; el frontend ya no envía `SUC` en la edición desde validación.
- Ordenes de trabajo / Asignar (2026-04-21): el catálogo de colaboradores se consulta por `DAT_LAB.SUC` del laboratorio asignado a la ORD; tanto la selección en grilla como el modal de relación rechazan mezclar ORDs con laboratorios de sucursales distintas.
- Ordenes de trabajo / Consulta estado (2026-04-23): el panel conserva filtros aplicados por modo, añade columna `OPV` con nombre tomado de `USUARIO`, expone nuevo módulo solo lectura `/taller/ordenes-trabajo/estado` para `admin`/`jefe taller`/`analista`, captura `HR_ENT` en máscara `HH:MM` dentro del detalle y refuerza la etiqueta (`FCNS`, cliente grande y QR con más padding).
- Ordenes de trabajo / Incidencia (2026-04-07): el flujo de regreso por incidencia valida `ESTSEGU=8` con colaborador asignado y confirma transición a `ESTSEGU=9` (pendiente recibir en analista); la recepción en tienda resuelve `9.1/9.2` según `TIPOM`.
- Ordenes de trabajo / Cambio material y Merma (2026-04-08): el modal opera con semáforo interno `selCtrlOrd` (`NULL/0/13/14/15`) y flujo `Crear Nueva ORD -> Solicitar autorización -> Retrabajo (opcional) -> Autorizar` como cierre final; muestra resumen enriquecido de origen + captura derivada con `Subtotal/IVA/Total`, `Diferencia económica` y `CTD_C_M` (`1|0.5`).
- Ordenes de trabajo / Cambio material y Merma (2026-04-09): el cálculo mostrado en captura toma fiscalidad del folio origen (`REQF/RQFAC`, `AUT/ORIGEN_AUT`) además de `DAT_SUC.IVA_INTEGRADO`, corrigiendo casos donde `PV_CTR_ORDS.RQFAC` está `NULL`.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): se agrega botón `Crear Nueva ORD` para insertar staging de preparación; mientras no exista ese registro temporal se ocultan campos/botones de captura.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): la captura temporal puede recapturarse también con `selCtrlOrd=15` antes de volver a solicitar autorización.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): la captura muestra costo de artículo igual al de la ORD original para evitar diferencias de precio contra la nueva ORD.
- Ordenes de trabajo / Cambio material y Merma (2026-04-21): `Solicitar autorización` solo mueve a `selCtrlOrd=14`; `Retrabajo` devuelve a `15`; `Autorizar` queda visible solo para `admin`, `ANALISTA_INV` e `INVJEF` y ejecuta el cierre final del proceso.
- Ordenes de trabajo / Cambio material y Merma (2026-04-22): la captura de `Nueva ORD` vuelve a mostrar `Diferencia` y leyenda `Saldo a favor/en contra` según el artículo seleccionado y el cálculo homologado del backend.
- Ordenes de trabajo / Panel ORDs (2026-04-21): `ANALISTA_INV` e `INVJEF` ven solo la cola de revisión interna de cambio/merma pendiente en `selCtrlOrd=14`, sin alterar la visibilidad del resto de perfiles.
- Ordenes de trabajo / Garantía (2026-04-29): se restituye el módulo de entregadas/garantía en Home; en ese panel solo se habilita `Ver detalle` para `admin` y `JEF_TALLER`, el detalle mantiene `Guardar cambios` para comentario y `Garantía` confirma transición `11 -> 9.3`. En `9.3` aparece solo el botón `Aplicar merma o cambio` para elegir `TIPOM` (1/2) y `MOTR`, continuando el flujo existente de `9.1/9.2`.
- Ordenes de trabajo / Recepción laboratorio externo (2026-05-01): `Recibir en taller` permite a `ANALISTA_ORD/ANALISTA` recibir únicamente ORDs de laboratorio externo; en ese caso la transición es `ESTSEGU 5 -> 10` (pendiente entrega cliente), mientras laboratorio interno conserva `5 -> 7`.
- Ordenes de trabajo / Envío y recepción laboratorio externo (2026-05-03): `Enviar a taller` ahora mueve ORDs con `DAT_LAB.UBILAB='EXTERNO'` a `ESTSEGU=9` (pendiente recibir en analista), manteniendo `3 -> 5` para interno; `Recibir en taller` para `ANALISTA_ORD/ANALISTA` valida flujo `9` en externo y aplica `9 -> 10`.
- Ordenes de trabajo / Matriz persistente de visibilidad (2026-05-03): la visibilidad por flujo/rol en panel ORDs se controla desde backend con `dbo.DAT_JAO_ORD_FLUJO_VIS` para módulo `DAT_JAO_ORD`.
- Datos Maestros / Visualización por ROLL en ORD (2026-05-03): menú en maestros `Visualizacion por ROLL en ORD` con filtros por `ROLL` y `ESTSEGU`; formulario usa combos desde `ROL` y `DAT_EST_ORD`, `MODULO` bloqueado y `ORDEN` automático.
- Datos Maestros / Módulos Front unificado (2026-05-04): se retira el acceso directo `/#/masterdata/datmodulos` del menú de maestros y el mantenimiento de módulos se atiende desde `/#/masterdata/access/mod-front` usando el mismo CRUD de `datmodulos`.
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): nuevo acceso `/#/masterdata/access/enrolamiento-front-usr`; la visualización de módulos en Home prioriza reglas activas por usuario (`USR_GRUPMOD_FRONT`) y usa rol (`ROL_GRUPMOD_FRONT`) solo cuando usuario no tiene asignaciones.
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): el formulario incorpora filtros por `Sucursal` y `Departamento` para acotar la lista de usuarios disponibles en el dropdown.
- Datos Maestros / Acceso por sucursal (2026-05-04): en `/#/masterdata/access-reg-suc` se agregan dropdowns `Sucursal (usuario)` y `Departamento` tanto en el filtro del CRUD como en el popup de vinculación para acotar módulos front/usuarios y el listado de registros.
- Datos Maestros / Puestos migrado a ROL (2026-05-05): el formulario de usuarios ya no envía `IDPUESTO`, `/#/masterdata/puestos` opera como acceso de compatibilidad hacia `roles`, y los catálogos de cargos toman datos desde `ROL`.
- Entorno dev API (2026-05-05): para ejecución local en web/desktop, la base URL de desarrollo usa `http://127.0.0.1:3001` y en Android emulator `http://10.0.2.2:3001`.
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

## Documentacion viva
- Mantén este índice y los README/AGENTS de módulo actualizados cuando cambien flujos o contratos.
- Cambio material / Merma (2026-04-22): la nueva ORD derivada debe quedar sin colaborador asignado y la UI/PDF deben mostrar la diferencia contable real basada en `CTD_C_M`/importe sellado, no la diferencia por `CTD` completa.

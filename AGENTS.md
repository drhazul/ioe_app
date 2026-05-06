# Instrucciones de agente para ioe_app

> Abre otros README/AGENTS solo si la tarea lo exige; evita cargar contexto extra.

## Contexto del proyecto
- App Flutter feature-based (`lib/features`) con Riverpod, go_router y Dio.
- Consume `ioe-api` (NestJS + MSSQL) para auth, maestros, inventarios, control de cuentas y punto de venta.
- Entorno: `lib/core/env.dart` y `assets/.env` (solo release).
- Alcance de cambios en este AGENTS: actualizar aquí solo cuando se modifique estructura global, rutas base o se creen/eliminan módulos. Cambios funcionales específicos se documentan en los AGENTS/README del módulo impactado.

## Pruebas automatizadas
- `flutter analyze` y `flutter test` antes de entregar.
- Si hay cambios coordinados con `ioe-api`, validar también el backend (`npm test`).

## Arquitectura y estructura real
- `lib/main.dart`: bootstrap, carga opcional de `.env`, health check `/health`, `ProviderScope`.
- `lib/core/`: auth, router, env, cliente Dio, storage y utilidades compartidas.
- `lib/features/masterdata/`: catálogos y seguridad administrativa.
- `lib/features/modulos/`: inventarios, catálogo `datart`, MB51/MB52, control de cuentas, taller y punto de venta.
- Catálogo DAT_ART (2026-04): la ficha permite editar `UPC`; antes de guardar se valida que no esté asignado a otro `ART` de la misma sucursal.
- Punto de venta / Pago de Servicios (2026-04): el cierre operativo al salir de pago usa `ESTA='CERRADO_PS'` (compatibilidad de lectura para históricos en `TRANSMITIR`).
- Facturación / Cliente fiscal (2026-04-06): en edición de datos fiscales (módulo `FACTURA_MTTOCLIENTE` y diálogo de validación) la `SUC` del cliente es inmutable; no se envía `SUC` desde frontend al actualizar.
- Ordenes de trabajo / Asignar (2026-04-21): la selección de colaborador toma `DAT_LAB.SUC` del laboratorio asignado a cada ORD; si se mezclan ORDs de laboratorios en sucursales distintas, el flujo se bloquea hasta separarlas.
- Ordenes de trabajo / Consulta estado (2026-04-23): el panel conserva criterios por modo (`operativo`/`estado`), la columna `OPV` muestra `USUARIO.NOMBRE`, el nuevo módulo `/taller/ordenes-trabajo/estado` es solo lectura para `admin`/`jefe taller`/`analista`, y el detalle permite capturar `HR_ENT` con máscara `HH:MM`; la etiqueta muestra `FCNS`, cliente en tipografía reforzada y QR con más separación.
- Ordenes de trabajo / Incidencia (2026-04-07): `Regresar incidencia` valida `ESTSEGU=8` con colaborador asignado y cambia a `ESTSEGU=9`; `Regresar a tienda` desde `9` decide `9.1/9.2` por `TIPOM`.
- Ordenes de trabajo / Cambio material y Merma (2026-04-08): el modal de detalle usa `GET/POST /ordenes-trabajo/:iord/cambio-merma/*` para contexto/preparación/retrabajo/autorización final con `selCtrlOrd` (`NULL/0/13/14/15`), `CTD_C_M` (`1|0.5`), resumen enriquecido y cálculo homologado (`subtotal/iva/total/diferencia`).
- Ordenes de trabajo / Cambio material y Merma (2026-04-09): la captura refleja cálculo homologado a cotizaciones abiertas usando tipo/fiscalidad del folio origen (`AUT/ORIGEN_AUT`, `REQF/RQFAC`) junto con `DAT_SUC.IVA_INTEGRADO`.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): se agrega botón `Crear Nueva ORD` para crear staging (`PV_ORD_CAMBIO_MERMA_TMP`); sin staging no se muestran campos/acciones de captura, y la recaptura sigue permitida cuando `selCtrlOrd=15`.
- Ordenes de trabajo / Cambio material y Merma (2026-04-19): el costo de la nueva ORD se alinea al costo de la ORD original para evitar diferencias de precio en captura.
- Ordenes de trabajo / Cambio material y Merma (2026-04-21): `Solicitar autorización` fija `selCtrlOrd=14`; `Retrabajo` devuelve a `15`; `Autorizar` visible solo para `admin`, `ANALISTA_INV` e `INVJEF` crea la nueva ORD y anula la original.
- Ordenes de trabajo / Cambio material y Merma (2026-04-22): la sección `Nueva ORD` debe mostrar `Diferencia` y el estado `Saldo a favor/en contra` con el valor calculado para el artículo capturado.
- Ordenes de trabajo / Panel ORDs (2026-04-21): `ANALISTA_INV` e `INVJEF` operan una cola dedicada de revisión (`selCtrlOrd=14`) sin cambiar la vista del resto de roles.
- Ordenes de trabajo / Garantía (2026-04-29): el módulo de entregadas se restaura en Home para `admin`/`JEF_TALLER`, muestra solo `Ver detalle`; desde detalle la acción `Garantía` mueve `11 -> 9.3`, permite editar comentario y agrega `Aplicar merma o cambio` solo en `9.3` (captura `TIPOM` 1/2 + `MOTR`) para continuar el mismo flujo de `9.1/9.2`.
- Ordenes de trabajo / Recepción laboratorio externo (2026-05-01): `Recibir en taller` habilita también a `ANALISTA_ORD/ANALISTA` para ORDs de laboratorio externo; la recepción cambia `5 -> 10` en externo y conserva `5 -> 7` en laboratorio interno.
- Ordenes de trabajo / Envío y recepción laboratorio externo (2026-05-03): al `Enviar a taller`, si el laboratorio asignado (`DAT_LAB.UBILAB='EXTERNO'`) la ORD cambia `3 -> 9` (pendiente recibir en analista); `Recibir en taller` para `ANALISTA_ORD/ANALISTA` valida flujo `9` externo y aplica `9 -> 10`, mientras interno conserva `5 -> 7`.
- Ordenes de trabajo / Matriz persistente de visibilidad (2026-05-03): frontend consume la visibilidad de flujos que backend resuelve desde `dbo.DAT_JAO_ORD_FLUJO_VIS` (módulo `DAT_JAO_ORD`), incluyendo excepción de flujo `9` solo para laboratorio externo.
- Datos Maestros / Visualización por ROLL en ORD (2026-05-03): acceso en `/masterdata/ord-flujo-vis` con filtros dropdown `ROLL`/`ESTSEGU`; alta/edición con combos `ROLE_CODE` (tabla `ROL`) y `ESTA` (`DAT_EST_ORD`), campo `MODULO` bloqueado y `ORDEN` automático.
- Datos Maestros / Módulos Front unificado (2026-05-04): se elimina acceso directo `/#/masterdata/datmodulos` del menú `/#/masterdata`; el CRUD de módulos se centraliza en `/#/masterdata/access/mod-front` reutilizando pantalla `datmodulos` (sin duplicar CRUD).
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): se agrega gestión en `/#/masterdata/access/enrolamiento-front-usr`; Home prioriza asignaciones activas de `USR_GRUPMOD_FRONT` por usuario y, si no existen, usa fallback por rol (`ROL_GRUPMOD_FRONT`).
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): la pantalla agrega dropdowns `Sucursal` y `Departamento` para filtrar el selector de usuario antes de asignar grupos front.
- Datos Maestros / Acceso por sucursal (2026-05-04): `/#/masterdata/access-reg-suc` incorpora dropdowns `Sucursal (usuario)` y `Departamento` en CRUD principal y popup de vinculación para filtrar listado y catálogos (`Módulo Front` / `Usuario`) con el mismo criterio.
- Datos Maestros / Puestos migrado a ROL (2026-05-05): la app deja de enviar `IDPUESTO` en `/users`, el menú/ruta `/masterdata/puestos` redirige al mantenimiento de `roles`, y catálogos de cargos consumen `ROL` para compatibilidad con bases sin tabla `PUESTO`.
- Entorno dev API (2026-05-05): `Env.apiBaseUrl` en desarrollo web/desktop apunta a `http://127.0.0.1:3001` para usar backend local actualizado y evitar `404` de servidores remotos con build desfasado.

## Documentación por módulos
- Base de módulos: `docs/modules/base_modulos/AGENTS.md` (README: `docs/modules/base_modulos/README.md`)
- Core y seguridad: `docs/modules/core_seguridad/AGENTS.md` (README: `docs/modules/core_seguridad/README.md`)
- Punto de venta: `docs/modules/punto_venta/AGENTS.md` (README: `docs/modules/punto_venta/README.md`)
- Ordenes de trabajo: `docs/modules/ordenes_trabajo/AGENTS.md` (README: `docs/modules/ordenes_trabajo/README.md`)
- Reloj checador: `docs/modules/reloj_checador/AGENTS.md` (README: `docs/modules/reloj_checador/README.md`)

## Reglas estrictas
- No tocar lógica de negocio ni flujos de autenticación sin confirmación.
- No cambiar versiones de dependencias ni agregar nuevas sin permiso.
- No eliminar pantallas, rutas o providers sin confirmación explícita.
- No editar `assets/.env` ni exponer secretos.
- Evitar comandos destructivos.

## Refactors
- Hacerlos incrementales y por feature.
- Conservar convenciones: `*_api.dart`, `*_models.dart`, `*_providers.dart`, `*_page.dart`.
- Respetar la estructura de `lib/core`.

## Cambios estructurales
- Mover features o renombrar rutas requiere aprobación previa.
- Actualizar `lib/core/router.dart` al agregar rutas.
- Mantener coherencia de `AuthController` y guard de rutas.

## Cambios de dependencias
- Requieren aprobación y justificación técnica.

## Logica critica
- `AuthController`, refresh de tokens, interceptores Dio y guard de router.

## Documentacion viva obligatoria
- Cada cambio funcional debe reflejarse en el README/AGENTS principal y en los README/AGENTS del módulo afectado (app y API) en el mismo trabajo.
- Cambio material / Merma (2026-04-22): la nueva ORD derivada debe quedar sin colaborador asignado y la UI/PDF deben mostrar la diferencia contable real basada en `CTD_C_M`/importe sellado, no la diferencia por `CTD` completa.

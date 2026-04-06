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
- Ordenes de trabajo / Asignar (2026-04-05): para usuario `admin`, la selección de colaborador toma la sucursal elegida en el filtro del panel ORDs (prioriza sucursal de ORDs seleccionadas cuando aplica), evitando usar por defecto la sucursal base del token.
- Ordenes de trabajo / Incidencia (2026-04-05): el flujo `Regresar incidencia` mantiene contrato UI/API y se estabiliza con ajuste de SP backend (`sp_ordenes_trabajo_regresar_incidencia_lote`) para cambios `9 -> 9.1` con motivo.

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

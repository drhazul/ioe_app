# IOE App

Frontend Flutter del ecosistema IOE. Consume `ioe-api` para autenticación, maestros, inventarios, control de cuentas y punto de venta.

> Consulta otros README/AGENTS solo si la tarea lo exige; evita cargar contexto extra innecesario.

## Planteamiento funcional
- Centralizar operación administrativa (maestros y permisos) y operativa (inventarios, catálogos, cotizaciones y consultas).
- Mantener UI desacoplada de persistencia usando contratos HTTP definidos por `ioe-api`.
- Garantizar navegación protegida con sesión JWT y refresh.
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

# Reloj checador (front)

Navega a otros README/AGENTS solo si la tarea lo requiere.

Enlaces relacionados:
- README principal del frontend: `README.md`
- AGENTS de este módulo: `docs/modules/reloj_checador/AGENTS.md`
- Módulos vinculados: `docs/modules/base_modulos/README.md`, `docs/modules/core_seguridad/README.md`

## Reloj Checador (Asistencia)
- Rutas:
- `/reloj-checador/app` (marcaje)
- `/reloj-checador/consultas` (gestion y consulta)
- Archivos frontend:
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_page.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_api.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_models.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_providers.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_page.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_api.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_models.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_providers.dart`
- Flujo App (Marcaje):
- consume `GET /reloj-checador/context` para mostrar ultimo/siguiente marcaje y flags de policy.
- permite checkpoints `ENTRADA`, `SALIDA_COMER`, `REGRESO_COMER`, `SALIDA`.
- consume `POST /reloj-checador/timelog` con `AUTH_METHOD`, `LIVENESS_OK` y GPS cuando la policy lo requiere.
- Flujo Consultas:
- timelogs: filtros y correccion admin (`PUT /reloj-checador/timelog/:id` con reason).
- incidencias: crear/listar/cambiar estatus (`POST/GET/PUT`).
- documentos: subir base64/listar/descargar (`POST/GET/GET download`).
- overrides: crear/listar/revocar (`POST/GET/PUT`).
- policy: lectura/upsert solo admin (`GET/POST /reloj-checador/policy`).
- Integracion Home/Router:
- `lib/core/router.dart` registra rutas del modulo.
- `lib/features/home/home_page.dart` resuelve modulos de asistencia hacia `/reloj-checador/app`.


# Reloj checador (AGENTS front)

Navega a otros README/AGENTS solo cuando sea necesario.

Enlaces relacionados:
- AGENTS principal del frontend: `AGENTS.md`
- README de este módulo: `docs/modules/reloj_checador/README.md`
- Otros AGENTS: `docs/modules/base_modulos/AGENTS.md`, `docs/modules/core_seguridad/AGENTS.md`

## Reloj Checador (asistencia) - implementado (2026-02)
- Rutas UI:
- `/reloj-checador/app`
- `/reloj-checador/consultas`
- Integracion en router:
- `lib/core/router.dart` registra ambas rutas bajo Home.
- Integracion en Home:
- `lib/features/home/home_page.dart` resuelve codigo/nombre de modulo de asistencia hacia `/reloj-checador/app`.
- Estructura frontend:
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_page.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_api.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_models.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_providers.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_page.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_api.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_models.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_providers.dart`
- `lib/features/modulos/reloj_checador/consultas/download_helper.dart`
- `lib/features/modulos/reloj_checador/consultas/download_helper_stub.dart`
- `lib/features/modulos/reloj_checador/consultas/download_helper_web.dart`
- Endpoints consumidos:
- `GET /reloj-checador/context`
- `POST /reloj-checador/timelog`
- `GET /reloj-checador/timelogs`
- `PUT /reloj-checador/timelog/:id`
- `POST /reloj-checador/incidencias`
- `PUT /reloj-checador/incidencias/:id/status`
- `GET /reloj-checador/incidencias`
- `POST /reloj-checador/documentos`
- `GET /reloj-checador/documentos`
- `GET /reloj-checador/documentos/:id/download`
- `POST /reloj-checador/overrides`
- `GET /reloj-checador/overrides`
- `PUT /reloj-checador/overrides/:id/revoke`
- `GET /reloj-checador/policy`
- `POST /reloj-checador/policy`
- Reglas UI relevantes:
- App de marcaje muestra checkpoints `ENTRADA`, `SALIDA_COMER`, `REGRESO_COMER`, `SALIDA` y habilita botones segun secuencia devuelta por contexto.
- Si policy exige GPS, la UI de marcaje requiere `LAT/LON` (MVP con captura manual).
- En debug, la pantalla de marcaje expone switch de `Liveness OK` para pruebas de flujo FACE.
- Consultas incluye tabs de Timelogs, Incidencias, Documentos y Policy/Overrides con acciones condicionadas por rol.
- Correccion admin de timelog exige `REASON` y manda `PUT /reloj-checador/timelog/:id`.
- Carga de documentos en MVP usa `file_picker` + base64 JSON (sin multipart).
- Mounted checks:
- En operaciones async de app/consultas se usan verificaciones `if (!mounted) return;` y actualizacion de estado segura.


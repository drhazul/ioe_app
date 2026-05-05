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
- alcance por rol en consultas: `admin` y `rrhh` con visibilidad global de sucursales/colaboradores; demás roles se mantienen acotados por SUC/departamento.
- Integracion Home/Router:
- `lib/core/router.dart` registra rutas del modulo.
- `lib/features/home/home_page.dart` resuelve modulos de asistencia hacia `/reloj-checador/app`.

## Estructura de tablas involucradas por submódulo
- Cola local (frontend/offline): `sync_queue` en SQLite (`attendance_secure_queue.db`) guarda endpoint, payload, headers, prioridad, estado de sincronización, intentos, `client_id_unico`, timestamps.
- Marcaje core: `ATT_POLICY`, `ATT_TIME_LOG`, `MARCAJES`, `ATT_BIOMETRIC_TEMPLATE`, `ATT_ALERTA`.
- Gestión de sucursales: `SUCURSALES`, `ATT_ASISTENCIA_FOTO`, `COMANDOS_ADMS`.
- Gestión de colaboradores: `COLABORADORES`, `BIO_TEMPLATES`, `COLABORADORES_SUCURSALES`, `COLABORADORES_DOCUMENTOS`.
- Horarios y turnos: `HORARIOS`, `COLABORADORES_HORARIOS`, `TURNOS_CATALOGO`, `HORARIOS_CONFIRMACION`.
- Incidencias y vacaciones: `ATT_INCIDENCIA`, `ATT_PERMISOS_TIPOS`, `ATT_SOLICITUDES`, `ATT_VACACIONES_SALDOS`.
- Reporte mensual/asistencia: `ATT_ASISTENCIA_ESTATUS`, `ATT_RULES`, `PERIODOS_CIERRE`.
- Notificaciones y cumplimiento: `NOTIFICACIONES`, `CONTRATOS`, `HISTORICO_PUESTOS`, `ATT_NOM035_RESPUESTAS`.
- Auditoría operativa: `LOGS_AUDITORIA`, `AUDIT_LOGS`.
- Referencia detallada (backend/BD): `ioe-api/sql/reloj_checador/README_TABLAS_SUBMODULOS.md`.

## Ajustes recientes QA (2026-04-30)
- Persistencia de pestañas: `Horarios`, `Incidencias` y `Reporte` conservan estado/filtros al cambiar de tab (`AutomaticKeepAliveClientMixin`).
- Conectividad API visible: se expone banner rojo en shell de Reloj Checador cuando `localhost:3001` no responde.
- Interceptor Dio: set/clear de alerta global de conectividad mediante provider para feedback inmediato en UI.
- Marcaje 2FA: campo actualizado a `ID (Matrícula) o PIN`; se bloquea marcaje sin biometría y se muestra mensaje `Faltan datos biométricos del colaborador` con acciones `Ingresar datos` y `Cambiar datos`.
- Colaboradores: flujo de edición mantiene `UPDATE` (`PATCH /colaboradores/:id`) y mejora diagnóstico de errores 500 mostrando payload real del backend.
- Sucursales: columnas `Dispositivos` y `Cola de Envío` se movieron al menú de `Acciones`; tabla principal prioriza `Nombre sucursal` y `Empresa`.
- PIN automático: alta de colaborador ahora precarga PIN aleatorio de 4 dígitos con botón `Regenerar PIN`; acción `Resetear PIN` genera nuevo PIN y lo persiste mostrando confirmación.
- Horarios: toolbar/filtros superiores en `SingleChildScrollView` horizontal para eliminar overflow en pantallas estrechas; contenedor con `borderRadius: 12` y sombra ligera.
- Sincronización de rol: altas/ediciones envían `rol` (`TRABAJADOR`/`ADMIN`) para evitar `USUARIO: ROL inválido` durante sync de backend.
- Sucursales edición unificada: acción `Editar` abre el mismo formulario administrativo completo de `Agregar sucursal` en modo precargado.
- Corrección crash al cancelar (2026-05-05): se eliminó `FocusScope.unfocus()` + `Future.delayed` del método `_safePop` para evitar que `TextFormField` acceda a `FocusNode`/`TextEditingController` ya desechados al cerrar diálogos modales de colaboradores.

## Acta técnica de conformidad (2026-04-30)
- `flutter analyze` en `ioe_app`: **OK (0 issues)**.
- `npm run build` en `ioe-api`: **OK**.
- Reporte mensual: estructura dashboard lateral y filtros responsivos confirmados en código (`SingleChildScrollView horizontal` + `Wrap`).
- Horarios: header/filtros responsivos confirmados en código (`Wrap` con `spacing/runSpacing`) y badge semanal tipo píldora con borde dinámico para semana actual.
- Estatus `JUSTIFICADO`: render semafórico azul/celeste confirmado en tabla del reporte.
- Nota de auditoría: validación **pixel-perfect runtime** depende de sesión visual activa de la app (navegación real en dispositivo/navegador).


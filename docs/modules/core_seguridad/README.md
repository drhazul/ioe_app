# Core y seguridad (front)

Navega a otros README/AGENTS solo cuando la tarea lo requiera.

Enlaces relacionados:
- README principal del frontend: `README.md`
- AGENTS de este módulo: `docs/modules/core_seguridad/AGENTS.md`
- Otros módulos: `docs/modules/base_modulos/README.md`, `docs/modules/punto_venta/README.md`

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

## Reglas de autorizacion por sucursal (UI/API)
- Para modulos multi-sucursal, la UI debe respetar sucursales autorizadas por backend via `USR_MOD_SUC` y no forzar siempre `user.suc`.
- Modulos con regla activa:
- Inventarios (`DAT_JAA_ALM`).
- Control de cuentas (`DAT_CONS_CTAS`, `DAT_CTRL_CTAS`, `DAT_CTRL_CUENTAS`).
- Caja general (`DAT_FORM_ENTR_OPV`, `DAT_RES_ENTRE_CAJ`, `PV_ENTREGA_CG`).
- Si el usuario no-admin tiene sucursales vinculadas para el modulo, debe poder visualizar/procesar informacion de esas sucursales vinculadas.
- Compatibilidad legacy: si backend no encuentra filas activas en `USR_MOD_SUC` para el modulo, la app usa fallback a `user.suc`.
- La API es la fuente final de autorizacion; frontend solo refleja el contexto permitido y muestra error si backend rechaza.
- Caja general Excel: la hoja `DETALLE TRANSACCIONES` muestra `REQF` en la exportacion global y conserva el valor original (`-1/0/1`).
- Caja general Excel: los importes de `RESUMEN DIA` y `DETALLE TRANSACCIONES` se exportan como numericos con formato moneda (no texto).

## Regla principal FACTURA / FACTURA_VIEW (rutas y consultas)
- Toda nueva ruta, endpoint o consulta de facturación debe aplicar esta regla desde diseño.
- Enrutamiento UI:
- `/facturacion` requiere módulo front `FACTURA` (compatibilidad: `FACTURACION`, `PV_FACTURACION`, `FACT_IOE`).
- `/facturacion-view` requiere módulo front `FACTURA_VIEW`.
- Admin (rol/nivel administrativo configurado; incluye usuario `ADMIN`) mantiene bypass total en frontend y backend para consultar/editar/eliminar.
- Facturación no depende de `USR_MOD_SUC` en flujo base (`/facturacion`, `/facturacion-view`, unificación); no se requiere alta de admin en `USR_MOD_SUC` para habilitar estos accesos.
- Excepción: `REG_SINREQF` sí depende de `USR_MOD_SUC` para alcance de sucursales en usuarios no-admin.
- En unificación de facturación (`/facturacion/unificaciones/*`), no se debe restringir gestión por `user.suc` del JWT cuando el usuario ya cuenta con permisos de gestión.


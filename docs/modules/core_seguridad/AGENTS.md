# Core y seguridad (AGENTS front)

Navega a otros README/AGENTS solo cuando sea necesario.

Enlaces relacionados:
- AGENTS principal del frontend: `AGENTS.md`
- README de este módulo: `docs/modules/core_seguridad/README.md`
- Otros AGENTS: `docs/modules/base_modulos/AGENTS.md`, `docs/modules/punto_venta/AGENTS.md`

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

## Regla transversal UI/API: autorizacion por sucursal con USR_MOD_SUC
- En modulos multi-sucursal, la UI no debe asumir `user.suc` como unica sucursal operable para usuarios no-admin.
- Si backend expone sucursales autorizadas por `USR_MOD_SUC` para el modulo, la UI debe permitir consultar/procesar en todas esas sucursales vinculadas.
- El control de seguridad final siempre es backend; frontend solo habilita/oculta opciones segun contexto autorizado.
- Compatibilidad legacy: cuando backend no devuelve sucursales por `USR_MOD_SUC`, la UI puede operar con la sucursal del contexto (`user.suc`) para no romper flujos existentes.

## Regla principal FACTURA / FACTURA_VIEW (obligatoria)
- Esta regla es base para crear rutas, endpoints y consultas de facturación.
- Enrutamiento:
- `/facturacion` requiere módulo `FACTURA` (compat: `FACTURACION`, `PV_FACTURACION`, `FACT_IOE`).
- `/facturacion-view` requiere módulo `FACTURA_VIEW`.
- Admin (rol/nivel administrativo configurado; incluye usuario `ADMIN`) tiene bypass total en front y back para consultar/editar/eliminar en facturación.
- Facturación no usa `USR_MOD_SUC` como control de autorización en flujo base (`/facturacion`, `/facturacion-view`, unificación); no se requiere registro de admin en `USR_MOD_SUC`.
- Excepción: `REG_SINREQF` sí usa `USR_MOD_SUC` para alcance de sucursales no-admin.
- En unificación de facturación (`/facturacion/unificaciones/*`), no se debe forzar restricción operativa por `user.suc` del JWT cuando ya existe permiso de gestión.

## Caja General: autorizacion por sucursal
- Para `caja-general`, considerar autorizadas las sucursales vinculadas al usuario en `USR_MOD_SUC` para modulos `DAT_FORM_ENTR_OPV`, `DAT_RES_ENTRE_CAJ` y `PV_ENTREGA_CG`.
- No bloquear visualizacion/proceso por comparar exclusivamente contra `user.suc`; la UI debe respetar la sucursal seleccionada cuando backend la autoriza.
- Mantener manejo de error cuando backend rechace una sucursal fuera de la interseccion autorizada.
- Exportacion Excel global: la hoja `DETALLE TRANSACCIONES` incluye la columna `REQF` (dato entregado por backend desde `PV_CTR_FOL_ASVR.REQF`) y muestra el valor original (`-1/0/1`), sin convertirlo a booleano.
- Exportacion Excel global: los importes de `RESUMEN DIA` y `DETALLE TRANSACCIONES` deben escribirse como valores numericos y con formato moneda en Excel (no como texto).


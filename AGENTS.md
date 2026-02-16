# Instrucciones de agente para ioe_app

## Contexto del proyecto
- Aplicacion Flutter para el sistema IOE.
- Arquitectura feature-based en `lib/features`.
- Riverpod para estado, go_router para navegacion.
- Dio con interceptores para JWT y refresh token.
- Configuracion en `lib/core/env.dart` y `assets/.env`.

## Reglas estrictas
- No modificar logica de negocio ni flujos de autenticacion sin confirmacion.
- No cambiar versiones de dependencias ni agregar nuevas sin permiso.
- No eliminar pantallas, rutas o providers sin confirmacion explicita.
- No editar archivos generados (`build/`) ni plataformas (`android/`, `ios/`, etc.) salvo pedido.
- No modificar `assets/.env` ni exponer secretos.
- Evitar comandos destructivos.

## Refactors
- Incrementales y por feature.
- Mantener convenciones: `*_api.dart`, `*_models.dart`, `*_providers.dart`, `*_page.dart`.
- Mantener estructura de `lib/core` para utilidades compartidas.

## Cambios estructurales
- Mover features o renombrar rutas requiere aprobacion previa.
- Actualizar `lib/core/router.dart` cuando se agreguen rutas.
- Mantener `AuthController` y el guard de rutas coherentes.

## Cambios de dependencias
- Requieren aprobacion previa y justificacion tecnica.
- No actualizar versiones por iniciativa propia.

## Logica critica
- AuthController, token refresh, storage y router guard son criticos.
- Consultar antes de modificar interceptores Dio o reglas de redireccion.

## Inventarios: autorizacion por sucursal
- El filtro de sucursal en Inventarios se basa en `USR_MOD_SUC` para el modulo `DAT_JAA_ALM`.
- Los componentes de filtro (sucursal, nombre, fecha, filtrar/limpiar) deben mostrarse para todos los usuarios, incluido admin.
- La seleccion/cambio de sucursal en UI solo debe habilitarse cuando el usuario este autorizado por rol/listado (`USR_MOD_SUC`).
- Las acciones sensibles (ej. aplicar ajuste) deben usar la sucursal seleccionada y confiar en validacion backend de autorizacion.

## Control de Cuentas: autorizacion por sucursal
- El modulo de Home que navega a `/ctrl-ctas` puede llegar como `DAT_CONS_CTAS`, `DAT_CTRL_CTAS` o `DAT_CTRL_CUENTAS`.
- En `CtrlCtasConsultaPage`, la sucursal no debe quedar bloqueada por defecto para no-admin; debe depender de `ctrl-ctas/config` (`allowedSucs`, `canSelectSucs`, `forcedSuc`).
- Para no-admin, mostrar y permitir elegir solo sucursales autorizadas por backend (`allowedSucs`); para admin, mantener lista completa.
- Si `canSelectSucs` es `false`, la UI puede mostrar la sucursal forzada; si es `true`, habilitar dropdown/multiseleccion.
- No usar la sucursal del perfil/JWT como unica fuente en frontend; la autorizacion efectiva debe venir de `USR_MOD_SUC` via API.

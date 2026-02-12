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

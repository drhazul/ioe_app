# Pantallas Quadrum

Esta carpeta contiene pantallas y clientes Flutter del flujo Quadrum; `facturacion_page.dart` de Facturify permanece separado.

## Panel de correo

- `cfdi_correo_page.dart`: configuración, conexión Gmail OAuth, prueba de envío e historial de outbox en `/facturacion/correo`.
- `cfdi_correo_api.dart` consume `/cfdi/correo/*`; proveedores Riverpod viven en `cfdi_correo_providers.dart`.
- `correo_oauth_launcher*.dart` abre una pestaña desde el gesto del usuario y usa enlace copiable si el navegador bloquea la ventana.
- La ruta se restringe en Flutter a administración. La API aplica además `JwtAuthGuard` y `AdminOnlyGuard`.
- El refresh token nunca vive en Flutter; callback backend lo cifra y persiste. No guardar secretos OAuth en código, assets o `.env` de la App.
- El panel necesita API activa, DDL aplicado, variables seguras y cuenta autorizada. Su existencia en código no implica servicio desplegado.

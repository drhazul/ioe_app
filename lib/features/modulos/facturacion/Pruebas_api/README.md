# Pantallas Quadrum

Reintento de correo valida ID entero o textual BIGINT dentro del handler;
no convertir directamente con `as num` en el botón. API entrega entero seguro.
Esta acción encola correo con XML/PDF existentes y conserva UUID del CFDI.

Esta carpeta contiene pantallas y clientes Flutter del flujo Quadrum; `facturacion_page.dart` de Facturify permanece separado.

## Panel de correo

- `cfdi_correo_page.dart`: configuración, conexión Gmail OAuth, prueba de envío e historial de outbox en `/facturacion/correo`.
- `cfdi_correo_api.dart` consume `/cfdi/correo/*`; proveedores Riverpod viven en `cfdi_correo_providers.dart`.
- `correo_oauth_launcher*.dart` abre una pestaña desde el gesto del usuario y usa enlace copiable si el navegador bloquea la ventana.
- La ruta se restringe en Flutter a administración. La API aplica además `JwtAuthGuard` y `AdminOnlyGuard`.
- El refresh token nunca vive en Flutter; callback backend lo cifra y persiste. No guardar secretos OAuth en código, assets o `.env` de la App.
- El panel necesita API activa, DDL aplicado, variables seguras y cuenta autorizada. Su existencia en código no implica servicio desplegado.


## Consulta SAT Quadrum (2026-10-13)

Corrección exclusiva de API: obtiene_status_sat selecciona nombres de credenciales según WSDL de producción/desarrollo. Contrato HTTP Flutter y UI sin cambios. Código local validado; despliegue y consulta real pendientes. Seguimiento canónico en ioe-api/docs/modules/cfdi/QUADRUM_POST_TIMBRADO_CORRECCION_SEGUIMIENTO.md.

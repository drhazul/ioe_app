# Certificados CSD y cuenta Quadrum

Pantalla `/facturacion/csd`: carga/renovación de certificados y edición independiente de la cuenta PAC de cada RFC.

## Edición de cuenta

Botón **Editar Quadrum** por fila de certificado activo, disponible para administración; filas reemplazadas y usuarios sin administración muestran acción deshabilitada con motivo. Diálogo muestra RFC/razón social y precarga sólo usuario; contraseña actual permanece oculta y nunca se consulta.

Guardar usa `PATCH /cfdi/csd/:rfc/quadrum` mediante cliente `CsdApi`, protegido además por AdminOnlyGuard en backend. Contraseña nueva se oculta por defecto con control de visibilidad. Si usuario cambia, nueva contraseña es obligatoria; si conserva usuario, dejar contraseña vacía mantiene actual. Backend también exige contraseña cuando aún no existe una guardada.

Durante guardado se bloquean acciones y cierre accidental; errores permanecen en diálogo. Tras éxito se cierra y refresca listado. No requiere CER/KEY ni contraseña de llave, no timbra y no activa automáticamente RFC bloqueados. Contraseña del buzón de correo y de la llave CSD son independientes de cuenta Quadrum.

## Verificación local

Análisis dirigido CSD sin incidencias. Pruebas de widget cubren contraseña no precargada/oculta, usuario nuevo sin contraseña, guardar nuevo par, conservar contraseña y cancelar sin escritura. Hot reload aplicado a sesión web conectada, sin errores de runtime. Ruta PATCH desplegada en API 900b625 junto con App 9a72b96; consulta de documentación y petición sin JWT confirman ruta y protección. Hash de artefacto web servido coincide con build. No se modificaron credenciales reales por herramientas del agente para probar despliegue; UAT administrativa de guardado queda para una cuenta verificada.

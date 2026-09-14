# Instrucciones de agente para Inventarios App

## Alcance
- Features Flutter bajo `lib/features/modulos` relacionadas con inventarios: catalogo, inventarios, MB51/MB52, merma, transferencias y sugeridos.

## Recepción de mercancías
- Feature: `lib/features/modulos/recepciones`; ruta `/modulos/recepciones`; código `DAT_REC`.
- Consumir exclusivamente `/recepciones`; no actualizar `DAT_ART`, `DAT_MB51` ni estados de O.C. desde Flutter.
- Mantener separadas recepción física y autorización administrativa. Costos y documento comercial dependen de la proyección autorizada del backend.
- La pestaña Pedidos pendientes no consulta al entrar; solo consulta después de aplicar O.C., proveedor, fecha o sucursal. El selector operativo contiene únicamente `DF01/DF04/DF05/DF06`.
- El filtro Proveedor consume el catálogo ordenado de `/recepciones/catalogos/proveedores`; limpiar filtros debe regresar la pestaña a su estado inicial sin resultados.
- Histórico inicia sin resultados y exige uno de sus filtros propios por O.C., proveedor, fecha o sucursal, sin estatus; Indicadores mantiene sucursal y su acción de limpiar filtros.
- Para `ENCARGADO DE SUCURSAL` (`IDROL=13008`), DAT_REC solo muestra Pedidos pendientes en estado de O.C. `PROCESADO` y oculta órdenes `PARCIAL`, sucursal, Histórico e Indicadores; el alcance real debe mantenerse protegido por el API.
- El Encargado no solicita autorización manualmente: al guardar se valida, sale del detalle y el documento deja de aparecer en su listado. Jefe/Analista revisan documentos `VALIDADO` y conservan acciones de autorizar/rechazar.
- El detalle del Encargado usa borrador persistente, checkbox como primera columna, `Pos.` como segunda columna, selección total y paginación de 100. La tabla es adaptable y no muestra Recibido acum., Cantidad aceptada ni Estatus; Acciones captura únicamente Cantidad física, calcula internamente la aceptada con el mismo valor y conserva `APROBADO` como dato técnico. El diálogo final bloquea el tipo de recepción calculado, permite varios folios, acepta letras/números/signos en Guías de envío y muestra Paquetería antes de Observaciones. No se reintroduce recepción masiva para ese rol.
- En la captura para Jefe/Analista, usar el mismo resumen compacto y alineado a la izquierda del Encargado, colocar el formulario documental antes de la tabla y no mostrar `Recepción masiva` ni `Completar recepción física`. Esto no modifica las acciones de autorización/rechazo de documentos `VALIDADO`.
- Si la O.C. tiene una recepción activa, no mostrar captura vacía: cargar el documento persistido, presentar estado de recepción y datos documentales antes de la tabla, y usar una tabla adaptable sin `Pos.` basada en el detalle histórico guardado.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`) y `ANALISTA DE INVENTARIOS` (`IDROL=9005`), ocultar Cantidad aceptada, Estatus y Productos no solicitados, mostrar Faltantes y Sobrantes derivados de `REC_INCI_PED`, y etiquetar la autorización final como `Contabilizar`.
- La cola de Jefe y Analista conserva O.C. `PROCESADO/PARCIAL/VALIDADO/RECHAZADO` según la etapa administrativa. En una O.C. `PROCESADO`, el Jefe reutiliza el diseño de captura del Encargado y su acción principal es `Validar recepción`: crea el documento, solicita autorización, cierra el detalle y lo deja `VALIDADO`, sin contabilizarlo automáticamente. El Analista conserva el flujo de creación, validación y contabilización inmediata. En O.C. `PARCIAL`, si existe recepción previa `CONTABILIZADO`, reutilizar y mostrar antes de la tabla tipo de recepción, documento, folio, guías y observaciones; no abrir otra vez el diálogo documental al continuar. Solo solicitar esos datos cuando no exista captura previa.
- En un documento `VALIDADO`, el botón explícito `Contabilizar` del Jefe y Analista debe confirmar antes de llamar a autorización y cerrar el detalle únicamente cuando el backend responda correctamente. Después debe abrir Histórico filtrado por la O.C. para mostrar el documento `CONTABILIZADO`; no confundirlo con `Estado O.C.`, que puede seguir `PARCIAL` por faltantes.
- En captura DAT_REC, los filtros jerárquicos deben reutilizar `/jrqdepa`, `/jrqsubd`, `/jrqclas`, `/jrqscla` y `/jrqscla2`; cada nivel y `SPH/CYL/ADIC` puede aplicarse individualmente, mientras la cascada es solo una ayuda para acotar opciones. La vista agrupada usa la ruta jerárquica completa y no debe alterar selecciones ni cantidades al alternar con la vista por artículos. Mantener el bloque de botones alineado a la izquierda.
- `Rechazar mercancía` es exclusivo del Encargado en la captura, requiere motivo y envía todos los renglones pendientes con tipo `RECHAZO`; tras guardar debe cerrar la vista. Los documentos `RECHAZADO` no reaparecen para el Encargado y Jefe/Analista los abren en consulta.
- En `VALIDADO`, solo el Jefe (`IDROL=2`) muestra edición documental y la columna `Acciones`, exclusivamente para modificar el costo; la cantidad física ya validada es de solo lectura. La tabla incluye `Pos.`, el tipo de recepción permanece bloqueado y los folios persistidos se muestran separadamente. También reutiliza los filtros `DEP/SDEP/CLS/SCLS/SCLS2/SPH/CYL/ADIC`, la vista por jerarquías y la paginación de 100 artículos de la captura del Encargado.
- Para Jefe y Analista, el resumen superior de una recepción activa muestra la cantidad física persistida y el pendiente proyectado, calculados desde el documento.
- La tabla administrativa de un documento `VALIDADO` debe mostrar todos los artículos activos de la O.C., incluso los que no tuvieron captura física; estos se presentan con cantidad física `0` y su cantidad solicitada como faltante, sin habilitar acciones que requieran `IDREC`.
- Al contabilizar, solo los renglones con cantidad física mayor que cero generan movimiento; los renglones en cero permanecen visibles en el registro. Después de una contabilización exitosa, el documento queda `CONTABILIZADO`.
- Durante la captura de una O.C. `PROCESADO`, el resumen superior de Encargado y Jefe no muestra `Recibido acumulado`: presenta cantidad física, pendiente e importe de recepción calculados desde los controladores actuales y debe reaccionar a editar, seleccionar o limpiar renglones.
- En todas las tablas de resultados del detalle de recepción, sin importar el estatus, la columna `Descripción` debe envolver el texto en líneas adicionales, aumentar dinámicamente la altura del renglón y mostrar el contenido completo sin puntos suspensivos.
- El `Rechazar` administrativo no usa el rechazo definitivo de mercancía: solicita motivo, llama la devolución a sucursal, cierra el detalle y permite que el Encargado retome la O.C. `PROCESADO` desde el borrador reconstruido.

## Planeacion y sugeridos de compra
- Feature: `lib/features/modulos/sugeridos`.
- Ruta: `/#/modulos/sugeridos`.
- Codigo de menu gestion: `DAT_JAA_SUG`.
- Consumir exclusivamente `/sugeridos`; no recrear tablas temporales Access ni consumir consultas legacy locales.
- La primera ventana del modulo debe quedar solo para calculos y no consultar resultados al entrar; el filtro de sucursal visible debe incluir `DF01`, `DF04`, `DF05` y `DF06`.
- El calculo de sugerido se solicita al backend con filtros de sucursal/proveedor/linea de producto/categoria/marca/tipo de producto y la O.C. creada debe permanecer en `ABIERTO`.
- Los resultados deben conservar el orden de columnas del Excel de ejemplo de compra; `Cant Final Compra` es la cantidad operativa para crear la O.C.
- La tabla de resultados debe conservar scroll horizontal y vertical visible porque el resultado replica muchas columnas del Excel.
- No cargar todos los resultados de calculo en una sola respuesta; usar paginacion de 100 registros y controles de pagina en UI.
- La exportacion operativa de O.C. se entrega como CSV descargable compatible con Excel desde el detalle cargado.
- El AppBar de sugeridos no debe mostrar boton de nueva O.C.; ese boton corresponde al modulo `DAT_ORD_COMP`.

## Ordenes de compra
- Feature: `lib/features/modulos/sugeridos/presentation/pages/ordenes_compra_page.dart`.
- Ruta: `/#/modulos/ordenes-compra`.
- Codigo de menu gestion: `DAT_ORD_COMP`.
- Debe listar todas las O.C. consumiendo `/sugeridos`, permitir abrir detalle y mantener boton superior de nueva O.C.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`), habilitar `Cancelar` también en `PROCESADO`; el API debe rechazar la operación si ya existe recepción activa/contabilizada o cantidad recibida.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`) y `ANALISTA DE INVENTARIOS` (`IDROL=9005`), el filtro Estatus de Órdenes de compra oculta únicamente `PARCIAL`; el catálogo y los demás perfiles no se modifican.
- El catálogo debe mostrar `RECHAZADO` al Jefe. En ese estado, la tabla de detalle expone solo `Editar cantidad`: no permite agregar, eliminar ni modificar costo/unidad. El botón `Cancelar` queda habilitado para el Jefe y el API conserva la validación autoritativa.
- En detalle `RECHAZADO`, el Jefe muestra `Devolver a sucursal`; exige motivo, llama `POST /sugeridos/:nped/devolver-sucursal` y cierra al responder. El Encargado volverá a ver la O.C. como `PROCESADO` con cantidades del borrador en cero.
- El filtro de O.C. del Jefe muestra `VALIDADO`. Esas cabeceras deben listarse también en DAT_REC para revisión administrativa; el Encargado sigue limitado exclusivamente a `PROCESADO`.
- Para el Jefe, `Cancelar` también se habilita en `VALIDADO`. La app conserva la confirmación existente y delega al API la comprobación de cantidades recibidas y movimientos; la recepción queda `CANCELADO` y la O.C. debe permanecer consultable como `ANULADO`.

## Merma
- Feature: `lib/features/modulos/merma`.
- La evidencia adjunta en alta/edicion de articulo se comprime antes de generar el data URL; si queda por encima de 500 KB se bloquea y se solicita una imagen mas ligera.

## Transferencias entre sucursales
- Feature: `lib/features/modulos/transferencias`.
- Ruta: `/#/modulos/transferencias`.
- Detalle: `/#/modulos/transferencias/:doc`.
- Reportes: `/#/modulos/transferencias-reportes` y detalle `/#/modulos/transferencias-reportes/:doc`.
- Codigo de menu gestion: `DAT_JAA_TRAN`; codigo de menu reportes: `DAT_REP_TRAN`.
- Consumir exclusivamente `/transferencias` del backend; no usar tablas o endpoints legacy de traspasos.
- `Enviar a autorizacion` debe pedir confirmacion, cerrar el detalle al completar y refrescar la cola de notificaciones; el jefe de inventarios ve las pendientes como nueva solicitud de la sucursal solicitante.
- En detalle, `JEFE DE INVENTARIOS` debe ver `Cantidad liberada` y `Total liberada`; su columna de acciones solo edita `CTD_LIB`, dejando que backend calcule `CTOLIB`.
- `Liberar` debe cerrar el detalle al completar. La campana cuenta solo notificaciones no vistas y conserva las vistas entre ejecuciones; `LIBERADA` se presenta como mercancia por surtir para la sucursal origen/surtidora.
- La sucursal origen/surtidora debe ver una tabla reducida en `LIBERADA`/`PREPARACION` y capturar evidencia por renglon solo en `PREPARACION`.
- `Enviar a transito` debe confirmar, bloquear si algun renglon no tiene evidencia y cerrar el detalle al completar paqueteria. El PDF de envio debe ser carta y contener articulo, descripcion, cantidad solicitada, total, cantidad liberada y total liberada.
- En recepcion (`TRANSITO`) la columna de acciones/opciones no debe mostrar botones por renglon.
- `REVISANDO` solo debe listarse/notificarse a la sucursal solicitante. Abrir el detalle debe marcar la notificacion como vista para persistirlo entre ejecuciones.
- En `REVISANDO`, antes de `Contabilizar` debe mostrarse filtro local por SUC, ART/UPC/DES, DEPA, SUBD, CLAS, SCLA, SCLA2, SPH, CYL y ADIC.
- En `REVISANDO`, la tabla no debe mostrar existencias origen/destino, debe mostrar evidencia antes de acciones, y acciones por renglon debe editar cantidad recibida y estatus por articulo limitado a `CONTABILIZADO` o `INCIDENCIA`.
- `Contabilizar` debe confirmar, registrar salida/entrada MB51 mediante backend y cerrar el detalle al completar correctamente.
- `AUXILIAR DE INVENTARIOS` y `ENCARGADO DE SUCURSAL` no deben mostrar filtros de estatus ni usuario en el listado.
- `DAT_REP_TRAN` es solo para `JEFE DE INVENTARIOS`: no muestra campana ni acciones, inicia sin resultados hasta filtrar, incluye filtro de estatus sin `INCIDENCIA`, lista todos los estatus permitidos por el reporte y marca con color los documentos que tengan algun renglon con `ESTATUS_R=INCIDENCIA`.

## Reglas
- Mantener capas `data`, `domain`, `providers`, `presentation`.
- `DEV_PROVD` usa `lib/features/modulos/devoluciones_proveedor` y `/modulos/devoluciones-proveedor`; conservar Riverpod, Dio y go_router, sin arquitectura paralela.
- Mostrar creación/captura solo en `BORRADOR`; solicitud en `BORRADOR`; autorización/rechazo en `PENDIENTE`; consolidación solo para documentos `AUTORIZADA`.
- La devolución usa una sola evidencia de documento de hasta 500 KB. Las reglas críticas de disponibilidad, reserva y movimiento 102 permanecen en API/SP.
- En filtros DEV_PROVD, Proveedor replica Órdenes de compra con `ID - nombre` y orden numérico. Estatus presenta `NO ACEPTADA` para `RECHAZADA`; `RECIBIDA` es un estado real posterior a `EN_TRANSITO`.
- En Acciones del listado DEV_PROVD, el ojo solo visualiza. Antes de Autorizar, Rechazar, En tránsito, Recibida o Cancelar se requiere confirmación; Rechazar captura primero el motivo. Cancelar permanece habilitado salvo durante procesamiento.
- El AppBar DEV_PROVD muestra Envíos consolidados; Registrar salida debe confirmar antes de llamar el endpoint y cerrar el panel al completarse.
- En el diálogo Nueva devolución, Sucursal se limita a `DF01/DF04/DF05/DF06`, Proveedor conserva `ID - nombre` y orden numérico del filtro principal, no se captura O.C. y la recepción es opcional para permitir devoluciones manuales. Observaciones es opcional.
- En detalle DEV_PROVD no editable, omitir Autorizar/contabilizar, Rechazar y la columna Acciones. Solo BORRADOR conserva captura, edición/eliminación y envío a autorización.
- El alta de artículos DEV_PROVD parte de la O.C. o recepción seleccionada. En recepción, cada checkbox persiste o retira el detalle; cantidad y motivo pertenecen al renglón, mientras la fotografía es única para el documento. Enviar a autorización se habilita con al menos un detalle y conserva solo los seleccionados.
- Tras elegir artículo, usar diálogo compacto sin Observaciones; conservar únicamente resumen del artículo, Cantidad, Motivo, Lote, Caducidad y fotografía.
- El listado DEV_PROVD usa tabla y controles de paginación de Órdenes de compra; omite la columna Consolidar, muestra como Artículos el conteo de renglones y mantiene una acción explícita para abrir detalle.
- En el listado DEV_PROVD, presentar solo el consecutivo posterior al último guion y conservar el documento completo para API/rutas. Permitir selección múltiple persistente entre páginas; el icono Imprimir permanece visible, deshabilitado sin selección, y abre `Printing.layoutPdf` con un solo PDF carta horizontal donde cada documento comienza en hoja nueva; no descargarlo directamente.
- En el AppBar del detalle DEV_PROVD, también después de crear, presentar `Devolución a Proveedor` seguido únicamente del folio posterior al último guion; conservar siempre la clave completa para providers, rutas y API.
- Después de crear DEV_PROVD, cargar el documento origen desde `/sugeridos/:nped` o `/recepciones/documentos/:docrec`, mostrar todos sus renglones en tabla y quitar el buscador general de artículos. Cada renglón puede abrir Capturar artículo con el artículo precargado.
- La importación Excel de DEV_PROVD requiere encabezados `ART`, `DESC` y `CTDA`; validar los tres valores por fila y exigir `CTDA` numérica mayor a cero.
- En la tabla DEV_PROVD sin documento origen, Acciones presenta Editar y Eliminar como iconos directos y elimina la opción independiente de evidencia por artículo. Al importar Excel sin costo, omitir `costo` para que el backend tome `DAT_ART.CTOP` y recalcule importes y resumen.
- El listado DEV_PROVD incluye Fecha exacta con calendario y formato `YYYY-MM-DD`; se envía como rango `from/to` del mismo día y Limpiar debe restablecerla.
- El PDF de envio se genera desde el documento cargado en UI y debe reflejar origen, destino, guia y cantidades.
- El PDF de devolución a proveedor omite UPC en la tabla de artículos y muestra únicamente la descripción del motivo, sin su clave.
- No exponer captura de articulos fuera de `BORRADOR`; cantidades liberadas solo en `PENDIENTE`; cantidades recibidas solo en `TRANSITO`.
- El detalle DEV_PROVD presenta artículos en tabla horizontal con ART, UPC, Descripción, Motivo, Cantidad, Disponible, Costo, Importe, Lote, Caducidad, Evidencia y Acciones.
- En borrador DEV_PROVD, Acciones muestra iconos directos Editar y Eliminar; el diálogo Editar mide 520x330, precarga cantidad, motivo, lote y caducidad, y no permite agregar ni reemplazar evidencia por artículo.

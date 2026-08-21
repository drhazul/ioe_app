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
- El detalle del Encargado usa borrador persistente, checkbox como primera columna, selección total y paginación de 100. La tabla es adaptable y no muestra Recibido acum., Cantidad aceptada ni Estatus; Acciones captura únicamente Cantidad física, calcula internamente la aceptada con el mismo valor y conserva `APROBADO` como dato técnico. El diálogo final bloquea el tipo de recepción calculado, permite varios folios, acepta letras/números/signos en Guías de envío y muestra Paquetería antes de Observaciones. No se reintroducen recepción masiva ni Pos. para ese rol.
- En la captura para Jefe/Analista, usar el mismo resumen compacto y alineado a la izquierda del Encargado, colocar el formulario documental antes de la tabla y no mostrar `Recepción masiva` ni `Completar recepción física`. Esto no modifica las acciones de autorización/rechazo de documentos `VALIDADO`.
- Si la O.C. tiene una recepción activa, no mostrar captura vacía: cargar el documento persistido, presentar estado de recepción y datos documentales antes de la tabla, y usar una tabla adaptable sin `Pos.` basada en el detalle histórico guardado.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`) y `ANALISTA DE INVENTARIOS` (`IDROL=9005`), ocultar Cantidad aceptada, Estatus y Productos no solicitados, mostrar Faltantes y Sobrantes derivados de `REC_INCI_PED`, y etiquetar la autorización final como `Contabilizar`.
- La cola de Jefe y Analista conserva O.C. `PROCESADO/PARCIAL/VALIDADO/RECHAZADO` según la etapa administrativa. Debe reutilizar el diseño de captura del Encargado y cambiar la acción principal a `Contabilizar`, encadenando creación, validación y contabilización. En O.C. `PARCIAL`, si existe recepción previa `CONTABILIZADO`, reutilizar y mostrar antes de la tabla tipo de recepción, documento, folio, guías y observaciones; no abrir otra vez el diálogo documental al contabilizar. Solo solicitar esos datos cuando no exista captura previa.
- El botón `Contabilizar` de Jefe y Analista debe confirmar antes de llamar a autorización y cerrar el detalle únicamente cuando el backend responda correctamente. Después debe abrir Histórico filtrado por la O.C. para mostrar el documento `CONTABILIZADO`; no confundirlo con `Estado O.C.`, que puede seguir `PARCIAL` por faltantes.
- En captura DAT_REC, los filtros jerárquicos deben reutilizar `/jrqdepa`, `/jrqsubd`, `/jrqclas`, `/jrqscla` y `/jrqscla2`; cada nivel y `SPH/CYL/ADIC` puede aplicarse individualmente, mientras la cascada es solo una ayuda para acotar opciones. La vista agrupada usa la ruta jerárquica completa y no debe alterar selecciones ni cantidades al alternar con la vista por artículos. Mantener el bloque de botones alineado a la izquierda.
- `Rechazar mercancía` es exclusivo del Encargado en la captura, requiere motivo y envía todos los renglones pendientes con tipo `RECHAZO`; tras guardar debe cerrar la vista. Los documentos `RECHAZADO` no reaparecen para el Encargado y Jefe/Analista los abren en consulta.
- En `VALIDADO`, solo el Jefe (`IDROL=2`) muestra edición documental y columna `Acciones` para costo; el tipo de recepción permanece bloqueado y los folios persistidos se muestran separadamente.
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
- El PDF de envio se genera desde el documento cargado en UI y debe reflejar origen, destino, guia y cantidades.
- No exponer captura de articulos fuera de `BORRADOR`; cantidades liberadas solo en `PENDIENTE`; cantidades recibidas solo en `TRANSITO`.

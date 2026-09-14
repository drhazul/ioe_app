# Inventarios App

## Devoluciones a proveedor DEV_PROVD (2026-08-28)

- Feature `lib/features/modulos/devoluciones_proveedor`; rutas `/modulos/devoluciones-proveedor` y detalle `/:doc`.
- El módulo crea borradores, captura artículos/motivos/evidencias, reserva al solicitar y permite autorizar, rechazar o cancelar exclusivamente al Jefe de Inventarios.
- Las autorizadas del mismo proveedor pueden seleccionarse y consolidarse con transportista, guía, cajas y RMA; la vista de envíos registra la salida física.
- La UI informa que `DAT_ART.STOCK` se afecta únicamente al autorizar y consume `/devoluciones-proveedor` como fuente autoritativa.
- En el listado, Proveedor sigue el selector de Órdenes de compra (`ID - nombre`, orden numérico) y Estatus muestra `BORRADOR`, `AUTORIZADA`, `NO ACEPTADA`, `EN TRANSITO`, `RECIBIDA`, `PENDIENTE` y `CANCELADA`.
- Nueva devolución permite únicamente `DF01`, `DF04`, `DF05` y `DF06`; su proveedor replica el filtro principal. Crear exige exactamente una O.C. o recepción de mercancía, y Observaciones es opcional.
- El detalle no editable es solo lectura: omite Autorizar/contabilizar, Rechazar y la columna Acciones. En BORRADOR conserva captura, edición y eliminación de artículos.
- Después de crear, el detalle carga la O.C. o recepción seleccionada y muestra todos sus artículos en tabla con solicitada, recibida, pendiente y costo. Cada renglón abre la captura obligatoria de cantidad, motivo y fotografía, con lote/caducidad opcionales; no se muestra el buscador general.
- El botón Importar Excel acepta archivos cuya primera fila contiene `ART`, `DESC` y `CTDA`; valida que artículo y descripción tengan valor y que la cantidad sea numérica mayor a cero.
- La columna Acciones muestra iconos directos para editar y eliminar el artículo y ya no ofrece agregar evidencia por artículo. Las filas importadas toman el costo maestro desde el backend, actualizando importe total de la fila y del resumen superior.
- Para una devolución por recepción, seleccionar un checkbox crea el detalle y deseleccionarlo lo retira; cantidad e importe superiores se refrescan, autorización se habilita con al menos un seleccionado y la evidencia se conserva una sola vez por documento.
- El panel de captura seleccionado es compacto y omite Observaciones.
- Los botones operativos del listado solicitan confirmación antes de ejecutar; Rechazar primero captura el motivo y luego presenta la confirmación final. El ojo únicamente abre el detalle.
- El AppBar de DEV_PROVD abre Envíos consolidados; desde el panel se registra con confirmación la salida de envíos `CONSOLIDADO`.
- El listado DEV_PROVD muestra únicamente el consecutivo visible del documento y conserva la clave completa internamente. La columna Seleccionar admite varias devoluciones, incluso entre páginas, y habilita el icono permanente de impresión del AppBar; se abre un solo PDF carta horizontal y cada documento empieza en una hoja nueva.
- Al crear una devolución o abrir su detalle, el AppBar muestra `Devolución a Proveedor` seguido del folio consecutivo; el prefijo `DEV-sucursal-` permanece en la clave interna requerida por rutas y API.
- El filtro Fecha consulta un día exacto mediante calendario y se restablece con Limpiar.

## Recepción de mercancías DAT_REC (2026-08-11)

- Feature `lib/features/modulos/recepciones` y rutas `/modulos/recepciones` y `/modulos/recepciones/:nped`.
- La pantalla incluye pedidos pendientes, captura total/parcial/con diferencias, documento, guía, calidad por renglón, histórico e indicadores.
- `DAT_REC`, `RECEPCION_MERCANCIAS` y `RECEPCIONES` resuelven al módulo. Los campos financieros solo se muestran cuando la API los entrega.
- La recepción física muestra explícitamente que no afecta existencias hasta la autorización administrativa.
- Pedidos pendientes inicia sin resultados: exige filtrar por O.C., proveedor, fecha o sucursal y limita las sucursales operativas a `DF01`, `DF04`, `DF05` y `DF06`.
- Proveedor se selecciona desde un dropdown ordenado por ID numérico, igual que en Órdenes de compra, y `Limpiar filtros` restablece todos los criterios y vuelve a ocultar los resultados.
- Histórico inicia sin resultados y exige filtrar por Documento, proveedor, fecha o sucursal, sin filtro de estatus. El filtro de O.C. se presenta como `Documento` para Encargado de sucursal, Jefe de inventarios y Analista de inventarios. Indicadores conserva el filtro de sucursal y permite limpiarlo.
- `ENCARGADO DE SUCURSAL` (`IDROL=13008`) solo ve Pedidos pendientes de su sucursal asignada cuyo estado de O.C. sea `PROCESADO`; no se muestran órdenes `PARCIAL`, el selector de sucursal ni las pestañas Histórico e Indicadores.
- Al guardar la recepción, el Encargado sale automáticamente del detalle; el documento termina en `VALIDADO`, desaparece de su listado y queda disponible para Jefe o Analista de Inventarios.
- En el detalle para Encargado de sucursal, el resumen es compacto y alineado a la izquierda, se oculta recepción masiva y la tabla adaptable inicia con checkbox por artículo seguido de `Pos.`; omite Recibido acum., Cantidad aceptada y Estatus. `Acciones` permite capturar únicamente Cantidad física; Cantidad aceptada se calcula internamente con el mismo valor y el estado técnico se envía como aprobado. `Seleccionar todo` activa o limpia la selección completa. Tras confirmar, la ventana documental muestra bloqueado el tipo de recepción calculado y captura Documento, uno o más folios, Guías de envío alfanuméricas con signos, Paquetería y Observaciones. La captura se autoguarda como borrador y pagina 100 filas.
- En la captura para Jefe o Analista de Inventarios, el resumen también usa la presentación compacta y alineada del Encargado. Los datos documentales se muestran antes de la tabla y no se presentan los botones `Recepción masiva` ni `Completar recepción física`; la revisión de documentos `VALIDADO` conserva sus acciones administrativas.
- Al abrir una O.C. con recepción activa, el detalle carga el documento guardado y muestra su estado real, tipo de recepción, tipo de documento, folio, guías y observaciones antes de una tabla adaptable sin columna `Pos.`. La tabla usa las cantidades y el estatus persistidos en `REC_CTO_HIST`.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`) y `ANALISTA DE INVENTARIOS` (`IDROL=9005`), la tabla del documento oculta Cantidad aceptada, Estatus y Productos no solicitados, muestra las cantidades de incidencias `FALTANTE` y `SOBRANTE`, y presenta su acción administrativa principal como `Contabilizar`.
- Jefe y Analista conservan en Pedidos pendientes las O.C. `PROCESADO/PARCIAL/VALIDADO/RECHAZADO` conforme a la etapa administrativa. Usan el mismo diseño de captura del Encargado (selección, tabla y edición de cantidad física). Desde una O.C. `PROCESADO`, la acción del Jefe se llama `Validar recepción`: crea y valida el documento, cierra el detalle y lo deja pendiente de contabilización; no registra movimientos de inventario. El Analista conserva la creación, validación y contabilización inmediata. Para una O.C. `PARCIAL` con recepción previa contabilizada, tipo de recepción, documento, folio, guías y observaciones se reutilizan y muestran en modo lectura antes de la tabla. Cuando no existen datos previos, sí se solicita su captura.
- Al reabrir un documento `VALIDADO`, `Contabilizar` solicita confirmación a Jefe y Analista; después de una respuesta exitosa registra los movimientos, cierra automáticamente el detalle y abre Histórico filtrado por la O.C. para mostrar la recepción `CONTABILIZADO`. Pedidos pendientes etiqueta por separado `Estado O.C.`, que puede permanecer `PARCIAL` si existen faltantes.
- La captura permite filtrar los artículos por la jerarquía usada en Mermas (`DEP`, `SDEP`, `CLS`, `SCLS`, `SCLS2`, `SPH`, `CYL`, `ADIC`) usando uno o varios criterios sin tener que completar todos los niveles. La cascada solo ayuda a acotar catálogos. `Vista por jerarquías` agrupa la O.C. por la ruta descriptiva completa y muestra número de artículos, solicitado, pendiente, cantidad física y, para roles autorizados, importe; se puede regresar a `Vista por artículos` sin perder la captura. Las acciones se mantienen alineadas a la izquierda.
- Para el Encargado, `Rechazar mercancía` exige confirmación y motivo, marca toda la recepción como rechazo, cierra el detalle al guardar y la retira de su cola. El documento `RECHAZADO` queda disponible en la cola administrativa de Jefe/Analista con acción de consulta.
- En documentos `VALIDADO`, el Jefe de Inventarios visualiza cada folio en un bloque independiente y puede editar Documento, folios, Guía, Paquetería y Observaciones sin modificar el tipo de recepción. La tabla incluye `Pos.` y agrega `Acciones` exclusivamente para editar el costo unitario; la cantidad física validada permanece en modo lectura. También permite filtrar por jerarquía y alternar entre vista por artículos/jerarquías con paginación de 100. El resumen superior de Jefe y Analista toma la cantidad física del documento activo y recalcula el pendiente proyectado.
- En la revisión `VALIDADO`, la tabla combina la recepción con el detalle completo de la O.C.; los artículos no capturados permanecen visibles con cantidad física cero y faltante igual a lo solicitado. Al contabilizar, únicamente los renglones con cantidad física mayor que cero generan movimiento y, al concluir correctamente, el documento cambia a `CONTABILIZADO`.
- En una O.C. `PROCESADO`, el resumen de captura para Encargado y Jefe reemplaza `Recibido acumulado` por `Cantidad física`; `Pendiente` e `Importe recepción` se recalculan localmente al editar cantidades, seleccionar todo o limpiar la selección.
- La columna `Descripción` de las tablas del detalle utiliza altura adaptable y varias líneas en cualquier estatus, de modo que el texto completo se muestre sin puntos suspensivos.
- Para revisión administrativa, `Rechazar` exige motivo y devuelve la recepción al Encargado: el documento queda histórico como `DEVUELTO`, la O.C. regresa a `PROCESADO`, se reconstruye el borrador con cantidades y datos capturados y el detalle del Jefe se cierra.

## Planeacion y sugeridos de compra (2026-07-10)
- Nueva feature `lib/features/modulos/sugeridos` para calcular sugeridos y crear O.C. sobre `DAT_JAA_SUG`.
- Ruta registrada: `/modulos/sugeridos`; Home resuelve `DAT_JAA_SUG`, `SUGERIDOS_COMPRA` y `PLANEACION_COMPRAS` hacia esa pantalla.
- La pantalla inicial no consulta resultados al entrar y queda dedicada a calculos; el filtro de sucursal muestra `DF01`, `DF04`, `DF05` y `DF06`, permite filtrar por proveedor, linea de producto, categoria, marca y tipo de producto, calcular sugerido, seleccionar articulos, crear O.C. en `REC_CAB_PED/REC_DET_PED` y exportar el detalle a CSV compatible con Excel.
- La tabla de resultados de calculo sigue las columnas del ejemplo `Ejercicio de Compra para modulo Inventarios.xlsx`: jerarquia larga, articulo, UPC, descripcion, base, graduaciones, stock, minimos, reabasto, venta 3 meses, factores, sugerido, pedido, unidad y cantidad final de compra.
- La grilla de resultados usa scroll interno horizontal/vertical para navegar todas las columnas del ejercicio sin perder el panel de acciones.
- Los resultados del calculo se solicitan al backend paginados de 100 en 100; los botones de pagina cambian la consulta y evitan cargar todos los articulos de golpe.

## Ordenes de compra (2026-07-16)
- Nueva pantalla `lib/features/modulos/sugeridos/presentation/pages/ordenes_compra_page.dart` para el modulo `DAT_ORD_COMP`.
- Ruta registrada: `/modulos/ordenes-compra`; Home resuelve `DAT_ORD_COMP`, `ORDENES_COMPRA` y `ORD_COMPRA` hacia esa pantalla.
- Muestra todas las O.C. desde `/sugeridos`, con filtros por sucursal, estatus, fecha y busqueda; el AppBar incluye el boton de nueva O.C. que abre el flujo de sugeridos/calculo.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`), la acción `Cancelar` permanece habilitada después de autorizar mientras la O.C. esté `PROCESADO` y todavía no tenga recepción ni cantidades recibidas.
- Una recepción histórica `DEVUELTO`, `RECHAZADO` o `CANCELADO` sin cantidades recibidas ni movimientos no bloquea la cancelación de una O.C. `PROCESADO`; al cancelar se descarta su borrador y la O.C. queda `ANULADO`. Los errores de esta acción muestran el mensaje funcional del API, no el texto técnico de Dio.
- Para Jefe de Inventarios (`IDROL=2`) y Analista de Inventarios (`IDROL=9005`), el selector de estatus de Órdenes de compra no muestra la opción `PARCIAL`; las demás opciones permanecen sin cambios.
- Las recepciones rechazadas se reflejan como O.C. `RECHAZADO`. El Jefe puede filtrarlas, cancelar la orden o editar únicamente `Cantidad` desde el detalle; la UI no habilita alta, eliminación ni otros cambios de renglón.
- El selector de estatus para el Jefe incluye `VALIDADO`; al seleccionarlo muestra O.C. con recepción validada y pendiente de contabilización, sin alterar la restricción `PROCESADO` del Encargado.
- El Jefe puede cancelar una O.C. `VALIDADO` desde el listado. La acción solicita confirmación y solo concluye cuando el API determina que no hay recepción contabilizada ni movimientos; después la O.C. sigue visible y filtrable como `ANULADO`.
- El Jefe puede usar `Devolver a sucursal` sobre una O.C. rechazada. Después de confirmar el motivo, el detalle se cierra y la orden reaparece como `PROCESADO` para el Encargado, quien debe recapturar las cantidades físicas.
- El AppBar del modulo `DAT_JAA_SUG` queda sin boton de nueva O.C.; la creacion desde sugeridos se mantiene en los controles de resultados seleccionados.

## Merma (2026-06-12)
- La evidencia de articulo en `MermaAddItemDialog` se comprime a JPEG cuando es necesario y debe quedar en 500 KB o menos antes de enviarse como data URL.
- Si una imagen sigue siendo demasiado pesada despues de comprimirla, la UI muestra un mensaje y evita enviar un payload que provoque `request entity too large`.

## Transferencias entre sucursales (2026-06-09)
- Nueva feature `lib/features/modulos/transferencias` con gestion y detalle operativo.
- Rutas registradas en `lib/core/router.dart`: `/modulos/transferencias` y `/modulos/transferencias/:doc`.
- Home resuelve `DAT_JAA_TRAN`, `TRANSFERENCIAS` y `TRASPASOS_SUC` hacia el modulo operativo; `DAT_REP_TRAN` navega a `/modulos/transferencias-reportes`.
- La pantalla inicia sin consultar resultados hasta capturar al menos un filtro. Permite filtrar por documento, usuario y fecha; abrir notificaciones, crear solicitud, agregar articulos, enviar a autorizacion, liberar/rechazar, preparar, enviar a transito, recibir, contabilizar y generar PDF de envio.
- Para `AUXILIAR DE INVENTARIOS` y `ENCARGADO DE SUCURSAL` se ocultan los filtros de sucursal y usuario en el listado.
- El boton de nueva solicitud muestra confirmacion antes de abrir el formulario.
- El boton `Enviar a autorizacion` muestra confirmacion; al confirmar y ejecutar correctamente regresa al listado. La campana usa `/transferencias/notificaciones`, cuenta solo notificaciones no vistas y conserva las vistas entre ejecuciones; para `JEFE DE INVENTARIOS` las pendientes se muestran como nueva solicitud de la sucursal solicitante.
- En nueva solicitud, `Sucursal origen` solo muestra `DF01`, `DF04`, `DF05`, `DF06`, `DF14` y `DF16`, excluyendo la sucursal solicitante. Para `JEFE DE INVENTARIOS`, `Sucursal solicita` muestra ese mismo catalogo base.
- En seleccion de articulos, el dialogo incluye filtros por SUC, ART/UPC/DES, DEPA, SUBD, CLAS, SCLA, SCLA2, SPH, CYL y ADIC; al seleccionar un articulo se captura la cantidad a pedir.
- Cuando el usuario pertenece a la sucursal solicitante del documento, el detalle oculta PDF de envio y las columnas `Liberada`, `Recibida` y `Dif`; en BORRADOR puede editar solo la cantidad solicitada.
- Para `JEFE DE INVENTARIOS`, el detalle muestra `Cantidad liberada` y `Total liberada`; en acciones solo permite editar la cantidad liberada y el total se toma de `CTOLIB`.
- Al presionar `Liberar`, el detalle se cierra al completar y el documento `LIBERADA` aparece en notificaciones de la sucursal origen/surtidora como mercancia por surtir.
- Para la sucursal origen/surtidora, el detalle en `LIBERADA`/`PREPARACION` muestra vista reducida (`ART`, `Descripcion`, `Liberada`, `Total liberada`, `Evidencia`, `Acciones`); en `PREPARACION` puede adjuntar evidencia fotografica por renglon.
- `Enviar a transito` pide confirmacion, exige evidencia en todos los renglones y al terminar la captura de paqueteria cierra el detalle; las imagenes deben ser mayores a 500 bytes y no exceder 500 KB. El PDF de envio usa tamano carta y muestra articulo, descripcion, cantidad solicitada, total, cantidad liberada y total liberada.
- En recepcion (`TRANSITO`) la columna de acciones/opciones queda sin botones por renglon.
- Los documentos `REVISANDO` solo aparecen a la sucursal solicitante, tambien en notificaciones. Al abrir el detalle se marca la notificacion como vista para que no vuelva a contar al reiniciar.
- En `REVISANDO`, la sucursal solicitante ve filtros locales por SUC, ART/UPC/DES, DEPA, SUBD, CLAS, SCLA, SCLA2, SPH, CYL y ADIC antes de `Contabilizar`.
- En `REVISANDO`, la tabla de recepcion muestra cantidades/totales solicitados, liberados y recibidos, diferencias, estatus y evidencia por articulo, sin columnas de existencias; acciones permite editar cantidad recibida y estatus `CONTABILIZADO` o `INCIDENCIA`.
- `Contabilizar` solicita confirmacion, ejecuta el registro MB51 de salida en sucursal origen y entrada en sucursal solicitante mediante backend, y cierra el detalle al terminar correctamente.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`) se muestra nueva solicitud, se oculta estatus y la consulta queda limitada a pendientes.
- Para `AUXILIAR DE INVENTARIOS` (`IDROL=14008`) y `ENCARGADO DE SUCURSAL` (`IDROL=13008`) se ocultan los filtros de estatus y usuario.
- Reportes `DAT_REP_TRAN` (solo jefe de inventarios): la pantalla no consulta hasta capturar filtro, agrega filtro de estatus sin opcion `INCIDENCIA`, no muestra notificaciones ni acciones operativas, abre detalle de solo lectura y resalta documentos con algun articulo en incidencia.
- En DEV_PROVD, los artículos del documento se presentan en tabla horizontal con ART, UPC, descripción, motivo, cantidad, disponible, costo, importe, lote, caducidad, evidencia y acciones.
- En DEV_PROVD, Editar artículo usa un panel compacto 520x330, precarga cantidad, motivo, lote y caducidad, y omite por completo la captura o reemplazo de fotografía por artículo.
- En Nueva devolución DEV_PROVD no se muestra el campo O.C.; la recepción queda opcional para distinguir devoluciones por recepción de devoluciones manuales.
- En el PDF DEV_PROVD, la tabla omite UPC y Motivo contiene solo la descripción, sin la clave `DEV-xx`.

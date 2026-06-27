# Inventarios App

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
- En nueva solicitud, `Sucursal origen` solo muestra `DF01`, `DF04`, `DF05` y `DF06`, excluyendo la sucursal solicitante.
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
- Para `JEFE DE INVENTARIOS` (`IDROL=2`) se oculta nueva solicitud, se oculta estatus y la consulta queda limitada a pendientes.
- Para `AUXILIAR DE INVENTARIOS` (`IDROL=14008`) y `ENCARGADO DE SUCURSAL` (`IDROL=13008`) se ocultan los filtros de estatus y usuario.
- Reportes `DAT_REP_TRAN` (solo jefe de inventarios): la pantalla no consulta hasta capturar filtro, agrega filtro de estatus sin opcion `INCIDENCIA`, no muestra notificaciones ni acciones operativas, abre detalle de solo lectura y resalta documentos con algun articulo en incidencia.

# Instrucciones de agente para Inventarios App

## Alcance
- Features Flutter bajo `lib/features/modulos` relacionadas con inventarios: catalogo, inventarios, MB51/MB52, merma, transferencias y sugeridos.

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

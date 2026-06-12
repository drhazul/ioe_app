# Inventarios App

## Merma (2026-06-12)
- La evidencia de articulo en `MermaAddItemDialog` se comprime a JPEG cuando es necesario y debe quedar en 500 KB o menos antes de enviarse como data URL.
- Si una imagen sigue siendo demasiado pesada despues de comprimirla, la UI muestra un mensaje y evita enviar un payload que provoque `request entity too large`.

## Transferencias entre sucursales (2026-06-09)
- Nueva feature `lib/features/modulos/transferencias` con gestion y detalle operativo.
- Rutas registradas en `lib/core/router.dart`: `/modulos/transferencias` y `/modulos/transferencias/:doc`.
- Home resuelve `DAT_JAA_TRAN`, `TRANSFERENCIAS` y `TRASPASOS_SUC` hacia el modulo.
- La pantalla inicia sin consultar resultados hasta capturar al menos un filtro. Permite filtrar por documento, usuario y fecha; abrir notificaciones, crear solicitud, agregar articulos, enviar a autorizacion, liberar/rechazar, preparar, enviar a transito, recibir, contabilizar y generar PDF de envio.
- En nueva solicitud, `Sucursal origen` solo muestra sucursales de transferencia permitidas distintas a la sucursal solicitante.
- En seleccion de articulos, el dialogo incluye filtros por SUC, ART/UPC/DES, DEPA, SUBD, CLAS, SCLA, SCLA2, SPH, CYL y ADIC; al seleccionar un articulo se captura la cantidad a pedir.
- Para `JEFE DE INVENTARIOS` (`IDROL=2`) se oculta nueva solicitud, se oculta estatus y la consulta queda limitada a pendientes.
- Para `AUXILIAR DE INVENTARIOS` (`IDROL=14008`) y `ENCARGADO DE SUCURSAL` (`IDROL=13008`) se mantiene el filtro de estatus con opciones limitadas a `BORRADOR`, `PREPARACION`, `TRANSITO` y `REVISANDO`.

# Instrucciones de agente para Inventarios App

## Alcance
- Features Flutter bajo `lib/features/modulos` relacionadas con inventarios: catalogo, inventarios, MB51/MB52, merma y transferencias.

## Merma
- Feature: `lib/features/modulos/merma`.
- La evidencia adjunta en alta/edicion de articulo se comprime antes de generar el data URL; si queda por encima de 500 KB se bloquea y se solicita una imagen mas ligera.

## Transferencias entre sucursales
- Feature: `lib/features/modulos/transferencias`.
- Ruta: `/#/modulos/transferencias`.
- Detalle: `/#/modulos/transferencias/:doc`.
- Codigo de menu: `DAT_JAA_TRAN`.
- Consumir exclusivamente `/transferencias` del backend; no usar tablas o endpoints legacy de traspasos.

## Reglas
- Mantener capas `data`, `domain`, `providers`, `presentation`.
- El PDF de envio se genera desde el documento cargado en UI y debe reflejar origen, destino, guia y cantidades.
- No exponer captura de articulos fuera de `BORRADOR`; cantidades liberadas solo en `PENDIENTE`; cantidades recibidas solo en `TRANSITO`.

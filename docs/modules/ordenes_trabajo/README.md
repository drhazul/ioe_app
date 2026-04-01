# Ordenes de trabajo (front)

Navega a otros README/AGENTS solo cuando la tarea lo exija.

Enlaces relacionados:
- README principal del frontend: `README.md`
- AGENTS de este módulo: `docs/modules/ordenes_trabajo/AGENTS.md`
- Módulos vinculados: `docs/modules/base_modulos/README.md`, `docs/modules/punto_venta/README.md`, `docs/modules/core_seguridad/README.md`

## Ordenes de Trabajo (nuevo flujo 2026-03-22)

- Ruta:
- `/taller/ordenes-trabajo`
- Archivos frontend:
- `lib/features/modulos/taller/ordenes_trabajo/ordenes_trabajo_page.dart`
- `lib/features/modulos/taller/ordenes_trabajo/ordenes_trabajo_api.dart`
- `lib/features/modulos/taller/ordenes_trabajo/ordenes_trabajo_models.dart`
- `lib/features/modulos/taller/ordenes_trabajo/ordenes_trabajo_providers.dart`
- Integración de navegación:
- `lib/core/router.dart` registra `/taller/ordenes-trabajo`.
- `lib/features/home/home_page.dart` resuelve códigos de módulo de taller (`DAT_JAO_ORD` y compatibles) hacia la nueva ruta.
- Endpoints consumidos:
- `GET /ordenes-trabajo`
- `GET /ordenes-trabajo/:iord`
- `GET /ordenes-trabajo/:iord/detalle`
- `POST /ordenes-trabajo/:iord/autorizar|enviar|recibir|entregar|garantia|cambio-material|merma`
- `POST /ordenes-trabajo/enviar/validar`
- `POST /ordenes-trabajo/enviar/lote`
- `GET /ordenes-trabajo/asignar/colaboradores`
- `POST /ordenes-trabajo/asignar/validar`
- `POST /ordenes-trabajo/asignar/lote`
- `POST /ordenes-trabajo/trabajo-terminado/validar`
- `POST /ordenes-trabajo/trabajo-terminado/lote`
- `POST /ordenes-trabajo/regresar-incidencia/validar`
- `POST /ordenes-trabajo/regresar-incidencia/lote` (`tipom` requerido desde catálogo `DAT_ORD_TMOV`)
- `POST /ordenes-trabajo/regresar-tienda/validar`
- `POST /ordenes-trabajo/regresar-tienda/lote`
- `POST /ordenes-trabajo/asignar-laboratorio/lote`
- `POST /ordenes-trabajo/recibir/validar`
- `POST /ordenes-trabajo/recibir/lote`
- `POST /ordenes-trabajo/entregar/validar`
- `POST /ordenes-trabajo/entregar/lote`
- `POST /ordenes-trabajo/scan/recibir`
- `POST /ordenes-trabajo/scan/entregar`
- Reglas UI:
- filtros server-side con paginación y selección local en pantalla (sin flags persistidos en DB).
- barra de acciones por ORD seleccionada para flujo operativo completo.
- AppBar operativo compacto para reducir altura y ahorrar espacio en pantalla.
- detalle ORD/etiquetas (2026-03-30): el popup ordena siempre `OD/OI/ADD`, bloquea `JOB`, y `Imprimir etiqueta` primero guarda `laboratorio/comentarios/detalle` antes de abrir la impresión.
- detalle ORD/roles (2026-03-30): el selector `TIPO` (`TALLADO`/`BISELADO`) se muestra antes de `Laboratorio` y solo es visible para `admin`, `JEF_TALLER`, `ANALISTA_ORD` y `ANALISTA`; el botón `Imprimir etiqueta` usa la misma restricción.
- panel ORD UI (2026-03-24): la botonera principal sale del encabezado visible y se abre desde un popup `Opciones de Trabajo` en el AppBar.
- panel ORD UI (2026-03-24): `Configuracion de Vista` se mueve al AppBar del lado derecho; el bloque de filtros conserva solo criterios y acciones de consulta.
- panel ORD UI (2026-03-24): los botones del AppBar (`Opciones de Trabajo`, `Configuracion de Vista` y refrescar) usan fondo blanco para contrastar con el AppBar.
- panel ORD UI (2026-03-24): se elimina del card de filtros el label de selección de ORDs y el contador/paginador se integra en la misma banda de criterios, alineado a la derecha cuando hay ancho suficiente.
- panel ORD UI (2026-03-30): el filtro `Cliente` consulta coincidencias sobre `CLIEN` y `NCLIENTE` mediante el mismo criterio server-side.
- panel ORD UI (2026-03-30): las acciones del popup `Opciones de Trabajo` conservan la selección local mientras las ORDs sigan visibles después del refresh.
- panel ORD UI (2026-03-30): el modal de detalle y la etiqueta legado fuerzan el orden `OD`, `OI`, `ADD` en la matriz `JOB/ESF/CIL/EJE`; `JOB` queda sin foco/edición y el bloque completo se renderiza con tipografía reforzada en negritas.
- panel ORD UI (2026-03-30): el modal `DETALLE DE ORDEN DE TRABAJO` incorpora botón `Imprimir etiqueta` para roles con permiso `IMPRIMIR_ETIQUETA`.
- panel ORD UI/Home (2026-03-24): `HomePage` agrega accesos directos a `Enviar`, `Asignar`, `Regresar a tienda`, `Recibir` y `Entregar`; cada tarjeta solo se muestra cuando `GET /ordenes-trabajo` expone el permiso correspondiente en `allowedActions`.
- panel ORD UI/Home (2026-03-24): `router.dart` registra rutas directas `/taller/ordenes-trabajo/enviar|asignar|regresar-tienda|recibir|entregar` hacia páginas adicionales standalone (`ordenes_trabajo_action_page.dart`) que no muestran el panel principal ni redirigen a él.
- panel ORD UI/Home (2026-03-24): las páginas standalone replican la mecánica de los popups del panel (`captura/escaneo`, validación de estado, lista relacionada, confirmación y cambio de `ESTSEGU`) y el panel principal conserva intactos sus botones y mensajes emergentes.
- panel ORD UI/Home (2026-03-24): la página directa de `Entregar` agrega captura de firma digital del cliente y procesa las ORDs relacionadas una por una con `POST /ordenes-trabajo/:iord/entregar`, reutilizando el mismo contrato API sin cambios backend ni SP adicional.
- matriz botones ORD (2026-03-24): `JEF_TALLER/TALLER` conserva flujo completo e impresión; `ANALISTA_ORD/ANALISTA` ve `Ver detalle`, `Autorizar`, `Enviar`, `Asignar laboratorio`, `Entregar` e `Imprimir etiqueta`; `ENC_MAQUILA/ENCARGADO_MAQUILA/ENC_BISEL/ENCARGADO_BISELADO` ve `Ver detalle`, `Asignar`, `Trabajo terminado`, `Regresar incidencia`, `Regresar a tienda` y `Recibir`.
- etiqueta ORD legado (2026-03-24): `Imprimir etiqueta` genera una página por ORD seleccionada con tamaño fijo `76mm x 51mm`, reutilizando `ticket_ords_legacy_layout.dart`.
- escaneo con captura manual (lector físico por Enter) y opción de cámara (`mobile_scanner`) para recepción/entrega.
- `detalle` de cabecera/renglones disponible desde panel para trazabilidad rápida.
- `Enviar` permanece habilitado sin selección: abre modal para digitar o escanear ORD, valida estatus `3 (NUEVA AUTORIZADA)` y agrega relación persistente en appstate (campos no editables, con eliminación por renglón).
- en el modal de envío se elimina botón `Agregar ORD`; la captura manual agrega la ORD al presionar `Enter` en el campo `ORD`.
- el modal de envío incluye `Cancelar` (limpia appstate y cierra), `Cerrar` (conserva appstate y cierra) y `Enviar` (confirma cambio a `ESTSEGU=5`, ejecuta lote, limpia appstate y refresca panel).
- cuando existen renglones seleccionados en grilla, el botón cambia a `ENVIAR Seleccionados`, solicita confirmación del cambio a `ESTSEGU=5` y ejecuta el envío por lote.
- `Scan recibir` y `Scan entregar` usan el mismo patrón modal de `Enviar` (captura/escaneo, lista relacionada en appstate, eliminar renglón, `Cancelar/Cerrar/Enviar`).
- `Scan recibir` valida estado previo `ESTSEGU=5` y confirma transición por lote a `ESTSEGU=7`.
- `Scan entregar` valida estado previo `ESTSEGU=10` y confirma transición por lote a `ESTSEGU=11`.
- el flujo de recepción elimina selección de destino (`TALLER/ANALISTA`) y unifica operación desde `Scan recibir`.
- `Asignar` usa modal equivalente a `Enviar`: valida `ESTSEGU=7`, permite seleccionar colaborador (`PV_OPV.IDOPV`, etiqueta `NOMB+APELM+APELP`, `NIVEL=41`, misma sucursal) y confirma cambio a `ESTSEGU=8`.
- `Trabajo terminado` usa modal equivalente: valida `ESTSEGU=8` y confirma cambio a `ESTSEGU=9`.
- `Regresar incidencia` usa modal equivalente: valida `ESTSEGU=9`, obliga seleccionar motivo desde `DAT_ORD_TMOV` y confirma cambio a `ESTSEGU=9.1` persistiendo `PV_CTR_ORDS.TIPOM`.
- `Regresar a tienda` usa modal equivalente: valida `ESTSEGU=9` y confirma cambio a `ESTSEGU=10`.
- `Asignar laboratorio` permite selección masiva en grilla para actualizar `LABOR` sobre ORDs de la misma sucursal.
- la columna `Asignado` del panel muestra el nombre legible del colaborador (`NOMB + APELM + APELP`) en vez del `IDOPV`.
- `Cambio material` y `Merma` ya no viven en el toolbar del panel operativo: se muestran dentro del modal de detalle únicamente cuando la ORD está en flujo `9.1` y según `TIPOM` (`1` muestra `Cambio material`, `2` muestra `Merma`).
- `Garantia` deja de mostrarse en el panel operativo y queda reservada para el panel de entregadas con estado `11`.


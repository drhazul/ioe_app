# IOE App

Aplicacion Flutter del sistema IOE. Este frontend consume `ioe-api` y cubre
autenticacion, datos maestros, inventarios, control de cuentas y punto de venta.

## Planteamiento funcional
- Centralizar operacion administrativa (maestros y permisos) y operativa
  (inventarios, catalogos, cotizaciones y consultas).
- Mantener una capa de UI desacoplada de persistencia, usando contratos HTTP
  definidos por `ioe-api`.
- Garantizar navegacion protegida por sesion JWT con renovacion de token.

## Arquitectura
- Enfoque feature-based en `lib/features`.
- Estado con Riverpod.
- Enrutamiento con go_router y guard en `lib/core/router.dart`.
- Cliente HTTP con Dio en `lib/core/dio_provider.dart`.
- Sesion y tokens en `lib/core/auth/auth_controller.dart` y `lib/core/storage.dart`.
- Configuracion de conexion en `lib/core/env.dart`.

## Estructura del proyecto
- `lib/main.dart`: bootstrap, carga de `.env` en release, health check `/health`.
- `lib/core/`: auth, router, env, cliente Dio, storage y utilidades compartidas.
- `lib/features/home/`: carga de menu por perfil.
- `lib/features/login/`: pantalla de login.
- `lib/features/masterdata/`: roles, deptos, puestos, usuarios, sucursales,
  datmodulos, accesos, `usr-mod-suc`, `cat-ctas`, `dat_form`.
- `lib/features/modulos/`: inventarios, captura, catalogo `datart`, MB51, MB52,
  control de cuentas, taller (ordenes de trabajo) y punto de venta.
- `assets/`: `assets/.env`.
- `test/`: pruebas de widget.

## Modulos, endpoints y datos (app -> api -> tablas)
- Home:
- `GET /access/me/front-menu`.
- tablas: `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Auth:
- `POST /auth/login`, `POST /auth/refresh`.
- Primer acceso (2026-03): cuando el JWT trae `mustChangePassword=true`, la app redirige a `/auth/change-password` y bloquea navegación hasta completar `POST /auth/change-password`.
- tablas: `USUARIO`, `USUARIO_TOKEN`.
- Maestros:
- `/roles` -> `ROL` (`IDROL`, `CODIGO`, `NOMBRE`, `ACTIVO`).
- `/deptos` -> `DEPARTAMENTO` (`IDDEPTO`, `NOMBRE`, `ACTIVO`).
- `/puestos` -> `PUESTO` (`IDPUESTO`, `IDDEPTO`, `NOMBRE`, `ACTIVO`).
- `/users` -> `USUARIO` (`IDUSUARIO`, `USERNAME`, `IDROL`, `IDDEPTO`, `IDPUESTO`, `SUC`, `ESTATUS`).
- UI maestros usuarios: el formulario valida `USERNAME` con minimo 3 caracteres antes de `POST /users`.
- UI maestros usuarios (2026-03): en alta se genera contraseña temporal aleatoria de 6 dígitos, con botón para regenerar y mostrar/ocultar contraseña.
- UI maestros usuarios (2026-03): el formulario permite controlar `FORZAR_CAMBIO_PASS` para exigir cambio de contraseña en el próximo acceso.
- UI maestros usuarios (2026-03): el listado soporta visualización agrupada por sucursal o departamento y filtros por ambas dimensiones.
- `/datmodulos` -> `MOD_FRONT` (`CODIGO`, `NOMBRE`, `DEPTO`, `ACTIVO`).
- `/usr-mod-suc` -> `USR_MOD_SUC` (`MODULO`, `USUARIO`, `SUC`, `ACTIVO`).
- `/cat-ctas` -> `DAT_CAT_CTAS` (`CTA`, `DCTA`, `RELACION`, `SUC`).
- `/access/*` -> `MODULO`, `GRUP_MODULO`, `GRUPMOD_MODULO`, `ROL_GRUP_MODULO_PERM`,
  `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Inventarios:
- `/conteos`, `/conteos/:cont/upload-items`, `/conteos/:cont/process`,
  `/conteos/:cont/apply-adjustment`, `/conteos/:cont/sync-capturas`,
  `/conteos/:cont/det`, `/conteos/:cont/summary`.
- `/capturas`, `/capturas/conteos-disponibles`, `/capturas/summary`.
- tablas: `DAT_CONT_CTRL`, `DAT_DET_SVR`, `DAT_CONT_CAPTURA`, `USR_MOD_SUC`.
- campos clave: `CONT`, `SUC`, `ESTA`, `TIPOCONT`, `TOTAL_ITEMS`, `EXT`,
  `ALMACEN`, `CANT`, `CAPTURA_UUID`.
- Catalogo articulos:
- `/datart`, `/datart/:suc/:art/:upc`, `/datart/massive-upload`,
  `/articulos/alta-masiva/upload|preview|validate|commit`.
- tablas: `DAT_ART`, `DAT_ART_MASIVA_TMP`.
- Impresion etiquetas DAT_ART (frontend):
- pantalla `lib/features/modulos/catalogo/datart_page.dart` con seleccion local por renglón y seleccion de filtrados para impresión masiva.
- imprime una etiqueta por artículo en PDF (`76mm x 56mm`) con vista previa de impresión/selección de impresora.
- el `EAN13` se construye tomando solo los 12 dígitos derechos de `UPC` (si excede) y calculando dígito verificador.
- campos de etiqueta: sucursal, artículo, fecha de impresión, descripción, ubicación física (`UMUE`, `UTRA`, `UNIV`) y código de barras.
- MB51/MB52:
- `/dat-mb51/search`, `/dat-mb52/resumen`, `/dat-almacen`, `/dat-cmov`.
- tablas/fuentes: `DAT_MB51`, `DAT_ART`, `DAT_ALMACEN`, `DAT_CMOV`.
- compatibilidad backend MB51 (2026-03): el script `ioe-api/sql/mb51transmicion.sql` habilita `MB51PROCES`/`ANULADO` en homologación de `ESTA`, conserva `TRANSMITIR` para PS y define `sp_mb51_transmitir_folio` para MB51 + stock sin cambiar endpoints/payload consumidos por app.
- Control de cuentas:
- `/ctrl-ctas/config`, `/ctrl-ctas/catalog/ctas`, `/ctrl-ctas/catalog/clientes`,
  `/ctrl-ctas/catalog/opvs`, `/ctrl-ctas/consulta/resumen-cliente`,
  `/ctrl-ctas/consulta/resumen-transaccion`, `/ctrl-ctas/consulta/detalle`.
- fuentes: `DAT_CTRL_CTAS`, `DAT_CAT_CTAS`, `FACT_CLIENT_SHP`, `PV_OPV`, `USR_MOD_SUC`.
- Compatibilidad histórica (2026-03): backend ejecuta SQL directo para `/ctrl-ctas/consulta/*`, normaliza `FCND`, completa faltantes de fecha con `1900-01-01` y `2100-12-31`, e incluye filas legacy con `SUC` nulo/vacío cuando hay filtro por sucursal.
- Regla UI de exportacion (pantalla `Resumen por Deudor`):
- se habilita exportar si hay exactamente una CTA en criterios, o si el usuario selecciona un CLIENT.
- si CTA esta en `Todas` o multiples CTA, exportar permanece deshabilitado hasta seleccionar un CLIENT.
- El AppBar de resumen muestra el detalle de CTA(s) activas tomadas de criterios.
- Si hay CTA unica y no se selecciona CLIENT, el archivo exporta `RESUMEN_TRANS` y `DETALLE` para todos los CLIENT que cumplan esa CTA.
- La carga de `DETALLE` para exportacion se ejecuta por cliente y por bloques de `IDFOL` para reducir fallas de red por demasiadas llamadas simultaneas.
- Durante exportacion se muestra una ventana emergente de progreso (no cerrable) y se cierra automaticamente al terminar o fallar.
- En la vista de resumen, el filtro `!= 0` inicia desactivado por defecto (cliente, transaccion y detalle) para mostrar todos los registros; puede activarse desde la barra de controles de cada panel.
- Punto de venta:
- `/factclientshp` -> `FACT_CLIENT_SHP`.
- Facturación `/facturacion/*` -> `FAC_SVR_SHAP`, `FACT_TICKET_SHP`, `FACT_CLIENT_SHP`, `DAT_SUC`.
- Facturación mantenimiento de clientes `/facturacion/mtto-clientes` (`FACTURA_MTTOCLIENTE`): panel sincronizado por sucursal con dropdown de filtro, búsqueda por nombre/RFC/IDC y formulario embebido que recalcula data fiscal (`UsoCfdi`, `RegimenFiscal`) y respeta las sucursales autorizadas por `USR_MOD_SUC`.
- Facturación compat (2026-03-13): la UI consume `IDFOL` como texto (no `int`) y codifica el parámetro de ruta; backend tolera esquemas `FAC_SVR_SHAP` legacy sin columna `AUT` (fallback `TIPOVTA`/`NULL`) para evitar `500` en `/facturacion/pendientes`.
- Facturación pendientes paginada (2026-03-13): la UI consume `GET /facturacion/pendientes` con `page`, `pageSize`, `suc`, `estatus`, `razonSocialReceptor`, `rfcReceptor`, `clien`, `idFol`, `tipoFact`.
- Facturación pendientes paginada (2026-03-13): filtros y orden por `FCN` se aplican en backend sobre todo el dataset; la UI muestra contador absoluto de registros y navegación entre páginas.
- Facturación filtros UI (2026-03-13): los criterios se aplican de forma manual con botón `APLICAR FILTROS`; `LIMPIAR FILTROS` restablece criterios, página y consulta.
- Facturación tabla UI (2026-03-15): la grilla principal incluye barra de scroll horizontal visible para recorrer todas las columnas y se ajustó la alineación encabezado/valor para evitar desfase visual.
- Facturación tabla UI (2026-03-15): la columna `IMPT` se muestra con formato monetario fijo a 2 decimales.
- Facturación tabla UI (2026-03-15): se agrega separación entre celdas/encabezados para evitar que los títulos se vean pegados (`IMPT` vs `F. Pago`) al desplazar horizontal.
- Facturación configuración visual (2026-03-15): la pantalla agrega botón `Configurar` que abre modal para ajustar escala global y tamaños de fuente por componente (AppBar, títulos, labels, body, botones, header/celda de tabla).
- Facturación anchos persistentes (2026-03-15): el modal permite ajustar ancho por columna y separación entre campos; los valores se guardan en `SharedPreferences` (cache local del navegador en web).
- Facturación resize directo (2026-03-15): el encabezado de la grilla incorpora separadores arrastrables entre columnas para redimensionar en vivo y persistir al soltar.
- Facturación validar detalle (2026-03-14): al seleccionar un folio y presionar `Validar`, la UI abre un modal emergente `Vista detalle factura` con artículos del folio (`IDFOL`, `UPC`, `Descripcion`, `ClaveProdServ`, `Unidad`, `Cantidad`, `ValorUnitario`, `PVTAT`, `Impuesto`, `Total`) y `Total factura`.
- Facturación validar importes (2026-03-14): el modal muestra `Cabecera`, `Detalle` y `Diferencia` con redondeo a 2 decimales para depurar descuadres por precisión.
- Facturación conciliación de centavos (2026-03-15): backend alinea `IMPT` de cabecera contra el total derivado de `FACT_TICKET_SHP` durante sincronización VF, por lo que nuevos folios en facturación deben mostrarse sin diferencia de centavos en el modal de validación.
- Facturación prevención CFDI40108 (2026-03-23): el modal de validación muestra estado `Subtotal SAT` y, cuando backend reporta `requiereAjusteSubtotalSat`, informa que en `emitir` se aplica ajuste de redondeo SAT para evitar error de timbrado en folios `PENDIENTE`.
- Facturación filtro por error (2026-03-27): la pantalla respeta el valor seleccionado en `ESTATUS` y permite consultar `PENDIENTE`, `CANCELACION PENDIENTE`, `FACTURADO`, `FACTURADO Y CANCELACION PENDIENTE` y `CON ERROR` contra `GET /facturacion/pendientes`.
- Facturación nomenclatura CFDI (2026-03-27): el backend controla la visual `RFC4-00001`; Facturify recibe `serie=RFC4` y `folio` entero puro, por lo que la app no recompone año/mes/día ni reinicia consecutivo localmente.
- Facturación unificación sucursal JWT (2026-03-16): backend dejó de forzar `user.suc` en `preview/create` de unificación para usuarios con permisos de gestión (`FACTURA`/compat), evitando bloqueos falsos de "folios fuera de la sucursal autorizada".
- REQF sin facturar (2026-03-16): la pantalla `/facturacion-sreqf` (módulo `REG_SINREQF`) consulta `GET /facturacion/reqf/folios`; backend aplica alcance no-admin por `USR_MOD_SUC` y frontend no fija `SUC` inicial por JWT para permitir ver todas las sucursales autorizadas.
- Panel clientes UI (2026-03): en alta de cliente, el modal usa valores predeterminados `SELECCIONAR` para `RfcEmisor`/`RegimenFiscalReceptor`/`UsoCfdi` (en payload `RegimenFiscalReceptor=0` por tipo numérico) y `COLOCAR` para `EmailReceptor`; incluye botón `CANCELAR` y, después de `Guardar registro`, cierra el modal y refresca la consulta del panel.
- `/pvctrfolasvr` -> `PV_CTR_FOL_ASVR`.
- `/pv/devoluciones/*` -> `PV_CTR_FOL_ASVR`, `PV_DEV_DET_TMP`, `PV_TICKET_LOG`, `PV_CTR_FOL_FORM(_SVR)`, `PV_CTR_ORDS`, `FAC_SVR_SHAP`, `FACT_IDFOLDEV`, `DAT_CTRL_CTAS`.
- `/ps/*` -> `PV_CTR_FOL_ASVR`, `PV_TICKET_LOG`, `PV_CTR_FOL_FORM`, `DAT_CTRL_CTAS`, `PV_DAT_PS`, `DAT_REF_GTO`.
- `/retiros/*` -> `DAT_RET_CTR_SVR`, `DAT_RET_DET_SVR`, `DAT_RET_DET_EFEC_SVR`, `VW_PV_FORM_TIPOTRAN_DISTINCT`.
- PS pago UI (2026-03): en `/ps/:idFol/pago` el alta de forma se hace por modal desde el bloque de `Formas de pago`; las formas se mantienen en appstate local y solo se persisten al finalizar pago.
- PS pago UI (2026-03): el modal de formas de pago excluye `CREDITO` y `DEUDOR`; para formas no `EFECTIVO` la referencia es solo lectura y se asigna reutilizando `ref_detalle_page.dart` de cotizaciones.
- `/pvticketlog` -> `PV_TICKET_LOG`.
- `/pvctrords` -> `PV_CTR_ORDS`, `PV_CTR_ORDS_DET`.
- `/ordenes-trabajo/*` -> `PV_CTR_ORDS`, `PV_CTR_ORDS_DET`, `DAT_EST_ORD`, `DAT_MB51`, `DAT_CTRL_CTAS`.
- `/refdetalle` -> `REF_DETALLE`.
- `/pv/refdetalle` -> `REF_DETALLE` (crear/asignar/eliminar referencias ligadas al folio).
- `/dat-form` -> `DAT_FORM` (CRUD de catalogo de formas de pago con estado activo/inactivo).
- `/jrqdepa|jrqsubd|jrqclas|jrqscla|jrqscla2|jrqguia` ->
  `JRQ_DEPA`, `JRQ_SUBD`, `JRQ_CLAS`, `JRQ_SCLA`, `JRQ_SCLA2`, `JRQ_GUIA`.

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

## Estado de Cajón OPV (nuevo flujo 2026-03)

- Ruta:
- `/estado-cajon`
- Archivos frontend:
- `lib/features/modulos/estado_cajon/app/estado_cajon_page.dart`
- `lib/features/modulos/estado_cajon/app/estado_cajon_api.dart`
- `lib/features/modulos/estado_cajon/app/estado_cajon_models.dart`
- `lib/features/modulos/estado_cajon/app/estado_cajon_providers.dart`
- Integración de navegación:
- `lib/core/router.dart` registra `/estado-cajon`.
- `lib/features/home/home_page.dart` mapea módulo/código hacia `/estado-cajon`.
- `lib/features/modulos/punto_venta/punto_venta_home_page.dart` expone card `Estado de cajon`.
- Endpoints usados:
- `POST /cajon-estado/autorizar`
- `GET /cajon-estado/resumen?fecha=YYYY-MM-DD`
- Flujo UI:
- al entrar, la pantalla solicita autorización de supervisor (password).
- si autoriza, consulta resumen por fecha del día (o fecha elegida) y no muestra botón manual de reautorización.
- renderiza tabla por forma con columnas `FORM | IMPT | IMPR | IMPE | DIFD`.
- `IMPE` se muestra como `-` cuando llega `null`.
- pie de tabla calcula totales de `IMPT`, `IMPR` y `DIFD`.
- usa provider de fecha (`estadoCajonFechaProvider`) y provider async de resumen (`estadoCajonResumenProvider`).
- al salir de `/estado-cajon`, la sesión de autorización se limpia y al reingresar vuelve a pedir contraseña.
- aplica mounted-checks después de `await` (`if (!mounted) return;`) en flujo de diálogo/autorización.

## Pago de Servicios (nuevo flujo 2026-03)

- Rutas:
- `/ps` (panel)
- `/ps/:idFol` (detalle)
- `/ps/:idFol/pago` (pago/cierre + salida)
- Archivos frontend:
- `lib/features/modulos/pagos_servicios/ps_panel_page.dart`
- `lib/features/modulos/pagos_servicios/ps_detalle_page.dart`
- `lib/features/modulos/pagos_servicios/ps_pago_page.dart`
- `lib/features/modulos/pagos_servicios/ps_api.dart`
- `lib/features/modulos/pagos_servicios/ps_models.dart`
- `lib/features/modulos/pagos_servicios/ps_providers.dart`
- Providers:
- `psFoliosProvider`
- `psDetalleProvider(idFol)`
- `psAdeudosProvider(client)`
- `psPagoSummaryProvider(idFol)`
- `psFormasPagoProvider(idFol)`
- `psSelectedArtProvider`
- Endpoints usados:
- `GET /ps/folios`, `POST /ps/folios`, `GET /ps/folios/:idFol`
- `PUT /ps/folios/:idFol/cliente`
- `POST /ps/folios/:idFol/ticket/service`
- `GET /ps/clientes/:client/adeudos`
- `GET /ps/clientes/:client/adeudos/:idFol/detalle`
- `POST /ps/folios/:idFol/ticket/reference/folio`
- `POST /ps/folios/:idFol/ticket/reference/gasto`
- `PUT /ps/folios/:idFol/ticket/pvta`
- `DELETE /ps/folios/:idFol/ticket/line`
- `POST /ps/folios/:idFol/procesar`
- `POST /ps/folios/:idFol/formas-pago`
- `DELETE /ps/folios/:idFol/formas-pago/:idF`
- `GET /ps/folios/:idFol/formas-pago/summary`
- `POST /ps/folios/:idFol/finalizar`
- `PATCH /pvctrfolasvr/:idfol`
- Reglas UI:
- flujo panel -> detalle -> pago, con captura de `PVTA` por línea y asignación de referencia por `ART` seleccionado.
- botón `Seleccione Cliente` abre modal y actualiza cliente del folio por `PUT /ps/folios/:idFol/cliente`; queda bloqueado cuando el ticket ya tiene líneas.
- `Seleccione Cliente` usa `GET /factclientshp` con filtro local por `header.suc`; en modo admin multi-sucursal el backend no debe limitar la lista a `user.suc`.
- en detalle, el backend valida `PVTA` por adeudo usando `DAT_CTRL_CTAS` (misma fuente de adeudos) y no permite captura sin `ORD`.
- en detalle, el resumen de adeudos usa `DAT_CTRL_CTAS` agrupado por `CLIENT + IDFOL` con filtro `SUM(IMPT) <> 0`.
- en detalle, `Procesar servicio` se movió al AppBar.
- en detalle, al agregar servicios `AD/AP/CR` se exige cliente seleccionado (`CLIEN != 1`); si no, la UI bloquea el alta y muestra `Seleccione Cliente`.
- en detalle, el backend valida la misma regla (`AD/AP/CR` con `CLIEN > 1`) y rechaza API directa con `Seleccione Cliente`.
- en detalle, cuando `ESTA IN ('PAGADO','TRANSMITIR')` se bloquea toda la pantalla (sin edición/selección), quedando activos solo `Procesar servicio` y el regreso del AppBar.
- en detalle/adeudos, cada renglón incluye botón `Ver registros` para abrir un popup tabular (listado por columnas) con todos los movimientos de `DAT_CTRL_CTAS` del `IDFOL` seleccionado.
- en pago, la vista usa dos contenedores (resumen y formas); el botón `Agregar` está dentro de `Formas de pago` y abre modal emergente para capturar `Forma/Importe/Autorización`.
- el modal de formas PS usa catálogo dinámico `DAT_FORM` (`GET /dat-form`) y la regla de referencia igual a cotizaciones (`TARJETA/CHEQUE/TRANSFERENCIA/DEPOSITO 3RO`).
- en pago, el dropdown del modal no muestra `CREDITO` ni `DEUDOR`.
- en pago, para formas no `EFECTIVO`, `Autorización/referencia` no es editable y se captura reutilizando `ref_detalle_page.dart` (`Generar/Asignar referencia`).
- en pago, una forma distinta de `EFECTIVO` no puede superar el restante por pagar (`total - pagado`), validado en modal y nuevamente antes de enviar al API.
- en pago, formas distintas de `EFECTIVO` exigen autorización/referencia.
- en pago (2026-03): los botones `Finalizar Pago de servicio` e `Imprimir ticket` se muestran fuera de contenedor y a ancho completo de la página.
- en pago, al cubrir total se habilita `Finalizar Pago de servicio`; este botón envía el lote local a `POST /ps/folios/:idFol/finalizar` para insertar `PV_CTR_FOL_FORM` (`IMPP/IMPC/IMPD/AUT`) y generar `DAT_CTRL_CTAS` antes de fijar `ESTA='PAGADO'`.
- política de fecha de finalización PS (2026-03): backend toma la fecha actual del sistema al finalizar para `PV_CTR_FOL_FORM.FCN`, `PV_CTR_FOL_ASVR.FCNM` y movimientos `DAT_CTRL_CTAS` del cierre.
- en pago, al generar `DAT_CTRL_CTAS`, el backend toma `CLSD` desde `DAT_CMOV.CMOV` filtrando `RELACION=<servicio>` y `TIPO='ABONO'`; si no encuentra mapeo, rechaza el cierre.
- en pago, el AppBar usa flecha mientras no está `PAGADO`; al quedar `PAGADO` (o al abrir un folio `PAGADO` desde panel) cambia a candado y habilita la salida a `TRANSMITIR`.
- en pago, el botón secundario es `Imprimir ticket` (sustituye `Regresar a detalle`).
- en impresión de ticket PS (2026-03): cuando existe al menos una forma distinta de `EFECTIVO`, el PDF agrega al final un bloque `SOPORTE RECEPCION PAGO` (voucher) con `FORM`, `IMPD`, `AUT o REF`, `AUT`, datos de cliente y folio.
- en impresión de ticket PS (2026-03): el voucher agrega espacio en blanco para firma y renglón `Firma cliente` después de `FCN`.
- en impresión de ticket PS (2026-03): el voucher se genera en un segundo PDF; al cerrar la vista previa del ticket principal, la app solicita confirmación y luego abre la vista previa del voucher.
- en impresión de ticket PS (2026-03): se agrega línea de recorte entre `RESUMEN DE ORDS` y `ORDS`; `GRACIAS POR SU CONFIANZA` se imprime después de `RESUMEN DE ORDS` y antes del recorte hacia `ORDS`.
- en impresión de ticket PS (2026-03-04): se retira del PDF el bloque detallado `ORDS` (barcode `CODE39` + tabla `JOB/ESF/CIL/EJE`); se conserva `RESUMEN DE ORDS` y vouchers. El diseño retirado queda respaldado en `lib/features/modulos/taller/etiqueta/ticket_ords_legacy_layout.dart`.
- en impresión de ticket PS (2026-03): se homologó el formato con cotizaciones/devoluciones usando bloques `DETALLE`, `TOTALES`, `FORMAS`, `TRANSACCION`, `RESUMEN DE ORDS`, `ORDS` (barcode `CODE39` + tabla `JOB/ESF/CIL/EJE`) y vouchers para formas no `EFECTIVO`.
- en panel, folios PS en estado `PAGADO` abren directo la página de pago (`/ps/:idFol/pago`).
- compatibilidad backend PS (2026-03): `sql/sp_ps_module_create.sql` crea/siembra `PV_TIPO_ESTA` para resolver alta de servicio cuando faltaba ese catálogo.
- compatibilidad backend PS (2026-03): consulta de adeudos acepta `CLIENT` grande (`BIGINT`) para evitar fallos de conversión por IDs altos.
- detalle PS (2026-03): el panel muestra `Adeudos` solo si el ticket contiene `AD/AP/CR`; muestra `Referencias de gasto` solo si contiene `DG/DC`.
- adeudos PS (2026-03): cuando `adeudosRes` llega vacío, la UI usa `adeudosR` para no ocultar resultados válidos de `DAT_CTRL_CTAS`.
- Referencia de error corregido (2026-03-03): al asignar adeudo en detalle PS se observó `400` con `No existe DAT_CTRL_CTAS_RES para validar referencia de folio`; backend se depuró para resolver la referencia directamente desde `DAT_CTRL_CTAS`.
- Regla vigente (2026-03-03): al usar el mismo adeudo en otra línea del ticket PS, backend devuelve `400` con `La referencia ya fue asignada a otra linea del ticket`.
- Regla origen PS (2026-03-21): la primera referencia ligada en detalle define `ORIGEN_AUT` del folio (`CA`/`VF`); si el ticket aún no tiene referencias, backend permite adoptar ese origen inicial. Cuando ya existen referencias, se conserva el origen y se bloquea la mezcla `CA`/`VF`.
- Corrección backend (2026-03-03): la validación de referencia/importe en PS consolida adeudo por `IDFOL/NDOC + RELACION` antes de validar, evitando falsos `400 La referencia seleccionada no tiene adeudo pendiente` cuando un folio mezcla cargos y abonos en `DAT_CTRL_CTAS`.
- Regla backend AD/AP/CR (2026-03-03): al editar `PVTA`, API bloquea importes por línea mayores a la deuda del folio referenciado y también bloquea sobreaplicación acumulada por `ORD` entre líneas `AD/AP/CR`.
- Referencia de error corregido (2026-03-03): al agregar forma PS se observaba `No existe tabla PV_CTR_FOL_FORMTMP`; backend usa fallback a `PV_CTR_FOL_FORM` y la UI de pago PS usa flujo de formas basado en `DAT_FORM` como cotizaciones.
- Referencia de error corregido (2026-03-03): al abrir detalle PS se observó `400` desde API con `Invalid object name 'dbo.PV_TICKET_LOG_SVR'.`; backend y script SQL se alinearon para usar exclusivamente `dbo.PV_TICKET_LOG`.

## Retiros Parciales (nuevo flujo 2026-03)

- Rutas:
- `/retiros` (panel)
- `/retiros/:idret` (detalle)
- `/retiros/efectivo/:idfor` (denominaciones)
- Archivos frontend:
- `lib/features/modulos/retiros/retiros_panel_page.dart`
- `lib/features/modulos/retiros/retiro_detalle_page.dart`
- `lib/features/modulos/retiros/retiro_efectivo_page.dart`
- `lib/features/modulos/retiros/retiros_api.dart`
- `lib/features/modulos/retiros/retiros_models.dart`
- `lib/features/modulos/retiros/retiros_providers.dart`
- Integración de navegación:
- `lib/core/router.dart` registra las rutas `/retiros/*`.
- `lib/features/home/home_page.dart` mapea códigos/nombres de módulo de retiro hacia `/retiros`.
- `lib/features/modulos/punto_venta/punto_venta_home_page.dart` conecta tarjeta `Retiro parcial` a `/retiros`.
- Endpoints usados:
- `POST /retiros`
- `GET /retiros/today`
- `GET /retiros/:idret`
- `POST /retiros/:idret/detalles`
- `PUT /retiros/detalles/:idfor/efectivo`
- `DELETE /retiros/detalles/:idfor`
- `POST /retiros/:idret/finalize`
- `POST /retiros/:idret/cancel`
- `GET /catalogos/formas-retiro`
- Reglas UI:
- panel muestra retiros del día y permite crear/cancelar retiros `ABIERTO`.
- detalle permite agregar formas (catálogo deduplicado) y finalizar retiro.
- para `EFECTIVO`, la captura de importe se hace por denominaciones y no por `IMPF` directo.
- detalle de efectivo acepta `CTDA` decimal (incluida morralla en denominación `1`) y guarda en batch.

## Reloj Checador (Asistencia)

- Rutas:
- `/reloj-checador/app` (marcaje)
- `/reloj-checador/consultas` (gestion y consulta)
- Archivos frontend:
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_page.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_api.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_models.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_providers.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_page.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_api.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_models.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_providers.dart`
- Flujo App (Marcaje):
- consume `GET /reloj-checador/context` para mostrar ultimo/siguiente marcaje y flags de policy.
- permite checkpoints `ENTRADA`, `SALIDA_COMER`, `REGRESO_COMER`, `SALIDA`.
- consume `POST /reloj-checador/timelog` con `AUTH_METHOD`, `LIVENESS_OK` y GPS cuando la policy lo requiere.
- Flujo Consultas:
- timelogs: filtros y correccion admin (`PUT /reloj-checador/timelog/:id` con reason).
- incidencias: crear/listar/cambiar estatus (`POST/GET/PUT`).
- documentos: subir base64/listar/descargar (`POST/GET/GET download`).
- overrides: crear/listar/revocar (`POST/GET/PUT`).
- policy: lectura/upsert solo admin (`GET/POST /reloj-checador/policy`).
- Integracion Home/Router:
- `lib/core/router.dart` registra rutas del modulo.
- `lib/features/home/home_page.dart` resuelve modulos de asistencia hacia `/reloj-checador/app`.

## Flujo de alta de cotizacion (panel)
- Pantalla: `lib/features/modulos/punto_venta/cotizaciones/cotizaciones_page.dart`.
- Al presionar `Agregar`:
- primero se confirma la creacion de nueva cotizacion.
- si se confirma, se abre modal de busqueda/seleccion de cliente.
- La seleccion de cliente se limita a la sucursal del usuario logueado.
- Compatibilidad admin multi-sucursal (2026-03-21): cuando `admin` cambia `SUC` en panel (cotizaciones/PS), la carga de clientes depende de `GET /factclientshp`; backend reconoce admin por `username='ADMIN'` y/o `ADMIN_ROLE_IDS`/`ADMIN_NIVELES` para no restringir el catálogo a `user.suc`.
- Secuencia API:
- `GET /factclientshp` para cargar clientes y filtrar por SUC.
- `POST /pvctrfolasvr/auto` para crear folio.
- `PATCH /pvctrfolasvr/:idfol` para asignar `CLIEN` al folio creado.
- Correccion de integracion (2026-02): cuando `CLIEN` supera el rango `int32`, backend trata `PV_CTR_FOL_ASVR.CLIEN` como `float` para evitar error `500` al asignar cliente en este flujo.

## Edicion de precio en detalle de cotizacion
- Pantalla: `lib/features/modulos/punto_venta/cotizaciones/detalle_cot/detalle_cot_page.dart`.
- Cabecera de detalle: se ocultan `IDFOLINICIAL`, `AUT`, `ESTA` y `ORIGEN_AUT`; se conserva contexto visible con `Sucursal`, `Cotizacion`, `Fecha`, `Nombre OPV`, `N Cliente` y `Nombre Cliente`.
- Interaccion: doble clic en columna `PVTA` del renglón agregado al ticket.
- Regla de autorizacion:
- usuario `SUPERPV` (supervisor) edita directo precio.
- la UI envia `PATCH /pvticketlog/:id/precio` sin `AUTH_PASSWORD`; backend determina si el solicitante ya es `SUPERPV`.
- si backend responde que requiere autorizacion `SUPERPV` (`403`), la UI solicita contraseña supervisor, la prevalida y reintenta el `PATCH` con `AUTH_PASSWORD`.
- si la contraseña no coincide con un `SUPERPV` activo, no se aplica el cambio de precio.
- Endpoint usado:
- `PATCH /pvticketlog/:id/precio` con `PVTA` y `AUTH_PASSWORD` cuando aplica.
- `POST /pvticketlog/precio/authorize` para validar contraseña `SUPERPV` cuando backend exige autorizacion.
- El flujo actualiza `PVTA/PVTAT` del renglón y mantiene sincronizacion local-remota de la cotizacion.
- Detalle cotización UX (2026-03-10): en el bloque superior se agregó captura rápida por `UPC` (EAN13); la UI sanitiza a dígitos, toma los primeros 12 y busca coincidencia exacta por `SUC` en `DAT_ART` para insertar directo al ticket con `CTD=1` y `PVTA` del artículo.
- Detalle cotización UX (2026-03-10): en la grilla DAT_ART el botón `Agregar` se movió al inicio del renglón.
- Detalle cotización UX (2026-03-10): la columna `DES` en consulta DAT_ART y en detalle de ticket usa texto seleccionable con tooltip para visualizar/copiar la descripción completa.
- Detalle cotización DAT_ART (2026-03-12): el módulo `detalle_cot` consulta artículos con `GET /datart?suc=<SUC>&sucExact=true&bloqNe=-1`; backend aplica `SUC=@SUC` y visibilidad `BLOQ IS NULL OR BLOQ<>-1` (compatibilidad con registros legacy `BLOQ=NULL`).
- Compatibilidad frontend (2026-03-12): si la respuesta con `bloqNe=-1` llega vacía (backend sin ajuste para `BLOQ=NULL`), la app reintenta sin `bloqNe` y aplica filtro local `BLOQ != -1`.

## Flujo de cierre de cotizacion (PV)
- Pantalla: `PagoCotizacionPage` en `lib/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_page.dart`.
- Ruta: `/punto-venta/cotizaciones/:idfol/pago`.
- Ruta secundaria de referencia: `/punto-venta/cotizaciones/:idfol/ref-detalle`.
- Entrada: desde `DetalleCotPage`, con modal previo para elegir tipo de cierre `CA` o `VF`.
- Providers/API del flujo:
- `cotizaciones/pago/pago_cotizacion_providers.dart`
- `cotizaciones/pago/pago_cotizacion_api.dart`
- `cotizaciones/pago/pago_cotizacion_models.dart`
- `cotizaciones/pago/ref_detalle/ref_detalle_providers.dart`
- `cotizaciones/pago/ref_detalle/ref_detalle_api.dart`
- `cotizaciones/pago/ref_detalle/ref_detalle_models.dart`
- La pantalla de pago no renderiza la tarjeta "Contexto del folio"; el contexto se usa internamente para preview/cierre.
- Endpoints backend usados:
- `GET /pv/cotizaciones/:idfol/cierre/context`
- `POST /pv/cotizaciones/:idfol/cierre/preview`
- `GET /pv/cotizaciones/:idfol/cierre/print-preview`
- `POST /pv/cotizaciones/:idfol/cierre`
- `GET /dat-form` (dropdown de formas de pago basado en tabla; por defecto solo activas)
- `GET /dat-form/:idform`, `POST /dat-form`, `PATCH /dat-form/:idform`, `DELETE /dat-form/:idform` (mantenimiento maestro de `DAT_FORM`)
- `GET /pv/refdetalle?idfol=:idfol&tipo=:tipo`
- `POST /pv/refdetalle/crear`
- `POST /pv/refdetalle/asignar`
- `DELETE /pv/refdetalle/:idref`
- Dependencia backend:
- `POST /pv/cotizaciones/:idfol/cierre` se ejecuta en API mediante `dbo.sp_pv_cotizacion_cerrar`.
- backend resuelve el folio de pago por `IDFOL` actual o `IDFOLINICIAL`, para que la UI siga operando cuando el cierre cambia el folio visible de `CP` a `CA/VF`.
- Si el SP no existe en SQL Server, la API devuelve `409` y se debe ejecutar `ioe-api/sql/sp_pv_cotizacion_cerrar_create.sql`.
- Si el SP rechaza el cierre por validacion de negocio, la API devuelve `400/409` con mensaje legible (ya no `500` por abortos de transaccion).
- Reglas UI de formas de pago:
- El dropdown de formas en pago usa `GET /dat-form` (tabla `DAT_FORM`) y respeta `ESTADO` para visibilidad.
- En cierre `CA`, el selector del modal lista `EFECTIVO` y `CREDITO`.
- `CREDITO` no se puede combinar con otras formas de pago en el mismo cierre.
- `Autorizacion / referencia` y el boton `Generar/Asignar referencia` solo aplican para `TARJETA`, `CHEQUE`, `TRANSFERENCIA` y `DEPOSITO 3RO`.
- La referencia no se captura manualmente: se crea/asigna en `REF_DETALLE` y se usa `IDREF` como `aut` de la forma.
- Si existen referencias en `CAPTURADO` o `PROCESADO` que no se usan en el payload final, backend rechaza el cierre hasta eliminarlas.
- Mantenimiento maestro de formas:
- ruta listado: `/masterdata/dat-form`
- rutas formulario: `/masterdata/dat-form/new` y `/masterdata/dat-form/:id`
- archivos: `lib/features/masterdata/dat_form/dat_form_page.dart`, `dat_form_form_page.dart`, `dat_form_providers.dart`, `dat_form_api.dart`, `dat_form_models.dart`.
- Para `CREDITO`/`DEUDOR`, backend guarda la forma en `PV_CTR_FOL_FORM_SVR` (fallback `PV_CTR_FOL_FORM`) con `IMPP` positivo y `AUT=IDFOL`.
- Para `CREDITO`, backend valida disponible usando saldo neto de `DAT_CTRL_CTAS` (`SUM(IMPT)`) con `CTA='101001002'` y `CLIENT=@IDC`; disponible = `FACT_CLIENT_SHP.L_CRED - MAX(-SUM(IMPT), 0)` (cargos negativos consumen crédito y abonos positivos lo liberan).
- Para `CREDITO`/`DEUDOR`, backend inserta cargo en `DAT_CTRL_CTAS` con `CMOV=602`, `CTA='101001002'`, `CLIENT`, `IDFOL`, `NDOC` e `IMPT` negativo.
- Compatibilidad de esquema backend: si `DAT_CTRL_CTAS` no tiene `CMOV`, usa `CLSD`; y cuando existen `FCND`/`RTXT` tambien se llenan en el cargo.
- `NDOC` se genera de forma concurrente en transaccion (sin conteos no seguros), base `N6000001+`.
- compatibilidad backend: el SP de cierre valida `NDOC` con `COL_LENGTH` y SQL dinamico para evitar errores de columna en esquemas legacy.
- Correccion tecnica web: el id temporal de formas se genera con `nextInt(0x100000000)` para evitar `RangeError` al usar `nextInt(1 << 32)` en Flutter Web.
- Con una o mas formas agregadas, la UI bloquea el cambio de `Tipo de cierre` (`CA`/`VF`) hasta que se eliminen todas las formas.
- Ajuste UI adicional: `RQFAC` fue movido al AppBar (junto al selector de tipo de cierre).
- Ajuste UI adicional: el resumen de `Total Caculado por Cotizacion` y `Totales de formas de pago` se presenta en un solo card.
- Ajuste UI adicional: tamanos de labels/importes de resumen se parametrizan en `pago_cotizacion_page.dart` con:
- `_kResumenTituloSize`, `_kResumenLabelSize`, `_kResumenImporteSize`, `_kFormasItemSize`, `_kFormasRefSize`.
- Ajuste UI adicional: se oculto en pantalla el label/valor `IVA integrado sucursal` del resumen.
- Ajuste funcional: cada entrada/reentrada a la pagina de pago vuelve a ejecutar inicializacion y preview para recalcular importes segun `tipotran`, `rqfac` y parametros de IVA backend.
- Persistencia funcional: el switch `RQFAC` guarda inmediatamente en `PV_CTR_FOL_ASVR.REQF` (via `PATCH /pvctrfolasvr/:idfol`) para conservar seleccion al salir/entrar.
- Foliado visible: tras `POST /pv/cotizaciones/:idfol/cierre`, la pantalla adopta el `IDFOL` actual devuelto por backend (`SUC-YYYYMMDD-CA|VF-####`) para AppBar, impresión y salida a `MB51PROCES`; la ruta sigue siendo compatible por `IDFOLINICIAL`.
- Apertura de pago desde detalle: el query `rqfac` se arma desde `GET /pv/cotizaciones/:idfol/cierre/context` para evitar valores stale del folio cargado previamente.
- Validacion UI previa: al finalizar, la app revisa `GET /pv/refdetalle?idfol=:idfol` y bloquea cierre si detecta referencias `CAPTURADO/PROCESADO` no utilizadas.
- Si detecta referencias sin uso en esa validacion previa, la app navega directo a `/punto-venta/cotizaciones/:idfol/ref-detalle` con la referencia encontrada seleccionada para gestionar su uso/eliminacion.
- Validacion UI de importe por forma: al agregar/editar, `impp` no puede exceder el faltante de la cotizacion (`total - sum(formas restantes)`), excepto `EFECTIVO` (puede exceder para cambio).
- Ajuste tecnico: controles `Radio` migrados a `RadioGroup` en dialogos de seleccion (cliente y referencias) para compatibilidad con Flutter >= 3.32.
- Regla funcional CA: cuando `tipotran=CA`, app fuerza `rqfac=false` y persiste `REQF=0` en `PV_CTR_FOL_ASVR` antes del preview para recalcular importes sin factura.
- Al cierre exitoso, backend deja la cotizacion en `PV_CTR_FOL_ASVR.ESTA='PAGADO'` y app no redirige de inmediato.
- Al cierre exitoso, backend ejecuta `dbo.sp_mb51_transmitir_folio` para insertar renglones en `DAT_MB51` y ajustar `DAT_ART.STOCK` por resumen de `ART+SUC`; `ESTA` permanece en `PAGADO`.
- política de fecha de finalización cotización (2026-03): backend registra fecha de proceso actual al cerrar en `PV_CTR_FOL_FORM(_SVR).FCN`, `PV_CTR_FOL_ASVR.FCNM` y movimientos contables de `CREDITO/DEUDOR`.
- En estado `PAGADO`, el boton regresar en pago cambia a icono de candado y, al presionarlo, actualiza `ESTA='MB51PROCES'` para regresar al panel.
- Si una cotizacion en panel tiene `ESTA='PAGADO'`, la seleccion abre directo la pantalla de pago en lugar del detalle.
- El panel de cotizaciones muestra registros con estado `PENDIENTE`, `EDITANDO` y `PAGADO` usando filtro por `ESTA` (sin condicionar por `AUT`); `MB51PROCES` se conserva para salida operativa y ya no aparece en el panel.
- Optimizacion panel (2026-03): la lista de cotizaciones consulta `GET /pvctrfolasvr` con filtros `suc`, `opv` y `search` en backend; la pantalla espera cargar contexto JWT antes de disparar la consulta para evitar carga masiva sin criterios.
- Compatibilidad de consulta (2026-03): la app ya no envia query param `_` en `GET /pvctrfolasvr` para evitar rechazo `400` cuando backend aplica validacion estricta de query.
- Panel cotizaciones UI (2026-03): la tabla usa columnas de ancho dinamico segun contenido y scroll horizontal para mejorar visualizacion de datos largos.
- Panel cotizaciones UI (2026-03): se agregan columnas `CLIEN` y `Razon social receptor`.
- Panel cotizaciones busqueda (2026-03): el input de busqueda permite localizar por `IDFOL`, `CLIEN` y `RazonSocialReceptor`.
- Panel cotizaciones busqueda OPV (2026-03-10): si `Buscar` recibe un valor con formato OPV (4 dígitos), la búsqueda cruzada permite traer folios de otros OPV solo cuando cumplen `AUT='CP'` y `ESTA='PENDIENTE'`.
- Panel cotizaciones seguridad (2026-03): la lista normal conserva filtro estricto por `SUC/OPV`; en búsqueda cruzada (folio/cliente/razón social/OPV) solo se permiten folios de otros OPV con `AUT='CP'` y `ESTA='PENDIENTE'`.
- Paneles PV (2026-03-10): en cotizaciones/devoluciones/pago de servicios, la papelera no elimina físicamente; ahora cambia `ESTA='ANULADO'` por `PATCH /pvctrfolasvr/:idfol` y solo se habilita cuando `ESTA='PENDIENTE'`.
- Paneles PV (2026-03-21): los listados de cotizaciones/devoluciones/pago de servicios excluyen `ESTA='ANULADO'`; se muestran únicamente `PENDIENTE`, `EDITANDO` y `PAGADO`.
- Al cierre exitoso, app habilita un boton `Imprimir ticket` debajo de `Finalizar cierre`.
- Al presionar `Imprimir ticket`, app muestra dialogo de ancho 58mm/80mm y abre la vista previa PDF.
- En ticket de cotización (2026-03), si hay formas no `EFECTIVO`, la impresión agrega al final un voucher `SOPORTE RECEPCION PAGO` por cada forma no efectivo.
- En ticket de cotización (2026-03), el voucher agrega espacio en blanco para firma y renglón `Firma cliente` después de `FCN`.
- En impresión de cotización (2026-03), los vouchers se generan en un segundo PDF; al cerrar la vista previa del ticket principal, la app pide confirmación y luego abre la vista previa del PDF de vouchers con el mismo ancho seleccionado (58/80).
- En ticket de cotización (2026-03), se agrega línea de recorte entre `RESUMEN DE ORDS` y `ORDS`; `GRACIAS POR SU CONFIANZA` se imprime después de `RESUMEN DE ORDS` y antes del recorte hacia `ORDS`.
- En ticket de cotización (2026-03-04), se retira del PDF el bloque detallado `ORDS` (barcode `CODE39` + tabla `JOB/ESF/CIL/EJE`); se conserva `RESUMEN DE ORDS` y vouchers. El diseño retirado queda respaldado en `lib/features/modulos/taller/etiqueta/ticket_ords_legacy_layout.dart`.
- Navegacion de regreso en pago: si no esta finalizada la cotizacion vuelve a detalle; si ya esta finalizada vuelve al panel de cotizaciones.
- PDF de cierre (58/80mm): cabecera sucursal (`DAT_SUC`), detalle de articulos (`PV_TICKET_LOG`), totales+formas+cambio, pie transaccional (`OPV/OPVM`, `IDFOL`, `FCNM`, cliente) y ORDs con `ORD + UPC`, codigo de barras `CODE39` y tabla con bordes del detalle.
- Ajuste visual ticket: se removio el encabezado repetitivo `COTIZACION FINALIZADA` y el `IDFOL` mostrado al inicio.
- Ajuste de maquetacion ticket: se aplica margen izquierdo fijo de `2mm` para ambos formatos (58mm y 80mm).
- Regla ticket para cotizacion abierta (`CA`): en la seccion `TOTALES` solo se muestra `Total base` y se oculta el bloque `FORMAS` (se mantienen TRANSACCION y ORDs).
- Ajuste ORDs en ticket: se removio `EST` y el campo `ART` en cabecera de ORD; por cada ORD se imprime `ORD`, `UPC`, descripcion + `TIPO`, codigo de barras `CODE39` y tabla con bordes (`JOB/ESF/CIL/EJE`) usando `PV_CTR_ORDS_DET`.
- Tabla de detalle ORD en ticket: se quitaron guiones en celdas vacias para mostrar celdas limpias.
- Ajuste ticket: entre `TRANSACCION` y `ORDS` se imprime bloque `RESUMEN DE ORDS` con `ORD`, descripcion y `UPC` por orden.
- Ajuste ticket: en `DETALLE` se agrega `UPC` por producto y alternancia de fondo gris/blanco por renglon.
- Ajuste ticket: cada bloque `ORD` inicia con una linea de recorte e icono de recorte para separar ordenes.
- Ajuste ticket: la altura del PDF se calcula de forma dinamica segun el contenido para evitar hojas extra con espacios vacios; mantiene multihoja cuando el detalle realmente excede una sola hoja.
- Ajuste ticket: `MultiPage` usa margen izquierdo explicito de `2mm` para asegurar desplazamiento real del contenido en 58/80mm.
- Ajuste ticket: en 80mm se recalibro la altura dinamica con estimacion mas conservadora (lineas/tablas/buffer por ORDs) para evitar hoja extra; 58mm queda sin cambios de logica.
- Tablas involucradas en el cierre (via API):
- `PV_CTR_FOL_ASVR` (estado e importe final: `ESTA='PAGADO'` al finalizar y `ESTA='MB51PROCES'` al regresar al panel, `IMPT`, `AUT='CA'|'VF'`)
- `PV_CTR_FOL_ASVR` conserva `IDFOLINICIAL` y cambia `IDFOL` visible al cerrar (`CP -> CA/VF`), mientras backend/UI mantienen compatibilidad por ambos identificadores.
- `PV_TICKET_LOG` (base de calculo `SUM(CTD * PVTA)`)
- `PV_CTR_FOL_FORM` (formas definitivas y cambio; en este flujo backend guarda `IMPD` por forma aplicada: `IMPP-IMPC`, y deja `IMPA=0`)
- `PV_CTR_FOL_FORM_SVR` / `PV_CTR_FOL_FORM` (formas definitivas segun disponibilidad de tabla)
- `PV_CTR_ORDS` (al cierre backend cambia `ESTATUS=2` para el folio)
- `DAT_SUC` (`IVA_INTEGRADO` para regla de total)
- El frontend solo presenta y captura formas; el calculo final y validaciones de negocio son autoritativos en backend.
- Para ORDs creadas desde cotizacion, `PV_CTR_ORDS.CLIEN` se maneja como `FLOAT` para soportar IDs grandes; requiere script `ioe-api/sql/PV_CTR_ORDS_CLIEN_float.sql`.

## Flujo de devoluciones PV
- Rutas UI:
- `/punto-venta/devoluciones`
- `/punto-venta/devoluciones/:idfolDev` (selección de artículos)
- `/punto-venta/devoluciones/:idfolDev/detalle` (detalle devolución)
- `/punto-venta/devoluciones/:idfolDev/pago`
- Archivos frontend:
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_page.dart`
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_api.dart`
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_models.dart`
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_providers.dart`
- `lib/features/modulos/punto_venta/devoluciones/detalle/detalle_devolucion_page.dart`
- `lib/features/modulos/punto_venta/devoluciones/detalle/detalle_devolucion_resumen_page.dart`
- `lib/features/modulos/punto_venta/devoluciones/pago/pago_devolucion_page.dart`
- Endpoints usados:
- `GET /pv/devoluciones`
- `POST /pv/devoluciones/crear`
- `GET /pv/devoluciones/:idfolDev/detalle`
- `POST /pv/devoluciones/:idfolDev/devolver-todo`
- `PATCH /pv/devoluciones/:idfolDev/lineas/:lineId`
- `POST /pv/devoluciones/:idfolDev/detalle/preparar`
- `POST /pv/devoluciones/:idfolDev/pago/preview`
- `POST /pv/devoluciones/:idfolDev/pago/finalizar`
- `GET /pv/devoluciones/:idfolDev/print-preview`
- Reglas UI:
- alta por modal con `IDFOL` origen + contraseña supervisor.
- selección de artículos editable solo en `CTDD`; no hay UI para agregar/eliminar artículos ni editar precio.
- `Devolver TODO` asigna `CTDD=DIFD` para líneas permitidas y respeta bloqueos ORD.
- en selección se oculta la columna `DIFD` y el botón principal cambia a `Ir Detalle devolución`.
- detalle devolución ejecuta `POST /pv/devoluciones/:idfolDev/detalle/preparar` para insertar en `PV_TICKET_LOG` únicamente artículos con `CTDD>0`.
- navegación a pago habilitada desde detalle devolución.
- trazabilidad UI (2026-03): en `/punto-venta/devoluciones/:idfolDev/detalle`, `Ir a pago` se movió al `AppBar` con icono de caja (`Icons.point_of_sale`) y se retiró del bloque de acciones del body.
- trazabilidad UI (2026-03): en la tarjeta de contexto de detalle devolución se ocultaron `AUT dev`, `AUT origen` y `Estado`.
- pago usa preview backend para totales/IVA con `RQFAC` del folio origen (switch visible solo lectura).
- trazabilidad UI (2026-03): en `/punto-venta/devoluciones/:idfolDev/pago`, la tarjeta de contexto oculta `AUT dev`, `AUT origen`, `Tipo` y `Líneas seleccionadas`.
- en pago no se permite agregar, editar ni eliminar formas de pago.
- en pago devolución (2026-03-10): las formas se recargan siempre desde `preview.formasSugeridas` (folio origen) para devolver por el mismo concepto en no efectivo y conservar `aut/ref` para el cierre backend.
- forma devolución = forma origen (2026-03-20): backend valida que devoluciones no `CREDITO/DEUDOR` se finalicen en la misma forma del ticket origen (`EFECTIVO`, `TRANSFERENCIA`, `TARJETA`, `CHEQUE`, `DEPOSITO 3RO`); la UI mantiene formas en solo lectura.
- al finalizar devolución, el folio queda en `ESTA='PAGADO'`.
- al finalizar devolución, backend ejecuta `dbo.sp_mb51_transmitir_folio` para insertar renglones en `DAT_MB51` y ajustar `DAT_ART.STOCK` por resumen de `ART+SUC`; `ESTA` permanece en `PAGADO`.
- facturación devolución VF (2026-03-20): al finalizar `POST /pv/devoluciones/:idfolDev/pago/finalizar`, backend sincroniza facturación del folio origen con `sp_fact_sync_folio_vf` y actualiza `FAC_SVR_SHAP/FACT_TICKET_SHP` según `CTD-CTDDF` (devolución total: `ESTATUS='VTA DEV'`, `IMPT=0`; parcial: disminuye `IMPT`).
- saneamiento DVF facturación (2026-03-20): al cerrar devolución, backend depura cualquier registro residual del folio devolución en `FAC_SVR_SHAP/FACT_TICKET_SHP` para evitar filas no deseadas en facturación.
- respuesta de finalización devolución (2026-03-20): el payload incluye `facturacionSync` y la UI de pago muestra confirmación explícita en snackbar sobre el resultado de sincronización en facturación.
- política de fecha de finalización devolución (2026-03): backend reutiliza una fecha de proceso actual única al cerrar para `FACT_IDFOLDEV` (`FCN/FCNR`), `PV_CTR_FOL_FORM(_SVR).FCN`, `PV_CTR_FOL_ASVR.FCNM`, `PV_TICKET_LOG.UPDATED_AT` y movimientos contables relacionados.
- cuando el folio está en `PAGADO`, el botón regresar cambia a candado; al presionarlo actualiza `ESTA='MB51PROCES'` y vuelve al panel.
- al volver al panel desde pago/candado, frontend invalida el provider del panel y recarga la consulta.
- el panel de devoluciones muestra únicamente estados `PENDIENTE`, `EDITANDO` y `PAGADO`; `MB51PROCES` sigue existiendo para salida operativa, pero queda fuera del panel.
- desde panel, si el folio está en `PAGADO`, la selección abre directo la ruta de pago (sin mostrar selección/detalle).
- desde panel, si el folio no está en `PAGADO` pero ya tiene artículos seleccionados (`linesSelected > 0` o alguna línea con `CTDD > 0`), la selección abre directo `/punto-venta/devoluciones/:idfolDev/detalle`; sin selección previa, abre `/punto-venta/devoluciones/:idfolDev`.
- al finalizar se habilita `Imprimir ticket`; al presionarlo abre selector 58mm/80mm y la vista previa PDF con `GET /pv/devoluciones/:idfolDev/print-preview`.
- En ticket de devolución (2026-03), si hay formas no `EFECTIVO`, la impresión agrega al final un voucher `SOPORTE RECEPCION PAGO` por cada forma no efectivo.
- En ticket de devolución (2026-03), el voucher agrega espacio en blanco para firma y renglón `Firma cliente` después de `FCN`.
- En impresión de devolución (2026-03), el voucher se genera en un segundo PDF; al cerrar la vista previa del ticket principal, la app solicita confirmación y luego abre la vista previa del voucher.
- En ticket de devolución (2026-03), se agrega línea de recorte entre `RESUMEN DE ORDS` y `ORDS`; `GRACIAS POR SU CONFIANZA` se imprime después de `RESUMEN DE ORDS` y antes del recorte hacia `ORDS`.
- En ticket de devolución (2026-03-04), se retira del PDF el bloque detallado `ORDS` (barcode `CODE39` + tabla `JOB/ESF/CIL/EJE`); se conserva `RESUMEN DE ORDS` y vouchers. El diseño retirado queda respaldado en `lib/features/modulos/taller/etiqueta/ticket_ords_legacy_layout.dart`.
- En ticket de devolución (2026-03), se homologó el formato con cotizaciones usando bloques `DETALLE`, `TOTALES`, `FORMAS`, `TRANSACCION`, `RESUMEN DE ORDS`, `ORDS` (barcode `CODE39` + tabla `JOB/ESF/CIL/EJE`) y vouchers para formas no `EFECTIVO`.
## Conexion y entorno
- Variables de entorno:
- `API_BASE_URL`
- `API_BASE_URL_WEB`
- Resolucion de base URL (`lib/core/env.dart`):
- debug: `http://localhost:3001`.
- release web: `API_BASE_URL_WEB` y fallback `/api`.
- release mobile: `API_BASE_URL` y fallback hardcoded actual.
- En `main.dart`, el health check inicial consulta `/health`.

## Sesion, seguridad y navegacion
- `AuthController`:
- login con `/auth/login`.
- refresh proactivo y en demanda con `/auth/refresh`.
- timeout por inactividad (15 min) y registro de actividad por eventos de UI.
- `dio_provider`:
- agrega `Authorization` en requests protegidos.
- reintenta en 401 con refresh (si aplica).
- `router.dart` redirige segun `AuthState`.

## Reglas de autorizacion por sucursal (UI/API)
- Para modulos multi-sucursal, la UI debe respetar sucursales autorizadas por backend via `USR_MOD_SUC` y no forzar siempre `user.suc`.
- Modulos con regla activa:
- Inventarios (`DAT_JAA_ALM`).
- Control de cuentas (`DAT_CONS_CTAS`, `DAT_CTRL_CTAS`, `DAT_CTRL_CUENTAS`).
- Caja general (`DAT_FORM_ENTR_OPV`, `DAT_RES_ENTRE_CAJ`, `PV_ENTREGA_CG`).
- Si el usuario no-admin tiene sucursales vinculadas para el modulo, debe poder visualizar/procesar informacion de esas sucursales vinculadas.
- Compatibilidad legacy: si backend no encuentra filas activas en `USR_MOD_SUC` para el modulo, la app usa fallback a `user.suc`.
- La API es la fuente final de autorizacion; frontend solo refleja el contexto permitido y muestra error si backend rechaza.
- Caja general Excel: la hoja `DETALLE TRANSACCIONES` muestra `REQF` en la exportacion global y conserva el valor original (`-1/0/1`).
- Caja general Excel: los importes de `RESUMEN DIA` y `DETALLE TRANSACCIONES` se exportan como numericos con formato moneda (no texto).

## Regla principal FACTURA / FACTURA_VIEW (rutas y consultas)
- Toda nueva ruta, endpoint o consulta de facturación debe aplicar esta regla desde diseño.
- Enrutamiento UI:
- `/facturacion` requiere módulo front `FACTURA` (compatibilidad: `FACTURACION`, `PV_FACTURACION`, `FACT_IOE`).
- `/facturacion-view` requiere módulo front `FACTURA_VIEW`.
- Admin (rol/nivel administrativo configurado; incluye usuario `ADMIN`) mantiene bypass total en frontend y backend para consultar/editar/eliminar.
- Facturación no depende de `USR_MOD_SUC` en flujo base (`/facturacion`, `/facturacion-view`, unificación); no se requiere alta de admin en `USR_MOD_SUC` para habilitar estos accesos.
- Excepción: `REG_SINREQF` sí depende de `USR_MOD_SUC` para alcance de sucursales en usuarios no-admin.
- En unificación de facturación (`/facturacion/unificaciones/*`), no se debe restringir gestión por `user.suc` del JWT cuando el usuario ya cuenta con permisos de gestión.

## Tecnologias
- Flutter / Dart
- flutter_riverpod
- go_router
- dio
- shared_preferences
- flutter_dotenv
- file_picker, mobile_scanner, uuid, excel, pdf, printing

## Ejecucion
```bash
flutter pub get
flutter run
```

Web:
```bash
flutter run -d chrome
```

Testing:
```bash
flutter test
```

## Documentacion viva obligatoria
- Cada cambio funcional o tecnico que afecte modulos, rutas, providers,
  endpoints, tablas, campos o consultas debe actualizar en el mismo trabajo:
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\README.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\README.md`
- Esta actualizacion es obligatoria para retroalimentacion y trazabilidad.


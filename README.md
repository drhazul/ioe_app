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
  control de cuentas y punto de venta.
- `assets/`: `assets/.env`.
- `test/`: pruebas de widget.

## Modulos, endpoints y datos (app -> api -> tablas)
- Home:
- `GET /access/me/front-menu`.
- tablas: `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Auth:
- `POST /auth/login`, `POST /auth/refresh`.
- tablas: `USUARIO`, `USUARIO_TOKEN`.
- Maestros:
- `/roles` -> `ROL` (`IDROL`, `CODIGO`, `NOMBRE`, `ACTIVO`).
- `/deptos` -> `DEPARTAMENTO` (`IDDEPTO`, `NOMBRE`, `ACTIVO`).
- `/puestos` -> `PUESTO` (`IDPUESTO`, `IDDEPTO`, `NOMBRE`, `ACTIVO`).
- `/users` -> `USUARIO` (`IDUSUARIO`, `USERNAME`, `IDROL`, `IDDEPTO`, `IDPUESTO`, `SUC`, `ESTATUS`).
- UI maestros usuarios: el formulario valida `USERNAME` con minimo 3 caracteres antes de `POST /users`.
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
- MB51/MB52:
- `/dat-mb51/search`, `/dat-mb52/resumen`, `/dat-almacen`, `/dat-cmov`.
- tablas/fuentes: `DAT_MB51`, `DAT_ART`, `DAT_ALMACEN`, `DAT_CMOV`.
- Control de cuentas:
- `/ctrl-ctas/config`, `/ctrl-ctas/catalog/ctas`, `/ctrl-ctas/catalog/clientes`,
  `/ctrl-ctas/catalog/opvs`, `/ctrl-ctas/consulta/resumen-cliente`,
  `/ctrl-ctas/consulta/resumen-transaccion`, `/ctrl-ctas/consulta/detalle`.
- fuentes: `DAT_CTRL_CTAS`, `DAT_CAT_CTAS`, `FACT_CLIENT_SHP`, `PV_OPV`, `USR_MOD_SUC`.
- Regla UI de exportacion (pantalla `Resumen por Deudor`):
- se habilita exportar si hay exactamente una CTA en criterios, o si el usuario selecciona un CLIENT.
- si CTA esta en `Todas` o multiples CTA, exportar permanece deshabilitado hasta seleccionar un CLIENT.
- El AppBar de resumen muestra el detalle de CTA(s) activas tomadas de criterios.
- Si hay CTA unica y no se selecciona CLIENT, el archivo exporta `RESUMEN_TRANS` y `DETALLE` para todos los CLIENT que cumplan esa CTA.
- La carga de `DETALLE` para exportacion se ejecuta por cliente y por bloques de `IDFOL` para reducir fallas de red por demasiadas llamadas simultaneas.
- Durante exportacion se muestra una ventana emergente de progreso (no cerrable) y se cierra automaticamente al terminar o fallar.
- En la vista de resumen, el filtro `!= 0` inicia activo por defecto (cliente, transaccion y detalle).
- Punto de venta:
- `/factclientshp` -> `FACT_CLIENT_SHP`.
- `/pvctrfolasvr` -> `PV_CTR_FOL_ASVR`.
- `/pv/devoluciones/*` -> `PV_CTR_FOL_ASVR`, `PV_DEV_DET_TMP`, `PV_TICKET_LOG`, `PV_CTR_FOL_FORM(_SVR)`, `PV_CTR_ORDS`, `FAC_SVR_SHAP`, `FACT_IDFOLDEV`, `DAT_CTRL_CTAS`.
- `/pvticketlog` -> `PV_TICKET_LOG`.
- `/pvctrords` -> `PV_CTR_ORDS`, `PV_CTR_ORDS_DET`.
- `/refdetalle` -> `REF_DETALLE`.
- `/pv/refdetalle` -> `REF_DETALLE` (crear/asignar/eliminar referencias ligadas al folio).
- `/dat-form` -> `DAT_FORM` (CRUD de catalogo de formas de pago con estado activo/inactivo).
- `/jrqdepa|jrqsubd|jrqclas|jrqscla|jrqscla2|jrqguia` ->
  `JRQ_DEPA`, `JRQ_SUBD`, `JRQ_CLAS`, `JRQ_SCLA`, `JRQ_SCLA2`, `JRQ_GUIA`.

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
- Secuencia API:
- `GET /factclientshp` para cargar clientes y filtrar por SUC.
- `POST /pvctrfolasvr/auto` para crear folio.
- `PATCH /pvctrfolasvr/:idfol` para asignar `CLIEN` al folio creado.
- Correccion de integracion (2026-02): cuando `CLIEN` supera el rango `int32`, backend trata `PV_CTR_FOL_ASVR.CLIEN` como `float` para evitar error `500` al asignar cliente en este flujo.

## Edicion de precio en detalle de cotizacion
- Pantalla: `lib/features/modulos/punto_venta/cotizaciones/detalle_cot/detalle_cot_page.dart`.
- Interaccion: doble clic en columna `PVTA` del renglón agregado al ticket.
- Regla de autorizacion:
- usuario `SUPERPV` (supervisor) edita directo precio.
- usuario no supervisor debe capturar contraseña valida de un usuario con rol `SUPERPV`.
- la contraseña se prevalida en backend y, si no coincide con `SUPERPV`, no se abre el popup de precio.
- Endpoint usado:
- `PATCH /pvticketlog/:id/precio` con `PVTA` y `AUTH_PASSWORD` cuando aplica.
- `POST /pvticketlog/precio/authorize` para validar contraseña `SUPERPV` previo al popup de precio.
- El flujo actualiza `PVTA/PVTAT` del renglón y mantiene sincronizacion local-remota de la cotizacion.

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
- Si el SP no existe en SQL Server, la API devuelve `409` y se debe ejecutar `ioe-api/sql/sp_pv_cotizacion_cerrar_create.sql`.
- Si el SP rechaza el cierre por validacion de negocio, la API devuelve `400/409` con mensaje legible (ya no `500` por abortos de transaccion).
- Reglas UI de formas de pago:
- El dropdown de formas en pago usa `GET /dat-form` (tabla `DAT_FORM`) y respeta `ESTADO` para visibilidad.
- En cierre `CA`, el selector del modal solo lista `EFECTIVO`.
- `Autorizacion / referencia` y el boton `Generar/Asignar referencia` solo aplican para `TARJETA`, `CHEQUE`, `TRANSFERENCIA` y `DEPOSITO 3RO`.
- La referencia no se captura manualmente: se crea/asigna en `REF_DETALLE` y se usa `IDREF` como `aut` de la forma.
- Si existen referencias en `CAPTURADO` o `PROCESADO` que no se usan en el payload final, backend rechaza el cierre hasta eliminarlas.
- Mantenimiento maestro de formas:
- ruta listado: `/masterdata/dat-form`
- rutas formulario: `/masterdata/dat-form/new` y `/masterdata/dat-form/:id`
- archivos: `lib/features/masterdata/dat_form/dat_form_page.dart`, `dat_form_form_page.dart`, `dat_form_providers.dart`, `dat_form_api.dart`, `dat_form_models.dart`.
- Para `CREDITO`/`DEUDOR`, backend guarda la forma en `PV_CTR_FOL_FORM_SVR` (fallback `PV_CTR_FOL_FORM`) con `IMPP` positivo y `AUT=IDFOL`.
- Para `CREDITO`, backend valida disponible usando `FACT_CLIENT_SHP.L_CRED - SUM(ABS(DAT_CTRL_CTAS.IMPT))` (`CTA='101001002'`, `CLIENT=@IDC`).
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
- Apertura de pago desde detalle: el query `rqfac` se arma desde `GET /pv/cotizaciones/:idfol/cierre/context` para evitar valores stale del folio cargado previamente.
- Validacion UI previa: al finalizar, la app revisa `GET /pv/refdetalle?idfol=:idfol` y bloquea cierre si detecta referencias `CAPTURADO/PROCESADO` no utilizadas.
- Si detecta referencias sin uso en esa validacion previa, la app navega directo a `/punto-venta/cotizaciones/:idfol/ref-detalle` con la referencia encontrada seleccionada para gestionar su uso/eliminacion.
- Validacion UI de importe por forma: al agregar/editar, `impp` no puede exceder el faltante de la cotizacion (`total - sum(formas restantes)`), excepto `EFECTIVO` (puede exceder para cambio).
- Ajuste tecnico: controles `Radio` migrados a `RadioGroup` en dialogos de seleccion (cliente y referencias) para compatibilidad con Flutter >= 3.32.
- Regla funcional CA: cuando `tipotran=CA`, app fuerza `rqfac=false` y persiste `REQF=0` en `PV_CTR_FOL_ASVR` antes del preview para recalcular importes sin factura.
- Al cierre exitoso, backend deja la cotizacion en `PV_CTR_FOL_ASVR.ESTA='PAGADO'` y app no redirige de inmediato.
- En estado `PAGADO`, el boton regresar en pago cambia a icono de candado y, al presionarlo, actualiza `ESTA='TRANSMITIR'` para regresar al panel.
- Si una cotizacion en panel tiene `ESTA='PAGADO'`, la seleccion abre directo la pantalla de pago en lugar del detalle.
- El panel de cotizaciones muestra registros con estado `PENDIENTE`, `PAGADO` y `EDITANDO` usando filtro por `ESTA` (sin condicionar por `AUT`).
- Optimizacion panel (2026-03): la lista de cotizaciones consulta `GET /pvctrfolasvr` con filtros `suc`, `opv` y `search` en backend; la pantalla espera cargar contexto JWT antes de disparar la consulta para evitar carga masiva sin criterios.
- Compatibilidad de consulta (2026-03): la app ya no envia query param `_` en `GET /pvctrfolasvr` para evitar rechazo `400` cuando backend aplica validacion estricta de query.
- Al cierre exitoso, app habilita un boton `Imprimir ticket` debajo de `Finalizar cierre`.
- Al presionar `Imprimir ticket`, app muestra dialogo de ancho 58mm/80mm y abre la vista previa PDF.
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
- `PV_CTR_FOL_ASVR` (estado e importe final: `ESTA='PAGADO'` al finalizar y `ESTA='TRANSMITIR'` al regresar al panel, `IMPT`, `AUT='CA'|'VF'`)
- `PV_TICKET_LOG` (base de calculo `SUM(CTD * PVTA)`)
- `PV_CTR_FOL_FORM` (formas definitivas y cambio; en este flujo backend guarda en `IMPD` el total final de la cotizacion y deja `IMPA=0`)
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
- pago usa preview backend para totales/IVA con `RQFAC` del folio origen (switch visible solo lectura).
- en pago no se permite agregar, editar ni eliminar formas de pago.
- al finalizar devolución, el folio queda en `ESTA='PAGADO'`.
- cuando el folio está en `PAGADO`, el botón regresar cambia a candado; al presionarlo actualiza `ESTA='TRANSMITIR'` y vuelve al panel.
- al volver al panel desde pago/candado, frontend invalida el provider del panel y recarga la consulta.
- el panel de devoluciones muestra únicamente estados `DEV PEND` y `PAGADO`.
- desde panel, si el folio está en `PAGADO`, la selección abre directo la ruta de pago (sin mostrar selección/detalle).
- al finalizar se habilita `Imprimir ticket`; al presionarlo abre selector 58mm/80mm y la vista previa PDF con `GET /pv/devoluciones/:idfolDev/print-preview`.

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

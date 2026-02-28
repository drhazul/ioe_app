# Instrucciones de agente para ioe_app

## Contexto del proyecto
- Aplicacion Flutter del ecosistema IOE.
- Frontend feature-based en `lib/features` con Riverpod, go_router y Dio.
- Consume `ioe-api` (NestJS + MSSQL) para auth, maestros, inventarios, control de cuentas y punto de venta.
- Configuracion de entorno en `lib/core/env.dart` y `assets/.env` (solo release).

## Arquitectura y estructura real
- `lib/main.dart`: bootstrap, carga opcional de `.env` en release, health check a `/health`, `ProviderScope`.
- `lib/core/`:
- `auth/auth_controller.dart`: login, refresh, idle timeout, actividad de usuario.
- `dio_provider.dart`: cliente HTTP global, bearer token, retry en 401 con refresh.
- `router.dart`: rutas + guard por estado de autenticacion.
- `env.dart`: seleccion de base URL por plataforma/modo.
- `storage.dart`: persistencia de `access_token`, `refresh_token`, `last_activity_epoch_ms`.
- `lib/features/masterdata/`: catalogos y seguridad administrativa.
- `lib/features/modulos/`: inventarios, catalogo, mb51, mb52, ctrl-ctas y punto-venta.

## Mapa funcional (feature -> API -> tablas/campos)
- Home/Menu: `/access/me/front-menu` -> `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Auth:
- `/auth/login`, `/auth/refresh` -> `USUARIO`, `USUARIO_TOKEN`.
- payload JWT esperado: `sub`, `username`, `roleId`, `nivel`, `suc`.
- Maestros:
- Roles `/roles` -> `ROL`: `IDROL`, `CODIGO`, `NOMBRE`, `DESCRIPCION`, `ACTIVO`, `FCNR`.
- Deptos `/deptos` -> `DEPARTAMENTO`: `IDDEPTO`, `NOMBRE`, `ACTIVO`, `FCNR`.
- Puestos `/puestos` -> `PUESTO`: `IDPUESTO`, `IDDEPTO`, `NOMBRE`, `ACTIVO`, `FCNR`.
- Usuarios `/users` -> `USUARIO`: `IDUSUARIO`, `USERNAME`, `NOMBRE`, `APELLIDOS`, `MAIL`, `ESTATUS`, `NIVEL`, `IDROL`, `IDDEPTO`, `IDPUESTO`, `SUC`.
- Validacion UI usuarios: el formulario de alta/edicion exige `USERNAME` con minimo 3 caracteres para alinear con validacion backend de `/users`.
- Sucursales `/dat-suc` (en backend) -> `DAT_SUC`: `SUC`, `DESC`, `ENCAR`, `ZONA`, `RFC`, `DIRECCION`, `CONTACTO`, `IVA_INTEGRADO`.
- Datmodulos `/datmodulos` -> `MOD_FRONT`: `IDMOD_FRONT`, `CODIGO`, `NOMBRE`, `DEPTO`, `ACTIVO`, `FCNR`.
- Accesos `/access/*` -> `MODULO`, `GRUP_MODULO`, `GRUPMOD_MODULO`, `ROL_GRUP_MODULO_PERM`, `MOD_FRONT`, `GRUPMOD_FRONT`, `GRUPMOD_FRONT_MOD`, `ROL_GRUPMOD_FRONT`.
- Acceso regional por sucursal `/usr-mod-suc` -> `USR_MOD_SUC`: `MODULO`, `USUARIO`, `SUC`, `ACTIVO`, `FCNR`.
- Cat. cuentas `/cat-ctas` -> `DAT_CAT_CTAS`: `CTA`, `DCTA`, `RELACION`, `SUC`.
- Inventarios:
- `/conteos`, `/conteos/:cont/*`, `/datcontctrl`, `/datdetsvr/:id`, `/capturas*`.
- tablas: `DAT_CONT_CTRL`, `DAT_DET_SVR`, `DAT_CONT_CAPTURA`, `USR_MOD_SUC`.
- campos clave: `CONT`, `SUC`, `ESTA`, `TIPOCONT`, `TOTAL_ITEMS`, `EXT`, `ALMACEN`, `CANT`, `CAPTURA_UUID`.
- Catalogo articulos:
- `/datart`, `/datart/massive-upload`, `/articulos/alta-masiva/*`.
- tablas: `DAT_ART`, `DAT_ART_MASIVA_TMP`.
- campos clave: `SUC`, `ART`, `UPC`, `DES`, `TIPO`, `PVTA`, `CTOP`, `DEPA`, `SUBD`, `CLAS`, `SCLA`, `SCLA2`.
- MB51/MB52:
- `/dat-mb51/search`, `/dat-mb52/resumen`, `/dat-almacen`, `/dat-cmov`.
- tablas/fuentes: `DAT_MB51`, `DAT_ALMACEN`, `DAT_CMOV`, `DAT_ART`.
- Control de cuentas:
- `/ctrl-ctas/config`, `/ctrl-ctas/catalog/*`, `/ctrl-ctas/consulta/*`.
- tablas/fuentes: `DAT_CTRL_CTAS`, `DAT_CAT_CTAS`, `FACT_CLIENT_SHP`, `PV_OPV`, `USR_MOD_SUC`.
- Punto de venta:
- Clientes `/factclientshp` -> `FACT_CLIENT_SHP`.
- Cotizaciones `/pvctrfolasvr` -> `PV_CTR_FOL_ASVR`.
- Devoluciones `/pv/devoluciones/*` -> `PV_CTR_FOL_ASVR`, `PV_DEV_DET_TMP`, `PV_TICKET_LOG`, `PV_CTR_FOL_FORM(_SVR)`, `PV_CTR_ORDS`, `FAC_SVR_SHAP`, `FACT_IDFOLDEV`, `DAT_CTRL_CTAS`.
- Tickets `/pvticketlog` -> `PV_TICKET_LOG`.
- Ordenes `/pvctrords` -> `PV_CTR_ORDS`, `PV_CTR_ORDS_DET`.
- Referencias `/refdetalle` -> `REF_DETALLE`.
- Referencias PV `/pv/refdetalle` -> `REF_DETALLE` (crear/asignar/eliminar por `IDFOL`).
- Catalogo formas `/dat-form` -> `DAT_FORM` (`IDFORM`, `ASPEL`, `FORM`, `NOM`, `ESTADO`).
- Mantenimiento maestro DAT_FORM (UI) -> rutas `/masterdata/dat-form`, `/masterdata/dat-form/new`, `/masterdata/dat-form/:id`.
- Clasificadores `/jrq*` -> `JRQ_DEPA`, `JRQ_SUBD`, `JRQ_CLAS`, `JRQ_SCLA`, `JRQ_SCLA2`, `JRQ_GUIA`.

## Punto de venta: alta de cotizacion desde panel
- En `CotizacionesPage`, al presionar `Agregar` primero se confirma la creacion y, al aceptar, se abre un segundo modal para buscar/seleccionar cliente.
- El modal de cliente filtra por la sucursal del usuario logueado (SUC del contexto JWT).
- Al crear (`POST /pvctrfolasvr/auto`) se asigna el cliente seleccionado con `PATCH /pvctrfolasvr/:idfol` enviando `CLIEN`.
- Correccion de integracion (2026-02): para IDs de cliente mayores a `2,147,483,647`, backend mapea `PV_CTR_FOL_ASVR.CLIEN` como `float` (no `int`) para evitar `500 EPARAM` al asignar cliente en el alta.

## Punto de venta: edicion de precio en detalle de cotizacion
- En `DetalleCotPage`, doble clic sobre la celda `PVTA` abre edicion de precio del renglón en `PV_TICKET_LOG`.
- Si el usuario logueado tiene rol supervisor (`SUPERPV`), abre directo el modal de nuevo importe.
- Si no es supervisor, primero abre modal de autorizacion para capturar contraseña de un usuario `SUPERPV`; la contraseña se valida en backend y solo si es valida se abre modal de nuevo importe.
- Si la contraseña no coincide con un usuario activo `SUPERPV`, la UI no avanza al modal de importe.
- La actualizacion remota se hace via `PATCH /pvticketlog/:id/precio` enviando `PVTA` y, cuando aplica, `AUTH_PASSWORD`.
- La prevalidacion de contraseña se realiza con `POST /pvticketlog/precio/authorize`.
- La app mantiene sincronizacion local/remota del renglón y refresca providers de ticket al aplicar el cambio.

## Punto de venta: cierre de cotizacion (implementado)
- Ruta UI: `/punto-venta/cotizaciones/:idfol/pago`.
- Ruta UI secundaria (referencias): `/punto-venta/cotizaciones/:idfol/ref-detalle`.
- Entrada desde `DetalleCotPage`: boton "Pago y cierre", validacion de contexto y modal obligatorio para seleccionar `CA` o `VF`.
- Archivos frontend:
- `lib/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_page.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_providers.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_api.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_models.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_page.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_providers.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_api.dart`
- `lib/features/modulos/punto_venta/cotizaciones/pago/ref_detalle/ref_detalle_models.dart`
- La UI de pago ya no muestra la tarjeta "Contexto del folio"; el contexto se mantiene para validaciones y payload backend.
- Endpoints consumidos:
- `GET /pv/cotizaciones/:idfol/cierre/context`
- `POST /pv/cotizaciones/:idfol/cierre/preview`
- `GET /pv/cotizaciones/:idfol/cierre/print-preview`
- `POST /pv/cotizaciones/:idfol/cierre`
- `GET /dat-form` (formas activas para dropdown de pago; `includeInactive=true` opcional)
- `GET /dat-form/:idform`, `POST /dat-form`, `PATCH /dat-form/:idform`, `DELETE /dat-form/:idform` (CRUD maestro DAT_FORM)
- `GET /pv/refdetalle?idfol=:idfol&tipo=:tipo`
- `POST /pv/refdetalle/crear`
- `POST /pv/refdetalle/asignar`
- `DELETE /pv/refdetalle/:idref`
- Dependencia backend de cierre:
- `POST /pv/cotizaciones/:idfol/cierre` se procesa en API via `dbo.sp_pv_cotizacion_cerrar`; si ese SP no existe, backend responde `409` indicando ejecutar `ioe-api/sql/sp_pv_cotizacion_cerrar_create.sql`.
- En fallos de validacion SQL del SP de cierre, backend responde `400/409` con mensaje de negocio (en lugar de `500` por abortos transaccionales internos).
- Totales y validaciones criticas siempre se confirman en backend (no confiar en calculo frontend).
- Al finalizar exitosamente se refrescan providers de cotizacion/ticket y la pantalla queda en pago (sin redireccion inmediata).
- El cierre exitoso persiste `PV_CTR_FOL_ASVR.ESTA='PAGADO'` (estado confirmado desde backend, no flag local de UI).
- Tras cierre exitoso se habilita boton `Imprimir ticket` (debajo de `Finalizar cierre`), que abre dialogo de ancho 58mm/80mm y luego la vista previa PDF.
- En pago, cuando `ESTA` es `PAGADO`, el boton regresar cambia a icono de candado y al presionarlo actualiza `ESTA='TRANSMITIR'` y regresa al panel.
- Boton regresar en pago: si aun no esta en `PAGADO` vuelve a `detalle`; en `PAGADO` aplica flujo de envio a `TRANSMITIR`.
- Desde panel de cotizaciones, si el folio ya esta en `PAGADO`, la seleccion abre directo la pantalla de pago (no detalle) para identificar el proceso de salida/transmision.
- El panel de cotizaciones lista folios en `PENDIENTE`, `PAGADO` y `EDITANDO` filtrando por `ESTA` (sin depender del valor de `AUT`).
- Vista previa PDF de cierre (ticket 58/80mm): cabecera sucursal (`DAT_SUC`), detalle de articulos (`PV_TICKET_LOG`), totales+formas+cambio, pie transaccional (`OPV/OPVM`, `IDFOL`, `FCNM`, cliente) y ORDs con control (`ORD + UPC`) + codigo de barras `CODE39` + tabla con bordes del detalle.
- Ajuste de impresion: se removio del encabezado del ticket el texto `COTIZACION FINALIZADA` y el `IDFOL` superior repetitivo.
- Ajuste de maquetacion ticket: se aplica margen izquierdo fijo de `2mm` en tickets 58/80mm.
- Regla ticket CA: cuando `tipotran=CA` (cotizacion abierta), en la seccion de `TOTALES` solo se imprime `Total base` y se oculta bloque `FORMAS` (se mantienen TRANSACCION y ORDs).
- Ajuste ORDs en impresion: no se imprime `EST` ni el campo `ART` del encabezado de ORD; se imprime `ORD` + `UPC`, descripcion de articulo + `TIPO` de ORD, codigo de barras `CODE39` por ORD y tabla con bordes (`JOB/ESF/CIL/EJE`) desde `PV_CTR_ORDS_DET`.
- Tabla de detalle ORD en ticket: se retiraron guiones de celdas vacias; ahora se muestran vacias dentro de la tabla.
- Ajuste ticket (2026-02): entre `TRANSACCION` y `ORDS` se imprime bloque `RESUMEN DE ORDS` con `ORD`, descripcion y `UPC` de cada orden.
- Ajuste ticket (2026-02): en `DETALLE` se imprime `UPC` por producto y se aplica alternancia visual gris/blanco por renglon.
- Ajuste ticket (2026-02): al iniciar cada bloque de `ORD` se agrega linea de recorte con icono para separacion por orden.
- Ajuste ticket (2026-02): la impresion usa altura de pagina dinamica segun contenido (detalle, totales y ORDs) para reducir hojas sobrantes y mantener multihoja solo cuando realmente se requiere.
- Ajuste ticket (2026-02): `MultiPage` usa margen izquierdo explicito de `2mm` para asegurar desplazamiento real en 58/80mm.
- Ajuste ticket (2026-02): calibracion de altura dinamica en 80mm con estimacion mas conservadora (chars/linea, alto de linea, tabla y buffer por ORD) para evitar hoja extra por salto de pagina; 58mm mantiene su logica actual.
- Al cerrar en backend, `PV_CTR_FOL_ASVR.AUT` se actualiza con el tipo de cierre aplicado (`CA` o `VF`).
- Al cerrar en backend, `PV_CTR_FOL_FORM`/`PV_CTR_FOL_FORM_SVR` guarda en `IMPD` el total final de la cotizacion (costo total de articulos segun regla de cierre), con `IMPA` en `0` para este flujo, y actualiza `PV_CTR_ORDS.ESTATUS = 2`.
- Para ORDs creadas desde cotizacion, `PV_CTR_ORDS.CLIEN` se maneja como `FLOAT` para soportar IDs grandes; requiere script `ioe-api/sql/PV_CTR_ORDS_CLIEN_float.sql`.
- Reglas UI de formas (actualizacion):
- El dropdown de formas de pago en el modal se alimenta desde `DAT_FORM` via `GET /dat-form` (ya no lista fija hardcodeada).
- Con `tipotran=CA`, el selector de formas en el modal solo permite `EFECTIVO`.
- El campo `Autorizacion / referencia` y el boton `Generar/Asignar referencia` solo se muestran para `TARJETA`, `CHEQUE`, `TRANSFERENCIA` y `DEPOSITO 3RO`.
- La referencia ya no se captura manualmente: se crea/asigna via `REF_DETALLE` y se regresa `IDREF` al formulario de pago.
- Si hay referencias del folio en `CAPTURADO` o `PROCESADO` que no se usan en el cierre, backend rechaza finalizar hasta eliminarlas.
- En cierre `VF`, para formas `CREDITO`/`DEUDOR` backend inserta en `PV_CTR_FOL_FORM_SVR` (si existe; fallback `PV_CTR_FOL_FORM`) con `IMPP` positivo y `AUT=IDFOL`.
- Para `CREDITO`, backend valida disponible con `FACT_CLIENT_SHP.L_CRED - SUM(ABS(DAT_CTRL_CTAS.IMPT))` filtrando `CTA='101001002'` y `CLIENT=@IDC`.
- Para `CREDITO`/`DEUDOR`, backend registra cargo en `DAT_CTRL_CTAS` con `CMOV=602`, `CTA='101001002'`, `CLIENT`, `IDFOL`, `NDOC` y `IMPT` negativo.
- Compatibilidad backend en `DAT_CTRL_CTAS`: puede insertar clase en `CMOV` o `CLSD` segun columnas disponibles y completar `FCND/RTXT` cuando existan.
- `NDOC` de cargo se genera concurrente bajo transaccion (sin `DCount`), con formato base `N6000001+`.
- compatibilidad backend: el SP de cierre valida existencia de `NDOC` via `COL_LENGTH` para evitar errores de columna en esquemas legacy.
- Correccion tecnica (web): generacion de id local de forma usa `nextInt(0x100000000)` en lugar de `nextInt(1 << 32)` para evitar `RangeError` en Flutter Web.
- Con al menos una forma de pago agregada, el selector `Tipo de cierre` (`CA`/`VF`) queda bloqueado; solo se habilita de nuevo al eliminar todas las formas.
- Ajuste UI: el control `RQFAC` se muestra en el AppBar junto al `Tipo de cierre` (ya no como card separado en el body).
- Ajuste UI: los totales de cotizacion y de formas de pago se muestran unificados en un solo card (`Total Caculado por Cotizacion` + `Totales de formas de pago`).
- Ajuste UI: tamanos de labels/importes del resumen se controlan con constantes en `pago_cotizacion_page.dart`:
- `_kResumenTituloSize`, `_kResumenLabelSize`, `_kResumenImporteSize`, `_kFormasItemSize`, `_kFormasRefSize`.
- Ajuste UI: en el resumen unificado ya no se muestra el label/valor `IVA integrado sucursal`.
- Ajuste funcional: al entrar/reingresar a la pagina de pago se vuelve a recalcular preview/totales (sin reutilizar inicializacion previa), respetando `tipotran`/`rqfac` y reglas de IVA del backend.
- Persistencia `RQFAC`: al activar/desactivar el switch en pago se actualiza `PV_CTR_FOL_ASVR.REQF` por `IDFOL` via `PATCH /pvctrfolasvr/:idfol`.
- Reingreso a pago: `DetalleCotPage` abre pago tomando `rqfac` desde `cierre/context` (backend) para evitar usar valores stale de la grilla local.
- Validacion UI previa a cierre: antes de `POST /pv/cotizaciones/:idfol/cierre`, la app consulta `GET /pv/refdetalle?idfol=:idfol` y bloquea finalizar si hay referencias `CAPTURADO/PROCESADO` no usadas en `formas.aut`.
- Si la prevalidacion detecta referencias sin usar, la app redirige a `/punto-venta/cotizaciones/:idfol/ref-detalle` con la referencia detectada preseleccionada para su gestion (usar/eliminar) antes de permitir cerrar.
- Validacion UI de importes: al agregar/editar forma, el `impp` no puede exceder el faltante por pagar (`total - sum(formas restantes)`) excepto cuando la forma es `EFECTIVO` (puede exceder para cambio).
- Ajuste tecnico Flutter: dialogos de seleccion migrados a `RadioGroup` (cliente en cotizaciones y referencia en `REF_DETALLE`) para eliminar uso deprecated de `Radio.groupValue/onChanged`.
- Regla CA/RQFAC: cuando el tipo de cierre es `CA` (al entrar o al cambiar), app fuerza `RQFAC=false` y persiste `PV_CTR_FOL_ASVR.REQF=0` antes del recalculo de preview/totales.

## Punto de venta: devoluciones de cotizacion/venta/apartado (implementado 2026-02)
- Rutas UI:
- `/punto-venta/devoluciones` (panel)
- `/punto-venta/devoluciones/:idfolDev` (selección de artículos)
- `/punto-venta/devoluciones/:idfolDev/detalle` (detalle devolución)
- `/punto-venta/devoluciones/:idfolDev/pago` (pago/finalización)
- Integracion en router:
- `lib/core/router.dart` registra las rutas de panel, selección, detalle y pago bajo `/punto-venta`.
- Integracion en Home PV:
- `lib/features/modulos/punto_venta/punto_venta_home_page.dart` habilita acceso directo al panel de devoluciones.
- Estructura frontend:
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_page.dart`
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_api.dart`
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_models.dart`
- `lib/features/modulos/punto_venta/devoluciones/devoluciones_providers.dart`
- `lib/features/modulos/punto_venta/devoluciones/detalle/detalle_devolucion_page.dart`
- `lib/features/modulos/punto_venta/devoluciones/detalle/detalle_devolucion_resumen_page.dart`
- `lib/features/modulos/punto_venta/devoluciones/pago/pago_devolucion_page.dart`
- Endpoints consumidos:
- `GET /pv/devoluciones`
- `POST /pv/devoluciones/crear`
- `GET /pv/devoluciones/:idfolDev/detalle`
- `POST /pv/devoluciones/:idfolDev/devolver-todo`
- `PATCH /pv/devoluciones/:idfolDev/lineas/:lineId`
- `POST /pv/devoluciones/:idfolDev/detalle/preparar`
- `POST /pv/devoluciones/:idfolDev/pago/preview`
- `POST /pv/devoluciones/:idfolDev/pago/finalizar`
- `GET /pv/devoluciones/:idfolDev/print-preview`
- Reglas UI relevantes:
- alta solicita `IDFOL` origen + contraseña supervisor y navega al detalle al crear.
- selección de artículos permite editar solo `CTDD`; para líneas bloqueadas por ORD se marca el estado y backend rechaza edición.
- botón `Devolver TODO` aplica asignación masiva (`CTDD=DIFD`) respetando bloqueos ORD.
- en selección se oculta columna `DIFD` y el botón principal navega a `Ir Detalle devolución`.
- al abrir detalle devolución, frontend ejecuta `POST /pv/devoluciones/:idfolDev/detalle/preparar` para insertar en `PV_TICKET_LOG` solo líneas con `CTDD>0`.
- navegación a pago se habilita desde detalle devolución cuando existe ticket preparado.
- pago recalcula preview usando `RQFAC` derivado del folio origen (solo lectura en UI, sin edición manual del switch).
- en pago no se permite agregar, editar ni eliminar formas de pago.
- al finalizar devolución, backend deja el folio en `ESTA='PAGADO'`; en esa condición la navegación de regreso muestra icono candado.
- al presionar candado en pago, frontend actualiza `ESTA='TRANSMITIR'` via `PATCH /pvctrfolasvr/:idfol` y regresa al panel.
- al regresar a panel desde pago/candado, frontend invalida el provider del panel para forzar recarga inmediata de la consulta.
- el panel de devoluciones solo muestra folios con `ESTA IN ('DEV PEND','PAGADO')`.
- desde panel de devoluciones, si un folio ya está en `PAGADO`, la selección abre directo `/pago` (sin pasar por selección de artículos/detalle).
- tras finalizar se habilita botón `Imprimir ticket`, que sigue flujo similar a cotizaciones: selector 58mm/80mm y vista previa PDF con `GET /pv/devoluciones/:idfolDev/print-preview`.

## Reloj Checador (asistencia) - implementado (2026-02)
- Rutas UI:
- `/reloj-checador/app`
- `/reloj-checador/consultas`
- Integracion en router:
- `lib/core/router.dart` registra ambas rutas bajo Home.
- Integracion en Home:
- `lib/features/home/home_page.dart` resuelve codigo/nombre de modulo de asistencia hacia `/reloj-checador/app`.
- Estructura frontend:
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_page.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_api.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_models.dart`
- `lib/features/modulos/reloj_checador/app/reloj_checador_app_providers.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_page.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_api.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_models.dart`
- `lib/features/modulos/reloj_checador/consultas/reloj_checador_consultas_providers.dart`
- `lib/features/modulos/reloj_checador/consultas/download_helper.dart`
- `lib/features/modulos/reloj_checador/consultas/download_helper_stub.dart`
- `lib/features/modulos/reloj_checador/consultas/download_helper_web.dart`
- Endpoints consumidos:
- `GET /reloj-checador/context`
- `POST /reloj-checador/timelog`
- `GET /reloj-checador/timelogs`
- `PUT /reloj-checador/timelog/:id`
- `POST /reloj-checador/incidencias`
- `PUT /reloj-checador/incidencias/:id/status`
- `GET /reloj-checador/incidencias`
- `POST /reloj-checador/documentos`
- `GET /reloj-checador/documentos`
- `GET /reloj-checador/documentos/:id/download`
- `POST /reloj-checador/overrides`
- `GET /reloj-checador/overrides`
- `PUT /reloj-checador/overrides/:id/revoke`
- `GET /reloj-checador/policy`
- `POST /reloj-checador/policy`
- Reglas UI relevantes:
- App de marcaje muestra checkpoints `ENTRADA`, `SALIDA_COMER`, `REGRESO_COMER`, `SALIDA` y habilita botones segun secuencia devuelta por contexto.
- Si policy exige GPS, la UI de marcaje requiere `LAT/LON` (MVP con captura manual).
- En debug, la pantalla de marcaje expone switch de `Liveness OK` para pruebas de flujo FACE.
- Consultas incluye tabs de Timelogs, Incidencias, Documentos y Policy/Overrides con acciones condicionadas por rol.
- Correccion admin de timelog exige `REASON` y manda `PUT /reloj-checador/timelog/:id`.
- Carga de documentos en MVP usa `file_picker` + base64 JSON (sin multipart).
- Mounted checks:
- En operaciones async de app/consultas se usan verificaciones `if (!mounted) return;` y actualizacion de estado segura.

## Conexiones y consultas
- Base URL por `Env.apiBaseUrl`:
- debug: `http://localhost:3001`.
- release web: `API_BASE_URL_WEB` o fallback `/api`.
- release mobile: `API_BASE_URL` o fallback hardcoded actual.
- `dio_provider` aplica:
- header `Authorization: Bearer`.
- refresh automatizado en 401 (excepto rutas auth).
- tracking de requests protegidos para idle timeout.
- Consultas del frontend siempre via APIs de feature (`*_api.dart`).

## Reglas estrictas
- No modificar logica de negocio ni flujos de autenticacion sin confirmacion.
- No cambiar versiones de dependencias ni agregar nuevas sin permiso.
- No eliminar pantallas, rutas o providers sin confirmacion explicita.
- No editar archivos generados (`build/`) ni plataformas (`android/`, `ios/`, etc.) salvo pedido.
- No modificar `assets/.env` ni exponer secretos.
- Evitar comandos destructivos.

## Refactors
- Incrementales y por feature.
- Mantener convenciones: `*_api.dart`, `*_models.dart`, `*_providers.dart`, `*_page.dart`.
- Mantener estructura de `lib/core` para utilidades compartidas.

## Cambios estructurales
- Mover features o renombrar rutas requiere aprobacion previa.
- Actualizar `lib/core/router.dart` cuando se agreguen rutas.
- Mantener `AuthController` y el guard de rutas coherentes.

## Cambios de dependencias
- Requieren aprobacion previa y justificacion tecnica.
- No actualizar versiones por iniciativa propia.

## Logica critica
- AuthController, token refresh, storage y router guard son criticos.
- Consultar antes de modificar interceptores Dio o reglas de redireccion.

## Inventarios: autorizacion por sucursal
- El filtro de sucursal en Inventarios se basa en `USR_MOD_SUC` para el modulo `DAT_JAA_ALM`.
- Los componentes de filtro (sucursal, nombre, fecha, filtrar/limpiar) deben mostrarse para todos los usuarios, incluido admin.
- La seleccion/cambio de sucursal en UI solo debe habilitarse cuando el usuario este autorizado por rol/listado (`USR_MOD_SUC`).
- Las acciones sensibles (ej. aplicar ajuste) deben usar la sucursal seleccionada y confiar en validacion backend de autorizacion.

## Control de Cuentas: autorizacion por sucursal
- El modulo de Home que navega a `/ctrl-ctas` puede llegar como `DAT_CONS_CTAS`, `DAT_CTRL_CTAS` o `DAT_CTRL_CUENTAS`.
- En `CtrlCtasConsultaPage`, la sucursal no debe quedar bloqueada por defecto para no-admin; debe depender de `ctrl-ctas/config` (`allowedSucs`, `canSelectSucs`, `forcedSuc`).
- Para no-admin, mostrar y permitir elegir solo sucursales autorizadas por backend (`allowedSucs`); para admin, mantener lista completa.
- Si `canSelectSucs` es `false`, la UI puede mostrar la sucursal forzada; si es `true`, habilitar dropdown/multiseleccion.
- No usar la sucursal del perfil/JWT como unica fuente en frontend; la autorizacion efectiva debe venir de `USR_MOD_SUC` via API.
- En `CtrlCtasResumenClientePage`, la exportacion Excel debe habilitarse cuando hay una sola CTA seleccionada en criterios, o cuando existe un CLIENT seleccionado en la grilla.
- Si CTA queda en `Todas` (sin CTA) o se seleccionan multiples CTA, la exportacion debe permanecer deshabilitada hasta seleccionar un CLIENT.
- El AppBar de `Resumen por Deudor` debe mostrar el resumen de CTA(s) enviadas desde criterios (`CTA: Todas`, una CTA, o multiples con contador).
- En exportacion con CTA unica y sin CLIENT seleccionado, `RESUMEN_TRANS` y `DETALLE` deben incluir todos los CLIENT de la consulta (filtrados por la CTA seleccionada).
- Para evitar errores de conexion, la consulta de `DETALLE` en exportacion debe enviarse por cliente y por bloques de `IDFOL` (secuencial), no con N llamadas concurrentes por folio.
- La exportacion en `CtrlCtasResumenClientePage` debe mostrar modal de progreso no cerrable manualmente, con avance por etapas, y cerrarse solo al finalizar o en error.
- En `CtrlCtasResumenClientePage` el filtro `!= 0` debe iniciar activo por defecto en resumen cliente, resumen transaccion y detalle de transaccion.

## Documentacion viva obligatoria
- Cada nueva implementacion que cambie modulos, rutas, providers, endpoints, tablas, campos o consultas debe actualizar en el mismo trabajo:
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe_app\README.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\AGENTS.md`
- `C:\Users\PCDESARROLLO\Proyectos\ioe-api\README.md`
- No cerrar una tarea funcional sin dejar trazabilidad documental sincronizada entre app y api.

# Base de módulos (front)

Navega solo a otros README/AGENTS cuando la tarea lo exija; evita cargar contexto extra sin motivo.

Enlaces relacionados:
- README principal del frontend: `README.md`
- AGENTS principal del frontend: `AGENTS.md`
- AGENTS de este módulo: `docs/modules/base_modulos/AGENTS.md`
- Otros módulos útiles: `docs/modules/core_seguridad/README.md`, `docs/modules/punto_venta/README.md`, `docs/modules/ordenes_trabajo/README.md`, `docs/modules/reloj_checador/README.md`

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
- `/puestos` (compat legacy) -> `ROL` (`IDROL` expuesto como `IDPUESTO`, `IDDEPTO`, `NOMBRE`, `ACTIVO`).
- `/users` -> `USUARIO` (`IDUSUARIO`, `USERNAME`, `IDROL`, `IDDEPTO`, `SUC`, `ESTATUS`).
- UI maestros usuarios: el formulario valida `USERNAME` con minimo 3 caracteres antes de `POST /users`.
- UI maestros usuarios (2026-03): en alta se genera contraseña temporal aleatoria de 6 dígitos, con botón para regenerar y mostrar/ocultar contraseña.
- UI maestros usuarios (2026-03): el formulario permite controlar `FORZAR_CAMBIO_PASS` para exigir cambio de contraseña en el próximo acceso.
- UI maestros usuarios (2026-03): el listado soporta visualización agrupada por sucursal o departamento y filtros por ambas dimensiones.
- `/datmodulos` -> `MOD_FRONT` (`CODIGO`, `NOMBRE`, `DEPTO`, `ACTIVO`).
- Datos Maestros / Módulos Front (2026-05-04): se quitó la entrada `Módulos` en `/#/masterdata`; el CRUD de `MOD_FRONT` se consume desde `/#/masterdata/access/mod-front` para evitar doble mantenimiento de pantallas.
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): nuevo menú `/#/masterdata/access/enrolamiento-front-usr`; la carga de Home prioriza `USR_GRUPMOD_FRONT` por usuario y hace fallback a `ROL_GRUPMOD_FRONT`.
- Datos Maestros / Enrolamiento Front por usuario (2026-05-04): el selector de usuario ahora permite filtrar por `Sucursal` y `Departamento` desde dropdowns dedicados.
- Datos Maestros / Acceso por sucursal (2026-05-04): `/#/masterdata/access-reg-suc` incorpora filtros dropdown de `Sucursal (usuario)` y `Departamento` en la barra principal y en el popup de vinculación para acotar módulos front, usuarios y resultados de `USR_MOD_SUC`.
- Datos Maestros / Configuración maestra (2026-05-05): el submódulo usa `GET/PUT /masterdata/configuracion-maestra` y conserva fallback local de catálogos si la API no responde.
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
- Edición detalle (2026-04): la ficha permite editar `UPC`; antes de guardar se valida que no esté asignado a otro `ART` de la misma sucursal.
- Alta masiva: la validación considera duplicados por sucursal (`SUC + ART` / `SUC + UPC`), permitiendo subir el mismo `ART`/`UPC` para distintas sucursales sin bloquear la carga.
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
- Facturación paginación (2026-03-31, actualizado 2026-06-29): el panel de pendientes/consulta carga 150 registros por página por defecto, alineado al límite backend de `/facturacion/pendientes`.
- Facturación selección por IDFOL (2026-04-01, actualizado 2026-06-29): el panel de pendientes agrega botón `Cargar IDFOL` para capturar folios manualmente o cargar un Excel (una sola columna). Tras validar hasta 500 folios, `SELECCIONAR relacionados` filtra la tabla a todos los folios `PENDIENTE` encontrados mediante `POST /facturacion/pendientes/idfols`, sin limitarse a la página visible.
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
- `/dat-form` -> `DAT_FORM` (CRUD de catalogo de formas de pago con estado activo/inactivo; `ASPEL` resuelve `FormaPagoSAT` y `TARJETA CREDITO` usa `04`).
- `/ord-flujo-vis` -> `DAT_JAO_ORD_FLUJO_VIS` (CRUD de visualización por ROLL en ORD, filtros por `ROLL`/`ESTSEGU`, combos `ROL`/`DAT_EST_ORD`, `MODULO` bloqueado y `ORDEN` automático).
- `/jrqdepa|jrqsubd|jrqclas|jrqscla|jrqscla2|jrqguia` ->
  `JRQ_DEPA`, `JRQ_SUBD`, `JRQ_CLAS`, `JRQ_SCLA`, `JRQ_SCLA2`, `JRQ_GUIA`.

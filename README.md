# IOE App

Aplicacion Flutter para el sistema IOE. Consume la API (ioe-api) y ofrece
pantallas de login, datos maestros y modulos operativos (inventarios, captura).

## Alcance funcional (segun el codigo)
- Login y manejo de tokens JWT.
- Datos maestros: roles, usuarios, departamentos, puestos, sucursales, modulos.
- Accesos: modulos/grupos backend y front, permisos por rol.
- Inventarios: listado, alta y captura.
- Navegacion con guardia de autenticacion.

## Tecnologias
- Flutter / Dart
- Riverpod (estado)
- go_router (rutas)
- Dio (HTTP) + interceptores
- shared_preferences (tokens)
- flutter_dotenv (config)
- file_picker, mobile_scanner, uuid, pdf/printing

## Estructura de carpetas
- `lib/core/`: auth, router, env, dio, storage y helpers
- `lib/features/`: features por dominio (api, models, providers, pages)
- `assets/`: configuracion (.env)
- `test/`: pruebas de widget

## Arquitectura
- Enfoque feature-based.
- Cada feature suele tener `*_api.dart`, `*_models.dart`, `*_providers.dart`, `*_page.dart`.
- Riverpod gestiona estado y caching.
- Dio agrega Authorization y hace refresh token en 401.
- go_router aplica redireccion segun `AuthState`.

## Configuracion
- `assets/.env` (no versionado) con variables:
  - `API_BASE_URL`
  - `API_BASE_URL_WEB`
- Alternativas:
  - `--dart-define=API_BASE_URL=...`
  - `--dart-define=API_BASE_URL_WEB=...`
- En release:
  - Web usa `/api` si no se define base URL.
  - Mobile usa el fallback definido en `lib/core/env.dart`.

## Ejecucion
```bash
flutter pub get
flutter run
```

Ejemplo web:
```bash
flutter run -d chrome
```

## Testing
```bash
flutter test
```

## Notas operativas
- Al iniciar la app se ejecuta un health check a `/health`.
- En Web puede requerir CORS habilitado en el backend o un proxy (Nginx).

## Pendientes / dudas
- Definir valores de `assets/.env` por entorno (dev/qa/prod).
- Documentar endpoints requeridos y permisos por rol.

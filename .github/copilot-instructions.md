# IOE App (Flutter)

## Architecture & data flow
- Entry point in [lib/main.dart](lib/main.dart): loads `assets/.env`, runs a backend health check, then starts Riverpod `ProviderScope`.
- Routing is centralized in [lib/core/router.dart](lib/core/router.dart) using GoRouter + Riverpod. Auth gating happens in the `redirect` callback and listens to the auth controller stream.

## API integration
- Base URL logic lives in [lib/core/env.dart](lib/core/env.dart):
  - Dev uses `http://localhost:3001`.
  - Web resolves `API_BASE_URL_WEB` (compile-time define or `.env`) or falls back to `/api`.
  - Mobile defaults to `http://192.168.10.234:3001` unless `API_BASE_URL` is provided.
- All HTTP goes through Dio in [lib/core/dio_provider.dart](lib/core/dio_provider.dart): injects `Authorization: Bearer` from `SharedPreferences`, and auto-refreshes on 401 via `/auth/refresh` once per request.

## Auth state pattern
- [lib/core/auth/auth_controller.dart](lib/core/auth/auth_controller.dart) boots from stored JWT, decodes payload (`sub`, `username`, `roleId`) and exposes a stream used by routing.
- Tokens are persisted in [lib/core/storage.dart](lib/core/storage.dart) with `SharedPreferences`.

## UI feature organization
- Feature pages live under [lib/features](lib/features) and are wired into nested routes in [lib/core/router.dart](lib/core/router.dart). Use existing feature folders (e.g., `masterdata`, `inventarios`) as templates.

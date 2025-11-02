# Flutter Web Frontend

This package provides the web frontends for yetAnotherBoilerplate:

- Customer app: entry `lib/main.dart`
- Admin portal: entry `lib/main_admin.dart`

The app is Flutter + Riverpod + go_router + Dio. It reads the API base URL from the `API_BASE_URL` compile-time define.

## Quick start (web)

Prereqs: Flutter SDK with web enabled.

- Customer app (Chrome):

```zsh
flutter run -d chrome -t lib/main.dart --dart-define API_BASE_URL=http://localhost:8000
```

- Admin portal (Chrome):

```zsh
flutter run -d chrome -t lib/main_admin.dart --dart-define API_BASE_URL=http://localhost:8000
```

The Home/Dashboard screen includes a "health" button that calls `GET /health/` on the backend and shows the status.

## Builds

- Customer web build:

```zsh
flutter build web --release --web-renderer canvaskit --dart-define API_BASE_URL=https://api.example.com
```

- Admin web build:

```zsh
flutter build web -t lib/main_admin.dart --release --web-renderer canvaskit --dart-define API_BASE_URL=https://api.example.com
```

## Docker

- Customer:

```zsh
# Build image (override API at build time if desired)
docker build -f Dockerfile.web -t yab-web:latest --build-arg API_BASE_URL=https://api.example.com .
```

- Admin:

```zsh
docker build -f Dockerfile.admin.web -t yab-admin:latest --build-arg API_BASE_URL=https://api.example.com .
```

Serve behind an ingress or proxy; the default NGINX config rewrites unknown paths to `index.html` for SPA routing. Adjust `/api/` proxying in `Dockerfile.web`'s embedded config as needed.

## Configuration

- `API_BASE_URL` (required): root URL for API calls, e.g., `http://localhost:8000`.
- Optional toggles from Docs/06-frontend.md (e.g., Sentry) can be added via additional `--dart-define` values.

## Notes

- Mobile targets (iOS/Android) will be added later. The project currently contains only the web wrapper (`web/`).
- Shared UI kit (`packages/ui_kit`) is not yet created; components use Material defaults.

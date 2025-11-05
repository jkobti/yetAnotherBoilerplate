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

Auth demo:

- Visit `/login` to sign in with email/password (uses `POST /api/auth/jwt/token/`).
- After login, Home shows your email via `GET /api/v1/me` and a Logout button.
- Admin Dashboard shows whether you're an admin based on `is_staff`.

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

### Use a config file (recommended)

Flutter supports passing many `--dart-define` values from a JSON file.

1) Copy the example file and fill in values:

```zsh
cp env/local.json.example env/local.json
```

2) Run with the config file:

```zsh
flutter run -d chrome -t lib/main.dart --dart-define-from-file=env/local.json
```

Admin portal:

```zsh
flutter run -d chrome -t lib/main_admin.dart --dart-define-from-file=env/local.json
```

The file format is simple JSON key/value pairs. See `env/local.json.example`.

### Push notifications (web demo)

This project includes a minimal FCM Web Push demo behind a feature flag. Foreground messages are handled inside the app; background notifications require configuring the service worker.

Enable with the following defines (replace with your Firebase Web App config):

```
--dart-define PUSH_NOTIFICATIONS_ENABLED=true \
--dart-define FIREBASE_API_KEY=... \
--dart-define FIREBASE_APP_ID=... \
--dart-define FIREBASE_MESSAGING_SENDER_ID=... \
--dart-define FIREBASE_PROJECT_ID=... \
--dart-define FIREBASE_VAPID_KEY=...
```

Optional:

```
--dart-define FIREBASE_AUTH_DOMAIN=... \
--dart-define FIREBASE_STORAGE_BUCKET=...
```

Run (customer):

```zsh
flutter run -d chrome -t lib/main.dart \
	--dart-define API_BASE_URL=http://localhost:8000 \
	--dart-define PUSH_NOTIFICATIONS_ENABLED=true \
	--dart-define FIREBASE_API_KEY=... \
	--dart-define FIREBASE_APP_ID=... \
	--dart-define FIREBASE_MESSAGING_SENDER_ID=... \
	--dart-define FIREBASE_PROJECT_ID=... \
	--dart-define FIREBASE_VAPID_KEY=...
```

Or, add these values into `env/local.json` and run with `--dart-define-from-file=env/local.json` as shown above.

Run (admin):

```zsh
flutter run -d chrome -t lib/main_admin.dart \
	--dart-define API_BASE_URL=http://localhost:8000 \
	--dart-define PUSH_NOTIFICATIONS_ENABLED=true \
	--dart-define FIREBASE_API_KEY=... \
	--dart-define FIREBASE_APP_ID=... \
	--dart-define FIREBASE_MESSAGING_SENDER_ID=... \
	--dart-define FIREBASE_PROJECT_ID=... \
	--dart-define FIREBASE_VAPID_KEY=...
```

Notes:
- Foreground: Incoming messages appear as Snackbars while the tab is active.
- Background: The service worker loads Firebase config from `/env/local.json` at runtime. Before running or building, sync your env into the web root so the worker can fetch it:

```zsh
./scripts/sync_env.sh
```

This copies `env/local.json` to `web/env/local.json`. Do not commit `web/env/` (it's gitignored). Ensure your `env/local.json` includes:

```
FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID
```

Optional:

```
FIREBASE_AUTH_DOMAIN, FIREBASE_STORAGE_BUCKET
```
- Backend: Set `FCM_SERVER_KEY` in the backend environment to enable the admin test endpoint `/admin/api/push/send-test`.

### Optional: Use a .env file

If you prefer a `.env` file, use the helper script to convert it to `--dart-define` flags at runtime. Create `packages/flutter_app/.env` with lines like:

```
API_BASE_URL=http://localhost:8000
PUSH_NOTIFICATIONS_ENABLED=true
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_VAPID_KEY=...
```

Then run:

```zsh
./scripts/run_with_env.zsh customer   # or: admin
```

The script reads `.env`, converts keys into `--dart-define` flags, and runs the chosen entrypoint.

## Notes

- Mobile targets (iOS/Android) will be added later. The project currently contains only the web wrapper (`web/`).
- Shared UI kit (`packages/ui_kit`) is not yet created; components use Material defaults.

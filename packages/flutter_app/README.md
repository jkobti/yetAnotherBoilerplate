# Flutter Frontend Apps

This package provides the shared Flutter frontend for yetAnotherBoilerplate:

- Customer app: entry `lib/main.dart`
- Admin portal: entry `lib/main_admin.dart`
- Android customer wrapper lives under `android/`

The app is Flutter + Riverpod + go_router + Dio. It reads the API base URL from the `API_BASE_URL` compile-time define.

## Quick start

Prereqs: Flutter SDK with web and Android enabled (`flutter config --enable-web --enable-android`).

## Install dependencies

Install pub packages for this package:

```zsh
cd packages/flutter_app
flutter pub get
```

If you use FVM:

```zsh
cd packages/flutter_app
fvm flutter pub get
```

If the app is already running, restart it after adding new dependencies.

### Run (web)

- Customer app (Chrome):

```zsh
flutter run -d chrome -t lib/main.dart --dart-define API_BASE_URL=http://localhost:8000
```

- Admin portal (Chrome):

```zsh
flutter run -d chrome -t lib/main_admin.dart --dart-define API_BASE_URL=http://localhost:8000
```

### Run (Android)

Make sure an Android emulator or device is available (e.g., `flutter devices`). Then run:

```zsh
flutter run -d android -t lib/main.dart --dart-define-from-file=env/local.json
```

Alternatively, the helper script infers `--dart-define` values from `.env`:

```zsh
./scripts/run_with_env.zsh customer android
```

The Home/Dashboard screen includes a "health" button that calls `GET /health/` on the backend and shows the status.

Auth demo:

- Visit `/login` to sign in with email/password (uses `POST /api/auth/jwt/token/`).
- After login, Home shows your email via `GET /api/v1/me` and a Logout button.
- Admin Dashboard shows whether you're an admin based on `is_staff`.

## Builds

- Customer web build:

```zsh
 flutter build web --release --web-renderer canvaskit --dart-define API_BASE_URL=http://localhost:8000
```

- Admin web build:

```zsh
 flutter build web -t lib/main_admin.dart --release --web-renderer canvaskit --dart-define API_BASE_URL=http://localhost:8000
```

- Customer Android build (Play bundle):

```zsh
flutter build appbundle -t lib/main.dart --dart-define-from-file=env/prod.json
```

For sideloading or emulator testing you can also build an APK:

```zsh
flutter build apk -t lib/main.dart --dart-define-from-file=env/local.json
```

## Docker
The repository includes two production-style multi-stage Dockerfiles:

- `Dockerfile.web` (customer app) → Flutter SDK build stage → NGINX static runtime
- `Dockerfile.admin.web` (admin portal) → Flutter SDK build stage → NGINX static runtime

Both embed configuration at build time using `--build-arg` → `--dart-define`. This means changes to values like `API_BASE_URL` require rebuilding the image (future enhancement: runtime config shim via injected JSON file before serving).

### Build Images

Customer (web) (local backend on 8000, run from repo root for path dependency):
```zsh
docker build -f packages/flutter_app/Dockerfile.web -t yab-web:dev \
  --build-arg API_BASE_URL=http://localhost:8000 \
  --build-arg PUSH_NOTIFICATIONS_ENABLED=true \
  --build-arg FIREBASE_API_KEY=public-key \
  --build-arg FIREBASE_APP_ID=app-id \
  --build-arg FIREBASE_MESSAGING_SENDER_ID=sender-id \
  --build-arg FIREBASE_PROJECT_ID=project-id \
  --build-arg FIREBASE_VAPID_KEY=vapid-key \
  --build-arg FIREBASE_AUTH_DOMAIN=project.firebaseapp.com \
  --build-arg FIREBASE_STORAGE_BUCKET=project.appspot.com \
  .
```

Admin (web) (local backend on 8000, run from repo root):
```zsh
docker build -f packages/flutter_app/Dockerfile.admin.web -t yab-admin:dev \
  --build-arg API_BASE_URL=http://localhost:8000 \
  --build-arg PUSH_NOTIFICATIONS_ENABLED=false \
  .
```

Minimal builds (only API_BASE_URL - local, from repo root):
```zsh
docker build -f packages/flutter_app/Dockerfile.web -t yab-web:dev --build-arg API_BASE_URL=http://localhost:8000 .
docker build -f packages/flutter_app/Dockerfile.admin.web -t yab-admin:dev --build-arg API_BASE_URL=http://localhost:8000 .

Production builds: replace `http://localhost:8000` with your deployed API host (e.g. `https://api.example.com`) and, if using HTTPS, ensure the backend `ALLOWED_HOSTS` and CORS settings reflect the production domain.

### Build Images from JSON env (prod/local)

Instead of passing many `--build-arg` flags manually, use the helper script to convert a JSON file (e.g. `env/prod.json`) into build arguments. This keeps the file out of the image context (due to `.dockerignore`) and avoids copying sensitive/non-public data.

```zsh
# Customer prod build (using env/prod.json values)
cd packages/flutter_app
./scripts/inject_firebase_config.sh env/prod.json   # inject service worker config (optional)
./scripts/docker_build_from_env_json.zsh web packages/flutter_app/env/prod.json yab-web:prod Dockerfile.web

# Admin prod build
./scripts/docker_build_from_env_json.zsh admin packages/flutter_app/env/prod.json yab-admin:prod Dockerfile.admin.web
```

If `API_BASE_URL` is missing in the JSON file, the script defaults it to `http://localhost:8000`. Run the script from any directory; it detects the repo root to include the `ui_kit` path dependency.

To verify which build args were applied:

```zsh
docker history --no-trunc yab-web:prod | grep -i buildarg || true
```

### Using env/prod.json at runtime (flutter run)

For a production-like local test with the same file:

```zsh
flutter run -d chrome -t lib/main.dart --dart-define-from-file=env/prod.json
```

Admin portal:

```zsh
flutter run -d chrome -t lib/main_admin.dart --dart-define-from-file=env/prod.json
```

### Service worker config (Firebase) with alternate env file

The injection script now accepts an env file path:

```zsh
./scripts/inject_firebase_config.sh env/prod.json
```

This will embed values from `env/prod.json` if push is enabled (`PUSH_NOTIFICATIONS_ENABLED=true`) and necessary Firebase fields are present.

### Secret Handling Guidance

Firebase web config keys are public identifiers, not secrets. Avoid placing true secrets (API private keys, auth tokens) in `env/prod.json` if they would be baked into the build via `--dart-define`. For sensitive values consider:
- Runtime served `config.js` (mutable without rebuild).
- Backend proxy endpoints requiring auth.
- Separate encrypted secret management for the native mobile apps.

Future enhancement: add a small pre-start hook to load a ConfigMap-based `config.js` when running under Kubernetes for safer runtime overrides.
```

## Local JSON Tutorial (Customer & Admin)

Use a single JSON file (`env/local.json`) to drive both customer and admin apps locally. This avoids long lists of manual `--dart-define` flags and keeps values versioned.

### 1. Create / Update `env/local.json`

```zsh
cp env/local.json.example env/local.json  # if not present
```
Edit values (remove any ` (optional)` suffix text):

```jsonc
{
  "API_BASE_URL": "http://localhost:8000",  // change if backend mapped differently
  "PUSH_NOTIFICATIONS_ENABLED": "true",
  "FIREBASE_API_KEY": "your-key",
  "FIREBASE_APP_ID": "your-app-id",
  "FIREBASE_MESSAGING_SENDER_ID": "your-sender-id",
  "FIREBASE_PROJECT_ID": "your-project-id",
  "FIREBASE_VAPID_KEY": "your-vapid-key",
  "FIREBASE_AUTH_DOMAIN": "your-project.firebaseapp.com",
  "FIREBASE_STORAGE_BUCKET": "your-project.appspot.com"
}
```

If you run the backend container with a remapped port e.g. `docker run -p 8080:8000`, set `API_BASE_URL` to `http://localhost:8080`.

### 2. Run Customer & Admin with JSON

From repo root (explicit paths) or after `cd packages/flutter_app` (drop the leading path):

```zsh
flutter run -d chrome -t packages/flutter_app/lib/main.dart --dart-define-from-file=packages/flutter_app/env/local.json
flutter run -d chrome -t packages/flutter_app/lib/main_admin.dart --dart-define-from-file=packages/flutter_app/env/local.json
```

Change to Android:

```zsh
flutter run -d android -t packages/flutter_app/lib/main.dart --dart-define-from-file=packages/flutter_app/env/local.json
```

Restart the command after editing the JSON; hot reload does not pick up changed compile-time defines.

### 3. Optional: Service Worker Firebase Injection

If `PUSH_NOTIFICATIONS_ENABLED` is true and Firebase keys are present, inject them into the service worker before building Docker images:

```zsh
cd packages/flutter_app
./scripts/inject_firebase_config.sh env/local.json
```

### 4. Build Docker Images from JSON (Static)

```zsh
packages/flutter_app/scripts/docker_build_from_env_json.zsh web packages/flutter_app/env/local.json yab-web:local Dockerfile.web
packages/flutter_app/scripts/docker_build_from_env_json.zsh admin packages/flutter_app/env/local.json yab-admin:local Dockerfile.admin.web
```

Run them:

```zsh
docker run --rm -p 8080:80 yab-web:local
docker run --rm -p 8081:80 yab-admin:local
```

### 5. Verify Embedded Config (Docker)

Inspect the service worker for Firebase + API values:

```zsh
docker exec <container> grep -E 'FIREBASE|API_BASE_URL' /usr/share/nginx/html/firebase-messaging-sw.js || echo 'missing'
```

### 6. Common Pitfalls

| Issue                             | Cause                           | Fix                                          |
| --------------------------------- | ------------------------------- | -------------------------------------------- |
| Values still show old API host    | Forgot to restart `flutter run` | Stop process & rerun with JSON file          |
| `authDomain` shows `(optional)`   | Suffix left in JSON             | Remove ` (optional)` text; rebuild/run       |
| 404s for API calls                | Wrong `API_BASE_URL` port       | Match backend mapped host port (e.g. 8080)   |
| Missing Firebase config in Docker | Didn't run inject script        | Run `inject_firebase_config.sh` then rebuild |

### 7. Switching Between Local & Prod

Keep both `env/local.json` and `env/prod.json`. Swap in commands:

```zsh
flutter run -d chrome -t lib/main.dart --dart-define-from-file=env/prod.json
```

Docker build (customer example):

```zsh
packages/flutter_app/scripts/docker_build_from_env_json.zsh web packages/flutter_app/env/prod.json yab-web:prod Dockerfile.web
```

### 8. Using `.env` Instead of JSON

If you prefer key-value `.env` format for quick iteration:

```zsh
./scripts/run_with_env.zsh customer chrome
./scripts/run_with_env.zsh admin chrome
```

This does not read `local.json`; it maps each line to `--dart-define` flags.

### 9. Clean Up Containers

```zsh
docker rm -f yab-web:local || true
docker rm -f yab-admin:local || true
```

*(Use container names you actually ran; if using `--rm` they disappear automatically.)*

### 10. Next Enhancements

Planned: runtime `config.js` injection (Kubernetes ConfigMap) for mutable post-build config, and CI scanning (Trivy) + digest pinning.


### Run Locally (Static Serving)

Customer:
```zsh
docker run --rm -p 8080:80 yab-web:dev
# Open http://localhost:8080
```

Admin:
```zsh
docker run --rm -p 8081:80 yab-admin:dev
# Open http://localhost:8081
```

Both images serve content from NGINX with a SPA fallback: unknown paths rewrite to `index.html`.

### API Connectivity

In Kubernetes you will typically terminate TLS and route `/api/` at the ingress layer to the backend service. The new `Dockerfile.web` removed its inline `/api/` proxy block to avoid coupling the static container to runtime routing. For local sidecar experiments you can create a custom nginx.conf and COPY it in a derived image:

```dockerfile
FROM yab-web:dev AS base
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

### Build-Time vs Runtime Config

Current images bake config at build. For runtime mutability later consider:
- Injecting a small `config.js` before container start (mounted ConfigMap) that sets `window.__APP_CONFIG__` consumed by the app.
- Serving a JSON config endpoint that the app fetches on bootstrap (trade-off: extra request & caching complexity).

### Firebase / Push Variables

Firebase web config values (API key, project ID, etc.) are public client identifiers—not secrets. Treat them as configuration. Still avoid leaking unrelated sensitive data via build args.

### Image Optimization Notes

- Docker caching improved: `pubspec.yaml` + `pubspec.lock` copied before full source to avoid reinstalling dependencies each change.
- `.dockerignore` added to prevent sending build outputs and tooling metadata.
- Future: pre-compress assets (gzip/brotli) and add appropriate `Content-Encoding` via ingress or NGINX tweaks.
- Pin base image digests and run vulnerability scans (e.g., Trivy) in CI.

### Example CI Steps (Pseudo)

```yaml
steps:
  - name: Build customer web
    run: docker build -f packages/flutter_app/Dockerfile.web -t ghcr.io/yourorg/web:sha-${GITHUB_SHA} .
  - name: Build admin web
    run: docker build -f packages/flutter_app/Dockerfile.admin.web -t ghcr.io/yourorg/admin:sha-${GITHUB_SHA} .
  - name: Scan images
    run: trivy image ghcr.io/yourorg/web:sha-${GITHUB_SHA}
```

### Rebuild on Config Change Cheat Sheet

Change build-time values? Re-run `docker build ...` with updated `--build-arg` flags. Local development (hot reload) should use `flutter run` directly instead of rebuilding images after each change.

### Troubleshooting

- Missing API_URL after build: confirm `--build-arg API_BASE_URL=...` supplied—otherwise default `http://localhost:8000` may fail in remote environment.
- Stale frontend calling old backend: verify a fresh image tag; browsers may cache aggressively—force reload (Shift+Reload) or cache-busting query param.
- Push notifications not appearing: ensure `PUSH_NOTIFICATIONS_ENABLED=true` and that the service worker (`firebase-messaging-sw.js`) contains injected Firebase config (run `./scripts/inject_firebase_config.sh` prior to build).

## Configuration

- `API_BASE_URL` (required): root URL for API calls, e.g., `http://localhost:8000`.
- Optional toggles from Docs/06-frontend.md (e.g., Sentry) can be added via additional `--dart-define` values.

Port mapping tip: If you run the backend container with a different host port (e.g. `docker run -p 8080:8000`), set `API_BASE_URL=http://localhost:8080` (the host-facing port). Inside Kubernetes, this will later become the ingress host (e.g. `https://api.local.dev`). Keep `ALLOWED_HOSTS` in the backend updated if you change the hostname.

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

**Recommended approach (build-time injection):**

This approach embeds the Firebase config directly in the service worker at build time, avoiding the need to expose a separate JSON file.

1. Add Firebase config to `env/local.json`:

```json
{
  "API_BASE_URL": "http://localhost:8000",
  "PUSH_NOTIFICATIONS_ENABLED": "true",
  "FIREBASE_API_KEY": "your-api-key",
  "FIREBASE_APP_ID": "your-app-id",
  "FIREBASE_MESSAGING_SENDER_ID": "your-sender-id",
  "FIREBASE_PROJECT_ID": "your-project-id",
  "FIREBASE_VAPID_KEY": "your-vapid-key",
  "FIREBASE_AUTH_DOMAIN": "your-project.firebaseapp.com",
  "FIREBASE_STORAGE_BUCKET": "your-project.appspot.com"
}
```

2. Inject the config into the service worker before running:

```zsh
./scripts/inject_firebase_config.sh
```

3. Run the app:

```zsh
flutter run -d chrome -t lib/main.dart --dart-define-from-file=env/local.json
```

**Alternative approach (runtime fetch - less secure):**

The old approach fetches config from `/env/local.json` at runtime. This exposes a separate JSON endpoint that's easy to discover. If you prefer this approach:

```zsh
./scripts/sync_env.sh  # Copies env/local.json to web/env/local.json
flutter run -d chrome -t lib/main.dart --dart-define-from-file=env/local.json
```

**Security note:**

Firebase Web App config values (API Key, App ID, etc.) are **client-side credentials** that are exposed in the browser anyway - they're not secret. However, the build-time injection approach is preferred because:
- It doesn't create a separate `/env/local.json` endpoint that's easy to discover
- The config is embedded in the service worker file itself
- The service worker is still publicly accessible, but it's less obvious than a dedicated config endpoint

**Notes:**
- Foreground: Incoming messages appear as Snackbars while the tab is active.
- Background: The service worker handles notifications when the app is not in focus.
- Backend: Set `GOOGLE_APPLICATION_CREDENTIALS` or `GOOGLE_SERVICE_ACCOUNT_JSON` in the backend environment to enable the admin test endpoint `/admin/api/push/send-test`.

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
./scripts/run_with_env.zsh customer           # defaults to Chrome
./scripts/run_with_env.zsh customer android   # run on Android
./scripts/run_with_env.zsh admin chrome       # admin portal on Chrome
```

The script reads `.env`, converts keys into `--dart-define` flags, and runs the chosen entrypoint.

## Notes

- Android support is available via the committed `android/` wrapper. iOS will follow once the native project is generated.
- The shared UI kit lives in `packages/ui_kit` and provides the `YabTheme` helpers used by the app shells.
- `android/app/src/main/AndroidManifest.xml` enables cleartext traffic to reach `http://localhost:8000` during development. Swap to HTTPS or a stricter network security config before production releases.

## Static content pages (About, Privacy Policy, Terms)

The customer app includes static content pages rendered from Markdown:

- Routes: `/about`, `/privacy`, `/terms`
- Source files: `assets/content/about.md`, `assets/content/privacy.md`, `assets/content/terms.md`
- Asset registration: listed under `flutter.assets` in `pubspec.yaml`

Rendering details:

- Markdown is rendered with the `flutter_markdown` package inside a centered, max-width container.
- Scrolling is handled by the top-level scaffold; the Markdown widget itself does not scroll independently.
- The footer is appended after the page content. It stays at the bottom of the viewport for short pages and appears after scrolling for long pages.

Flutter Web asset path nuance:

- Web builds serve assets under `assets/…`. The app uses a small `kIsWeb` check to load `content/*.md` on web and `assets/content/*.md` on other platforms, so no additional configuration is required when adding new Markdown files—just register them in `pubspec.yaml`.

Hot reload vs assets:

- Asset changes (Markdown files) are picked up reliably after a hot restart. For production builds, run `flutter build web` to bundle updated assets.

Extending with new pages:

1) Create a new Markdown file under `assets/content/` and register it in `pubspec.yaml`.
2) Add a simple page widget that loads the file with `rootBundle.loadString(...)` following the existing pattern.
3) Add a route in `lib/core/router.dart` and a link in the footer if desired.

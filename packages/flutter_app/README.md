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
flutter build web --release --web-renderer canvaskit --dart-define API_BASE_URL=https://api.example.com
```

- Admin web build:

```zsh
flutter build web -t lib/main_admin.dart --release --web-renderer canvaskit --dart-define API_BASE_URL=https://api.example.com
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

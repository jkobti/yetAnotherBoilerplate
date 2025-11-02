# Frontend Application Stack

This document captures the detailed guidance for building and operating the client applications that ship with the yetanotherboilerplate project. A single Flutter codebase targets web, iOS, and Android; this doc expands on the core stack, optional integrations, and platform-specific release processes.

> Current status (Nov 2025): The Flutter project is initialized with web support and two entry points: `lib/main.dart` (Customer) and `lib/main_admin.dart` (Admin). Mobile platform wrappers (iOS/Android) will be added later.

## 1. Core Stack

| Layer                | Recommendation                             | Notes                                                     |
| :------------------- | :----------------------------------------- | :-------------------------------------------------------- |
| Framework            | Flutter (stable channel)                   | Shared UI toolkit across web, iOS, Android.               |
| State management     | Riverpod or Bloc                           | Pick one consistently; examples assume Riverpod.          |
| API client           | `dio` + generated clients from OpenAPI     | Backed by the backend OpenAPI schema (`drf-spectacular`). |
| Design system        | Custom component library in `packages/ui/` | Encapsulate typography, spacing, color tokens.            |
| Routing              | `go_router`                                | Declarative deep-link friendly navigation.                |
| Analytics (optional) | Segment (or Firebase Analytics)            | Feature-flagged via environment variables.                |

### Project layout (conceptual)

```
packages/
	web/
		lib/
			main_web.dart
	ios/
		Runner/
			AppDelegate.swift
	android/
		app/src/main/kotlin/.../MainActivity.kt
	shared_flutter/
		lib/
			main.dart          # entry point used by mobile builds
			src/
				app.dart
				features/
				shared/
```

`packages/shared_flutter/` contains the bulk of the Flutter application. Platform folders (`web/`, `ios/`, `android/`) wrap the shared code with platform-specific build targets and native configuration.

## 2. Platform Notes

### 2.1 Web

- Serve via static hosting (NGINX, CloudFront, Firebase Hosting) behind the Kubernetes ingress.
- Respect the `API_BASE_URL` environment variable injected at build time (use `--dart-define`).
- Ensure service workers are optional; disable them for environments where caching complicates rollbacks.
- Provide an accessibility audit checklist (Lighthouse, axe) before production launches.

### 2.2 iOS

- Minimum version: iOS 14.
- Xcode project lives in `packages/ios/`; use `flutter build ipa` within CI.
- Configure push notifications via APNs when feature flagged; use secrets-backed `IOS_PUSH_CERT` values in CI.
- Enforce automatic code signing via `MATCH` or App Store Connect API keys stored in the CI secret store.
- Distribute through TestFlight for pre-release validation.

### 2.3 Android

- Minimum version: Android 8.0 (API level 26).
- Gradle build wrappers are committed and pinned; use `./gradlew assembleRelease` via `flutter build apk`.
- Upload signing keys to a secure secret manager; wire them into CI using environment variables.
- Support Play App Signing to simplify key rotation.
- Release tracks: internal testing -> closed testing -> production.

## 3. Feature Modules (Optional)

| Feature               | Purpose                           | Implementation Notes                                                          | Toggle                                                     |
| :-------------------- | :-------------------------------- | :---------------------------------------------------------------------------- | :--------------------------------------------------------- |
| Error reporting       | Capture runtime exceptions        | `sentry_flutter` with environment-specific DSN                                | `FRONTEND_SENTRY_DSN` env var; absent = disabled           |
| Authentication flow   | Login/logout, password reset, MFA | Flutter screens backed by backend endpoints (`/auth/...`)                     | Feature flagged server-side; UI hides routes when disabled |
| Feature flags         | Gradual rollouts                  | `unleash_proxy_client_flutter` (default)                                      | `FEATURE_FLAG_CLIENT_ENABLED`                              |
| Push notifications    | Realtime alerts                   | Firebase Cloud Messaging; wraps APNs on iOS                                   | `PUSH_NOTIFICATIONS_ENABLED`                               |
| WebSocket client      | Live updates                      | `web_socket_channel` or `stomp_dart_client`, point to `/ws/` backend endpoint | `REALTIME_ENABLED`                                         |
| Direct object storage | Upload/download large files       | Request pre-signed URLs from backend; upload via `http`                       | `OBJECT_STORAGE_DIRECT_ACCESS`                             |

> Tip: Keep optional modules isolated behind a `FeatureToggles` provider so components remain testable even when a module is switched off.

## 4. Configuration & Environment Variables

| Variable                       | Description                                                          |
| :----------------------------- | :------------------------------------------------------------------- |
| `API_BASE_URL`                 | Root URL for REST/GraphQL calls.                                     |
| `FRONTEND_SENTRY_DSN`          | Enables Sentry when provided.                                        |
| `PUSH_NOTIFICATIONS_ENABLED`   | Boolean string (`true` / `false`) controlling FCM/APNs registration. |
| `REALTIME_ENABLED`             | Enables WebSocket clients.                                           |
| `FEATURE_FLAG_CLIENT_ENABLED`  | Turns on Unleash (or other) SDK initialization.                      |
| `OBJECT_STORAGE_DIRECT_ACCESS` | Enables pre-signed upload flows.                                     |

Use `flutter --dart-define-from-file=env/local.json` for local development and Helm chart ConfigMaps + Secrets for web deployments. Mobile builds should inject values during CI using `--dart-define` arguments sourced from the secure secret store.

## 5. Development Workflow

1. Run the backend locally (or via remote tunnel) so the API is reachable.
2. Start Flutter development server: `flutter run -d chrome` for web or attach to simulators/emulators for mobile.
3. Watch mode: rely on Hot Reload; ensure state management resets correctly when toggles change.
4. Golden tests: store reference images per component to avoid regressions; run with `flutter test --update-goldens` only when intentional.

## 6. Build & Release Workflow

| Stage            | Web                                      | iOS                                                          | Android                                |
| :--------------- | :--------------------------------------- | :----------------------------------------------------------- | :------------------------------------- |
| Lint/Test        | `flutter analyze` + `flutter test`       | same command executed on macOS runners                       | same command executed on Linux runners |
| Build            | `flutter build web` with cache busting   | `flutter build ipa --export-options-plist=...`               | `flutter build appbundle`              |
| Artifact storage | Upload to object storage (e.g., GCS, S3) | Store IPA in CI artifact store before uploading to App Store | Upload AAB to Play Console             |
| Deployment       | Sync to CDN bucket + invalidate caches   | App Store Connect (TestFlight/Production)                    | Google Play tracks                     |

Use CI matrix builds to parallelize platform builds. Gate releases on automated tests and smoke tests against staging environments.

## 7. Testing Strategy

- **Unit tests:** Validate widgets and state providers in isolation.
- **Integration tests:** Use `flutter drive` to run end-to-end flows against staging APIs.
- **Visual regression:** Golden tests per design system component.
- **Accessibility checks:** Leverage `flutter_test` semantics assertions and run Lighthouse/Axe for web builds.
- **Device coverage:** Maintain a device matrix (e.g., iPhone SE, iPhone 14 Pro, Pixel 5, Pixel 8, iPad) in CI or manual QA.

## 8. References

- [Flutter documentation](https://docs.flutter.dev)
- [Riverpod](https://riverpod.dev) / [Bloc](https://bloclibrary.dev)
- [Dio HTTP client](https://pub.dev/packages/dio)
- [Sentry for Flutter](https://docs.sentry.io/platforms/flutter/)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Unleash proxy client for Flutter](https://github.com/Unleash/unleash-flutter-client)

---

This document should evolve alongside the client applications. When adding significant features or new platform targets (e.g., desktop), extend this guide and reference it from `Docs/main.md`.

## 9. Admin Portal (Webapp)

A dedicated web application must be included for administrators. Its scope is intentionally narrow and security-focused:

- Display operational and/or business statistics relevant to admins (e.g., health, usage metrics, job statuses).
- Trigger privileged actions that are allowed only for administrators (e.g., toggling features, kicking off jobs, running maintenance tasks).

Key guidelines:

- Access control: require authentication and an admin role/claim; hide routes and UI for non-admin users and block API calls server-side.
- Implementation: build as a web-only target; reuse the shared design system (`packages/ui/`) for consistency.
- Routing: deploy on a separate host (e.g., `admin.example.com`) or under a reserved path (e.g., `/admin`) with stricter caching and security headers.
- API surface: call admin-only backend endpoints that enforce RBAC and are audited; see `Docs/backend-api.md`.
- Observability: optionally embed or deep-link to dashboards (e.g., Grafana) using secure, least-privilege access patterns.

Suggested environment variables:

| Variable                | Description                                              |
| :---------------------- | :------------------------------------------------------- |
| `ADMIN_PORTAL_ENABLED`  | Feature gate for showing the admin portal entry points.  |
| `ADMIN_PORTAL_BASE_URL` | External URL of the deployed admin portal (if separate). |

Build & deploy follow the same web pipeline as other Flutter web targets; see `Docs/k8s.md` for routing and ingress setup.

---
applyTo: "packages/flutter_app/**,packages/ui_kit/**"
---

# Shared Flutter folders instructions

- Use the project’s Flutter SDK version as defined in `pubspec.yaml`.
- All commands in these folders must use the defined environment (e.g., `flutter run`, `flutter test`, `dart analyze`).
- When adding dependencies, update `pubspec.yaml`, run `flutter pub get`, and commit `pubspec.yaml` (and `pubspec.lock` if applicable).
- For `packages/ui_kit` (the shared UI kit): components/widgets should be decoupled, accept data via props/injections, and be reusable across apps.
- Write widget tests or integration tests for new UI components/screens in both folders; use `flutter test` or integration test setups.
- Use linting/formatting (`flutter format`, `dart analyze`) and ensure no analyzer errors/warnings before merge.
- When making breaking changes to widgets/API in `ui_kit`, update version in `pubspec.yaml`, add CHANGELOG entry, and inform dependent apps (`flutter_app`) of changes.
- Keep UI logic (widgets, themes, styling) separate from business/data logic; apps should depend on `ui_kit` for UI-only code, not embed duplication.

/// Application mode configuration for B2B/B2C support.
///
/// - `b2c`: Personal workspace auto-created on registration, team features hidden in UI
/// - `b2b`: Users must explicitly create/join organizations, full team management UI
enum AppMode {
  b2c,
  b2b;

  /// Whether this mode automatically creates a personal workspace on registration.
  bool get autoCreatesPersonalWorkspace => this == AppMode.b2c;

  /// Whether team management features should be shown in UI.
  bool get showTeamFeatures => this == AppMode.b2b;
}

/// Helper class to access app mode configuration.
class AppConfig {
  AppConfig._();

  static const String _appModeEnv = String.fromEnvironment(
    'APP_MODE',
    defaultValue: 'b2c',
  );

  /// Current application mode, read from build-time configuration.
  static AppMode get appMode {
    switch (_appModeEnv.toLowerCase()) {
      case 'b2b':
        return AppMode.b2b;
      case 'b2c':
      default:
        return AppMode.b2c;
    }
  }

  /// Whether we're in B2C mode (personal workspace, hidden team features).
  static bool get isB2C => appMode == AppMode.b2c;

  /// Whether we're in B2B mode (explicit org creation, full team UI).
  static bool get isB2B => appMode == AppMode.b2b;
}

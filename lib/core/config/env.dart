/// Build-time settings, injected with `--dart-define-from-file=env/<name>.json`.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5206',
  );

  /// The two pages payOS sends the buyer back to. Matched by path only, so a different host (or a different
  /// environment) still works.
  static const payosReturnPath = String.fromEnvironment(
    'PAYOS_RETURN_PATH',
    defaultValue: '/payments/payos/return',
  );
  static const payosCancelPath = String.fromEnvironment(
    'PAYOS_CANCEL_PATH',
    defaultValue: '/payments/payos/cancel',
  );

  static const showDevTools = bool.fromEnvironment('SHOW_DEV_TOOLS');
}

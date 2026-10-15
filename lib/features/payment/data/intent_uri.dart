/// Banking apps are opened from the payOS page with an Android `intent://` link:
///
///     intent://host/path?x=1#Intent;scheme=momo;package=com.mservice.momotransfer;S.browser_fallback_url=https%3A%2F%2F...;end
///
/// A WebView cannot follow it, so this reads out the address to launch (`momo://host/path?x=1`), the package and the
/// address to open in the page when the app is not installed.
class IntentTarget {
  const IntentTarget({required this.launchUri, this.package, this.fallbackUrl});

  /// The address to hand to the system (`scheme://host/path?query`).
  final Uri launchUri;
  final String? package;

  /// `S.browser_fallback_url`: where to go when no app can open `launchUri`. Only ever http(s).
  final Uri? fallbackUrl;
}

/// Reads an `intent://` link, or returns null when it is not one or has no usable scheme.
IntentTarget? parseIntentUri(String raw) {
  const prefix = 'intent://';
  if (!raw.toLowerCase().startsWith(prefix)) return null;

  final hashIndex = raw.indexOf('#Intent;');
  final body = hashIndex < 0 ? raw.substring(prefix.length) : raw.substring(prefix.length, hashIndex);
  final extras = hashIndex < 0 ? '' : raw.substring(hashIndex + '#Intent;'.length);

  String? scheme;
  String? package;
  String? fallback;
  for (final part in extras.split(';')) {
    if (part.isEmpty || part == 'end') continue;
    final eq = part.indexOf('=');
    if (eq < 0) continue;
    final key = part.substring(0, eq);
    final value = part.substring(eq + 1);
    switch (key) {
      case 'scheme':
        scheme = value;
      case 'package':
        package = value;
      case 'S.browser_fallback_url':
        fallback = Uri.decodeComponent(value);
    }
  }

  if (scheme == null || scheme.isEmpty) return null;
  // A scheme that is itself a web address would turn this into an ordinary link; nothing to hand over.
  if (scheme == 'http' || scheme == 'https') return null;

  final launch = Uri.tryParse('$scheme://$body');
  if (launch == null) return null;

  Uri? fallbackUri;
  if (fallback != null) {
    final parsed = Uri.tryParse(fallback);
    if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) fallbackUri = parsed;
  }

  return IntentTarget(launchUri: launch, package: package, fallbackUrl: fallbackUri);
}

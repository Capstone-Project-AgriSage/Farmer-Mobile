import '../../../core/config/env.dart';

/// What payOS puts on the link it sends the buyer back to (`?code=00&id=...&cancel=false&status=PAID&orderCode=...`),
/// plus the `simulated=1` flag of the test gateway. It is only a hint for choosing the first screen: the payment is
/// always confirmed with the server.
class PayosReturnParams {
  const PayosReturnParams({
    this.code,
    this.id,
    this.cancel,
    this.status,
    this.orderCode,
    this.simulated = false,
  });

  final String? code;
  final String? id;
  final bool? cancel;
  final String? status;
  final String? orderCode;
  final bool simulated;

  factory PayosReturnParams.fromUri(Uri uri) {
    final q = uri.queryParameters;
    final cancel = q['cancel']?.toLowerCase();
    return PayosReturnParams(
      code: q['code'],
      id: q['id'],
      cancel: cancel == null ? null : cancel == 'true',
      status: q['status'],
      orderCode: q['orderCode'],
      simulated: q['simulated'] == '1',
    );
  }

  /// The buyer pressed "cancel" on the payOS page.
  bool get isCancelled => cancel == true || status?.toUpperCase() == 'CANCELLED';
}

sealed class PayosNavigation {
  const PayosNavigation();
}

/// Let the WebView load it.
class AllowNavigation extends PayosNavigation {
  const AllowNavigation();
}

/// payOS sent the buyer back to us (success, failure or cancel): do not load the page, show the result instead.
class ReturnNavigation extends PayosNavigation {
  const ReturnNavigation(this.params, {required this.cancelled});
  final PayosReturnParams params;
  final bool cancelled;
}

/// A bank app or another app: hand it to the system.
class ExternalNavigation extends PayosNavigation {
  const ExternalNavigation(this.uri);
  final Uri uri;
}

/// Decides what to do with each address the payOS WebView is about to open.
///
/// The return and cancel pages are recognised by their **path only**, so a different host (the web app's address, a
/// tunnel, another environment) still works. Both paths come from the build configuration.
class PayosUrlMatcher {
  PayosUrlMatcher({required String returnPath, required String cancelPath})
      : _returnPath = _normalize(returnPath),
        _cancelPath = _normalize(cancelPath);

  PayosUrlMatcher.fromEnv() : this(returnPath: Env.payosReturnPath, cancelPath: Env.payosCancelPath);

  final String _returnPath;
  final String _cancelPath;

  static const _webSchemes = {'http', 'https'};
  // Pages a browser opens by itself; they must not be thrown at another app.
  static const _inlineSchemes = {'about', 'data', 'blob', 'javascript'};

  static String _normalize(String path) {
    var p = path.trim();
    if (!p.startsWith('/')) p = '/$p';
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p.toLowerCase();
  }

  PayosNavigation decide(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (_webSchemes.contains(scheme)) {
      final path = _normalize(uri.path.isEmpty ? '/' : uri.path);
      if (path == _cancelPath) {
        return ReturnNavigation(PayosReturnParams.fromUri(uri), cancelled: true);
      }
      if (path == _returnPath) {
        final params = PayosReturnParams.fromUri(uri);
        return ReturnNavigation(params, cancelled: params.isCancelled);
      }
      return const AllowNavigation();
    }

    if (scheme.isEmpty || _inlineSchemes.contains(scheme)) return const AllowNavigation();
    return ExternalNavigation(uri);
  }
}

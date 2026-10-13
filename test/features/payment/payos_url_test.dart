import 'package:farmer_mobile/features/payment/data/intent_uri.dart';
import 'package:farmer_mobile/features/payment/data/payos_url_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final matcher = PayosUrlMatcher(returnPath: '/payments/payos/return', cancelPath: '/payments/payos/cancel');

  PayosNavigation decide(String url) => matcher.decide(Uri.parse(url));

  group('PayosUrlMatcher', () {
    test('the return page is recognised and its parameters are read', () {
      final result = decide(
        'http://localhost:5174/payments/payos/return?code=00&id=abc123&cancel=false&status=PAID&orderCode=1700000001',
      );
      expect(result, isA<ReturnNavigation>());
      final r = result as ReturnNavigation;
      expect(r.cancelled, isFalse);
      expect(r.params.code, '00');
      expect(r.params.id, 'abc123');
      expect(r.params.status, 'PAID');
      expect(r.params.orderCode, '1700000001');
      expect(r.params.simulated, isFalse);
    });

    test('the host does not matter, only the path (another environment, a tunnel, https)', () {
      for (final url in [
        'https://app.agrisage.vn/payments/payos/return?status=PAID',
        'http://10.0.2.2:5174/payments/payos/return',
        'https://abc.ngrok.app/payments/payos/return/',
      ]) {
        expect(decide(url), isA<ReturnNavigation>(), reason: url);
      }
    });

    test('the cancel page means cancelled whatever its parameters say', () {
      final r = decide('http://localhost:5174/payments/payos/cancel?code=00&status=PAID') as ReturnNavigation;
      expect(r.cancelled, isTrue);
    });

    test('the return page with cancel=true or status=CANCELLED is a cancel', () {
      expect((decide('http://x/payments/payos/return?cancel=true') as ReturnNavigation).cancelled, isTrue);
      expect((decide('http://x/payments/payos/return?status=CANCELLED') as ReturnNavigation).cancelled, isTrue);
      expect((decide('http://x/payments/payos/return?status=cancelled') as ReturnNavigation).cancelled, isTrue);
      expect((decide('http://x/payments/payos/return?cancel=false&status=PAID') as ReturnNavigation).cancelled, isFalse);
    });

    test('a test-gateway link is a return link flagged simulated', () {
      final r = decide('http://localhost:5174/payments/payos/return?simulated=1&orderCode=42') as ReturnNavigation;
      expect(r.params.simulated, isTrue);
      expect(r.params.orderCode, '42');
      expect(r.cancelled, isFalse);
    });

    test('the path is compared exactly, ignoring case and a trailing slash', () {
      expect(decide('https://x/Payments/PayOS/Return'), isA<ReturnNavigation>());
      expect(decide('https://x/payments/payos/return/extra'), isA<AllowNavigation>());
      expect(decide('https://x/other/payments/payos/return'), isA<AllowNavigation>());
      expect(decide('https://x/payments/payos'), isA<AllowNavigation>());
    });

    test('payOS pages and everything else on the web load normally', () {
      expect(decide('https://pay.payos.vn/web/abc'), isA<AllowNavigation>());
      expect(decide('https://img.vietqr.io/image/x.png'), isA<AllowNavigation>());
    });

    test('pages a browser opens by itself are not handed to another app', () {
      expect(decide('about:blank'), isA<AllowNavigation>());
      expect(decide('data:text/html,hello'), isA<AllowNavigation>());
      expect(decide('blob:https://x/uuid'), isA<AllowNavigation>());
    });

    test('bank app and other schemes go to the system', () {
      for (final url in ['intent://qr#Intent;scheme=momo;end', 'momo://pay?x=1', 'tel:0912345678', 'mailto:a@b.vn', 'market://details?id=x']) {
        expect(decide(url), isA<ExternalNavigation>(), reason: url);
      }
    });

    test('the paths come from the configuration', () {
      final custom = PayosUrlMatcher(returnPath: 'pay/done/', cancelPath: '/pay/stop');
      expect(custom.decide(Uri.parse('https://x/pay/done')), isA<ReturnNavigation>());
      expect((custom.decide(Uri.parse('https://x/pay/stop')) as ReturnNavigation).cancelled, isTrue);
      expect(custom.decide(Uri.parse('https://x/payments/payos/return')), isA<AllowNavigation>());
    });
  });

  group('parseIntentUri', () {
    test('reads the app address, package and fallback out of an intent link', () {
      final t = parseIntentUri(
        'intent://pay/qr?id=9&amount=1000#Intent;scheme=momo;package=com.mservice.momotransfer;'
        'S.browser_fallback_url=https%3A%2F%2Fmomo.vn%2Fapp;end',
      )!;
      expect(t.launchUri.toString(), 'momo://pay/qr?id=9&amount=1000');
      expect(t.package, 'com.mservice.momotransfer');
      expect(t.fallbackUrl.toString(), 'https://momo.vn/app');
    });

    test('works without a fallback or a package', () {
      final t = parseIntentUri('intent://open#Intent;scheme=vcbpay;end')!;
      expect(t.launchUri.toString(), 'vcbpay://open');
      expect(t.package, isNull);
      expect(t.fallbackUrl, isNull);
    });

    test('is case-insensitive about the intent prefix', () {
      expect(parseIntentUri('INTENT://x#Intent;scheme=app;end')?.launchUri.toString(), 'app://x');
    });

    test('is not an intent link, or has no scheme to open', () {
      expect(parseIntentUri('https://example.com'), isNull);
      expect(parseIntentUri('momo://pay'), isNull);
      expect(parseIntentUri('intent://x#Intent;package=com.x;end'), isNull);
      expect(parseIntentUri('intent://x'), isNull);
    });

    test('an intent whose scheme is http would just be a web link, so it is refused', () {
      expect(parseIntentUri('intent://example.com/x#Intent;scheme=https;end'), isNull);
    });

    test('a fallback that is not a web address is dropped', () {
      final t = parseIntentUri('intent://x#Intent;scheme=app;S.browser_fallback_url=javascript%3Aalert(1);end')!;
      expect(t.fallbackUrl, isNull);
    });
  });
}

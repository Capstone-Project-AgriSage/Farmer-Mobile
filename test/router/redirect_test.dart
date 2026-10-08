import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

String? redirect(SessionStatus status, String location, {String? from, bool seen = true}) =>
    resolveRedirect(status: status, location: location, from: from, onboardingSeen: seen);

void main() {
  group('while the stored token is being checked', () {
    test('every place shows the splash', () {
      expect(redirect(SessionStatus.restoring, '/home'), AppRoutes.splash);
      expect(redirect(SessionStatus.restoring, '/login'), AppRoutes.splash);
      expect(redirect(SessionStatus.restoring, AppRoutes.splash), isNull);
    });
  });

  group('signed out', () {
    test('the splash leads to onboarding the first time and to the welcome screen after that', () {
      expect(redirect(SessionStatus.signedOut, AppRoutes.splash, seen: false), AppRoutes.onboarding);
      expect(redirect(SessionStatus.signedOut, AppRoutes.splash, seen: true), AppRoutes.welcome);
    });
    test('the guest screens stay open', () {
      for (final path in [AppRoutes.welcome, AppRoutes.login, AppRoutes.register, AppRoutes.forgotPassword]) {
        expect(redirect(SessionStatus.signedOut, path), isNull, reason: path);
      }
    });
    test('a protected screen goes to login and remembers where the user was heading', () {
      expect(redirect(SessionStatus.signedOut, '/orders/42'), '/login?from=%2Forders%2F42');
      expect(redirect(SessionStatus.signedOut, AppRoutes.home), '/login?from=%2Fhome');
    });
  });

  group('signed in', () {
    test('the auth screens lead into the app', () {
      expect(redirect(SessionStatus.signedIn, AppRoutes.login), AppRoutes.home);
      expect(redirect(SessionStatus.signedIn, AppRoutes.splash), AppRoutes.home);
      expect(redirect(SessionStatus.signedIn, AppRoutes.welcome), AppRoutes.home);
    });
    test('login returns to the page the user wanted', () {
      expect(redirect(SessionStatus.signedIn, AppRoutes.login, from: '/orders/42'), '/orders/42');
    });
    test('login never returns to an outside address or to another guest screen', () {
      expect(redirect(SessionStatus.signedIn, AppRoutes.login, from: 'https://evil.example'), AppRoutes.home);
      expect(redirect(SessionStatus.signedIn, AppRoutes.login, from: '//evil.example'), AppRoutes.home);
      expect(redirect(SessionStatus.signedIn, AppRoutes.login, from: '/register'), AppRoutes.home);
    });
    test('app screens stay open', () {
      expect(redirect(SessionStatus.signedIn, '/debt/history'), isNull);
      expect(redirect(SessionStatus.signedIn, '/profile/password'), isNull);
    });
  });
}

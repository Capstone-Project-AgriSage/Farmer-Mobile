import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/token_storage.dart';
import 'package:farmer_mobile/features/profile/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fakes.dart';

const _tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

void main() {
  group('Splash / khôi phục phiên', () {
    testWidgets('chưa có token → sang Onboarding', (tester) async {
      final h = AppHarness();
      await h.pump(tester); // initial '/'
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(h.session.status, SessionStatus.unauthenticated);
      expect(h.location, '/onboarding');
      expect(h.repo.calls, isEmpty);
    });

    testWidgets('có token hợp lệ → vào thẳng Home (không qua Onboarding)',
        (tester) async {
      final h = AppHarness();
      h.storage.tokens = _tokens;
      h.repo.onMe = () async => SessionUser.fromJson(meJson());
      await h.pump(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(h.location, '/home');
      expect(find.text('HOME'), findsOneWidget);
      expect(h.session.user?.fullName, 'Trần Văn Hải');
    });

    testWidgets('token hết hạn/bị thu hồi (401) → Onboarding, token bị xoá',
        (tester) async {
      final h = AppHarness();
      h.storage.tokens = _tokens;
      h.repo.onMe = () async => throw const ApiException(
          kind: ApiErrorKind.unauthorized, statusCode: 401, message: 'x');
      await h.pump(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(h.location, '/onboarding');
      expect(h.storage.tokens, isNull);
    });

    testWidgets('mất mạng: hiện "Thử lại", GIỮ token, thử lại thành công → Home',
        (tester) async {
      final h = AppHarness();
      h.storage.tokens = _tokens;
      var online = false;
      h.repo.onMe = () async {
        if (!online) {
          throw const ApiException(kind: ApiErrorKind.network, message: 'mạng');
        }
        return SessionUser.fromJson(meJson());
      };
      await h.pump(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(h.location, '/');
      expect(h.storage.tokens, isNotNull);

      online = true;
      await tester.tap(find.text('Thử lại'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(h.location, '/home');
    });

    testWidgets('mất mạng → "Đăng nhập lại" bỏ phiên cũ và về Welcome',
        (tester) async {
      final h = AppHarness();
      h.storage.tokens = _tokens;
      h.repo.onMe = () async =>
          throw const ApiException(kind: ApiErrorKind.timeout, message: 'chậm');
      await h.pump(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await tester.tap(find.text('Đăng nhập lại'));
      await tester.pumpAndSettle();

      expect(h.location, '/welcome');
      expect(h.storage.tokens, isNull);
    });
  });

  group('Router guard trong app chạy thật', () {
    testWidgets('chưa đăng nhập mở thẳng /profile → bị đưa về Welcome',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();
      expect(h.location, '/welcome');
    });

    testWidgets('đã đăng nhập mở /login → vào Home', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/login');
      await tester.pumpAndSettle();
      expect(h.location, '/home');
    });

    testWidgets('phiên hết hạn giữa chừng (refresh thất bại) → tự về Welcome',
        (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();
      expect(h.location, '/profile');

      h.signOut(); // interceptor gọi markUnauthenticated khi refresh bị từ chối
      await tester.pumpAndSettle();

      expect(h.location, '/welcome');
    });

    testWidgets('đăng nhập xong thì nút Back không quay lại màn login',
        (tester) async {
      final h = AppHarness();
      h.repo.onLogin = (_, __) async => fakeAuthResult();
      h.repo.onMe = () async => SessionUser.fromJson(meJson());
      await h.pump(tester, initial: '/login');

      await enter(tester, 'login_identifier', '0912345678');
      await enter(tester, 'login_password', 'matkhau123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(h.location, '/home');

      h.router.go('/login'); // ví dụ deep link hoặc bấm nhầm
      await tester.pumpAndSettle();
      expect(h.location, '/home');
    });
  });

  group('Hồ sơ & đăng xuất', () {
    testWidgets('hiện tên, SĐT và chữ cái đầu thật của người dùng', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();

      expect(find.text('Trần Văn Hải'), findsOneWidget);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text('TH'), findsOneWidget);
    });

    testWidgets('đăng xuất: hỏi xác nhận; Huỷ thì giữ phiên', (tester) async {
      final h = AppHarness()..signIn();
      h.storage.tokens = _tokens;
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();

      await tapText(tester, 'Đăng xuất');
      await tester.pumpAndSettle();
      expect(find.text('Bạn có chắc muốn đăng xuất khỏi AgriSage?'), findsOneWidget);

      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      expect(h.session.isAuthenticated, isTrue);
      expect(h.repo.calls, isEmpty);
      expect(h.location, '/profile');
    });

    testWidgets('đăng xuất xác nhận: gọi server, xoá token, về Welcome',
        (tester) async {
      final h = AppHarness()..signIn();
      h.storage.tokens = _tokens;
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();

      await tapText(tester, 'Đăng xuất');
      await tester.pumpAndSettle();
      await tester.tap(field('logout_confirm'));
      await tester.pumpAndSettle();

      expect(h.repo.calls, ['logout']);
      expect(h.storage.tokens, isNull);
      expect(h.session.status, SessionStatus.unauthenticated);
      expect(h.location, '/welcome');
    });

    testWidgets('đăng xuất khi offline vẫn thoát được', (tester) async {
      final h = AppHarness()..signIn();
      h.storage.tokens = _tokens;
      h.repo.onLogout = ({accessToken}) async =>
          throw const ApiException(kind: ApiErrorKind.network, message: 'mạng');
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();

      await tapText(tester, 'Đăng xuất');
      await tester.pumpAndSettle();
      await tester.tap(field('logout_confirm'));
      await tester.pumpAndSettle();

      expect(h.location, '/welcome');
      expect(h.storage.tokens, isNull);
    });

    testWidgets('chưa xác minh SĐT: có mục "Xác minh số điện thoại"; đã xác minh: ẩn',
        (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();
      expect(find.text('Xác minh số điện thoại'), findsOneWidget);
      expect(find.text('Xác minh email'), findsNothing); // không có email

      h.signIn(
          user: SessionUser.fromJson(
              meJson(phoneVerified: true, email: 'a@b.com')));
      await tester.pumpAndSettle();
      expect(find.text('Xác minh số điện thoại'), findsNothing);
      expect(find.text('Xác minh email'), findsOneWidget);
    });

    testWidgets('mục "Đổi mật khẩu" mở đúng màn', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();

      await tapText(tester, 'Đổi mật khẩu');
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });
  });
}

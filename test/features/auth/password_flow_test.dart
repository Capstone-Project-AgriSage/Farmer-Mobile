import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

final _goodToken = '${'a1' * 16}.${'A' * 43}';

ApiException _unavailable() => const ApiException(
    kind: ApiErrorKind.unavailable,
    statusCode: 503,
    message: 'Hiện chưa gửi được mã xác nhận. Vui lòng thử lại sau.');

void main() {
  group('Quên mật khẩu', () {
    testWidgets('validate identifier', (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/forgot-password');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
      await tester.pump();
      expect(find.text('Vui lòng nhập email hoặc số điện thoại'), findsOneWidget);

      await enter(tester, 'forgot_identifier', 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
      await tester.pump();
      expect(find.text('Số điện thoại hoặc email không hợp lệ'), findsOneWidget);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets('gửi thành công (email): thông báo trung tính + nút nhập mã',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/forgot-password');

      await enter(tester, 'forgot_identifier', 'user@example.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
      await tester.pumpAndSettle();

      expect(h.repo.lastIdentifier, 'user@example.com');
      expect(find.text('Đã gửi mã xác nhận'), findsOneWidget);
      // Không khẳng định tài khoản tồn tại.
      expect(find.textContaining('Nếu tài khoản tồn tại'), findsOneWidget);
      expect(find.textContaining('email'), findsWidgets);

      await tester.tap(field('forgot_enter_code'));
      await tester.pumpAndSettle();
      expect(h.location, '/reset-password');
    });

    testWidgets('gửi bằng SĐT: nói là SMS', (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/forgot-password');

      await enter(tester, 'forgot_identifier', '0912345678');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tin nhắn SMS'), findsOneWidget);
    });

    testWidgets('server chưa cấu hình SMTP/SMS (503): hiện lỗi, ở lại form',
        (tester) async {
      final h = AppHarness();
      h.repo.onForgot = () async => throw _unavailable();
      await h.pump(tester, initial: '/forgot-password');

      await enter(tester, 'forgot_identifier', 'user@example.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
      await tester.pumpAndSettle();

      expect(find.textContaining('chưa gửi được mã xác nhận'), findsOneWidget);
      expect(find.text('Đã gửi mã xác nhận'), findsNothing);
      expect(field('forgot_identifier'), findsOneWidget);
    });

    testWidgets('"Tôi đã có mã" đi thẳng tới đặt lại; quay lại về đăng nhập',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/forgot-password');

      await tapText(tester, 'Tôi đã có mã xác nhận');
      await tester.pumpAndSettle();
      expect(h.location, '/reset-password');

      h.router.go('/forgot-password');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(h.location, '/login');
    });
  });

  group('Đặt lại mật khẩu (hai bước: xác nhận mã, rồi mật khẩu mới)', () {
    // Bước 1: nhập mã (và số điện thoại nếu là mã SMS) rồi bấm "Xác nhận mã".
    Future<void> confirmCode(WidgetTester tester,
        {String? token, String? identifier}) async {
      if (identifier != null) await enter(tester, 'reset_identifier', identifier);
      await enter(tester, 'reset_token', token ?? _goodToken);
      final b = find.widgetWithText(ElevatedButton, 'Xác nhận mã');
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.pump();
    }

    // Bước 2: mật khẩu mới rồi bấm "Đặt lại mật khẩu".
    Future<void> savePassword(WidgetTester tester,
        {String pw = 'matkhaumoi1', String? confirm}) async {
      await enter(tester, 'reset_password', pw);
      await enter(tester, 'reset_confirm', confirm ?? pw);
      final b = find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu');
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.pump();
    }

    const expired = ApiException(
        kind: ApiErrorKind.businessRule,
        statusCode: 422,
        message: 'Mã xác nhận không đúng hoặc đã hết hạn.');

    testWidgets('bước 1 chỉ có ô mã; mã sai định dạng bị chặn, không gọi API',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/reset-password');

      expect(field('reset_token'), findsOneWidget);
      expect(field('reset_password'), findsNothing);

      await confirmCode(tester, token: 'khong-dung');

      expect(find.text('Mã xác nhận không đúng định dạng'), findsOneWidget);
      expect(field('reset_password'), findsNothing);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets('bước 2 validate mật khẩu ngắn và xác nhận lệch', (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester); // mã email: sang bước 2 không cần API
      await savePassword(tester, pw: '123', confirm: '456');

      expect(find.text('Mật khẩu tối thiểu 8 ký tự'), findsOneWidget);
      expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets(
        'mã email: không có bước kiểm tra, gửi token đã trim, về đăng nhập',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester, token: '  $_goodToken  ');
      expect(find.textContaining('kiểm tra khi lưu'), findsOneWidget);
      await savePassword(tester);
      await tester.pumpAndSettle();

      expect(h.repo.calls, ['resetPassword']);
      expect(h.repo.lastResetToken?.trim(), _goodToken);
      expect(h.location, '/login');
      expect(find.text('Đặt lại mật khẩu thành công. Vui lòng đăng nhập.'),
          findsOneWidget);
    });

    testWidgets('mã email bị từ chối khi lưu (422): quay lại bước 1 với thông báo',
        (tester) async {
      final h = AppHarness();
      h.repo.onReset = () async => throw expired;
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester);
      await savePassword(tester);
      await tester.pumpAndSettle();

      expect(find.text('Mã xác nhận không đúng hoặc đã hết hạn.'), findsOneWidget);
      expect(field('reset_token'), findsOneWidget);
      expect(field('reset_password'), findsNothing);
      expect(h.location, '/reset-password');
    });

    testWidgets(
        'SMS: mang theo số điện thoại, kiểm tra mã trước rồi mới hỏi mật khẩu',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/forgot-password');

      await enter(tester, 'forgot_identifier', '0912345678');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
      await tester.pumpAndSettle();
      await tester.tap(field('forgot_enter_code'));
      await tester.pumpAndSettle();

      expect(h.location, '/reset-password');
      expect(
        tester.widget<TextFormField>(field('reset_identifier')).controller!.text,
        '0912345678',
      );

      await confirmCode(tester, token: ' 123456 ');
      await tester.pumpAndSettle();

      // Mã đã được kiểm tra, mật khẩu chưa được gửi đi.
      expect(h.repo.calls, contains('verifyResetCode'));
      expect(h.repo.calls, isNot(contains('resetPasswordWithCode')));
      expect(h.repo.lastVerifyIdentifier, '0912345678');
      expect(h.repo.lastVerifyCode, '123456');
      expect(field('reset_password'), findsOneWidget);
      expect(field('reset_token'), findsNothing);
      expect(find.textContaining('mã đã được xác nhận'), findsOneWidget);

      await savePassword(tester);
      await tester.pumpAndSettle();

      expect(h.repo.calls, isNot(contains('resetPassword')));
      expect(h.repo.calls.indexOf('verifyResetCode'),
          lessThan(h.repo.calls.indexOf('resetPasswordWithCode')));
      expect(h.repo.lastResetCodeIdentifier, '0912345678');
      expect(h.repo.lastResetCode, '123456');
      expect(h.location, '/login');
    });

    testWidgets('mã 6 số mà chưa có số điện thoại: báo lỗi, không gọi API',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester, token: '123456');

      expect(find.text('Vui lòng nhập số điện thoại đã nhận mã'), findsOneWidget);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets('mã 6 số đi với email: nhắc nhập số điện thoại', (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester, identifier: 'user@example.com', token: '123456');

      expect(find.text('Mã 6 số được gửi qua SMS, hãy nhập số điện thoại'),
          findsOneWidget);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets(
        'mã 6 số sai (422 ở bước kiểm tra): hiện lỗi, ở bước 1, không hỏi mật khẩu',
        (tester) async {
      final h = AppHarness();
      h.repo.onVerifyCode = () async => throw expired;
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester, identifier: '0912345678', token: '000000');
      await tester.pumpAndSettle();

      expect(find.text('Mã xác nhận không đúng hoặc đã hết hạn.'), findsOneWidget);
      expect(field('reset_token'), findsOneWidget);
      expect(field('reset_password'), findsNothing);
      expect(h.repo.calls, ['verifyResetCode']);
      expect(h.location, '/reset-password');
    });

    testWidgets(
        'mã 6 số hết lượt giữa hai bước (422 khi lưu): quay lại bước 1',
        (tester) async {
      final h = AppHarness();
      h.repo.onReset = () async => throw expired;
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester, identifier: '0912345678', token: '123456');
      await tester.pumpAndSettle();
      await savePassword(tester);
      await tester.pumpAndSettle();

      expect(h.repo.calls, ['verifyResetCode', 'resetPasswordWithCode']);
      expect(find.text('Mã xác nhận không đúng hoặc đã hết hạn.'), findsOneWidget);
      expect(field('reset_token'), findsOneWidget);
      expect(field('reset_password'), findsNothing);
      expect(h.location, '/reset-password');
    });

    testWidgets(
        '"Nhập lại mã" và nút quay lại ở bước 2 về bước 1; ở bước 1 quay lại về "Quên mật khẩu"',
        (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/reset-password');

      await confirmCode(tester);
      expect(field('reset_password'), findsOneWidget);
      await tester.tap(field('reset_back_to_code'));
      await tester.pumpAndSettle();
      expect(field('reset_token'), findsOneWidget);
      expect(h.location, '/reset-password');

      await confirmCode(tester);
      expect(field('reset_password'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(field('reset_token'), findsOneWidget);
      expect(h.location, '/reset-password');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(h.location, '/forgot-password');
    });
  });

  group('Đổi mật khẩu (đã đăng nhập)', () {
    Future<void> fill(WidgetTester tester,
        {String cur = 'cu12345678', String neu = 'moi12345678', String? confirm}) async {
      await enter(tester, 'cp_current', cur);
      await enter(tester, 'cp_new', neu);
      await enter(tester, 'cp_confirm', confirm ?? neu);
    }

    Future<void> submit(WidgetTester tester) async {
      final b = find.widgetWithText(ElevatedButton, 'Cập nhật mật khẩu');
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.pump();
    }

    testWidgets('validate: trống, ngắn, trùng mật khẩu cũ, xác nhận lệch',
        (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile/password');

      await submit(tester);
      expect(find.text('Vui lòng nhập mật khẩu'), findsNWidgets(2));

      await fill(tester, cur: 'abcdefgh', neu: 'abcdefgh');
      await submit(tester);
      expect(find.text('Mật khẩu mới phải khác mật khẩu hiện tại'), findsOneWidget);

      await fill(tester, neu: '123', confirm: '1234');
      await submit(tester);
      expect(find.text('Mật khẩu tối thiểu 8 ký tự'), findsOneWidget);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets('sai mật khẩu hiện tại (401): hiện lỗi, VẪN đăng nhập', (tester) async {
      final h = AppHarness()..signIn();
      h.storage.tokens = null;
      h.repo.onChangePassword = () async => throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          statusCode: 401,
          message: 'Mật khẩu hiện tại không đúng.');
      await h.pump(tester, initial: '/profile/password');

      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(h.session.isAuthenticated, isTrue);
      expect(h.location, '/profile/password');
    });

    testWidgets('thành công: đăng xuất (backend huỷ mọi phiên), về Welcome, có thông báo',
        (tester) async {
      final h = AppHarness()..signIn();
      h.storage.tokens =
          const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await h.pump(tester, initial: '/profile/password');

      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();

      expect(h.repo.calls, ['changePassword']);
      expect(h.session.status, SessionStatus.unauthenticated);
      expect(h.storage.tokens, isNull);
      expect(h.location, '/welcome');
      expect(find.text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'),
          findsOneWidget);
    });
  });
}


import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fakes.dart';

const _phoneRoute = '/otp-verify?channel=phone&to=0912345678';
const _emailRoute = '/otp-verify?channel=email&to=a%40b.com';

ApiException _unavailable(String msg) => ApiException(
    kind: ApiErrorKind.unavailable, statusCode: 503, message: msg);

void main() {
  testWidgets('chưa đăng nhập không vào được màn xác minh', (tester) async {
    final h = AppHarness();
    await h.pump(tester, initial: _phoneRoute);
    await tester.pumpAndSettle();
    expect(h.location, '/welcome');
  });

  group('SĐT (OTP 6 số)', () {
    testWidgets('tự gửi mã khi mở màn, hiện đích và đếm ngược gửi lại',
        (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: _phoneRoute);
      await tester.pump();

      expect(h.repo.calls, ['requestPhone']);
      expect(find.textContaining('0912345678'), findsOneWidget);
      expect(find.text('Đã gửi mã. Vui lòng kiểm tra tin nhắn.'), findsOneWidget);
      expect(find.text('Gửi lại mã (3s)'), findsOneWidget);
      expect(
          tester.widget<TextButton>(field('verify_resend')).onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Gửi lại mã (2s)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Gửi lại mã'), findsOneWidget);
      expect(
          tester.widget<TextButton>(field('verify_resend')).onPressed, isNotNull);

      await tester.tap(field('verify_resend'));
      await tester.pump();
      expect(h.repo.calls, ['requestPhone', 'requestPhone']);
      await tester.pump(const Duration(seconds: 4)); // hết đếm ngược, dọn timer
    });

    testWidgets('SMS chưa cấu hình (503): hiện lỗi, cho gửi lại ngay',
        (tester) async {
      final h = AppHarness()..signIn();
      h.repo.onRequestPhone =
          () async => throw _unavailable('Hiện chưa gửi được mã qua SMS.');
      await h.pump(tester, initial: _phoneRoute);
      await tester.pump();

      expect(find.text('Hiện chưa gửi được mã qua SMS.'), findsOneWidget);
      expect(find.text('Gửi lại mã'), findsOneWidget);
      expect(
          tester.widget<TextButton>(field('verify_resend')).onPressed, isNotNull);
    });

    testWidgets('chỉ nhận chữ số, tối đa 6; thiếu số thì báo lỗi', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: _phoneRoute);
      await tester.pump();

      await enter(tester, 'verify_code', '12ab34cd5678');
      final text = tester
          .widget<EditableText>(find.descendant(
              of: field('verify_code'), matching: find.byType(EditableText)))
          .controller
          .text;
      expect(text, '123456'); // bỏ chữ cái rồi mới cắt còn 6

      await enter(tester, 'verify_code', '123 456'); // dán có dấu cách
      final pasted = tester
          .widget<EditableText>(find.descendant(
              of: field('verify_code'), matching: find.byType(EditableText)))
          .controller
          .text;
      expect(pasted, '123456');

      await enter(tester, 'verify_code', '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận'));
      await tester.pump();
      expect(find.text('Vui lòng nhập đủ 6 số'), findsOneWidget);
      expect(h.repo.calls.where((c) => c.startsWith('confirm')), isEmpty);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('xác nhận đúng: gọi confirm, tải lại user, quay về Hồ sơ',
        (tester) async {
      final h = AppHarness()..signIn();
      h.repo.onMe = () async => SessionUser.fromJson(meJson(phoneVerified: true));
      await h.pump(tester, initial: _phoneRoute);
      await tester.pump();

      await enter(tester, 'verify_code', '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(h.repo.calls, contains('confirmPhone:123456'));
      expect(h.session.user?.phoneVerified, isTrue);
      expect(h.location, '/profile');
      expect(find.text('Đã xác minh số điện thoại.'), findsOneWidget);
      // Đã xác minh nên mục xác minh biến mất khỏi Hồ sơ.
      expect(find.text('Xác minh số điện thoại'), findsNothing);
    });

    testWidgets('mã sai (422): hiện lỗi, ở lại, chưa tải lại user', (tester) async {
      final h = AppHarness()..signIn();
      h.repo.onConfirmPhone = () async => throw const ApiException(
          kind: ApiErrorKind.businessRule,
          statusCode: 422,
          message: 'Mã OTP không đúng hoặc đã hết hạn.');
      await h.pump(tester, initial: _phoneRoute);
      await tester.pump();

      await enter(tester, 'verify_code', '000000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Mã OTP không đúng hoặc đã hết hạn.'), findsOneWidget);
      expect(h.location, _phoneRoute);
      expect(h.repo.calls, isNot(contains('me')));
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Email (dán mã)', () {
    final token = '${'a1' * 16}.${'A' * 43}';

    testWidgets('gọi API email, hiện địa chỉ email', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: _emailRoute);
      await tester.pump();

      expect(h.repo.calls, ['requestEmail']);
      expect(find.textContaining('a@b.com'), findsOneWidget);
      expect(find.text('Xác minh email'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('mã sai định dạng bị chặn; mã đúng được gửi', (tester) async {
      final h = AppHarness()..signIn();
      h.repo.onMe = () async =>
          SessionUser.fromJson(meJson(emailVerified: true, email: 'a@b.com'));
      await h.pump(tester, initial: _emailRoute);
      await tester.pump();

      await enter(tester, 'verify_code', 'khong-dung');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận'));
      await tester.pump();
      expect(find.text('Mã xác nhận không đúng định dạng'), findsOneWidget);

      await enter(tester, 'verify_code', token);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(h.repo.calls, contains('confirmEmail:$token'));
      expect(h.session.user?.emailVerified, isTrue);
    });
  });
}

import 'dart:async';

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fakes.dart';

Future<void> fillValid(WidgetTester tester,
    {String name = 'Nguyễn Văn A',
    String phone = '0912 345 678',
    String email = '',
    String pw = 'matkhau123',
    String? confirm}) async {
  await enter(tester, 'register_name', name);
  await enter(tester, 'register_phone', phone);
  await enter(tester, 'register_email', email);
  await enter(tester, 'register_password', pw);
  await enter(tester, 'register_confirm', confirm ?? pw);
}

Future<void> submit(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, 'Đăng ký');
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pump();
}

void main() {
  testWidgets('form trống: báo lỗi từng trường, không gọi server', (tester) async {
    final h = AppHarness();
    await h.pump(tester, initial: '/register');

    await submit(tester);

    expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
    expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsNWidgets(1));
    expect(h.repo.calls, isEmpty);
  });

  testWidgets('SĐT sai, email sai, mật khẩu ngắn, xác nhận không khớp',
      (tester) async {
    final h = AppHarness();
    await h.pump(tester, initial: '/register');

    await fillValid(tester,
        phone: '12345', email: 'abc', pw: '1234567', confirm: '7654321');
    await submit(tester);

    expect(find.text('Số điện thoại di động Việt Nam không hợp lệ'),
        findsOneWidget);
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu tối thiểu 8 ký tự'), findsOneWidget);
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
    expect(h.repo.calls, isEmpty);
  });

  testWidgets('mật khẩu 8 ký tự là đủ (backend yêu cầu ≥ 8, không phải 6)',
      (tester) async {
    final h = AppHarness();
    h.repo.onRegister = () async => fakeAuthResult();
    h.repo.onMe = () async => SessionUser.fromJson(meJson());
    await h.pump(tester, initial: '/register');

    await fillValid(tester, pw: '12345678');
    await submit(tester);
    await tester.pumpAndSettle();

    expect(h.repo.calls, contains('register'));
  });

  testWidgets('đăng ký thành công: gửi SĐT đã chuẩn hoá, không gửi email rỗng, vào Home',
      (tester) async {
    final h = AppHarness();
    h.repo.onRegister = () async => fakeAuthResult();
    h.repo.onMe = () async => SessionUser.fromJson(meJson());
    await h.pump(tester, initial: '/register');

    await fillValid(tester, phone: '+84 912 345 678');
    await submit(tester);
    await tester.pumpAndSettle();

    expect(h.repo.lastRegisterPhone, '0912345678');
    expect(h.repo.lastRegisterEmail, '');
    expect(find.text('HOME'), findsOneWidget);
    expect(h.session.isAuthenticated, isTrue);
    expect(h.storage.tokens?.refreshToken, 'ref1');
  });

  testWidgets('trùng SĐT/email (409): hiện lỗi, ở lại màn, giữ dữ liệu đã nhập',
      (tester) async {
    final h = AppHarness();
    h.repo.onRegister = () async => throw const ApiException(
        kind: ApiErrorKind.conflict,
        statusCode: 409,
        message: 'Số điện thoại hoặc email này đã được đăng ký.');
    await h.pump(tester, initial: '/register');

    await fillValid(tester);
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Số điện thoại hoặc email này đã được đăng ký.'),
        findsOneWidget);
    expect(h.location, '/register');
    final name = tester.widget<EditableText>(find.descendant(
        of: field('register_name'), matching: find.byType(EditableText)));
    expect(name.controller.text, 'Nguyễn Văn A');
  });

  testWidgets('đang gửi: nút khoá, chỉ một request', (tester) async {
    final h = AppHarness();
    final gate = Completer<AuthResult>();
    h.repo.onRegister = () => gate.future;
    h.repo.onMe = () async => SessionUser.fromJson(meJson());
    await h.pump(tester, initial: '/register');

    await fillValid(tester);
    await submit(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(h.repo.calls.where((c) => c == 'register').length, 1);

    gate.complete(fakeAuthResult());
    await tester.pumpAndSettle();
  });

  testWidgets('liên kết "Đăng nhập" và nút quay lại', (tester) async {
    final h = AppHarness();
    await h.pump(tester, initial: '/register');

    await tapText(tester, 'Đăng nhập');
    await tester.pumpAndSettle();
    expect(h.location, '/login');

    h.router.go('/register');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(h.location, '/welcome');
  });
}

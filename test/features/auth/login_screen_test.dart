import 'dart:async';

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fakes.dart';

void main() {
  testWidgets('màn đăng nhập hiển thị đủ thành phần', (tester) async {
    final h = AppHarness();
    await h.pump(tester, initial: '/login');
    h.container.read(sessionProvider.notifier).markUnauthenticated();
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsNWidgets(2)); // tiêu đề + nút
    expect(field('login_identifier'), findsOneWidget);
    expect(field('login_password'), findsOneWidget);
    expect(find.text('Ghi nhớ đăng nhập'), findsOneWidget);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);
  });

  group('validate', () {
    testWidgets('để trống: báo lỗi và KHÔNG gọi server', (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/login');
      h.signOut();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();

      expect(find.text('Vui lòng nhập email hoặc số điện thoại'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets('SĐT sai định dạng', (tester) async {
      final h = AppHarness();
      await h.pump(tester, initial: '/login');
      h.signOut();
      await tester.pumpAndSettle();

      await enter(tester, 'login_identifier', '12345');
      await enter(tester, 'login_password', 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();

      expect(find.text('Số điện thoại hoặc email không hợp lệ'), findsOneWidget);
      expect(h.repo.calls, isEmpty);
    });

    testWidgets('mật khẩu ngắn vẫn được gửi (không chặn tài khoản cũ)',
        (tester) async {
      final h = AppHarness();
      h.repo.onLogin = (_, __) async =>
          throw const ApiException(kind: ApiErrorKind.unauthorized, message: 'sai');
      await h.pump(tester, initial: '/login');
      h.signOut();
      await tester.pumpAndSettle();

      await enter(tester, 'login_identifier', '0912345678');
      await enter(tester, 'login_password', '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();

      expect(h.repo.calls, contains('login'));
    });
  });

  testWidgets('đăng nhập thành công → vào Home, token lưu', (tester) async {
    final h = AppHarness();
    h.repo.onLogin = (_, __) async => fakeAuthResult();
    h.repo.onMe = () async => SessionUser.fromJson(meJson());
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    await enter(tester, 'login_identifier', '0912 345 678');
    await enter(tester, 'login_password', 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(h.location, '/home');
    expect(h.storage.tokens?.accessToken, 'acc1');
    expect(h.storage.lastPersist, isTrue);
    expect(h.repo.lastIdentifier, '0912 345 678');
  });

  testWidgets('bỏ tick "Ghi nhớ" thì không lưu token xuống máy', (tester) async {
    final h = AppHarness();
    h.repo.onLogin = (_, __) async => fakeAuthResult();
    h.repo.onMe = () async => SessionUser.fromJson(meJson());
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    await tester.tap(field('login_remember'));
    await tester.pump();
    await enter(tester, 'login_identifier', 'a@b.com');
    await enter(tester, 'login_password', 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(h.storage.lastPersist, isFalse);
  });

  testWidgets('sai mật khẩu: hiện banner lỗi, ở lại màn, mật khẩu còn nguyên',
      (tester) async {
    final h = AppHarness();
    h.repo.onLogin = (_, __) async => throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        statusCode: 401,
        message: 'Số điện thoại/email hoặc mật khẩu không đúng.');
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    await enter(tester, 'login_identifier', '0912345678');
    await enter(tester, 'login_password', 'saimatkhau');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Số điện thoại/email hoặc mật khẩu không đúng.'),
        findsOneWidget);
    expect(h.location, '/login');
    expect(h.session.isAuthenticated, isFalse);
    // Mật khẩu còn nguyên trong ô và vẫn đang bị che.
    final pw = tester.widget<EditableText>(find.descendant(
        of: field('login_password'), matching: find.byType(EditableText)));
    expect(pw.controller.text, 'saimatkhau');
    expect(pw.obscureText, isTrue);
  });

  testWidgets('đang gọi server: nút bị khoá, bấm đúp chỉ gửi một lần',
      (tester) async {
    final h = AppHarness();
    final gate = Completer<AuthResult>();
    h.repo.onLogin = (_, __) => gate.future;
    h.repo.onMe = () async => SessionUser.fromJson(meJson());
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    await enter(tester, 'login_identifier', '0912345678');
    await enter(tester, 'login_password', 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(h.repo.calls.where((c) => c == 'login').length, 1);

    gate.complete(fakeAuthResult());
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('mất mạng: hiện thông báo kết nối', (tester) async {
    final h = AppHarness();
    h.repo.onLogin = (_, __) async => throw const ApiException(
        kind: ApiErrorKind.network,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    await enter(tester, 'login_identifier', '0912345678');
    await enter(tester, 'login_password', 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
  });

  testWidgets('tài khoản nhân viên: báo "chỉ dành cho nông dân"', (tester) async {
    final h = AppHarness();
    h.repo.onLogin = (_, __) async => fakeAuthResult(role: 'DELIVERY_STAFF');
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    await enter(tester, 'login_identifier', '0912345678');
    await enter(tester, 'login_password', 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.textContaining('chỉ dành cho tài khoản nông dân'), findsOneWidget);
    expect(h.location, '/login');
    expect(h.storage.tokens, isNull);
  });

  testWidgets('nút hiện/ẩn mật khẩu', (tester) async {
    final h = AppHarness();
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    EditableText input() => tester.widget<EditableText>(
        find.descendant(of: field('login_password'), matching: find.byType(EditableText)));
    expect(input().obscureText, isTrue);

    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(input().obscureText, isFalse);
  });

  testWidgets('liên kết: Quên mật khẩu, Đăng ký ngay, nút quay lại', (tester) async {
    final h = AppHarness();
    await h.pump(tester, initial: '/login');
    h.signOut();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    expect(h.location, '/forgot-password');

    h.router.go('/login');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký ngay'));
    await tester.pumpAndSettle();
    expect(h.location, '/register');

    h.router.go('/login');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(h.location, '/welcome');
  });
}

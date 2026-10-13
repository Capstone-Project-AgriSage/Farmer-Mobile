import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

const _net = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');

AuthSession sessionOf(String id, {bool current = false, int agoMinutes = 5}) {
  final now = DateTime.now();
  return AuthSession(
    id: id,
    createdAt: now.subtract(const Duration(days: 2)),
    lastUsedAt: now.subtract(Duration(minutes: agoMinutes)),
    expiresAt: now.add(const Duration(days: 28)),
    isCurrent: current,
  );
}

Future<AppHarness> open(WidgetTester tester, {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  h.repo.sessions0 = [sessionOf('a', current: true), sessionOf('b', agoMinutes: 90)];
  setup?.call(h);
  await h.pump(tester, initial: '/profile/sessions');
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('Thiết bị đăng nhập', () {
    testWidgets('hiện thiết bị này (không có nút đăng xuất riêng) và thiết bị khác', (tester) async {
      await open(tester);
      expect(find.text('Thiết bị này'), findsOneWidget);
      expect(find.text('Đang dùng'), findsOneWidget);
      expect(find.text('Thiết bị khác'), findsOneWidget);
      expect(find.byKey(const Key('session_revoke_a')), findsNothing,
          reason: 'không tự đăng xuất thiết bị đang dùng ở đây (đã có nút Đăng xuất ở Hồ sơ)');
      expect(find.byKey(const Key('session_revoke_b')), findsOneWidget);
      expect(find.text('Hoạt động gần nhất: 5 phút trước'), findsOneWidget);
      expect(find.text('Hoạt động gần nhất: 1 giờ trước'), findsOneWidget);
    });

    testWidgets('đăng xuất thiết bị khác: hỏi xác nhận rồi gọi API và làm mới danh sách', (tester) async {
      final h = await open(tester);
      await tester.tap(find.byKey(const Key('session_revoke_b')));
      await tester.pumpAndSettle();
      expect(find.text('Đăng xuất thiết bị này?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sessions_confirm_yes')));
      await tester.pumpAndSettle();

      expect(h.repo.revoked, ['b']);
      expect(find.byKey(const Key('session_b')), findsNothing);
      expect(find.byKey(const Key('session_a')), findsOneWidget);
      expect(find.text('Đã đăng xuất thiết bị.'), findsOneWidget);
      expect(h.session.status, SessionStatus.authenticated, reason: 'phiên của máy này không bị ảnh hưởng');
    });

    testWidgets('bấm Huỷ trong hộp thoại: không gọi API', (tester) async {
      final h = await open(tester);
      await tester.tap(find.byKey(const Key('session_revoke_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sessions_confirm_no')));
      await tester.pumpAndSettle();
      expect(h.repo.revoked, isEmpty);
      expect(find.byKey(const Key('session_b')), findsOneWidget);
    });

    testWidgets('đăng xuất thiết bị thất bại: báo lỗi, danh sách vẫn còn', (tester) async {
      final h = await open(tester, setup: (h) => h.repo.revokeError = _net);
      await tester.tap(find.byKey(const Key('session_revoke_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sessions_confirm_yes')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      expect(find.byKey(const Key('session_b')), findsOneWidget);
      expect(h.repo.revoked, isEmpty);
    });

    testWidgets('đăng xuất tất cả: xác nhận → gọi API → về màn Chào mừng', (tester) async {
      final h = await open(tester);
      await tester.tap(find.byKey(const Key('sessions_logout_all')));
      await tester.pumpAndSettle();
      expect(find.text('Đăng xuất khỏi tất cả thiết bị?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sessions_confirm_yes')));
      await tester.pumpAndSettle();

      expect(h.repo.calls, contains('logoutAll'));
      expect(h.session.status, SessionStatus.unauthenticated);
      expect(find.text('Thiết bị đăng nhập'), findsNothing, reason: 'router guard đã đưa ra khỏi màn');
    });

    testWidgets('đăng xuất tất cả thất bại: vẫn đăng nhập, báo lỗi, nút dùng lại được', (tester) async {
      final h = await open(tester, setup: (h) => h.repo.logoutAllError = _net);
      await tester.tap(find.byKey(const Key('sessions_logout_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sessions_confirm_yes')));
      await tester.pumpAndSettle();
      expect(h.session.status, SessionStatus.authenticated);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('sessions_logout_all'))).onPressed,
          isNotNull);
    });

    testWidgets('lỗi tải danh sách: Thử lại', (tester) async {
      final h = await open(tester, setup: (h) => h.repo.sessionsError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      h.repo.sessionsError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session_a')), findsOneWidget);
    });

    testWidgets('chỉ có một phiên (thiết bị này): không có nút đăng xuất thiết bị khác', (tester) async {
      await open(tester, setup: (h) => h.repo.sessions0 = [sessionOf('a', current: true)]);
      expect(find.text('Thiết bị khác'), findsNothing);
      expect(find.byKey(const Key('sessions_logout_all')), findsOneWidget);
    });

    testWidgets('Hồ sơ có lối vào "Thiết bị đăng nhập"', (tester) async {
      final h = AppHarness()..signIn();
      h.repo.sessions0 = [sessionOf('a', current: true)];
      await h.pump(tester, initial: '/profile');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Thiết bị đăng nhập'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Thiết bị đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Thiết bị này'), findsOneWidget);
    });
  });
}

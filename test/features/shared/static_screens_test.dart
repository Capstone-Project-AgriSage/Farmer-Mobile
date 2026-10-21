import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/profile/screens/help_support_screen.dart';
import 'package:farmer_mobile/shared/widgets/not_found_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_harness.dart';

void main() {
  group('Cài đặt thông báo (chưa có API) → Sắp ra mắt', () {
    testWidgets('nói rõ thay vì hiện các công tắc không có tác dụng', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile/notifications');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coming_soon_title')), findsOneWidget);
      expect(find.text('Sắp ra mắt'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('mọi thông báo'), findsOneWidget);
    });
  });

  group('Trợ giúp', () {
    testWidgets('không còn số tổng đài bịa, không còn nút gọi/phản hồi vô dụng', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile/help');
      await tester.pumpAndSettle();
      expect(find.textContaining('1900'), findsNothing);
      expect(find.text('Gửi phản hồi'), findsNothing);
      expect(find.byIcon(Icons.phone), findsNothing);
      expect(find.textContaining('liên hệ cửa hàng'), findsWidgets);
    });

    testWidgets('các câu hỏi khớp chức năng thật và mở được', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile/help');
      await tester.pumpAndSettle();

      for (final (q, _) in HelpSupportScreen.faq) {
        expect(find.text(q), findsOneWidget, reason: q);
      }
      expect(find.textContaining('85%'), findsNothing, reason: 'không còn con số độ chính xác không có căn cứ');

      await tester.tap(find.text('Chẩn đoán bệnh lúa hoạt động thế nào?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('AI phân tích và cho kết quả ngay'), findsOneWidget);
      expect(find.textContaining('chuyên gia'), findsNothing);
    });

    testWidgets('FAQ không hứa điều app không làm', (tester) async {
      for (final (q, a) in HelpSupportScreen.faq) {
        final text = '$q $a'.toLowerCase();
        expect(text, isNot(contains('tổng đài')), reason: q);
        expect(text, isNot(contains('đổi đại lý')), reason: q);
      }
    });
  });

  group('Điều khoản', () {
    testWidgets('mô tả đúng cách mua ghi nợ và chẩn đoán đang chạy', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile/terms');
      await tester.pumpAndSettle();
      expect(find.textContaining('cửa hàng đã cấp hạn mức tín dụng'), findsOneWidget);
      expect(find.textContaining('của cả nông dân và đại lý'), findsNothing);
      expect(find.textContaining('AI phân tích tự động'), findsOneWidget);
      expect(find.textContaining('có thể chưa chính xác'), findsOneWidget);
      expect(find.textContaining('chuyên gia'), findsNothing);
    });

    testWidgets('chính sách bảo mật mở được', (tester) async {
      final h = AppHarness()..signIn();
      await h.pump(tester, initial: '/profile/privacy');
      await tester.pumpAndSettle();
      expect(find.text('Chính sách bảo mật'), findsWidgets);
    });
  });

  group('Không tìm thấy trang', () {
    testWidgets('hiện thông báo thân thiện + nút về trang chủ (không lộ lỗi kỹ thuật)', (tester) async {
      final router = GoRouter(
        initialLocation: '/khong-co',
        errorBuilder: (_, __) => const NotFoundScreen(),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('not_found_title')), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('/khong-co'), findsNothing);

      await tester.tap(find.byKey(const Key('not_found_home')));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}

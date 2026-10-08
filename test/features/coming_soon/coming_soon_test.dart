import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/ai_scan_home_screen.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/image_capture_screen.dart';
import 'package:farmer_mobile/features/home/screens/article_list_screen.dart';
import 'package:farmer_mobile/features/home/screens/home_screen.dart';
import 'package:farmer_mobile/features/home/screens/notification_screen.dart';
import 'package:farmer_mobile/features/profile/screens/help_support_screen.dart';
import 'package:farmer_mobile/features/profile/screens/notification_settings_screen.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import '../cart/cart_controller_test.dart' show TestUserId;

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<GoRouter> pump(WidgetTester tester, Widget home, {List<RouteBase> extra = const []}) async {
    final session = SessionManager(store: InMemoryTokenStore());
    await session.signIn(
      accessToken: 't',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      user: const SessionUser(id: 'u1', fullName: 'Nguyễn Văn An', role: 'FARMER', phoneNumber: '0912345678'),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: '${AppRoutes.home}/notifications', builder: (_, __) => const NotificationScreen()),
        GoRoute(path: '${AppRoutes.home}/articles', builder: (_, __) => const ArticleListScreen()),
        GoRoute(path: AppRoutes.aiScan, builder: (_, __) => const AiScanHomeScreen()),
        GoRoute(path: AppRoutes.imageCapture, builder: (_, __) => const ImageCaptureScreen()),
        GoRoute(path: AppRoutes.products, builder: (_, __) => const Scaffold(body: Text('PRODUCTS'))),
        GoRoute(path: AppRoutes.orderList, builder: (_, __) => const Scaffold(body: Text('ORDERS'))),
        GoRoute(path: AppRoutes.debt, builder: (_, __) => const Scaffold(body: Text('DEBT'))),
        ...extra,
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
          sessionManagerProvider.overrideWithValue(session),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('screens with no backend say so', () {
    for (final entry in <String, Widget>{
      'Thông báo': const NotificationScreen(),
      'Tin tức & Kiến thức': const ArticleListScreen(),
      'Cài đặt thông báo': const NotificationSettingsScreen(),
      'Trợ giúp & Hỗ trợ': const HelpSupportScreen(),
    }.entries) {
      testWidgets('${entry.key} is a "coming soon" page and shows no sample data', (tester) async {
        await pump(tester, entry.value);

        expect(find.text('Sắp ra mắt'), findsOneWidget);
        expect(find.text(entry.key), findsWidgets, reason: 'the title');
        expect(find.byType(ListTile), findsNothing);
        expect(find.byType(Switch), findsNothing, reason: 'no settings that change nothing');
      });
    }

    testWidgets('help does not show a made-up hotline', (tester) async {
      await pump(tester, const HelpSupportScreen());

      expect(find.textContaining('1900'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('home screen', () {
    testWidgets('greets the signed-in farmer and offers real shortcuts, with no sample cards', (tester) async {
      await pump(tester, const HomeScreen());

      expect(find.text('Xin chào, Nguyễn Văn An'), findsOneWidget);
      expect(find.text('Mua sắm'), findsOneWidget);
      expect(find.text('Đơn hàng'), findsOneWidget);
      expect(find.text('Công nợ'), findsOneWidget);
      // What the old mock home showed as if it were the farmer's own data.
      for (final fake in ['#DH-8842', 'Fuji-One', '04/12/2024', '02/12/2024', 'GỢI Ý ĐÃ ĐƯỢC DUYỆT', 'Xem lịch sử']) {
        expect(find.textContaining(fake), findsNothing, reason: fake);
      }
    });

    testWidgets('the shortcuts open the real pages', (tester) async {
      await pump(tester, const HomeScreen());

      await tester.tap(find.text('Đơn hàng'));
      await tester.pumpAndSettle();
      expect(find.text('ORDERS'), findsOneWidget);
    });

    testWidgets('the news row opens a "coming soon" page', (tester) async {
      await pump(tester, const HomeScreen());

      await tester.scrollUntilVisible(find.text('Tin tức & kiến thức'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Tin tức & kiến thức'));
      await tester.pumpAndSettle();

      expect(find.text('Tin tức & Kiến thức'), findsWidgets);
      expect(find.text('Sắp ra mắt'), findsOneWidget);
    });

    testWidgets('the bell opens "coming soon" notifications instead of invented ones', (tester) async {
      await pump(tester, const HomeScreen());

      await tester.tap(find.byIcon(Icons.notifications_none_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Thông báo'), findsWidgets);
      expect(find.text('Sắp ra mắt'), findsOneWidget);
    });

    testWidgets('the AI banner says the feature is not here yet and has no history button', (tester) async {
      await pump(tester, const HomeScreen());

      expect(find.textContaining('Sắp ra mắt'), findsWidgets);
      expect(find.text('Xem lịch sử'), findsNothing);
    });
  });

  group('AI doctor', () {
    testWidgets('the start page warns that analysis is not available and has no history', (tester) async {
      await pump(tester, const AiScanHomeScreen());

      expect(find.textContaining('sắp ra mắt'), findsOneWidget);
      expect(find.byIcon(Icons.history_outlined), findsNothing);
    });

    testWidgets('the start page leads to the photo page', (tester) async {
      await pump(tester, const AiScanHomeScreen());

      await tester.tap(find.text('Chuẩn bị ảnh').first);
      await tester.pumpAndSettle();

      expect(find.text('Chạm để chụp ảnh lá lúa'), findsOneWidget);
      expect(find.text('Phân tích bằng AI'), findsNothing, reason: 'only offered once a photo has been chosen');
    });

    testWidgets('"analyse" explains that nothing was sent', (tester) async {
      await pump(
        tester,
        Builder(builder: (context) => ElevatedButton(onPressed: () => showAiComingSoonDialog(context), child: const Text('ANALYSE'))),
      );

      await tester.tap(find.text('ANALYSE'));
      await tester.pumpAndSettle();

      expect(find.text('Sắp ra mắt'), findsOneWidget);
      expect(find.textContaining('chưa được gửi đi đâu'), findsOneWidget);

      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(find.text('Sắp ra mắt'), findsNothing);
    });
  });
}

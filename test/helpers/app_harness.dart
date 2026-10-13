import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:farmer_mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:farmer_mobile/features/auth/screens/login_screen.dart';
import 'package:farmer_mobile/features/auth/screens/onboarding_screen.dart';
import 'package:farmer_mobile/features/auth/screens/otp_verify_screen.dart';
import 'package:farmer_mobile/features/auth/screens/register_screen.dart';
import 'package:farmer_mobile/features/auth/screens/reset_password_screen.dart';
import 'package:farmer_mobile/features/auth/screens/splash_screen.dart';
import 'package:farmer_mobile/features/auth/screens/welcome_screen.dart';
import 'package:farmer_mobile/features/home/screens/home_screen.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:farmer_mobile/features/profile/screens/help_support_screen.dart';
import 'package:farmer_mobile/features/profile/screens/notification_settings_screen.dart';
import 'package:farmer_mobile/features/profile/screens/privacy_screen.dart';
import 'package:farmer_mobile/features/profile/screens/sessions_screen.dart';
import 'package:farmer_mobile/features/profile/screens/terms_screen.dart';
import 'package:farmer_mobile/features/profile/screens/address_form_screen.dart';
import 'package:farmer_mobile/features/profile/screens/address_list_screen.dart';
import 'package:farmer_mobile/features/profile/screens/change_password_screen.dart';
import 'package:farmer_mobile/features/profile/screens/edit_profile_screen.dart';
import 'package:farmer_mobile/features/profile/screens/profile_screen.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';
import 'package:farmer_mobile/features/products/screens/cart_screen.dart';
import 'package:farmer_mobile/features/products/screens/product_detail_screen.dart';
import 'package:farmer_mobile/features/products/screens/product_list_screen.dart';
import 'package:farmer_mobile/features/products/screens/order_confirm_screen.dart';
import 'package:farmer_mobile/features/products/screens/order_detail_screen.dart';
import 'package:farmer_mobile/features/products/screens/order_list_screen.dart';
import 'package:farmer_mobile/features/payment/screens/payment_result_screen.dart';
import 'package:farmer_mobile/features/payment/data/pending_payment.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';
import 'package:farmer_mobile/features/debt/screens/debt_history_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_detail_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_list_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_overview_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_repay_screen.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/ai_scan_home_screen.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/diagnose_case_screen.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/diagnose_history_screen.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/image_capture_screen.dart';
import 'package:farmer_mobile/features/home/screens/notification_screen.dart';
import 'package:farmer_mobile/features/notifications/data/notification_repository.dart';
import 'package:farmer_mobile/features/returns/data/return_repository.dart';
import 'package:farmer_mobile/features/returns/screens/return_detail_screen.dart';
import 'package:farmer_mobile/features/returns/screens/return_list_screen.dart';
import 'package:farmer_mobile/features/returns/screens/return_request_screen.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'auth_fakes.dart';
import 'catalog_fakes.dart';
import 'debt_fakes.dart';
import 'payment_test_support.dart';
import 'diagnosis_fakes.dart';
import 'return_fakes.dart';
import 'notification_fakes.dart';
import 'order_fakes.dart';
import 'profile_fakes.dart';

class _Refresh extends ChangeNotifier {
  _Refresh(ProviderContainer c) {
    c.listen<SessionState>(sessionProvider, (p, n) {
      if (p?.status != n.status) notifyListeners();
    });
  }
}

/// Dùng GoRouter thật + `authRedirect` thật + các màn auth thật.
/// Home và Profile con được thay bằng bản đơn giản để không kéo theo ảnh mạng.
class AppHarness {
  AppHarness({FakeAuthRepository? repo, MemoryTokenStorage? storage})
      : repo = repo ?? FakeAuthRepository(),
        storage = storage ?? MemoryTokenStorage() {
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(this.repo),
      profileRepositoryProvider.overrideWithValue(profile),
      catalogRepositoryProvider.overrideWithValue(catalog),
      cartRepositoryProvider.overrideWithValue(cart),
      orderRepositoryProvider.overrideWithValue(orders),
      paymentRepositoryProvider.overrideWithValue(payments),
      creditRepositoryProvider.overrideWithValue(credit),
      debtRepositoryProvider.overrideWithValue(debt),
      returnRepositoryProvider.overrideWithValue(returns),
      notificationRepositoryProvider.overrideWithValue(notifications),
      diagnosisRepositoryProvider.overrideWithValue(diagnosis),
      photoPickerProvider.overrideWithValue(photos),
      ...paymentTestOverrides(paymentStore),
      tokenStorageProvider.overrideWithValue(this.storage),
    ]);
  }

  final FakeAuthRepository repo;
  final FakeProfileRepository profile = FakeProfileRepository();
  final FakeCatalogRepository catalog = FakeCatalogRepository();
  final FakeCartRepository cart = FakeCartRepository();
  final FakeOrderRepository orders = FakeOrderRepository();
  final FakePaymentRepository payments = FakePaymentRepository();
  final FakeCreditRepository credit = FakeCreditRepository();
  final FakeDebtRepository debt = FakeDebtRepository();
  final FakeReturnRepository returns = FakeReturnRepository();
  final FakeNotificationRepository notifications = FakeNotificationRepository();
  final FakeDiagnosisRepository diagnosis = FakeDiagnosisRepository();
  final FakePhotoPicker photos = FakePhotoPicker();

  /// Dùng HomeScreen thật thay cho màn giả "HOME" (các test cũ dựa vào chữ HOME).
  bool realHome = false;

  /// Nhịp tự làm mới ca chẩn đoán đang chờ trong test (thật: 30 giây).
  Duration diagnosisPollInterval = const Duration(seconds: 30);

  /// Kho khoản thanh toán payOS dở (bộ nhớ, thay cho shared_preferences).
  final MemoryKeyValueStore paymentStore = MemoryKeyValueStore();
  final MemoryTokenStorage storage;
  late final ProviderContainer container;
  late GoRouter router;

  SessionState get session => container.read(sessionProvider);

  void signIn({SessionUser? user}) => container
      .read(sessionProvider.notifier)
      .setAuthenticated(user ?? SessionUser.fromJson(meJson()));

  void signOut() =>
      container.read(sessionProvider.notifier).markUnauthenticated();

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> pump(WidgetTester tester, {String initial = '/'}) async {
    // Font test (Ahem) rộng hơn font thật nên dùng khung rộng; bố cục hẹp kiểm ở app thật.
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(container.dispose);

    // Vào thẳng một màn (không qua splash) thì coi như phiên đã được xác định.
    if (initial != AppRoutes.splash &&
        session.status == SessionStatus.unknown) {
      signOut();
    }

    final refresh = _Refresh(container);
    router = GoRouter(
      initialLocation: initial,
      refreshListenable: refresh,
      redirect: (context, state) =>
          authRedirect(session.status, state.uri.toString()),
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: AppRoutes.onboarding,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: AppRoutes.welcome, builder: (_, __) => const WelcomeScreen()),
        GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
        GoRoute(
            path: AppRoutes.forgotPassword,
            builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(
            path: AppRoutes.resetPassword,
            builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(
          path: AppRoutes.otpVerify,
          builder: (_, s) => OtpVerifyScreen(
            destination: s.uri.queryParameters['to'] ?? '',
            channel: s.uri.queryParameters['channel'] == 'email'
                ? VerifyChannel.email
                : VerifyChannel.phone,
            resendSeconds: 3,
          ),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => realHome
              ? const HomeScreen()
              : const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(
            path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
        GoRoute(
            path: AppRoutes.sessions, builder: (_, __) => const SessionsScreen()),
        GoRoute(
            path: AppRoutes.helpSupport,
            builder: (_, __) => const HelpSupportScreen()),
        GoRoute(path: AppRoutes.terms, builder: (_, __) => const TermsScreen()),
        GoRoute(path: AppRoutes.privacy, builder: (_, __) => const PrivacyScreen()),
        GoRoute(
            path: AppRoutes.notificationSettings,
            builder: (_, __) => const NotificationSettingsScreen()),
        GoRoute(
            path: AppRoutes.changePassword,
            builder: (_, __) => const ChangePasswordScreen()),
        GoRoute(
          path: AppRoutes.products,
          builder: (_, __) => const ProductListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, s) =>
                  ProductDetailScreen(productId: s.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(path: AppRoutes.cart, builder: (_, __) => const CartScreen()),
        GoRoute(
          path: AppRoutes.orderConfirm,
          builder: (_, __) => const OrderConfirmScreen(),
        ),
        GoRoute(
            path: AppRoutes.orderList,
            builder: (_, __) => const OrderListScreen()),
        GoRoute(
          path: '/orders/:id',
          builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/orders/:id/return',
          builder: (_, s) => ReturnRequestScreen(orderId: s.pathParameters['id']!),
        ),
        GoRoute(path: '/ai-scan', builder: (_, __) => const AiScanHomeScreen()),
        GoRoute(
            path: '/ai-scan/capture', builder: (_, __) => const ImageCaptureScreen()),
        GoRoute(
            path: '/ai-scan/history',
            builder: (_, __) => const DiagnoseHistoryScreen()),
        GoRoute(
          path: '/ai-scan/case/:id',
          builder: (_, s) => DiagnoseCaseScreen(
              caseId: s.pathParameters['id']!, pollInterval: diagnosisPollInterval),
        ),
        GoRoute(
            path: '/home/notifications',
            builder: (_, __) => const NotificationScreen()),
        GoRoute(path: '/returns', builder: (_, __) => const ReturnListScreen()),
        GoRoute(
          path: '/returns/:id',
          builder: (_, s) => ReturnDetailScreen(returnId: s.pathParameters['id']!),
        ),
        // WebView không chạy được trong flutter test: màn thanh toán thật được thay bằng một
        // màn giả hiện mã khoản thanh toán (WebView chỉ kiểm tra được trên emulator).
        GoRoute(
          path: AppRoutes.payosCheckout,
          builder: (_, s) {
            final p = s.extra as PendingPayment;
            return Scaffold(
              appBar: AppBar(title: const Text('Thanh toán payOS')),
              body: Center(child: Text('PAYOS ${p.paymentId}', key: const Key('payos_stub'))),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.paymentResult,
          builder: (_, s) => PaymentResultScreen(args: s.extra as PaymentResultArgs),
        ),
        GoRoute(
          path: AppRoutes.debt,
          builder: (_, __) => const DebtOverviewScreen(),
          routes: [
            GoRoute(path: 'list', builder: (_, __) => const DebtListScreen()),
            GoRoute(path: 'history', builder: (_, __) => const DebtHistoryScreen()),
            GoRoute(
              path: 'repay',
              builder: (_, s) => DebtRepayScreen(
                initialAmount: int.tryParse(s.uri.queryParameters['amount'] ?? ''),
                previewDelay: const Duration(milliseconds: 50),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, s) => DebtDetailScreen(debtId: s.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(
            path: AppRoutes.editProfile,
            builder: (_, __) => const EditProfileScreen()),
        GoRoute(
            path: '/profile/addresses',
            builder: (_, __) => const AddressListScreen()),
        GoRoute(
            path: '/profile/addresses/add',
            builder: (_, __) => const AddressFormScreen()),
        GoRoute(
            path: '/profile/addresses/edit/:id',
            builder: (_, s) =>
                AddressFormScreen(addressId: s.pathParameters['id'])),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ));
    await tester.pump();
  }
}

Finder field(String key) => find.byKey(Key(key));

/// Nhập chữ vào ô theo key rồi đợi khung hình.
Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(field(key));
  await tester.enterText(field(key), text);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pump();
}

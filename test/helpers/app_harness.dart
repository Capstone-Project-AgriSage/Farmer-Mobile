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
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
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
import 'package:farmer_mobile/features/payment/screens/qr_payment_screen.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'auth_fakes.dart';
import 'catalog_fakes.dart';
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

  /// Nhịp hỏi trạng thái thanh toán trong test (thật: 3 giây).
  Duration paymentPollInterval = const Duration(seconds: 3);
  Duration paymentSyncAfter = const Duration(seconds: 60);
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
          builder: (_, __) => const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(
            path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
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
          path: AppRoutes.qrPayment,
          builder: (_, s) => QRPaymentScreen(
            orderId: s.uri.queryParameters['orderId'] ?? '',
            pollInterval: paymentPollInterval,
            syncAfter: paymentSyncAfter,
            showDevTools: true,
          ),
        ),
        GoRoute(
          path: AppRoutes.paymentResult,
          builder: (_, s) => PaymentResultScreen(
            success: s.uri.queryParameters['success'] == 'true',
            orderId: s.uri.queryParameters['orderId'],
          ),
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

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_provider.dart';

// Auth
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/otp_verify_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';

// Shell (Bottom Nav)
import '../shared/widgets/app_shell.dart';
import '../shared/widgets/not_found_screen.dart';
import '../shared/widgets/fallback_pop_scope.dart';

// Home
import '../features/home/screens/home_screen.dart';
import '../features/home/screens/notification_screen.dart';

// Products & Orders
import '../features/products/screens/product_list_screen.dart';
import '../features/products/screens/product_detail_screen.dart';
import '../features/products/screens/cart_screen.dart';
import '../features/products/screens/order_confirm_screen.dart';
import '../features/products/screens/order_list_screen.dart';
import '../features/products/screens/order_detail_screen.dart';
import '../features/returns/screens/return_detail_screen.dart';
import '../features/returns/screens/return_list_screen.dart';
import '../features/returns/screens/return_request_screen.dart';

// Payment
import '../features/payment/data/pending_payment.dart';
import '../features/payment/providers/payment_providers.dart';
import '../features/payment/screens/payos_checkout_screen.dart';
import '../features/payment/screens/payment_result_screen.dart';

// Debt
import '../features/debt/screens/debt_overview_screen.dart';
import '../features/debt/screens/debt_list_screen.dart';
import '../features/debt/screens/debt_detail_screen.dart';
import '../features/debt/screens/debt_repay_screen.dart';
import '../features/debt/screens/debt_history_screen.dart';

// AI Doctor
import '../features/ai_doctor/screens/ai_scan_home_screen.dart';
import '../features/ai_doctor/screens/image_capture_screen.dart';
import '../features/ai_doctor/screens/diagnose_case_screen.dart';
import '../features/ai_doctor/screens/diagnose_history_screen.dart';

// Profile
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/change_password_screen.dart';
import '../features/profile/screens/notification_settings_screen.dart';
import '../features/profile/screens/terms_screen.dart';
import '../features/profile/screens/privacy_screen.dart';
import '../features/profile/screens/help_support_screen.dart';
import '../features/profile/screens/address_list_screen.dart';
import '../features/profile/screens/address_form_screen.dart';

// Sessions
import '../features/profile/screens/sessions_screen.dart';

abstract class AppRoutes {
  // Auth
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const otpVerify = '/otp-verify';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Shell tabs
  static const home = '/home';
  static const products = '/products';
  static const aiScan = '/ai-scan';
  static const debt = '/debt';
  static const profile = '/profile';

  // Notifications
  static const notifications = '/notifications';

  // Products
  static const productDetail = '/products/:id';
  static const cart = '/cart';
  static const orderConfirm = '/order-confirm';
  static const orderList = '/orders';
  static const orderDetail = '/orders/:id';
  static const returnList = '/returns';

  // Payment
  static const payosCheckout = '/payment/payos';
  static const paymentResult = '/payment/result';

  // Debt
  static const debtList = '/debt/list';
  static const debtDetail = '/debt/:id';
  static const debtRepay = '/debt/repay';
  static const debtHistory = '/debt/history';

  // AI Doctor
  static const imageCapture = '/ai-scan/capture';
  static const diagnoseCase = '/ai-scan/case/:id';
  static const diagnoseHistory = '/ai-scan/history';

  // Profile sub-pages
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/password';
  static const sessions = '/profile/sessions';
  static const notificationSettings = '/profile/notifications';
  static const terms = '/profile/terms';
  static const privacy = '/profile/privacy';
  static const helpSupport = '/profile/help';
}


/// Các màn thuộc luồng đăng nhập/giới thiệu: người CHƯA đăng nhập được vào,
/// người ĐÃ đăng nhập thì bị đưa về Home.
const _authFlowRoutes = {
  AppRoutes.splash,
  AppRoutes.onboarding,
  AppRoutes.welcome,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};

/// Router guard. Trả về đường dẫn cần chuyển tới, hoặc null nếu giữ nguyên.
/// - Chưa biết trạng thái (đang khởi động): chỉ ở splash.
/// - Chưa đăng nhập: chỉ vào được các màn công khai, còn lại về Welcome.
/// - Đã đăng nhập: không ở lại các màn đăng nhập/giới thiệu.
String? authRedirect(SessionStatus status, String location) {
  final path = Uri.parse(location).path;
  switch (status) {
    case SessionStatus.unknown:
      return path == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionStatus.unauthenticated:
      return _authFlowRoutes.contains(path) ? null : AppRoutes.welcome;
    case SessionStatus.authenticated:
      return _authFlowRoutes.contains(path) ? AppRoutes.home : null;
  }
}

/// Cầu nối để GoRouter chạy lại `redirect` khi trạng thái phiên đổi.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      ref.read(sessionProvider).status,
      state.uri.toString(),
    ),
    routes: [
      // ── Auth flows (no bottom nav) ────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        builder: (_, state) => OtpVerifyScreen(
          destination: state.uri.queryParameters['to'] ?? '',
          channel: state.uri.queryParameters['channel'] == 'email'
              ? VerifyChannel.email
              : VerifyChannel.phone,
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        // `extra` = email/số điện thoại đã nhập ở màn "Quên mật khẩu".
        builder: (_, state) => ResetPasswordScreen(
          initialIdentifier: state.extra is String ? state.extra as String : null,
        ),
      ),

      // ── Main shell with Bottom Navigation ────────────────────
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'notifications',
                builder: (_, __) => const NotificationScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.products,
            builder: (_, __) => const ProductListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => ProductDetailScreen(
                  productId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.aiScan,
            builder: (_, __) => const AiScanHomeScreen(),
            routes: [
              GoRoute(
                path: 'capture',
                builder: (_, __) => const ImageCaptureScreen(),
              ),
              GoRoute(
                path: 'case/:id',
                builder: (_, state) => DiagnoseCaseScreen(
                  caseId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'history',
                builder: (_, __) => const DiagnoseHistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.debt,
            builder: (_, __) => const DebtOverviewScreen(),
            routes: [
              GoRoute(
                path: 'list',
                builder: (_, __) => const DebtListScreen(),
              ),
              // 'history' và 'repay' phải đứng trước ':id' kẻo bị coi là mã khoản nợ.
              GoRoute(
                path: 'history',
                builder: (_, __) => const DebtHistoryScreen(),
              ),
              GoRoute(
                path: 'repay',
                builder: (_, state) => DebtRepayScreen(
                  initialAmount:
                      int.tryParse(state.uri.queryParameters['amount'] ?? ''),
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => DebtDetailScreen(
                  debtId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, __) => const EditProfileScreen(),
              ),
              GoRoute(
                path: 'password',
                builder: (_, __) => const ChangePasswordScreen(),
              ),
              GoRoute(
                path: 'sessions',
                builder: (_, __) => const SessionsScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (_, __) => const NotificationSettingsScreen(),
              ),
              GoRoute(
                path: 'terms',
                builder: (_, __) => const TermsScreen(),
              ),
              GoRoute(
                path: 'privacy',
                builder: (_, __) => const PrivacyScreen(),
              ),
              GoRoute(
                path: 'help',
                builder: (_, __) => const HelpSupportScreen(),
              ),
              GoRoute(
                path: 'addresses',
                builder: (_, __) => const AddressListScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Address form (outside shell) ──────────────────────────
      // Reached from the profile (inside the shell) AND from the checkout (outside it). A route that lives inside the
      // ShellRoute and is pushed from a page above the shell puts the shell in the stack twice and trips the navigator's
      // duplicate-key assertion (the red screen on "Thêm địa chỉ"). Same path as before, so every caller is unchanged.
      GoRoute(
        path: '${AppRoutes.profile}/addresses/add',
        builder: (_, __) => const AddressFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.profile}/addresses/edit/:id',
        builder: (_, state) => AddressFormScreen(
          addressId: state.pathParameters['id'],
        ),
      ),

      // ── Cart & Orders (outside shell) ─────────────────────────
      GoRoute(
        path: AppRoutes.cart,
        builder: (_, __) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderConfirm,
        builder: (_, __) => const OrderConfirmScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderList,
        builder: (_, __) => const FallbackPopScope(
            fallback: AppRoutes.home, child: OrderListScreen()),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => FallbackPopScope(
          fallback: AppRoutes.orderList,
          child: OrderDetailScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/orders/:id/return',
        builder: (_, state) => ReturnRequestScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.returnList,
        builder: (_, __) => const ReturnListScreen(),
      ),
      GoRoute(
        path: '/returns/:id',
        builder: (_, state) => FallbackPopScope(
          fallback: AppRoutes.returnList,
          child: ReturnDetailScreen(returnId: state.pathParameters['id']!),
        ),
      ),

      // ── Payment ───────────────────────────────────────────────
      // Hai màn này nhận dữ liệu qua `extra` (khoản thanh toán dở): mất `extra` (mở lại từ
      // đường dẫn, khôi phục điều hướng) thì không có gì để thanh toán → về Trang chủ.
      GoRoute(
        path: AppRoutes.payosCheckout,
        redirect: (_, state) => state.extra is PendingPayment ? null : AppRoutes.home,
        builder: (_, state) =>
            PayosCheckoutScreen(payment: state.extra as PendingPayment),
      ),
      GoRoute(
        path: AppRoutes.paymentResult,
        redirect: (_, state) => state.extra is PaymentResultArgs ? null : AppRoutes.home,
        builder: (_, state) =>
            PaymentResultScreen(args: state.extra as PaymentResultArgs),
      ),
    ],
    errorBuilder: (_, __) => const NotFoundScreen(),
  );
});

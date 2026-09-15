import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

// Payment
import '../features/payment/screens/qr_payment_screen.dart';
import '../features/payment/screens/payment_pending_screen.dart';
import '../features/payment/screens/payment_result_screen.dart';

// Debt
import '../features/debt/screens/debt_overview_screen.dart';
import '../features/debt/screens/debt_list_screen.dart';
import '../features/debt/screens/debt_detail_screen.dart';
import '../features/debt/screens/debt_confirm_screen.dart';
import '../features/debt/screens/debt_history_screen.dart';

// AI Doctor
import '../features/ai_doctor/screens/ai_scan_home_screen.dart';
import '../features/ai_doctor/screens/image_capture_screen.dart';
import '../features/ai_doctor/screens/ai_analyzing_screen.dart';
import '../features/ai_doctor/screens/diagnose_result_screen.dart';
import '../features/ai_doctor/screens/diagnose_uncertain_screen.dart';
import '../features/ai_doctor/screens/suggestion_pending_screen.dart';
import '../features/ai_doctor/screens/product_suggestion_screen.dart';
import '../features/ai_doctor/screens/diagnose_history_screen.dart';

// Profile
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/change_password_screen.dart';
import '../features/profile/screens/notification_settings_screen.dart';
import '../features/profile/screens/terms_screen.dart';
import '../features/profile/screens/privacy_screen.dart';
import '../features/profile/screens/help_support_screen.dart';

// Route path constants
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
  static const productDetail = '/products/:slug';
  static const cart = '/cart';
  static const orderConfirm = '/order-confirm';
  static const orderList = '/orders';
  static const orderDetail = '/orders/:id';

  // Payment
  static const qrPayment = '/payment/qr';
  static const paymentPending = '/payment/pending';
  static const paymentResult = '/payment/result';

  // Debt
  static const debtList = '/debt/list';
  static const debtDetail = '/debt/:id';
  static const debtConfirm = '/debt/:id/confirm';
  static const debtHistory = '/debt/history';

  // AI Doctor
  static const imageCapture = '/ai-scan/capture';
  static const aiAnalyzing = '/ai-scan/analyzing';
  static const diagnoseResult = '/ai-scan/result';
  static const diagnoseUncertain = '/ai-scan/uncertain';
  static const suggestionPending = '/ai-scan/suggestion-pending';
  static const productSuggestion = '/ai-scan/suggestion';
  static const diagnoseHistory = '/ai-scan/history';

  // Profile sub-pages
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/password';
  static const notificationSettings = '/profile/notifications';
  static const terms = '/profile/terms';
  static const privacy = '/profile/privacy';
  static const helpSupport = '/profile/help';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
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
          phone: state.uri.queryParameters['phone'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, __) => const ResetPasswordScreen(),
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
                path: ':slug',
                builder: (_, state) => ProductDetailScreen(
                  slug: state.pathParameters['slug']!,
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
                path: 'analyzing',
                builder: (_, __) => const AiAnalyzingScreen(),
              ),
              GoRoute(
                path: 'result',
                builder: (_, __) => const DiagnoseResultScreen(),
              ),
              GoRoute(
                path: 'uncertain',
                builder: (_, __) => const DiagnoseUncertainScreen(),
              ),
              GoRoute(
                path: 'suggestion-pending',
                builder: (_, __) => const SuggestionPendingScreen(),
              ),
              GoRoute(
                path: 'suggestion',
                builder: (_, __) => const ProductSuggestionScreen(),
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
              GoRoute(
                path: ':id',
                builder: (_, state) => DebtDetailScreen(
                  debtId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: ':id/confirm',
                builder: (_, state) => DebtConfirmScreen(
                  debtId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'history',
                builder: (_, __) => const DebtHistoryScreen(),
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
            ],
          ),
        ],
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
        builder: (_, __) => const OrderListScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => OrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),

      // ── Payment ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.qrPayment,
        builder: (_, __) => const QrPaymentScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentPending,
        builder: (_, __) => const PaymentPendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentResult,
        builder: (_, state) => PaymentResultScreen(
          success: state.uri.queryParameters['success'] == 'true',
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Không tìm thấy trang: ${state.error}'),
      ),
    ),
  );
});

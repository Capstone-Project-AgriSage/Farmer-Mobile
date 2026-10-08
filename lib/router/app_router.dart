import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/network/dio_provider.dart';
import '../core/session/session_manager.dart';
import '../core/storage/app_prefs.dart';
import '../features/orders/data/order_models.dart';
import '../features/orders/screens/order_success_screen.dart';

// Auth
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';

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
import '../features/profile/screens/address_list_screen.dart';
import '../features/profile/screens/address_form_screen.dart';

// Articles
import '../features/home/screens/article_list_screen.dart';
import '../features/home/screens/article_detail_screen.dart';

abstract class AppRoutes {
  // Auth
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

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
  static const orderSuccess = '/order-success';
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

/// Screens a signed-out user may open; a signed-in user who lands on one of them is sent on to the app.
const _guestRoutes = {
  AppRoutes.splash,
  AppRoutes.onboarding,
  AppRoutes.welcome,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

/// Where the router sends the user, or null to let the navigation go ahead. Pure so it can be unit tested.
String? resolveRedirect({
  required SessionStatus status,
  required String location,
  required String? from,
  required bool onboardingSeen,
}) {
  if (status == SessionStatus.restoring) {
    // Hold every location on the splash until the stored token has been checked with the server.
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (status == SessionStatus.signedOut) {
    if (location == AppRoutes.splash) {
      return onboardingSeen ? AppRoutes.welcome : AppRoutes.onboarding;
    }
    if (_guestRoutes.contains(location)) return null;
    return '${AppRoutes.login}?from=${Uri.encodeComponent(location)}';
  }

  // Signed in.
  if (_guestRoutes.contains(location)) {
    return _safeReturnPath(from) ?? AppRoutes.home;
  }
  return null;
}

/// Only an in-app path may be returned to; never an external URL or a guest-only screen.
String? _safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) return null;
  final path = Uri.tryParse(from)?.path;
  if (path == null || _guestRoutes.contains(path)) return null;
  return from;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionManagerProvider);
  final prefs = ref.watch(appPrefsProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: session,
    redirect: (context, state) => resolveRedirect(
      status: session.status,
      location: state.uri.path,
      from: state.uri.queryParameters['from'],
      onboardingSeen: prefs.onboardingSeen,
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
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
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
              GoRoute(
                path: 'articles',
                builder: (_, __) => const ArticleListScreen(),
              ),
              GoRoute(
                path: 'articles/:id',
                builder: (_, state) => ArticleDetailScreen(
                  articleId: state.pathParameters['id']!,
                ),
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
              // Static paths first, otherwise `history` would be read as an `:id`.
              GoRoute(
                path: 'history',
                builder: (_, __) => const DebtHistoryScreen(),
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
              GoRoute(
                path: 'addresses',
                builder: (_, __) => const AddressListScreen(),
              ),
              GoRoute(
                path: 'addresses/add',
                builder: (_, __) => const AddressFormScreen(),
              ),
              GoRoute(
                path: 'addresses/edit/:id',
                builder: (_, state) => AddressFormScreen(
                  addressId: state.pathParameters['id'],
                ),
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
        path: AppRoutes.orderSuccess,
        builder: (_, state) => OrderSuccessScreen(order: state.extra is Order ? state.extra as Order : null),
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
        builder: (_, __) => const QRPaymentScreen(),
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

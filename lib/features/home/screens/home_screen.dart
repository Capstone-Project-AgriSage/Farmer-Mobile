import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../ai_doctor/data/diagnosis_models.dart';
import '../../ai_doctor/providers/diagnosis_providers.dart';
import '../../ai_doctor/widgets/diagnosis_widgets.dart';
import '../../debt/providers/debt_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../orders/data/order_models.dart';
import '../../orders/widgets/order_widgets.dart';
import '../../payment/widgets/pending_payment_banner.dart';
import '../../products/providers/catalog_providers.dart';
import '../providers/home_providers.dart';

/// Trang chủ: lối tắt và tóm tắt DỮ LIỆU THẬT của chính nông dân (chẩn đoán gần
/// đây, đơn hàng, công nợ). Không có nội dung mẫu.
///
/// Bố cục: đầu trang xanh (lời chào + chuông) → thẻ lối tắt đè lên mép đầu trang →
/// thẻ khám bệnh lúa → các mục có tiêu đề riêng (chẩn đoán, đơn hàng, công nợ).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(homeOrderStatsProvider)
      ..invalidate(latestDiagnosisProvider)
      ..invalidate(debtAccountProvider)
      ..invalidate(unreadCountProvider);
    await Future.wait([
      ref.read(homeOrderStatsProvider.future),
      ref.read(latestDiagnosisProvider.future),
      ref.read(debtAccountProvider.future),
    ]).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    // Đầu trang xanh kéo lên tận thanh trạng thái: chữ/biểu tượng hệ thống màu sáng.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        body: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          edgeOffset: MediaQuery.paddingOf(context).top,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(user: user),
                const _QuickActionsOverlap(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PendingPaymentBanner(),
                      _AiCard(),
                      _DiagnosisSection(),
                      _OrdersSection(),
                      _DebtSection(),
                      SizedBox(height: 96), // chừa chỗ cho thanh điều hướng dưới
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Đầu trang ───────────────────────────────────────────────────────

const _headerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.primaryDark, AppColors.primary],
);

String _greeting(DateTime now) {
  final h = now.hour;
  if (h < 11) return 'Chào buổi sáng';
  if (h < 14) return 'Chào buổi trưa';
  if (h < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

String _todayLabel(DateTime now) {
  const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
  final d = now.day.toString().padLeft(2, '0');
  final m = now.month.toString().padLeft(2, '0');
  return '${days[now.weekday - 1]}, $d/$m/${now.year}';
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final SessionUser? user;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _headerGradient),
      padding: EdgeInsets.fromLTRB(20, top + 16, 12, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hoạ tiết lá chìm (vẽ bằng icon, không tải từ mạng).
          Positioned(
            right: 36,
            top: -28,
            child: Icon(Icons.eco_rounded, size: 120, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                ),
                alignment: Alignment.center,
                child: Text(user?.initials ?? '',
                    style: AppTextStyles.h4.copyWith(color: AppColors.primaryDark)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(now),
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white.withValues(alpha: 0.85), height: 1.3)),
                    const SizedBox(height: 2),
                    Text(user?.fullName ?? '',
                        key: const Key('home_greeting'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(color: Colors.white, height: 1.25)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(_todayLabel(now),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Colors.white.withValues(alpha: 0.75))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const NotificationBell(
                  route: '${AppRoutes.home}/notifications',
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thẻ lối tắt đè lên mép dưới của đầu trang xanh.
class _QuickActionsOverlap extends StatelessWidget {
  const _QuickActionsOverlap();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Phần đuôi của đầu trang (bo góc dưới), thẻ lối tắt nằm đè lên.
        Container(
          height: 48,
          decoration: const BoxDecoration(
            gradient: _headerGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _QuickActions(),
        ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final overdue = ref.watch(hasOverdueDebtProvider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuickAction(
            key: const Key('home_qa_shop'),
            icon: Icons.storefront_outlined,
            label: 'Mua sắm',
            color: AppColors.primary,
            onTap: () => context.go(AppRoutes.products),
          ),
          _QuickAction(
            key: const Key('home_qa_cart'),
            icon: Icons.shopping_cart_outlined,
            label: 'Giỏ hàng',
            color: const Color(0xFFEF6C00),
            badge: cartCount > 0 ? (cartCount > 99 ? '99+' : '$cartCount') : null,
            onTap: () => context.push(AppRoutes.cart),
          ),
          _QuickAction(
            key: const Key('home_qa_orders'),
            icon: Icons.receipt_long_outlined,
            label: 'Đơn hàng',
            color: const Color(0xFF1565C0),
            onTap: () => context.push(AppRoutes.orderList),
          ),
          _QuickAction(
            key: const Key('home_qa_debt'),
            icon: Icons.account_balance_wallet_outlined,
            label: 'Công nợ',
            color: const Color(0xFF6A1B9A),
            dot: overdue,
            onTap: () => context.go(AppRoutes.debt),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Số nhỏ ở góc biểu tượng (vd. số món trong giỏ).
  final String? badge;

  /// Chấm đỏ cảnh báo (vd. có nợ quá hạn).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    // Máy màn hẹp (≈320px): ô nhỏ hơn một chút để nhãn không dính nhau.
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final box = narrow ? 46.0 : 52.0;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              children: [
                Badge(
                  isLabelVisible: badge != null || dot,
                  smallSize: 10,
                  label: badge == null ? null : Text(badge!),
                  backgroundColor: AppColors.statusError,
                  child: Container(
                    width: box,
                    height: box,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: narrow ? 23 : 26),
                  ),
                ),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: narrow ? 12 : 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Khám bệnh lúa ───────────────────────────────────────────────────

class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3F2E5), Color(0xFFF4FAF3)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_outlined,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('AI nhận diện ngay',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Khám bệnh cho cây lúa',
                        style: AppTextStyles.h3.copyWith(color: AppColors.primaryDark)),
                    const SizedBox(height: 4),
                    Text(
                      'Chụp ảnh lá lúa, AI cho biết bệnh và cách xử lý ngay; cửa hàng tư vấn thêm khi cần.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Màn hẹp: bỏ minh hoạ để chữ không bị dồn thành nhiều dòng.
              if (MediaQuery.sizeOf(context).width >= 360) ...[
                const SizedBox(width: 12),
                const _LeafIllustration(),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  key: const Key('home_capture'),
                  onPressed: () => context.push(AppRoutes.aiScan),
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Chụp ảnh')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  key: const Key('home_history'),
                  onPressed: () => context.push(AppRoutes.diagnoseHistory),
                  icon: const Icon(Icons.history_rounded, size: 20),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Lịch sử')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minh hoạ vẽ bằng hình tròn + biểu tượng (không cần ảnh).
class _LeafIllustration extends StatelessWidget {
  const _LeafIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF43A047), AppColors.primaryDark],
              ),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 30),
          ),
          Positioned(
            right: 2,
            bottom: 6,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.search_rounded, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Khung dùng chung của các mục ────────────────────────────────────

/// Tiêu đề mục (chữ thường, đậm) + liên kết bên phải.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionText,
    this.onAction,
    this.actionKey,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 17)),
          ),
          if (actionText != null)
            InkWell(
              key: actionKey,
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionText!,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thẻ trắng bo góc lớn, bóng mờ.
class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// Khung xương lấp lánh trong lúc tải (thay vòng quay).
class _Skeleton extends StatelessWidget {
  const _Skeleton({this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6ECE6),
      highlightColor: const Color(0xFFF6F9F5),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(0.5, 12),
                for (var i = 0; i < lines; i++) ...[
                  const SizedBox(height: 10),
                  bar(i.isEven ? 0.9 : 0.7, 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardError extends StatelessWidget {
  const _CardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_off_outlined, size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      );
}

/// Trạng thái trống trong một thẻ: biểu tượng + lời nhắn + nút hành động.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    super.key,
    required this.icon,
    required this.message,
    required this.button,
  });

  final IconData icon;
  final String message;
  final Widget button;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          button,
        ],
      );
}

ButtonStyle _softButtonStyle() => OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      backgroundColor: AppColors.primarySubtle,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

// ── Chẩn đoán gần đây ───────────────────────────────────────────────

class _DiagnosisSection extends ConsumerWidget {
  const _DiagnosisSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestDiagnosisProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Chẩn đoán gần đây',
          actionText: 'Lịch sử',
          actionKey: const Key('home_diag_history'),
          onAction: () => context.push(AppRoutes.diagnoseHistory),
        ),
        _Panel(
          key: const Key('home_diag_card'),
          child: latest.when(
            loading: () => const _Skeleton(),
            error: (_, __) => _CardError(
                message: 'Chưa tải được chẩn đoán gần đây.',
                onRetry: () => ref.invalidate(latestDiagnosisProvider)),
            data: (c) => c == null
                ? _InlineEmpty(
                    key: const Key('home_diag_none'),
                    icon: Icons.photo_camera_outlined,
                    message: 'Bạn chưa gửi ảnh lá lúa nào để AI chẩn đoán.',
                    button: OutlinedButton.icon(
                      key: const Key('home_diag_start'),
                      onPressed: () => context.push(AppRoutes.imageCapture),
                      style: _softButtonStyle(),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Chụp ảnh lá lúa'),
                    ),
                  )
                : _DiagnosisBody(summary: c),
          ),
        ),
      ],
    );
  }
}

class _DiagnosisBody extends ConsumerWidget {
  const _DiagnosisBody({required this.summary});

  final DiagnosisSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final verified = s.status == DiagnosisStatus.verified;
    final hasDisease = s.diseaseDisplay != null;
    final hint = switch (s.status) {
      _ when hasDisease && s.isUncertain =>
        'AI chưa chắc chắn. Hãy chụp lại gần một lá bệnh hoặc hỏi cửa hàng.',
      _ when hasDisease && verified => 'Cửa hàng đã xác nhận kết quả cho ảnh của bạn.',
      _ when hasDisease => 'AI đã có kết quả cho ảnh của bạn. Mở để xem cách xử lý.',
      DiagnosisStatus.inconclusive => 'Ảnh chưa đủ rõ. Hãy chụp lại và gửi ảnh mới.',
      DiagnosisStatus.cancelled => 'Bạn đã huỷ ca này.',
      DiagnosisStatus.failed => 'AI chưa phân tích được ảnh. Mở để thử lại.',
      _ => 'AI đang phân tích ảnh của bạn.',
    };
    final (statusFg, statusBg) = DiagnosisStatus.colors(s.status);
    final icon = switch (s.status) {
      _ when hasDisease && s.isUncertain => Icons.help_outline_rounded,
      _ when hasDisease => Icons.task_alt_rounded,
      DiagnosisStatus.inconclusive => Icons.camera_enhance_outlined,
      DiagnosisStatus.cancelled => Icons.block_rounded,
      DiagnosisStatus.failed => Icons.cloud_off_outlined,
      _ => Icons.hourglass_top_rounded,
    };

    // Sản phẩm gợi ý: AI chắc chắn, hoặc ca cũ đã xác nhận; AI chưa chắc thì không có. Lỗi thì bỏ qua phần này.
    final products = hasDisease && !s.isUncertain
        ? ref.watch(diagnosisDetailProvider(s.id)).valueOrNull?.result?.products ??
            const <RecommendedProduct>[]
        : const <RecommendedProduct>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('home_diag_latest'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/ai-scan/case/${s.id}'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: statusFg, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.caseNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textMuted, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        DiagnosisStatusBadge(s.status),
                      ],
                    ),
                    if (hasDisease) ...[
                      const SizedBox(height: 4),
                      Text(s.isUncertain ? 'Có thể là ${s.diseaseDisplay!}' : s.diseaseDisplay!,
                          key: const Key('home_diag_disease'),
                          style: AppTextStyles.h4.copyWith(fontSize: 16)),
                    ],
                    const SizedBox(height: 4),
                    Text(hint,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 12),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        if (products.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Sản phẩm gợi ý',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final p in products.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: Key('home_diag_product_${p.storeProductId}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/products/${p.storeProductId}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_pharmacy_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLarge),
                      ),
                      const SizedBox(width: 8),
                      Text('Xem',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
        // Ca cũ cửa hàng đã xác nhận ghi rõ; kết quả AI ghi là AI dự đoán.
        if (hasDisease) ...[
          const SizedBox(height: 6),
          Row(
            key: Key(verified ? 'home_diag_verified_note' : 'home_diag_ai_note'),
            children: [
              Icon(verified ? Icons.verified_user_outlined : Icons.auto_awesome_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    verified
                        ? 'Kết quả do cửa hàng xác nhận'
                        : 'Kết quả do AI dự đoán, có thể chưa chính xác',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Đơn hàng ────────────────────────────────────────────────────────

class _OrdersSection extends ConsumerWidget {
  const _OrdersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeOrderStatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Đơn hàng của bạn',
          actionText: 'Xem tất cả',
          actionKey: const Key('home_orders_all'),
          onAction: () => context.push(AppRoutes.orderList),
        ),
        _Panel(
          key: const Key('home_orders_card'),
          child: stats.when(
            loading: () => const _Skeleton(lines: 3),
            error: (_, __) => _CardError(
                message: 'Chưa tải được đơn hàng của bạn.',
                onRetry: () => ref.invalidate(homeOrderStatsProvider)),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          valueKey: const Key('home_stat_pending'),
                          title: 'Chờ xác nhận',
                          count: s.pending,
                          color: const Color(0xFFEF6C00),
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _Stat(
                          valueKey: const Key('home_stat_progress'),
                          title: 'Đang xử lý',
                          count: s.inProgress,
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _Stat(
                          valueKey: const Key('home_stat_done'),
                          title: 'Hoàn thành',
                          count: s.done,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.borderSubtle),
                ),
                if (s.latest == null)
                  _InlineEmpty(
                    key: const Key('home_orders_none'),
                    icon: Icons.shopping_bag_outlined,
                    message: 'Bạn chưa có đơn hàng nào.',
                    button: OutlinedButton.icon(
                      key: const Key('home_shop_now'),
                      onPressed: () => context.go(AppRoutes.products),
                      style: _softButtonStyle(),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Mua sắm ngay'),
                    ),
                  )
                else
                  _LatestOrder(order: s.latest!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.title,
    required this.count,
    required this.valueKey,
    required this.color,
  });

  final Key valueKey;
  final String title;
  final int count;

  /// Màu của con số khi > 0 (bằng 0 thì xám cho đỡ rối mắt).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Column(
      children: [
        Text('$count',
            key: valueKey,
            style: AppTextStyles.h2.copyWith(
                color: active ? color : AppColors.textMuted, height: 1.2)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(title,
              maxLines: 1,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: VerticalDivider(width: 1, thickness: 1, color: AppColors.borderSubtle),
      );
}

class _LatestOrder extends StatelessWidget {
  const _LatestOrder({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final caption = AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary);
    return InkWell(
      key: const Key('home_latest_order'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/orders/${order.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đơn gần nhất',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(order.orderNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelLarge),
                    ),
                    const SizedBox(width: 8),
                    Text(formatVnd(order.totalAmount),
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryDark)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OrderStatusBadge(order.status),
                    Text('Đặt lúc ${formatDateTime(order.createdAt)}', style: caption),
                    Text('•', style: caption),
                    Text('${order.itemCount} sản phẩm', style: caption),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 12),
            child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Công nợ ─────────────────────────────────────────────────────────

/// Chỉ hiện khi nông dân đang có nợ (không có nợ thì không chiếm chỗ).
class _DebtSection extends ConsumerWidget {
  const _DebtSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(debtAccountProvider).valueOrNull;
    if (account == null || !account.hasDebt) return const SizedBox.shrink();
    final overdue = account.hasOverdue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Công nợ',
          actionText: 'Xem chi tiết',
          actionKey: const Key('home_debt_open'),
          onAction: () => context.go(AppRoutes.debt),
        ),
        _Panel(
          key: const Key('home_debt_card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: Color(0xFF6A1B9A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đang nợ',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary, fontSize: 13)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(formatVnd(account.currentBalance),
                              key: const Key('home_debt_balance'),
                              style: AppTextStyles.h2.copyWith(height: 1.25)),
                        ),
                      ],
                    ),
                  ),
                  if (account.openEntryCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${account.openEntryCount} khoản',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              if (overdue) ...[
                const SizedBox(height: 12),
                Container(
                  key: const Key('home_debt_overdue'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.statusErrorSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 18, color: AppColors.debtOverdue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${formatVnd(account.overdueAmount)} đã quá hạn',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.debtOverdue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

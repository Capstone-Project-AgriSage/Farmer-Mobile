import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/diagnosis_models.dart';
import '../data/diagnosis_repository.dart';
import '../providers/diagnosis_providers.dart';
import '../widgets/diagnosis_widgets.dart';
import '../../home/providers/home_providers.dart';

/// Chi tiết một ca chẩn đoán. Từ 21/10/2026 không còn chuyên gia duyệt: AI phân tích xong là có kết quả
/// (AI chắc chắn, hoặc chưa chắc thì không gợi ý thuốc). AI lỗi thì nông dân bấm "Thử lại".
///
/// Khi AI còn đang phân tích, màn hình tự hỏi lại định kỳ và khi người dùng quay lại app.
class DiagnoseCaseScreen extends ConsumerStatefulWidget {
  const DiagnoseCaseScreen({
    super.key,
    required this.caseId,
    @visibleForTesting this.pollInterval = const Duration(seconds: 30),
  });

  final String caseId;
  final Duration pollInterval;

  @override
  ConsumerState<DiagnoseCaseScreen> createState() => _DiagnoseCaseScreenState();
}

class _DiagnoseCaseScreenState extends ConsumerState<DiagnoseCaseScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  bool _cancelling = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(widget.pollInterval, (_) => _pollIfWaiting());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pollIfWaiting();
  }

  void _pollIfWaiting() {
    final c = ref.read(diagnosisDetailProvider(widget.caseId)).valueOrNull;
    if (c != null && c.isWaiting) {
      ref.invalidate(diagnosisDetailProvider(widget.caseId));
      invalidateDiagnoses(ref);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(diagnosisDetailProvider(widget.caseId));
    invalidateDiagnoses(ref);
    await ref
        .read(diagnosisDetailProvider(widget.caseId).future)
        .then((_) {}, onError: (_) {});
  }

  Future<void> _cancel(DiagnosisCase c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ ca chẩn đoán'),
        content: Text('Bạn muốn huỷ ca ${c.caseNumber}? Ca sẽ được lưu là đã huỷ.'),
        actions: [
          TextButton(
            key: const Key('case_cancel_no'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không huỷ'),
          ),
          ElevatedButton(
            key: const Key('case_cancel_yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Huỷ ca'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(diagnosisRepositoryProvider).cancel(c.id);
      if (!mounted) return;
      await _refresh();
      messenger.showSnackBar(const SnackBar(content: Text('Đã huỷ ca chẩn đoán.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      await _refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _retry(DiagnosisCase c) async {
    setState(() => _retrying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(diagnosisRepositoryProvider).retry(c.id);
      if (!mounted) return;
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      await _refresh();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(diagnosisDetailProvider(widget.caseId));
    final c = detail.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.diagnoseHistory),
        ),
        title: const Text('Chi tiết chẩn đoán'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: detail.when(
        skipLoadingOnRefresh: true,
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerLoadingWidget(height: 220, borderRadius: 20),
            SizedBox(height: 12),
            ShimmerLoadingWidget(height: 72, borderRadius: 18),
            SizedBox(height: 12),
            ShimmerLoadingWidget(height: 160, borderRadius: 18),
          ],
        ),
        error: (e, _) => ErrorRetryWidget(
            error: e,
            onRetry: () => ref.invalidate(diagnosisDetailProvider(widget.caseId))),
        data: (d) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (d.image != null) DiagnosisPhoto(url: d.image!.url),
              if (d.image != null) const SizedBox(height: 12),
              _Header(c: d),
              const SizedBox(height: 12),
              if (d.result != null)
                _ResultView(result: d.result!)
              else if (d.status == DiagnosisStatus.inconclusive)
                _InconclusiveView(info: d.inconclusive)
              else if (d.status == DiagnosisStatus.cancelled)
                const _CancelledView()
              else if (d.status == DiagnosisStatus.failed || d.canRetry)
                _FailedView(
                  canRetry: d.canRetry,
                  retrying: _retrying,
                  onRetry: () => _retry(d),
                )
              else
                const _WaitingView(),
              if (d.note != null && d.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  icon: Icons.notes,
                  title: 'Ghi chú của bạn',
                  child: Text(d.note!, style: AppTextStyles.bodySmall),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: c != null && c.canCancel
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('case_cancel'),
                    onPressed: _cancelling ? null : () => _cancel(c),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      side: const BorderSide(color: AppColors.statusError),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Huỷ ca chẩn đoán'),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c});

  final DiagnosisCase c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_florist_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.caseNumber,
                    style: AppTextStyles.labelLarge, key: const Key('case_number')),
                const SizedBox(height: 2),
                Text('Gửi lúc ${formatDateTime(c.submittedAt)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DiagnosisStatusBadge(c.status),
        ],
      ),
    );
  }
}

/// AI đang phân tích ảnh (thường chỉ vài giây).
class _WaitingView extends StatelessWidget {
  const _WaitingView();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.hourglass_top,
      title: 'AI đang phân tích ảnh',
      child: Column(
        key: const Key('case_waiting'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Step(text: 'Đã gửi ảnh', done: true),
          const _Step(text: 'AI phân tích ảnh', current: true),
          const _Step(text: 'Có kết quả và cách xử lý', last: true),
          const SizedBox(height: 12),
          Text(
            'Thường chỉ mất vài giây. Kéo xuống để làm mới.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// AI chưa phân tích được ảnh (dịch vụ AI bận hoặc chưa sẵn sàng): thử lại, hoặc gửi ảnh khác.
class _FailedView extends StatelessWidget {
  const _FailedView({required this.canRetry, required this.retrying, required this.onRetry});

  final bool canRetry;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.cloud_off_outlined,
      title: 'Chưa phân tích được ảnh',
      child: Column(
        key: const Key('case_failed'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dịch vụ AI đang bận hoặc chưa sẵn sàng. Bạn hãy thử lại sau ít phút, hoặc gửi một ảnh khác.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          if (canRetry)
            ElevatedButton.icon(
              key: const Key('case_retry'),
              onPressed: retrying ? null : onRetry,
              icon: retrying
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
              label: Text(retrying ? 'Đang phân tích lại...' : 'Thử lại'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('case_new_photo'),
            onPressed: retrying ? null : () => context.pushReplacement(AppRoutes.imageCapture),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Gửi ảnh khác'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.text, this.done = false, this.current = false, this.last = false});

  final String text;
  final bool done;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = done
        ? (Icons.check_circle_rounded, AppColors.statusSuccess)
        : current
            ? (Icons.radio_button_checked_rounded, AppColors.primary)
            : (Icons.radio_button_unchecked_rounded, AppColors.borderStrong);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: done || current ? FontWeight.w600 : FontWeight.w400,
                    color: done || current ? AppColors.textPrimary : AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _CancelledView extends StatelessWidget {
  const _CancelledView();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.cancel_outlined,
      title: 'Đã huỷ',
      child: Text('Bạn đã huỷ ca này. Cần khám lại thì hãy gửi ảnh mới.',
          key: const Key('case_cancelled'),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _InconclusiveView extends StatelessWidget {
  const _InconclusiveView({required this.info});

  final DiagnosisInconclusive? info;

  @override
  Widget build(BuildContext context) {
    final retake = info?.hint == 'RETAKE_PHOTO' || info?.hint == null;
    return SectionCard(
      icon: Icons.photo_camera_outlined,
      title: 'Cửa hàng chưa kết luận được',
      child: Column(
        key: const Key('case_inconclusive'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            retake
                ? 'Ảnh chưa đủ rõ để kết luận. Bạn hãy chụp lại và gửi ảnh mới.'
                : 'Chưa thể kết luận từ ảnh này.',
            style: AppTextStyles.bodySmall,
          ),
          if (info?.comment != null && info!.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Cửa hàng nhắn: "${info!.comment}"',
                  key: const Key('case_comment'), style: AppTextStyles.bodySmall),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('case_retake'),
              onPressed: () => context.pushReplacement(AppRoutes.imageCapture),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Chụp lại'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final d = result.disease;
    final uncertain = result.isUncertain;
    final color = d.isHealthy && !uncertain ? AppColors.statusSuccess : AppColors.statusWarning;
    final bg = d.isHealthy && !uncertain ? AppColors.statusSuccessSurface : AppColors.statusWarningSurface;
    final heading = switch (result.certainty) {
      DiagnosisCertainty.uncertain => 'AI chưa chắc chắn, có thể là',
      DiagnosisCertainty.confident => 'Kết quả từ AI',
      _ => 'Cửa hàng đã xác nhận',
    };
    final noContent = !_has(d.symptoms) && !_has(d.prevention) && result.treatments.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('case_result'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                      uncertain
                          ? Icons.help_outline_rounded
                          : d.isHealthy
                              ? Icons.verified_rounded
                              : Icons.coronavirus_outlined,
                      size: 18,
                      color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(heading,
                        key: const Key('case_certainty'),
                        style: AppTextStyles.caption
                            .copyWith(color: color, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(d.displayName,
                  key: const Key('case_disease'),
                  style: AppTextStyles.h2.copyWith(color: color)),
              if (d.name.isNotEmpty && d.name != d.displayName)
                Text(d.name, style: AppTextStyles.caption.copyWith(color: color)),
              if (d.isHealthy && !uncertain) ...[
                const SizedBox(height: 6),
                Text('Cây không có dấu hiệu bệnh.',
                    style: AppTextStyles.bodySmall.copyWith(color: color)),
              ],
              if (result.isFromAi) ...[
                const SizedBox(height: 6),
                Text('Kết quả do AI dự đoán từ ảnh, có thể chưa chính xác.',
                    style: AppTextStyles.caption.copyWith(color: color)),
              ],
            ],
          ),
        ),
        if (uncertain) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.photo_camera_outlined,
            title: 'Nên chụp lại hoặc hỏi cửa hàng',
            child: Column(
              key: const Key('case_uncertain'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'AI chưa chắc đây là bệnh gì nên chưa gợi ý thuốc. Bạn hãy chụp lại gần một lá bệnh, đủ sáng, hoặc mang mẫu lá đến cửa hàng để được tư vấn.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  key: const Key('case_retake'),
                  onPressed: () => context.pushReplacement(AppRoutes.imageCapture),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Chụp lại'),
                ),
              ],
            ),
          ),
        ],
        if (result.reviewerComment != null && result.reviewerComment!.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.record_voice_over_outlined,
            title: 'Nhận xét của cửa hàng',
            child: Text(result.reviewerComment!,
                key: const Key('case_comment'), style: AppTextStyles.bodySmall),
          ),
        ],
        if (_has(d.symptoms)) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.search,
            title: 'Triệu chứng',
            child: Text(d.symptoms!, style: AppTextStyles.bodySmall),
          ),
        ],
        if (_has(d.prevention)) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.shield_outlined,
            title: 'Cách phòng ngừa',
            child: Text(d.prevention!, style: AppTextStyles.bodySmall),
          ),
        ],
        if (result.treatments.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.medical_services_outlined,
            title: 'Hướng dẫn điều trị',
            child: Column(
              key: const Key('case_treatments'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < result.treatments.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: AppColors.borderSubtle),
                  _TreatmentTile(t: result.treatments[i]),
                ],
              ],
            ),
          ),
        ],
        if (noContent && !d.isHealthy) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.info_outline,
            title: 'Cách xử lý',
            child: Text('Cửa hàng chưa nhập hướng dẫn cho bệnh này. Bạn hãy hỏi cửa hàng để được tư vấn.',
                key: const Key('case_no_content'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
        ],
        if (result.products.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Sản phẩm gợi ý',
            child: Column(
              key: const Key('case_products'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in result.products) _ProductTile(p: p),
              ],
            ),
          ),
        ] else if (result.certainty == DiagnosisCertainty.confident && !d.isHealthy) ...[
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Sản phẩm gợi ý',
            child: Text('Cửa hàng chưa có sản phẩm gợi ý cho bệnh này, hãy hỏi cửa hàng.',
                key: const Key('case_no_products'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
        ],
        if (result.isFromAi || result.treatments.isNotEmpty || result.products.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('case_disclaimer'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              result.isFromAi
                  ? 'Kết quả do AI gợi ý, không thay thế tư vấn của cán bộ kỹ thuật. Đọc kỹ nhãn thuốc và hỏi cửa hàng trước khi dùng.'
                  : 'Hãy đọc kỹ hướng dẫn và liên hệ cửa hàng khi cần thêm tư vấn trước khi dùng thuốc.',
              style: AppTextStyles.caption.copyWith(color: const Color(0xFF5D4037), height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  bool _has(String? s) => s != null && s.trim().isNotEmpty;
}

class _TreatmentTile extends StatelessWidget {
  const _TreatmentTile({required this.t});

  final Treatment t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(
                text: treatmentTypeLabel(t.type),
                fg: AppColors.primaryDark,
                bg: AppColors.primaryLight),
            Text(t.title,
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        Text(t.instructions, style: AppTextStyles.bodySmall),
        if (t.activeIngredientName != null && t.activeIngredientName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Hoạt chất: ${t.activeIngredientName}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ],
        if (t.precautions != null && t.precautions!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.statusWarning),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Lưu ý: ${t.precautions}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.p});

  final RecommendedProduct p;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('case_product_${p.storeProductId}'),
      onTap: () => context.push('/products/${p.storeProductId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: p.imageUrl == null || p.imageUrl!.isEmpty
                    ? const _ProductPlaceholder()
                    : CachedNetworkImage(
                        imageUrl: p.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const _ProductPlaceholder(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  if (p.reason != null && p.reason!.isNotEmpty)
                    Text(p.reason!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surfaceSubtle,
        child: const Icon(Icons.inventory_2_outlined, color: AppColors.borderStrong),
      );
}

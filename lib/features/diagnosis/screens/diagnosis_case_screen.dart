import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/diagnosis_labels.dart';
import '../../../core/labels/status_label.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/diagnosis_models.dart';
import '../providers/diagnosis_providers.dart';

/// One diagnosis case: waiting for a specialist, the verified result with guidance and products, or "send a better photo".
class DiagnosisCaseScreen extends ConsumerWidget {
  const DiagnosisCaseScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(diagnosisDetailProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/ai-scan'),
        ),
        title: const Text('Kết quả chẩn đoán'),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(diagnosisDetailProvider(caseId))),
        data: (item) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(diagnosisDetailProvider(caseId));
            try {
              await ref.read(diagnosisDetailProvider(caseId).future);
            } catch (_) {
              // The screen shows its own error.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _Header(item: item),
              const SizedBox(height: 16),
              if (item.isVerified)
                _VerifiedBody(result: item.result!)
              else if (item.isInconclusive)
                _InconclusiveBody(item: item)
              else if (item.isCancelled)
                const _Notice(
                  icon: Icons.cancel_outlined,
                  title: 'Yêu cầu này đã hủy',
                  message: 'Bác có thể gửi một ảnh mới bất cứ lúc nào.',
                )
              else
                _WaitingBody(item: item),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});

  final DiagnosisCase item;

  @override
  Widget build(BuildContext context) {
    final photo = item.photo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('#${item.caseNumber}', style: AppTextStyles.labelLarge)),
              const SizedBox(width: 8),
              StatusBadge(labelOf(diagnosisStatusLabels, item.status)),
            ],
          ),
          if (item.submittedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Gửi lúc ${formatVnDateTime(item.submittedAt!)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (photo != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.network(
                  photo.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceSubtle,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 36),
                  ),
                ),
              ),
            ),
          ],
          if (item.farmerNote != null) ...[
            const SizedBox(height: 12),
            Text('Ghi chú của Bác: ${item.farmerNote}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _WaitingBody extends ConsumerStatefulWidget {
  const _WaitingBody({required this.item});

  final DiagnosisCase item;

  @override
  ConsumerState<_WaitingBody> createState() => _WaitingBodyState();
}

class _WaitingBodyState extends ConsumerState<_WaitingBody> {
  bool _busy = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy yêu cầu này?'),
        content: const Text('Chuyên viên sẽ không xem ảnh này nữa. Bác có thể gửi ảnh mới sau.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Giữ lại')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hủy yêu cầu')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(diagnosisActionsProvider).cancel(widget.item.id);
    } on AppException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Notice(
          icon: Icons.hourglass_top_rounded,
          title: 'Đang chờ chuyên viên xem',
          message:
              'Chuyên viên của đại lý sẽ xem ảnh của Bác và xác nhận bệnh. Bác sẽ nhận thông báo khi có kết quả; kéo xuống để cập nhật.',
        ),
        if (widget.item.canCancel) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Hủy yêu cầu'),
          ),
        ],
      ],
    );
  }
}

class _InconclusiveBody extends StatelessWidget {
  const _InconclusiveBody({required this.item});

  final DiagnosisCase item;

  @override
  Widget build(BuildContext context) {
    final comment = item.inconclusive?.comment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          icon: Icons.photo_camera_back_outlined,
          title: 'Chưa thể kết luận từ ảnh này',
          message: comment == null || comment.isEmpty
              ? 'Chuyên viên chưa đủ căn cứ để kết luận. Bác thử chụp lại ảnh rõ hơn: gần lá bệnh, đủ sáng, không bị mờ.'
              : comment,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => context.push('/ai-scan/capture'),
          icon: const Icon(Icons.camera_alt, size: 20),
          label: const Text('Chụp lại ảnh'),
        ),
      ],
    );
  }
}

class _VerifiedBody extends StatelessWidget {
  const _VerifiedBody({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final disease = result.disease;
    final name = diseaseDisplayName(disease.code, fallback: disease.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          accent: disease.isHealthy ? AppColors.primary : AppColors.statusWarning,
          children: [
            Text(disease.isHealthy ? 'Kết luận' : 'Chuyên viên xác nhận bệnh', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(name, style: AppTextStyles.h3),
            if (disease.symptoms != null) ...[
              const SizedBox(height: 12),
              Text('Biểu hiện', style: AppTextStyles.labelLarge),
              const SizedBox(height: 4),
              Text(disease.symptoms!, style: AppTextStyles.bodySmall),
            ],
            if (disease.prevention != null) ...[
              const SizedBox(height: 12),
              Text('Phòng ngừa', style: AppTextStyles.labelLarge),
              const SizedBox(height: 4),
              Text(disease.prevention!, style: AppTextStyles.bodySmall),
            ],
            if (result.reviewerComment != null) ...[
              const SizedBox(height: 12),
              Text('Nhận xét của chuyên viên', style: AppTextStyles.labelLarge),
              const SizedBox(height: 4),
              Text(result.reviewerComment!, style: AppTextStyles.bodySmall),
            ],
          ],
        ),
        if (result.treatments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Cách xử lý', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          for (final treatment in result.treatments) ...[
            _Card(
              children: [
                Text(treatmentTypeLabel(treatment.type), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(treatment.title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 6),
                Text(treatment.instructions, style: AppTextStyles.bodySmall),
                if (treatment.precautions != null) ...[
                  const SizedBox(height: 6),
                  Text('Lưu ý: ${treatment.precautions}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusWarning)),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (result.products.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Sản phẩm gợi ý của đại lý', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          for (final product in result.products) ...[
            _ProductTile(product: product),
            const SizedBox(height: 8),
          ],
          Text(
            'Đọc kỹ nhãn và hỏi nhân viên cửa hàng trước khi dùng thuốc.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final RecommendedProduct product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: product.productId.isEmpty ? null : () => context.push('/products/${product.productId}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: product.imageUrl == null
                    ? Container(color: AppColors.surfaceSubtle, child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted))
                    : Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceSubtle, child: const Icon(Icons.inventory_2_outlined)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: AppTextStyles.labelLarge),
                  if (product.reason != null) ...[
                    const SizedBox(height: 2),
                    Text(product.reason!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children, this.accent});

  final List<Widget> children;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent ?? AppColors.borderSubtle, width: accent == null ? 1 : 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusWarningSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.statusWarning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 4),
                Text(message, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5D4037), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

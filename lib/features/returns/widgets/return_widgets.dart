import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/return_models.dart';

class ReturnStatusBadge extends StatelessWidget {
  const ReturnStatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = ReturnStatus.colors(status);
    return StatusChip(text: ReturnStatus.label(status), fg: fg, bg: bg);
  }
}

/// Tiến trình xử lý một yêu cầu trả hàng.
class ReturnTimeline extends StatelessWidget {
  const ReturnTimeline({super.key, required this.detail});

  final ReturnDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.status;
    final steps = <_Step>[
      _Step('Gửi yêu cầu', detail.requestedAt),
      _Step('Cửa hàng duyệt', detail.approvedAt),
      _Step('Cửa hàng nhận hàng', detail.receivedAt),
      _Step('Kiểm tra hàng', detail.inspectedAt),
      _Step('Hoàn tất', detail.completedAt),
    ];

    if (ReturnStatus.isFailed(s)) {
      // Dừng ở bước đã đạt, rồi một bước kết thúc màu đỏ.
      final reached = <_Step>[steps.first];
      if (detail.approvedAt != null) reached.add(steps[1]);
      if (detail.receivedAt != null) reached.add(steps[2]);
      return Column(children: [
        for (final r in reached) _row(r.label, r.at, _State.done),
        _row(
          s == ReturnStatus.rejected ? 'Cửa hàng từ chối' : 'Đã huỷ yêu cầu',
          detail.cancelledAt,
          _State.failed,
          last: true,
        ),
      ]);
    }

    final reachedIndex = switch (s) {
      ReturnStatus.requested => 0,
      ReturnStatus.approved => 1,
      ReturnStatus.received => 2,
      ReturnStatus.inspected || ReturnStatus.partiallyResolved => 3,
      ReturnStatus.completed => 4,
      _ => 0,
    };
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        _row(
          steps[i].label,
          steps[i].at,
          i < reachedIndex || (i == reachedIndex && s == ReturnStatus.completed)
              ? _State.done
              : i == reachedIndex
                  ? _State.current
                  : _State.todo,
          last: i == steps.length - 1,
        ),
    ]);
  }

  Widget _row(String label, DateTime? at, _State state, {bool last = false}) {
    final (icon, color) = switch (state) {
      _State.done => (Icons.check_circle, AppColors.statusSuccess),
      _State.current => (Icons.radio_button_checked, AppColors.primary),
      _State.failed => (Icons.cancel, AppColors.statusError),
      _State.todo => (Icons.radio_button_unchecked, AppColors.borderStrong),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(icon, size: 20, color: color),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: AppColors.borderSubtle),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: state == _State.todo ? FontWeight.w400 : FontWeight.w600,
                          color: state == _State.todo
                              ? AppColors.textMuted
                              : state == _State.failed
                                  ? AppColors.statusError
                                  : AppColors.textPrimary)),
                  if (at != null)
                    Text(formatDateTime(at),
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _State { done, current, failed, todo }

class _Step {
  const _Step(this.label, this.at);

  final String label;
  final DateTime? at;
}

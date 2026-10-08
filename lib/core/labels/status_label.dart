import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum LabelTone { neutral, pending, progress, success, danger }

/// A status as the farmer sees it: Vietnamese words and a colour.
class StatusLabel {
  const StatusLabel(this.label, this.tone);

  final String label;
  final LabelTone tone;
}

/// Looks a code up; a code the app does not know yet shows as itself (neutral) instead of breaking the screen.
StatusLabel labelOf(Map<String, StatusLabel> map, String? code) {
  if (code == null || code.isEmpty) return const StatusLabel('—', LabelTone.neutral);
  return map[code] ?? StatusLabel(code, LabelTone.neutral);
}

extension LabelToneColors on LabelTone {
  Color get foreground => switch (this) {
        LabelTone.neutral => AppColors.textSecondary,
        LabelTone.pending => const Color(0xFF92400E),
        LabelTone.progress => const Color(0xFF1E40AF),
        LabelTone.success => AppColors.primary,
        LabelTone.danger => AppColors.statusError,
      };

  Color get background => switch (this) {
        LabelTone.neutral => AppColors.surfaceSubtle,
        LabelTone.pending => const Color(0xFFFFFBEB),
        LabelTone.progress => const Color(0xFFEFF6FF),
        LabelTone.success => AppColors.primaryLight,
        LabelTone.danger => AppColors.statusErrorSurface,
      };
}

import 'package:flutter/material.dart';

/// AgriSage Design Tokens — bám sát chính xác @theme trong Farmer-Web/src/index.css
abstract class AppColors {
  // ── Primary (xanh lá nông nghiệp) ──────────────────────────────
  static const Color primary = Color(0xFF2E7D32);        // --color-primary
  static const Color primaryDark = Color(0xFF1B5E20);    // --color-primary-dark
  static const Color primaryHover = Color(0xFF256628);   // --color-primary-hover
  static const Color primaryLight = Color(0xFFE8F5E9);   // --color-primary-light
  static const Color primarySubtle = Color(0xFFF5FBF4);  // --color-primary-subtle

  // ── Surface ────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF);            // --color-surface
  static const Color surfaceSecondary = Color(0xFFEDF4EE);   // --color-surface-secondary
  static const Color surfaceSubtle = Color(0xFFF5FBF4);      // --color-surface-subtle
  static const Color surfaceDim = Color(0xFFD6DCD5);         // --color-surface-dim

  // ── Border ─────────────────────────────────────────────────────
  static const Color borderSubtle = Color(0xFFE1E8E2);   // --color-border-subtle
  static const Color borderStrong = Color(0xFFB0BEB3);   // --color-border-strong

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF172118);    // --color-text-primary
  static const Color textSecondary = Color(0xFF465348);  // --color-text-secondary
  static const Color textMuted = Color(0xFF7A8A7C);      // --color-text-muted

  // ── Status ─────────────────────────────────────────────────────
  static const Color statusError = Color(0xFFC62828);          // --color-status-error
  static const Color statusErrorSurface = Color(0xFFFFEBEE);   // --color-status-error-surface
  static const Color statusSuccess = Color(0xFF2E7D32);        // --color-status-success
  static const Color statusSuccessSurface = Color(0xFFE8F5E9); // --color-status-success-surface
  static const Color statusWarning = Color(0xFFE65100);        // --color-status-warning (orange)
  static const Color statusWarningSurface = Color(0xFFFFF3E0);

  // ── Debt Status Colors (5 trạng thái sổ nợ) ───────────────────
  static const Color debtNormal = Color(0xFF2E7D32);      // Bình thường
  static const Color debtSoonDue = Color(0xFFF57F17);     // Sắp đến hạn
  static const Color debtDue = Color(0xFFE65100);         // Đến hạn
  static const Color debtOverdue = Color(0xFFC62828);     // Quá hạn
  static const Color debtPaid = Color(0xFF7A8A7C);        // Đã thanh toán

  // ── Misc ───────────────────────────────────────────────────────
  static const Color scrim = Color(0x80000000);          // overlay 50%
  static const Color transparent = Colors.transparent;
}

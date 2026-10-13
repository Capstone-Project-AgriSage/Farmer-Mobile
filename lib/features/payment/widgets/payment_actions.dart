import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../router/app_router.dart';
import '../data/pending_payment.dart';

/// Tạo link payOS (qua [start], thường là `launcher.startOrderPayment` / `startDebtRepayment`) rồi
/// mở trang thanh toán trong app. Lỗi (503 chưa cấu hình payOS, mất mạng...) hiện bằng snackbar.
///
/// Trả `true` khi trang thanh toán đã mở và đã đóng lại (hoặc được thay bằng màn kết quả).
Future<bool> openPayosPayment({
  required GoRouter router,
  required ScaffoldMessengerState messenger,
  required Future<PendingPayment> Function() start,
}) async {
  final PendingPayment pending;
  try {
    pending = await start();
  } on ApiException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
  await router.push<void>(AppRoutes.payosCheckout, extra: pending);
  return true;
}

// Chụp ảnh luồng payOS (màn kết quả các trạng thái, banner thanh toán dở, trang WebView giả)
// bằng font thật (cần mạng để tải font Google).
//
//   SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/payment_screenshots_test.dart
//
// Ảnh ra ở test/visual/shots/ (xem xong thì xoá thư mục). Test cũng thất bại nếu
// có lỗi tràn layout với font thật ở cả khung 390px và 320px.
// Trang payOS thật (WebView) không chụp được ở đây: xem tool/payos_webview_test.
import 'dart:convert';
import 'dart:io';

import 'package:farmer_mobile/features/payment/data/pending_payment.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/debt_fakes.dart';
import '../helpers/order_fakes.dart';
import 'auth_screenshots_test.dart' show shoot, useRealFonts;

final _on = Platform.environment['SCREENSHOTS'] == '1';

PendingPayment _order() => PendingPayment(
      paymentId: 'pay1',
      paymentNumber: 'PM-20261013-0001',
      context: PaymentContext.orderPayment,
      amount: 1560000,
      checkoutUrl: 'https://pay.payos.vn/web/pay1',
      userId: 'u1',
      orderId: 'o1',
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );

PendingPayment _debt() => PendingPayment(
      paymentId: 'pay2',
      paymentNumber: 'PM-20261013-0002',
      context: PaymentContext.debtRepayment,
      amount: 2350000,
      checkoutUrl: 'https://pay.payos.vn/web/pay2',
      userId: 'u1',
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );

void main() {
  for (final width in [390.0, 320.0]) {
    final tag = width.toInt();

    Future<AppHarness> openResult(WidgetTester tester, PendingPayment p, PaymentHint hint,
        {bool simulated = false, void Function(AppHarness)? setup}) async {
      await useRealFonts(tester);
      final h = AppHarness()..signIn();
      h.orders.orders['o1'] = orderOf(id: 'o1');
      h.orders.paymentsByOrder['o1'] = paymentsOf(total: 1560000);
      h.orders.deliveriesByOrder['o1'] = const [];
      h.debt.account0 = accountOf();
      setup?.call(h);
      await h.pump(tester, initial: '/home');
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      h.router.push(AppRoutes.paymentResult,
          extra: PaymentResultArgs(p, hint, simulated: simulated));
      await tester.pumpAndSettle();
      return h;
    }

    group('ảnh thanh toán payOS $tag px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      testWidgets('kết quả: đơn hàng thành công', (tester) async {
        await openResult(tester, _order(), PaymentHint.returned,
            setup: (h) => h.payments.statuses.add('PAID'));
        await shoot(tester, '${tag}_pay_result_order_paid');
      });

      testWidgets('kết quả: trả nợ thành công', (tester) async {
        await openResult(tester, _debt(), PaymentHint.returned,
            setup: (h) => h.payments.statuses.add('PAID'));
        await shoot(tester, '${tag}_pay_result_debt_paid');
      });

      testWidgets('kết quả: đã huỷ', (tester) async {
        await openResult(tester, _order(), PaymentHint.cancelled);
        await shoot(tester, '${tag}_pay_result_cancelled');
      });

      testWidgets('kết quả: đang chờ xác nhận', (tester) async {
        await openResult(tester, _order(), PaymentHint.check,
            setup: (h) => h.payments.statuses.addAll(List.filled(20, 'PENDING')));
        await shoot(tester, '${tag}_pay_result_pending');
      });

      testWidgets('kết quả: thất bại', (tester) async {
        await openResult(tester, _order(), PaymentHint.returned,
            setup: (h) => h.payments.statuses.add('FAILED'));
        await shoot(tester, '${tag}_pay_result_failed');
      });

      testWidgets('kết quả: cổng thử', (tester) async {
        await openResult(tester, _order(), PaymentHint.returned,
            simulated: true, setup: (h) => h.payments.statuses.add('PENDING'));
        await shoot(tester, '${tag}_pay_result_simulated');
      });

      testWidgets('trang chủ: banner thanh toán dở', (tester) async {
        await useRealFonts(tester);
        final h = AppHarness()..signIn();
        h.realHome = true;
        h.debt.account0 = null;
        await h.paymentStore
            .setString(PendingPaymentStore.key, jsonEncode(_order().toJson()));
        await h.pump(tester, initial: '/home');
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        await tester.pumpAndSettle();
        expect(find.textContaining('chưa hoàn tất'), findsOneWidget);
        await shoot(tester, '${tag}_home_pending_payment');
      });
    });
  }
}

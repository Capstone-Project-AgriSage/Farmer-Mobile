import 'dart:convert';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/debt/screens/debt_overview_screen.dart';
import 'package:farmer_mobile/features/payment/data/pending_payment.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:farmer_mobile/features/payment/screens/payment_result_screen.dart';
import 'package:farmer_mobile/features/products/screens/order_detail_screen.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/debt_fakes.dart';
import '../../helpers/order_fakes.dart';

// Màn kết quả + banner thanh toán dở + nút "Thanh toán" ở chi tiết đơn.
// Trang payOS (WebView) không chạy trong flutter test: harness thay bằng màn giả `payos_stub`;
// WebView được kiểm tra trên emulator (integration_test).

PendingPayment orderPayment({String id = 'pay1', String? orderId = 'o1'}) => PendingPayment(
      paymentId: id,
      paymentNumber: 'PM-$id',
      context: PaymentContext.orderPayment,
      amount: 1560000,
      checkoutUrl: 'https://pay.payos.vn/web/$id',
      userId: 'u1',
      orderId: orderId,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

PendingPayment debtPayment({String id = 'pay1'}) => PendingPayment(
      paymentId: id,
      paymentNumber: 'PM-$id',
      context: PaymentContext.debtRepayment,
      amount: 500000,
      checkoutUrl: 'https://pay.payos.vn/web/$id',
      userId: 'u1',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

/// Vào Trang chủ giả rồi đẩy màn kết quả lên (đúng cách trang payOS làm: pushReplacement).
Future<AppHarness> openResult(
  WidgetTester tester,
  PendingPayment payment,
  PaymentHint hint, {
  bool simulated = false,
  void Function(AppHarness)? setup,
}) async {
  final h = AppHarness()..signIn();
  h.orders.orders['o1'] = orderOf(id: 'o1');
  h.orders.paymentsByOrder['o1'] = paymentsOf(total: 1560000);
  h.orders.deliveriesByOrder['o1'] = const [];
  h.debt.account0 = accountOf();
  setup?.call(h);
  await h.pump(tester, initial: '/home');
  await h.container.read(pendingPaymentProvider.notifier).save(payment);
  h.router.push(AppRoutes.paymentResult,
      extra: PaymentResultArgs(payment, hint, simulated: simulated));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('Màn kết quả thanh toán', () {
    testWidgets('PAID đơn hàng: biên nhận, quên khoản dở, dẫn tới đơn', (tester) async {
      final h = await openResult(tester, orderPayment(), PaymentHint.returned,
          setup: (h) => h.payments.statuses.add('PAID'));

      expect(find.text('Thanh toán thành công!'), findsOneWidget);
      expect(find.text('Mã thanh toán: PM-pay1'), findsOneWidget);
      expect(find.textContaining('xác nhận đơn hàng của bạn'), findsOneWidget);
      expect(h.container.read(pendingPaymentProvider), isNull);

      await tester.tap(find.text('Xem chi tiết đơn hàng'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    });

    testWidgets('PAID trả nợ: lời nhắn riêng và nút về Sổ nợ', (tester) async {
      await openResult(tester, debtPayment(), PaymentHint.returned,
          setup: (h) => h.payments.statuses.add('PAID'));

      expect(find.text('Thanh toán thành công!'), findsOneWidget);
      expect(find.textContaining('Khoản trả nợ đã được ghi nhận vào Sổ nợ'), findsOneWidget);

      await tester.tap(find.text('Quay lại Sổ nợ'));
      await tester.pumpAndSettle();
      expect(find.byType(DebtOverviewScreen), findsOneWidget);
    });

    testWidgets('server nói còn PENDING: không bao giờ báo thành công, cho kiểm tra lại', (tester) async {
      final h = await openResult(tester, orderPayment(), PaymentHint.returned,
          setup: (h) => h.payments.statuses.addAll(List.filled(20, 'PENDING')));

      expect(find.text('Thanh toán thành công!'), findsNothing);
      expect(find.text('Đang chờ xác nhận'), findsOneWidget);
      expect(find.text('Kiểm tra lại'), findsOneWidget);
      expect(h.container.read(pendingPaymentProvider), isNotNull);
    });

    testWidgets('đã huỷ: báo server huỷ, cho Thanh toán lại bằng link mới', (tester) async {
      final h = await openResult(tester, orderPayment(), PaymentHint.cancelled);

      expect(h.payments.calls, contains('cancel:pay1'));
      expect(find.text('Bạn đã hủy thanh toán'), findsOneWidget);
      expect(h.container.read(pendingPaymentProvider), isNull);

      await tester.tap(find.text('Thanh toán lại'));
      await tester.pumpAndSettle();

      expect(h.payments.calls, contains('create:o1'));
      expect(find.byKey(const Key('payos_stub')), findsOneWidget);
      expect(h.container.read(pendingPaymentProvider)?.orderId, 'o1');
    });

    testWidgets('trả nợ đã huỷ: Thanh toán lại tạo link trả nợ đúng số tiền', (tester) async {
      final h = await openResult(tester, debtPayment(), PaymentHint.cancelled);

      await tester.tap(find.text('Thanh toán lại'));
      await tester.pumpAndSettle();

      expect(h.payments.lastDebtAmount, 500000);
      expect(find.byKey(const Key('payos_stub')), findsOneWidget);
    });

    testWidgets('thất bại: báo lỗi và cho thanh toán lại', (tester) async {
      await openResult(tester, orderPayment(), PaymentHint.returned,
          setup: (h) => h.payments.statuses.add('FAILED'));

      expect(find.text('Thanh toán không thành công'), findsOneWidget);
      expect(find.text('Thanh toán lại'), findsOneWidget);
    });

    testWidgets('mất mạng: lỗi có nút Thử lại, rồi thành công', (tester) async {
      final h = await openResult(tester, orderPayment(), PaymentHint.check,
          setup: (h) => h.payments.getError = const ApiException(
              kind: ApiErrorKind.network,
              message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.'));

      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      expect(h.payments.calls.where((c) => c.startsWith('cancel')), isEmpty);

      h.payments.getError = null;
      h.payments.statuses.add('PAID');
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công!'), findsOneWidget);
    });

    testWidgets('link thử: hộp môi trường thử và nút thanh toán nhanh', (tester) async {
      final h = await openResult(tester, orderPayment(), PaymentHint.returned,
          simulated: true, setup: (h) => h.payments.statuses.add('PENDING'));

      expect(find.textContaining('môi trường thử'), findsWidgets);
      await tester.tap(find.text('Thanh toán nhanh (môi trường thử)'));
      await tester.pumpAndSettle();

      expect(h.payments.calls, contains('simulate:pay1'));
      expect(find.text('Thanh toán thành công!'), findsOneWidget);
    });

    testWidgets('nút Back không quay về trang payOS: về Trang chủ', (tester) async {
      final h = await openResult(tester, orderPayment(), PaymentHint.returned,
          setup: (h) => h.payments.statuses.add('PAID'));
      expect(find.byType(PaymentResultScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PaymentResultScreen), findsNothing);
      expect(h.location, AppRoutes.home);
    });
  });

  group('Banner thanh toán dở ở Trang chủ', () {
    Future<AppHarness> openHome(WidgetTester tester, {PendingPayment? pending}) async {
      final h = AppHarness()..signIn();
      h.realHome = true;
      h.debt.account0 = null;
      h.orders.orders['o1'] = orderOf(id: 'o1');
      h.orders.paymentsByOrder['o1'] = paymentsOf(total: 1560000);
      h.orders.deliveriesByOrder['o1'] = const [];
      if (pending != null) {
        await h.paymentStore.setString(
            PendingPaymentStore.key, jsonEncode(pending.toJson()));
      }
      await h.pump(tester, initial: '/home');
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('không có khoản dở: không hiện banner', (tester) async {
      await openHome(tester);
      expect(find.textContaining('chưa hoàn tất'), findsNothing);
    });

    testWidgets('có khoản dở: hiện số tiền, Kiểm tra mở màn kết quả', (tester) async {
      final h = await openHome(tester, pending: orderPayment());
      h.payments.statuses.add('PAID');

      expect(find.textContaining('một thanh toán chưa hoàn tất'), findsOneWidget);
      expect(find.textContaining('1.560.000đ'), findsWidgets);

      await tester.tap(find.text('Kiểm tra'));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công!'), findsOneWidget);
    });

    testWidgets('Thanh toán tiếp mở lại đúng trang payOS của khoản đó', (tester) async {
      await openHome(tester, pending: orderPayment(id: 'payX'));

      await tester.tap(find.text('Thanh toán tiếp'));
      await tester.pumpAndSettle();

      expect(find.text('PAYOS payX'), findsOneWidget);
    });

    testWidgets('khoản dở đã hết hạn: không hiện', (tester) async {
      final expired = PendingPayment(
        paymentId: 'old',
        paymentNumber: 'PM-old',
        context: PaymentContext.orderPayment,
        amount: 1000,
        checkoutUrl: 'https://pay.payos.vn/web/old',
        userId: 'u1',
        orderId: 'o1',
        expiresAt: DateTime.utc(2020),
      );
      await openHome(tester, pending: expired);
      expect(find.textContaining('chưa hoàn tất'), findsNothing);
    });
  });

  group('Nút Thanh toán ở chi tiết đơn', () {
    testWidgets('bấm Thanh toán: tạo link, lưu khoản dở, mở trang payOS', (tester) async {
      final h = AppHarness()..signIn();
      h.orders.orders['o1'] = orderOf(id: 'o1');
      h.orders.paymentsByOrder['o1'] = paymentsOf(total: 1560000, paid: 0);
      h.orders.deliveriesByOrder['o1'] = const [];
      await h.pump(tester, initial: '/orders/o1');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('order_pay')));
      await tester.pumpAndSettle();

      expect(h.payments.calls, ['create:o1']);
      expect(find.text('PAYOS pay1'), findsOneWidget);
      expect(h.container.read(pendingPaymentProvider)?.orderId, 'o1');
    });

    testWidgets('payOS chưa cấu hình (503): báo bằng thông báo, không mở trang thanh toán', (tester) async {
      final h = AppHarness()..signIn();
      h.orders.orders['o1'] = orderOf(id: 'o1');
      h.orders.paymentsByOrder['o1'] = paymentsOf(total: 1560000, paid: 0);
      h.orders.deliveriesByOrder['o1'] = const [];
      h.payments.createError = const ApiException(
          kind: ApiErrorKind.unavailable,
          statusCode: 503,
          message: 'Thanh toán online đang gián đoạn. Vui lòng thử lại sau hoặc thanh toán tại cửa hàng.');
      await h.pump(tester, initial: '/orders/o1');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('order_pay')));
      await tester.pumpAndSettle();

      expect(find.textContaining('gián đoạn'), findsOneWidget);
      expect(find.byKey(const Key('payos_stub')), findsNothing);
      expect(h.container.read(pendingPaymentProvider), isNull);
    });
  });
}

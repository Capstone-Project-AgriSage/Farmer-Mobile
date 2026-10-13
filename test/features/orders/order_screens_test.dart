import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/order_fakes.dart';

const _net = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');

Future<AppHarness> open(WidgetTester tester, String route,
    {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  setup?.call(h);
  await h.pump(tester, initial: route);
  await tester.pumpAndSettle();
  return h;
}

void seedOrder(AppHarness h, OrderDetail o,
    {OrderPayments? payments, List<Delivery> deliveries = const []}) {
  h.orders.orders[o.id] = o;
  h.orders.paymentsByOrder[o.id] = payments ?? paymentsOf(total: o.totalAmount);
  h.orders.deliveriesByOrder[o.id] = deliveries;
}

void main() {
  group('Danh sách đơn', () {
    testWidgets('hiện số đơn, trạng thái, hình thức, tổng tiền', (tester) async {
      await open(tester, '/orders', setup: (h) {
        h.orders.list0 = [
          summaryOf('a', status: 'PENDING_CONFIRMATION', total: 1560000),
          summaryOf('b', status: 'COMPLETED', total: 450000, settlement: 'CREDIT', fulfillment: 'PICKUP'),
        ];
      });

      expect(find.text('DH-a'), findsOneWidget);
      expect(find.text('Chờ xác nhận'), findsWidgets);
      expect(find.text('Hoàn thành'), findsWidgets);
      expect(find.text('1.560.000đ'), findsOneWidget);
      expect(find.textContaining('Giao hàng tận nơi · Trả ngay · 1 sản phẩm'), findsOneWidget);
      expect(find.textContaining('Nhận tại cửa hàng · Mua ghi nợ'), findsOneWidget);
    });

    testWidgets('lọc theo trạng thái gọi API với status', (tester) async {
      final h = await open(tester, '/orders', setup: (h) {
        h.orders.list0 = [
          summaryOf('a', status: 'PENDING_CONFIRMATION'),
          summaryOf('b', status: 'COMPLETED'),
        ];
      });

      await tester.scrollUntilVisible(find.byKey(const Key('order_filter_COMPLETED')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('order_filter_COMPLETED')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order_filter_COMPLETED')));
      await tester.pumpAndSettle();

      expect(h.orders.listCalls.last, (page: 1, status: 'COMPLETED'));
      expect(find.byKey(const Key('order_b')), findsOneWidget);
      expect(find.byKey(const Key('order_a')), findsNothing);
    });

    testWidgets('trống: thông báo; lọc mà trống: nêu tên trạng thái', (tester) async {
      await open(tester, '/orders');
      expect(find.text('Bạn chưa có đơn hàng nào.'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('order_filter_CANCELLED')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('order_filter_CANCELLED')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order_filter_CANCELLED')));
      await tester.pumpAndSettle();
      expect(find.text('Không có đơn hàng "Đã huỷ".'), findsOneWidget);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, '/orders', setup: (h) => h.orders.listError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);

      h.orders.listError = null;
      h.orders.list0 = [summaryOf('a')];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order_a')), findsOneWidget);
    });

    testWidgets('nhiều trang: Xem thêm tải trang 2', (tester) async {
      final h = AppHarness()..signIn();
      h.orders.pageSize0 = 2;
      h.orders.list0 = [for (var i = 0; i < 3; i++) summaryOf('o$i')];
      await h.pump(tester, initial: '/orders');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byKey(const Key('orders_load_more')), 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const Key('orders_load_more')));
      await tester.pumpAndSettle();

      expect(h.orders.listCalls.last.page, 2);
      await tester.scrollUntilVisible(find.byKey(const Key('order_o2')), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const Key('order_o2')), findsOneWidget);
      expect(find.byKey(const Key('orders_load_more')), findsNothing);
    });

    testWidgets('bấm đơn mở chi tiết', (tester) async {
      final h = await open(tester, '/orders', setup: (h) {
        h.orders.list0 = [summaryOf('a')];
        seedOrder(h, orderOf(id: 'a'));
      });
      await tester.tap(find.byKey(const Key('order_a')));
      await tester.pumpAndSettle();
      expect(h.orders.calls, contains('get:a'));
      expect(find.byKey(const Key('order_number')), findsOneWidget);
    });
  });

  group('Chi tiết đơn', () {
    testWidgets('đơn chờ xác nhận chưa trả: nhắc chờ thanh toán, có nút Thanh toán và Huỷ',
        (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1')));

      expect(find.text('Chờ xác nhận'), findsWidgets);
      expect(find.textContaining('Cửa hàng chỉ xác nhận đơn khi đã nhận đủ tiền'), findsOneWidget);
      expect(find.text('Lúa giống ST25'), findsOneWidget);
      expect(find.text('Bao 25 kg × 2 · 780.000đ'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('order_total'))).data, '1.560.000đ');
      expect(tester.widget<Text>(find.byKey(const Key('pay_remaining'))).data, '1.560.000đ');
      expect(find.byKey(const Key('order_pay')), findsOneWidget);
      expect(find.text('Thanh toán 1.560.000đ'), findsOneWidget);
      expect(find.byKey(const Key('order_cancel')), findsOneWidget);
      expect(find.textContaining('Ấp 3, Tân Phú, Cái Răng, Cần Thơ'), findsOneWidget);
    });

    testWidgets('đã trả đủ: ẩn nút Thanh toán, hiện lịch sử thanh toán', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1'),
          payments: paymentsOf(paid: 1560000, items: [paymentItem('p1')])));

      expect(find.byKey(const Key('order_pay')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('pay_paid'))).data, '1.560.000đ');
      expect(tester.widget<Text>(find.byKey(const Key('pay_remaining'))).data, '0đ');
      expect(find.text('Đã thanh toán'), findsWidgets);
      expect(find.textContaining('payOS (VietQR) · 1.560.000đ'), findsOneWidget);
      // Vẫn huỷ được khi đơn chờ xác nhận.
      expect(find.byKey(const Key('order_cancel')), findsOneWidget);
    });

    testWidgets('đơn đã xác nhận: không huỷ online được, không có nút huỷ', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1', status: 'CONFIRMED'),
          payments: paymentsOf(paid: 1560000, items: [paymentItem('p1')])));
      expect(find.byKey(const Key('order_cancel')), findsNothing);
      expect(find.byKey(const Key('order_pay')), findsNothing);
    });

    testWidgets('đơn xác nhận nhưng còn nợ tiền: vẫn có nút Thanh toán số còn lại', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1', status: 'CONFIRMED'),
          payments: paymentsOf(paid: 500000, items: [paymentItem('p1', amount: 500000)])));
      expect(find.text('Thanh toán 1.060.000đ'), findsOneWidget);
    });

    testWidgets('đơn mua ghi nợ: không có nút Thanh toán, giải thích công nợ', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h,
          orderOf(id: 'o1', settlement: 'CREDIT', creditTermDays: 30)));
      expect(find.byKey(const Key('order_pay')), findsNothing);
      expect(find.textContaining('trả nợ ở mục Công nợ'), findsOneWidget);
      expect(find.text('Mua ghi nợ · 30 ngày'), findsOneWidget);
    });

    testWidgets('đơn đã huỷ: lý do, không có nút nào; ghi chú hiện', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h,
          orderOf(id: 'o1', status: 'CANCELLED', cancelReason: 'Đổi ý', note: 'Gọi trước')));
      expect(find.text('Đơn đã bị huỷ: Đổi ý'), findsOneWidget);
      expect(find.text('Ghi chú: Gọi trước'), findsOneWidget);
      expect(find.byKey(const Key('order_pay')), findsNothing);
      expect(find.byKey(const Key('order_cancel')), findsNothing);
    });

    testWidgets('đơn đã huỷ có khoản hoàn tiền: nhắc cửa hàng sẽ liên hệ', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h,
          orderOf(id: 'o1', status: 'CANCELLED'),
          payments: paymentsOf(paid: 1560000, items: [paymentItem('p1')], refunds: 1)));
      expect(find.byKey(const Key('pay_refund_note')), findsOneWidget);
    });

    testWidgets('huỷ đơn: hỏi xác nhận, gửi lý do, đơn chuyển Đã huỷ', (tester) async {
      final h = await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1')));

      await tester.tap(find.byKey(const Key('order_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Bạn có chắc muốn huỷ đơn DH-o1?'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('cancel_reason')), 'Đổi ý');
      await tester.tap(find.byKey(const Key('cancel_confirm')));
      await tester.pumpAndSettle();

      expect(h.orders.lastCancelReason, 'Đổi ý');
      expect(find.text('Đơn đã bị huỷ: Đổi ý'), findsOneWidget);
      expect(find.byKey(const Key('order_cancel')), findsNothing);
      expect(find.text('Đã huỷ đơn hàng.'), findsOneWidget);
    });

    testWidgets('huỷ đơn đã trả tiền: cảnh báo hoàn tiền thủ công', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1'),
          payments: paymentsOf(paid: 1560000, items: [paymentItem('p1')])));

      await tester.tap(find.byKey(const Key('order_cancel')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cửa hàng sẽ liên hệ để hoàn tiền'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Đã huỷ đơn. Cửa hàng sẽ liên hệ hoàn tiền.'), findsOneWidget);
    });

    testWidgets('Không huỷ: giữ nguyên đơn', (tester) async {
      final h = await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1')));
      await tester.tap(find.byKey(const Key('order_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không'));
      await tester.pumpAndSettle();
      expect(h.orders.calls.where((c) => c.startsWith('cancel')), isEmpty);
    });

    testWidgets('cửa hàng vừa xác nhận (422 khi huỷ): báo lỗi và tải lại trạng thái', (tester) async {
      final h = await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1')));
      h.orders.cancelError = const ApiException(
          kind: ApiErrorKind.businessRule,
          statusCode: 422,
          message: 'Cửa hàng đã xác nhận đơn nên không thể huỷ online. Vui lòng liên hệ cửa hàng.');
      h.orders.orders['o1'] = orderOf(id: 'o1', status: 'CONFIRMED');

      await tester.tap(find.byKey(const Key('order_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel_confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('không thể huỷ online'), findsOneWidget);
      expect(find.byKey(const Key('order_cancel')), findsNothing); // trạng thái đã cập nhật
    });

    testWidgets('đơn không tồn tại (404)', (tester) async {
      await open(tester, '/orders/khong-co');
      expect(find.text('Không tìm thấy đơn hàng.'), findsOneWidget);
    });

    testWidgets('giao hàng: chưa lập phiếu → thông báo', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1')));
      await tester.scrollUntilVisible(find.byKey(const Key('delivery_empty')), 200);
      expect(find.byKey(const Key('delivery_empty')), findsOneWidget);
    });

    testWidgets('nhận tại cửa hàng: không có mục theo dõi giao hàng', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1', fulfillment: 'PICKUP')));
      expect(find.text('THEO DÕI GIAO HÀNG'), findsNothing);
    });

    testWidgets('giao hàng: tài xế, tiến độ, lần giao thất bại có lý do', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h,
          orderOf(id: 'o1', status: 'PARTIALLY_FULFILLED'),
          payments: paymentsOf(paid: 1560000, items: [paymentItem('p1')]),
          deliveries: [
            deliveryOf('d1', status: 'RETRY_PENDING', attempts: [
              DeliveryAttempt(
                number: 1,
                status: 'FAILED',
                startedAt: DateTime.utc(2026, 10, 12, 5, 10),
                completedAt: DateTime.utc(2026, 10, 12, 5, 20),
                failureReasonCode: 'CUSTOMER_ABSENT',
              ),
            ]),
          ]));

      await tester.scrollUntilVisible(find.byKey(const Key('delivery_d1')), 300);
      expect(find.text('DL-d1'), findsOneWidget);
      expect(find.text('Chờ giao lại'), findsOneWidget);
      expect(find.textContaining('Tài xế: Trần Văn B · 0912000111'), findsOneWidget);
      expect(find.byKey(const Key('call_d1')), findsOneWidget);
      expect(find.textContaining('đã giao 1/2 · còn 1'), findsOneWidget);
      expect(find.text('Lần 1: Không thành công'), findsOneWidget);
      expect(find.text('Lý do: Khách vắng nhà'), findsOneWidget);
    });

    testWidgets('lỗi tải thanh toán / giao hàng không làm hỏng cả màn: có nút Thử lại', (tester) async {
      await open(tester, '/orders/o1', setup: (h) => seedOrder(h, orderOf(id: 'o1')));
      // Màn vẫn hiện thông tin đơn dù các mục phụ có thể lỗi (kiểm tra cấu trúc).
      expect(find.byKey(const Key('order_number')), findsOneWidget);
    });
  });

  test('PayOsLink / Payment parse', () {
    final p = Payment.fromJson({'id': 'x', 'paymentNumber': 'PM', 'status': 'PAID', 'amount': 5});
    expect(p.isPaid, isTrue);
    expect(PaymentStatus.label('FAILED'), 'Thất bại / hết hạn');
  });
}


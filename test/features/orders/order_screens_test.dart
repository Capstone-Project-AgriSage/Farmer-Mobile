import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/network/paged.dart';
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/orders/data/delivery_models.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:farmer_mobile/features/payment/data/payment_repository.dart';
import 'package:farmer_mobile/features/products/screens/order_detail_screen.dart';
import 'package:farmer_mobile/features/products/screens/order_list_screen.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/checkout_fixtures.dart' show orderJson;
import '../../support/order_fixtures.dart';
import '../../support/payment_fixtures.dart' show payosStartJson;
import '../cart/cart_controller_test.dart' show TestUserId;
import '../checkout/checkout_controller_test.dart' show MockOrderRepository;
import '../payment/payment_providers_test.dart' show MockPaymentRepository;

void main() {
  late MockOrderRepository orders;
  late MockPaymentRepository payments;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    orders = MockOrderRepository();
    payments = MockPaymentRepository();
  });

  Future<GoRouter> pump(WidgetTester tester, Widget home, {String initial = '/'}) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: '/orders/:id', builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!)),
        GoRoute(path: AppRoutes.orderList, builder: (_, __) => const OrderListScreen()),
        GoRoute(path: AppRoutes.home, builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: AppRoutes.payosCheckout, builder: (_, state) => const Scaffold(body: Text('PAYOS PAGE'))),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          paymentRepositoryProvider.overrideWithValue(payments),
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// The status tabs scroll sideways: bring the one wanted into view, then tap it.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 150, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text(label)); // built is not the same as on screen
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Paged<OrderListItem> rows(List<Map<String, dynamic>> items) =>
      Paged(items: items.map(OrderListItem.fromJson).toList(), page: 1, pageSize: 20, totalCount: items.length);

  void stubList(Paged<OrderListItem> Function(String? status) answer) {
    when(() => orders.list(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .thenAnswer((invocation) async => answer(invocation.namedArguments[#status] as String?));
  }

  group('order list', () {
    testWidgets('shows each order with its status, date, size and total', (tester) async {
      stubList((_) => rows([
            orderListRow(number: 'OD-1', status: 'PENDING_CONFIRMATION'),
            orderListRow(id: 'o-2', number: 'OD-2', status: 'COMPLETED', settlement: 'CREDIT', total: 460000),
          ]));
      await pump(tester, const OrderListScreen());

      expect(find.text('#OD-1'), findsOneWidget);
      expect(find.text('#OD-2'), findsOneWidget);
      expect(find.text('Chờ xác nhận'), findsWidgets); // the badge and the tab
      expect(find.text('1.560.000 ₫'), findsOneWidget);
      expect(find.text('1 sản phẩm · Mua ghi nợ'), findsOneWidget);
      expect(find.text('16:10 08/10/2026'), findsWidgets, reason: '09:10 UTC is 16:10 in Vietnam');
    });

    testWidgets('a tab asks the server for that status', (tester) async {
      stubList((status) => status == 'COMPLETED' ? rows([orderListRow(number: 'OD-DONE', status: 'COMPLETED')]) : rows([orderListRow(number: 'OD-ALL')]));
      await pump(tester, const OrderListScreen());
      expect(find.text('#OD-ALL'), findsOneWidget);

      await tapTab(tester, 'Hoàn thành');

      expect(find.text('#OD-DONE'), findsOneWidget);
      expect(find.text('#OD-ALL'), findsNothing);
      verify(() => orders.list(status: 'COMPLETED', page: 1, pageSize: 20)).called(1);
    });

    testWidgets('no orders at all, and no orders in a status, say different things', (tester) async {
      stubList((_) => rows([]));
      await pump(tester, const OrderListScreen());
      expect(find.text('Bác chưa có đơn hàng nào'), findsOneWidget);

      await tapTab(tester, 'Đã hủy');
      expect(find.text('Không có đơn hàng ở trạng thái này'), findsOneWidget);
    });

    testWidgets('a failure shows the message and a retry that works', (tester) async {
      var fail = true;
      when(() => orders.list(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async {
        if (fail) throw const AppException.offline();
        return rows([orderListRow(number: 'OD-BACK')]);
      });
      await pump(tester, const OrderListScreen());
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('#OD-BACK'), findsOneWidget);
    });

    testWidgets('tapping an order opens it', (tester) async {
      stubList((_) => rows([orderListRow(id: 'o-1', number: 'OD-1')]));
      when(() => orders.get('o-1')).thenAnswer((_) async => Order.fromJson(orderWith()));
      when(() => orders.deliveries('o-1')).thenAnswer((_) async => []);
      when(() => orders.payments('o-1')).thenAnswer((_) async => OrderPaymentSummary.fromJson(paymentSummaryJson()));
      await pump(tester, const OrderListScreen());

      await tester.tap(find.text('#OD-1'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
      expect(find.text('Mã đơn: ON-20261008-0001'), findsOneWidget);
    });
  });

  group('order detail', () {
    void stubDetail({
      String status = 'PENDING_CONFIRMATION',
      String settlement = 'FULL_PAYMENT',
      String? cancelReason,
      Map<String, dynamic>? summary,
      List<Map<String, dynamic>> deliveries = const [],
    }) {
      when(() => orders.get('o-1')).thenAnswer((_) async => Order.fromJson(orderWith(status: status, settlement: settlement, cancelReason: cancelReason)));
      when(() => orders.deliveries('o-1')).thenAnswer((_) async => deliveries.map(MyDelivery.fromJson).toList());
      when(() => orders.payments('o-1')).thenAnswer((_) async => OrderPaymentSummary.fromJson(summary ?? paymentSummaryJson()));
    }

    Future<void> open(WidgetTester tester) => pump(tester, const OrderDetailScreen(orderId: 'o-1'));

    testWidgets('shows the order, its address, note, items and the money', (tester) async {
      stubDetail();
      await open(tester);

      expect(find.text('Mã đơn: ON-20261008-0001'), findsOneWidget);
      expect(find.text('Chờ xác nhận'), findsOneWidget);
      expect(find.text('Nông dân E2E 170679 | 0917067932'), findsOneWidget);
      expect(find.text('Ấp 2, Thới Lai, Cần Thơ'), findsOneWidget);
      expect(find.textContaining('Giao buổi sáng'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Thành tiền'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
      expect(find.text('Thành tiền'), findsOneWidget);
    });

    testWidgets('an unpaid payOS order shows what is left and a button to pay it', (tester) async {
      stubDetail();
      await open(tester);

      await tester.scrollUntilVisible(find.textContaining('qua payOS'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Còn phải trả'), findsOneWidget);
      expect(find.text('Thanh toán 1.560.000 ₫ qua payOS'), findsOneWidget);
    });

    testWidgets('paying opens the payOS page', (tester) async {
      stubDetail();
      when(() => payments.startOrderPayment('o-1')).thenAnswer((_) async => PayosStart.fromJson(payosStartJson));
      await open(tester);

      await tester.scrollUntilVisible(find.textContaining('qua payOS'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.textContaining('qua payOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('qua payOS'));
      await tester.pumpAndSettle();

      expect(find.text('PAYOS PAGE'), findsOneWidget);
    });

    testWidgets('a paid order shows its payment and offers nothing more to pay', (tester) async {
      stubDetail(
        status: 'CONFIRMED',
        summary: paymentSummaryJson(paid: 1560000, remaining: 0, payments: [paidPaymentJson, cancelledPaymentJson]),
      );
      await open(tester);

      await tester.scrollUntilVisible(find.text('PM-20261008-0002'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('PM-20261008-0002'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsWidgets);
      expect(find.text('PM-20261008-0001'), findsNothing, reason: 'cancelled attempts are noise');
      expect(find.textContaining('qua payOS'), findsNothing);
    });

    testWidgets('a credit order explains that the money goes to the debt book and has no pay button', (tester) async {
      stubDetail(settlement: 'CREDIT');
      await open(tester);

      await tester.scrollUntilVisible(find.textContaining('Sổ nợ'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('ghi vào Sổ nợ'), findsOneWidget);
      expect(find.textContaining('qua payOS'), findsNothing);
    });

    testWidgets('an order waiting for the store can be cancelled, with a reason', (tester) async {
      stubDetail();
      when(() => orders.cancel('o-1', reason: any(named: 'reason'))).thenAnswer((_) async => Order.fromJson(orderWith(status: 'CANCELLED')));
      stubList((_) => rows([]));
      await open(tester);

      await tester.tap(find.text('Hủy đơn hàng'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy đơn hàng?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Đặt nhầm');
      await tester.tap(find.text('Hủy đơn'));
      await tester.pumpAndSettle();

      verify(() => orders.cancel('o-1', reason: 'Đặt nhầm')).called(1);
      expect(find.text('Đã hủy đơn hàng ON-20261008-0001.'), findsOneWidget);
    });

    testWidgets('backing out of the cancel dialog cancels nothing', (tester) async {
      stubDetail();
      await open(tester);

      await tester.tap(find.text('Hủy đơn hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giữ đơn'));
      await tester.pumpAndSettle();

      verifyNever(() => orders.cancel(any(), reason: any(named: 'reason')));
    });

    testWidgets('once the store has confirmed it there is no cancel button', (tester) async {
      stubDetail(status: 'CONFIRMED');
      await open(tester);
      expect(find.text('Hủy đơn hàng'), findsNothing);
    });

    testWidgets('a cancelled order shows why, and has neither tracking nor a pay button', (tester) async {
      stubDetail(status: 'CANCELLED', cancelReason: 'Đặt nhầm');
      await open(tester);

      expect(find.text('Lý do hủy: Đặt nhầm'), findsOneWidget);
      expect(find.text('Trạng thái giao hàng'), findsNothing);
      expect(find.textContaining('qua payOS'), findsNothing);
      // The payment summary still computes an amount, but a cancelled order owes nothing: do not show one.
      await tester.scrollUntilVisible(find.text('Còn phải trả'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Còn phải trả'), findsOneWidget);
      expect(find.text('—'), findsOneWidget, reason: 'a dash where the amount left to pay would be');
    });

    testWidgets('a delivery shows the driver, a call button, the items, the attempts and why a retry is needed', (tester) async {
      stubDetail(status: 'PARTIALLY_FULFILLED', deliveries: [retryDeliveryJson]);
      await open(tester);

      expect(find.text('DL-20261008-0001'), findsOneWidget);
      expect(find.text('Chờ giao lại'), findsOneWidget);
      expect(find.text('Lần giao trước không thành công: Khách vắng nhà'), findsOneWidget);
      expect(find.text('Nhân viên giao: Anh Tài Xế'), findsOneWidget);
      expect(find.text('0987654321'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Người nhận: Chị Hai'), findsOneWidget);
      expect(find.text('Lý do: Khách vắng nhà'), findsOneWidget);
    });

    testWidgets('an order that is ready to ship but has no delivery yet says it is being prepared', (tester) async {
      stubDetail(status: 'READY_FOR_FULFILLMENT');
      await open(tester);
      expect(find.text('Đơn hàng đang được chuẩn bị giao.'), findsOneWidget);
    });

    testWidgets('payments that cannot be read are said so, not hidden', (tester) async {
      stubDetail();
      when(() => orders.payments('o-1')).thenThrow(const AppException.offline());
      await open(tester);

      await tester.scrollUntilVisible(find.text('Không tải được thông tin thanh toán.'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Không tải được thông tin thanh toán.'), findsOneWidget);
      expect(find.textContaining('qua payOS'), findsNothing);
    });

    testWidgets('an order that cannot be loaded shows the error with a retry', (tester) async {
      var fail = true;
      when(() => orders.get('o-1')).thenAnswer((_) async {
        if (fail) throw const AppException.offline();
        return Order.fromJson(orderWith());
      });
      when(() => orders.deliveries('o-1')).thenAnswer((_) async => []);
      when(() => orders.payments('o-1')).thenAnswer((_) async => OrderPaymentSummary.fromJson(paymentSummaryJson()));
      await open(tester);
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: ON-20261008-0001'), findsOneWidget);
    });
  });

  test('the checkout fixture is a valid order for these screens', () {
    expect(Order.fromJson(orderJson).orderNumber, isNotEmpty);
  });
}

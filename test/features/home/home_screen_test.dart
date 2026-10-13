import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/ai_scan_home_screen.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/diagnose_case_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_overview_screen.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/products/screens/order_detail_screen.dart';
import 'package:farmer_mobile/features/products/screens/order_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/debt_fakes.dart';
import '../../helpers/diagnosis_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/order_fakes.dart';

const _net = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');

Future<AppHarness> open(WidgetTester tester, {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  h.realHome = true;
  h.debt.account0 = null;
  setup?.call(h);
  await h.pump(tester, initial: '/home');
  await tester.pumpAndSettle();
  return h;
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// 12 đơn: 2 chờ xác nhận, 3 đang xử lý, 4 hoàn thành, 1 huỷ phần còn lại, 2 đã huỷ.
List<OrderSummary> sampleOrders() => [
      summaryOf('new', status: 'PENDING_CONFIRMATION', total: 1560000),
      summaryOf('p2', status: 'PENDING_CONFIRMATION'),
      summaryOf('c1', status: 'CONFIRMED'),
      summaryOf('c2', status: 'PREPARING'),
      summaryOf('c3', status: 'PARTIALLY_FULFILLED'),
      for (var i = 1; i <= 4; i++) summaryOf('d$i', status: 'COMPLETED'),
      summaryOf('pc', status: 'PARTIALLY_CANCELLED'),
      summaryOf('x1', status: 'CANCELLED'),
      summaryOf('x2', status: 'CANCELLED'),
    ];

void main() {
  group('Trang chủ: lời chào và các thẻ', () {
    testWidgets('chào đúng tên người dùng; không còn nội dung mẫu', (tester) async {
      await open(tester);
      expect(textOf(tester, 'home_greeting'), contains('Xin chào, '));
      // Những chuỗi của dữ liệu mẫu cũ không được xuất hiện nữa.
      for (final fake in ['DH-8842', 'Fuji-One', '85.000đ', '04/12/2024', 'Đại lý Cần Thơ', 'Thới Phước', '13']) {
        expect(find.text(fake), findsNothing, reason: fake);
      }
      expect(find.textContaining('TIN TỨC'), findsNothing);
    });

    testWidgets('banner chẩn đoán: nút Chụp ảnh mở màn quét, Xem lịch sử mở lịch sử', (tester) async {
      final h = await open(tester);
      await tester.tap(find.byKey(const Key('home_capture')));
      await tester.pumpAndSettle();
      expect(find.byType(AiScanHomeScreen), findsOneWidget);
      h.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_history')));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử khám cây'), findsOneWidget);
    });
  });

  group('Thẻ Đơn hàng', () {
    testWidgets('đếm đúng từng nhóm, "đang xử lý" = tổng trừ các nhóm còn lại', (tester) async {
      await open(tester, setup: (h) => h.orders.list0 = sampleOrders());
      expect(textOf(tester, 'home_stat_pending'), '2');
      expect(textOf(tester, 'home_stat_progress'), '3');
      expect(textOf(tester, 'home_stat_done'), '5', reason: '4 hoàn thành + 1 huỷ phần còn lại');
    });

    testWidgets('chỉ gọi API 5 lần (pageSize=1), không tải cả danh sách', (tester) async {
      final h = await open(tester, setup: (h) => h.orders.list0 = sampleOrders());
      expect(h.orders.sizeCalls.where((s) => s == 1).length, 5);
      expect(h.orders.sizeCalls.every((s) => s == 1), isTrue);
    });

    testWidgets('đơn mới nhất: mã, trạng thái, tổng tiền, số sản phẩm; bấm mở chi tiết', (tester) async {
      final h = await open(tester, setup: (h) {
        h.orders.list0 = sampleOrders();
        h.orders.orders['new'] = orderOf(id: 'new', status: 'PENDING_CONFIRMATION');
      });
      expect(find.text('DH-new'), findsOneWidget);
      expect(find.text('Chờ xác nhận'), findsWidgets);
      expect(find.text('1.560.000đ'), findsOneWidget);
      expect(find.text('1 sản phẩm'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('home_latest_order')));
      await tester.tap(find.byKey(const Key('home_latest_order')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(h.orders.calls, contains('get:new'));
    });

    testWidgets('chưa có đơn: số 0 và gợi ý Mua sắm ngay', (tester) async {
      await open(tester);
      expect(textOf(tester, 'home_stat_pending'), '0');
      expect(textOf(tester, 'home_stat_progress'), '0');
      expect(textOf(tester, 'home_stat_done'), '0');
      expect(find.byKey(const Key('home_orders_none')), findsOneWidget);
      expect(find.byKey(const Key('home_latest_order')), findsNothing);
    });

    testWidgets('Xem tất cả mở danh sách đơn', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byKey(const Key('home_orders_all')));
      await tester.tap(find.byKey(const Key('home_orders_all')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderListScreen), findsOneWidget);
    });

    testWidgets('lỗi mạng: thông báo trong thẻ + Thử lại tải lại được', (tester) async {
      final h = await open(tester, setup: (h) => h.orders.listError = _net);
      expect(find.text('Chưa tải được đơn hàng của bạn.'), findsOneWidget);
      // Các thẻ khác vẫn hoạt động.
      expect(find.byKey(const Key('home_diag_card')), findsOneWidget);

      h.orders.listError = null;
      h.orders.list0 = sampleOrders();
      await tester.ensureVisible(find.text('Thử lại').last);
      await tester.tap(find.text('Thử lại').last);
      await tester.pumpAndSettle();
      expect(textOf(tester, 'home_stat_pending'), '2');
    });
  });

  group('Thẻ Chẩn đoán gần đây', () {
    testWidgets('chưa gửi ảnh: mời chụp ảnh', (tester) async {
      final h = await open(tester);
      expect(find.byKey(const Key('home_diag_none')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('home_diag_start')));
      await tester.tap(find.byKey(const Key('home_diag_start')));
      await tester.pumpAndSettle();
      expect(find.text('Chụp ảnh lá lúa'), findsWidgets);
      expect(h.diagnosis.calls, contains('list'));
    });

    testWidgets('chỉ lấy 1 ca mới nhất (pageSize=1)', (tester) async {
      final h = await open(tester, setup: (h) {
        h.diagnosis.list0 = [diagSummaryOf('a', status: 'UNDER_REVIEW')];
      });
      expect(h.diagnosis.listCalls.single, (page: 1, status: null));
    });

    testWidgets('đang chờ chuyên gia: nói rõ, không có tên bệnh/sản phẩm', (tester) async {
      await open(tester, setup: (h) {
        h.diagnosis.list0 = [diagSummaryOf('a', status: 'AI_COMPLETED')];
      });
      expect(find.text('Chờ chuyên gia xem'), findsOneWidget);
      expect(find.textContaining('Chuyên gia đang xem ảnh của bạn'), findsOneWidget);
      expect(find.byKey(const Key('home_diag_disease')), findsNothing);
    });

    testWidgets('đã có kết luận: tên bệnh tiếng Việt + tối đa 2 sản phẩm gợi ý, bấm mở sản phẩm',
        (tester) async {
      await open(tester, setup: (h) {
        h.diagnosis.list0 = [
          diagSummaryOf('v', status: 'VERIFIED', code: 'LEAF_BLAST', name: 'Leaf Blast'),
        ];
        h.diagnosis.cases['v'] = caseOf('v',
            status: 'VERIFIED',
            withImage: false,
            result: resultJson(products: [
              for (var i = 1; i <= 3; i++)
                {
                  'storeProductId': 'sp$i',
                  'productId': 'p$i',
                  'name': 'Thuốc $i',
                  'sku': 'S$i',
                  'rankOrder': i,
                }
            ]));
      });
      expect(textOf(tester, 'home_diag_disease'), 'Đạo ôn lá');
      expect(find.text('Thuốc 1'), findsOneWidget);
      expect(find.text('Thuốc 2'), findsOneWidget);
      expect(find.text('Thuốc 3'), findsNothing, reason: 'chỉ hiện 2 sản phẩm đầu');
      expect(find.text('Đã có kết quả'), findsOneWidget);
    });

    testWidgets('bấm ca gần đây mở chi tiết ca', (tester) async {
      await open(tester, setup: (h) {
        h.diagnosis.list0 = [diagSummaryOf('a', status: 'UNDER_REVIEW')];
        h.diagnosis.cases['a'] = caseOf('a', status: 'UNDER_REVIEW', withImage: false);
      });
      await tester.tap(find.byKey(const Key('home_diag_latest')));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnoseCaseScreen), findsOneWidget);
    });

    testWidgets('cần chụp lại / đã huỷ: mô tả đúng', (tester) async {
      await open(tester, setup: (h) {
        h.diagnosis.list0 = [diagSummaryOf('i', status: 'INCONCLUSIVE')];
      });
      expect(find.textContaining('Ảnh chưa đủ rõ'), findsOneWidget);
    });

    testWidgets('lỗi mạng: thông báo trong thẻ, các thẻ khác vẫn có dữ liệu', (tester) async {
      await open(tester, setup: (h) {
        h.diagnosis.listError = _net;
        h.orders.list0 = sampleOrders();
      });
      expect(find.text('Chưa tải được chẩn đoán gần đây.'), findsOneWidget);
      expect(textOf(tester, 'home_stat_pending'), '2');
    });
  });

  group('Thẻ Công nợ', () {
    testWidgets('không có nợ / chưa có sổ nợ: không hiện thẻ', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('home_debt_card')), findsNothing);
    });

    testWidgets('có nợ: hiện dư nợ; có quá hạn thì cảnh báo; bấm mở công nợ', (tester) async {
      await open(tester, setup: (h) {
        h.debt.account0 = accountOf(balance: 4100000, overdue: 2350000);
        h.credit.credit = creditOf();
      });
      await tester.scrollUntilVisible(find.byKey(const Key('home_debt_card')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(textOf(tester, 'home_debt_balance'), '4.100.000đ');
      expect(find.byKey(const Key('home_debt_overdue')), findsOneWidget);
      expect(find.text('2.350.000đ đã quá hạn'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home_debt_open')));
      await tester.pumpAndSettle();
      expect(find.byType(DebtOverviewScreen), findsOneWidget);
    });

    testWidgets('có nợ nhưng chưa quá hạn: không có cảnh báo đỏ', (tester) async {
      await open(tester, setup: (h) => h.debt.account0 = accountOf(balance: 1000000, overdue: 0));
      await tester.scrollUntilVisible(find.byKey(const Key('home_debt_card')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('home_debt_overdue')), findsNothing);
    });

    testWidgets('lỗi tải công nợ: không hiện thẻ (không báo sai)', (tester) async {
      await open(tester, setup: (h) => h.debt.accountError = _net);
      expect(find.byKey(const Key('home_debt_card')), findsNothing);
    });
  });

  group('Chuông thông báo và kéo để làm mới', () {
    testWidgets('chuông hiện số chưa đọc thật', (tester) async {
      await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a'), notifOf('b'), notifOf('c', read: true)];
      });
      expect(find.byKey(const Key('bell_badge')), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('kéo xuống để làm mới: gọi lại cả 3 nguồn dữ liệu', (tester) async {
      final h = await open(tester, setup: (h) => h.orders.list0 = sampleOrders());
      final orders = h.orders.sizeCalls.length;
      final diag = h.diagnosis.listCalls.length;
      final debt = h.debt.calls.where((c) => c == 'account').length;

      await tester.fling(find.byType(SingleChildScrollView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(h.orders.sizeCalls.length, greaterThan(orders));
      expect(h.diagnosis.listCalls.length, greaterThan(diag));
      expect(h.debt.calls.where((c) => c == 'account').length, greaterThan(debt));
    });
  });
}

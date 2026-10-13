import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/returns/screens/return_detail_screen.dart';
import 'package:farmer_mobile/features/returns/screens/return_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/order_fakes.dart';
import '../../helpers/return_fakes.dart';

const _net = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');

Future<AppHarness> open(WidgetTester tester, String route,
    {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  h.orders.orders['o1'] = orderOf(id: 'o1', status: 'COMPLETED');
  h.returns.returnables['o1'] = returnableOf();
  setup?.call(h);
  await h.pump(tester, initial: route);
  await tester.pumpAndSettle();
  return h;
}

Future<void> choose(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  unexpectedErrorTests();
  group('Lối vào từ chi tiết đơn', () {
    testWidgets('đơn đã giao xong: có nút Yêu cầu trả hàng, bấm mở màn tạo yêu cầu', (tester) async {
      await open(tester, '/orders/o1');
      await tester.scrollUntilVisible(find.byKey(const Key('order_return')), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('order_return')));
      await tester.pumpAndSettle();
      expect(find.byType(ReturnRequestScreen), findsOneWidget);
    });

    for (final s in ['PENDING_CONFIRMATION', 'CANCELLED', 'CONFIRMED', 'PREPARING']) {
      testWidgets('đơn $s: KHÔNG có nút trả hàng', (tester) async {
        await open(tester, '/orders/o1', setup: (h) {
          h.orders.orders['o1'] = orderOf(id: 'o1', status: s);
        });
        expect(find.byKey(const Key('order_return')), findsNothing);
      });
    }

    testWidgets('đã giao một phần: có nút trả hàng', (tester) async {
      await open(tester, '/orders/o1', setup: (h) {
        h.orders.orders['o1'] = orderOf(id: 'o1', status: 'PARTIALLY_FULFILLED');
      });
      await tester.scrollUntilVisible(find.byKey(const Key('order_return')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('order_return')), findsOneWidget);
    });
  });

  group('Tạo yêu cầu trả hàng', () {
    testWidgets('chỉ hiện món còn trả được; tên quy cách lấy từ đơn; nút khoá khi chưa chọn',
        (tester) async {
      await open(tester, '/orders/o1/return');

      expect(find.text('Lúa giống ST25'), findsOneWidget);
      expect(find.text('Phân NPK'), findsNothing, reason: 'đã trả hết');
      expect(find.textContaining('Đã nhận 2 Bao 25 kg · có thể trả 2 Bao 25 kg'), findsOneWidget);
      expect(find.byKey(const Key('ret_reason_oi1')), findsNothing);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('ret_submit'))).onPressed, isNull);
    });

    testWidgets('+/− chặn ở 0 và số tối đa; hiện lý do + tổng tiền ước tính', (tester) async {
      await open(tester, '/orders/o1/return');
      IconButton btn(String k) => tester.widget<IconButton>(find.byKey(Key(k)));

      expect(btn('ret_minus_oi1').onPressed, isNull);
      await tester.tap(find.byKey(const Key('ret_plus_oi1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ret_plus_oi1')));
      await tester.pump();

      expect(textOf(tester, 'ret_qty_oi1'), '2');
      expect(btn('ret_plus_oi1').onPressed, isNull, reason: 'tối đa 2 bao');
      expect(textOf(tester, 'ret_total'), '1.560.000đ');
      expect(find.byKey(const Key('ret_reason_oi1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ret_minus_oi1')));
      await tester.pump();
      expect(textOf(tester, 'ret_total'), '780.000đ');
      await tester.tap(find.byKey(const Key('ret_minus_oi1')));
      await tester.pump();
      expect(find.byKey(const Key('ret_total')), findsNothing);
    });

    testWidgets('chưa chọn lý do: báo lỗi và KHÔNG gọi API', (tester) async {
      final h = await open(tester, '/orders/o1/return');
      await tester.tap(find.byKey(const Key('ret_plus_oi1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ret_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng chọn lý do'), findsOneWidget);
      expect(h.returns.lastCreate, isNull);
    });

    testWidgets('gửi thành công: chia 2 lô đúng, kèm ghi chú, mở chi tiết yêu cầu mới', (tester) async {
      final h = await open(tester, '/orders/o1/return');
      await tester.tap(find.byKey(const Key('ret_plus_oi1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ret_plus_oi1')));
      await tester.pump();
      await choose(tester, 'ret_reason_oi1', 'Sản phẩm bị hư hỏng');
      await tester.enterText(find.byKey(const Key('ret_note')), '  Bao bị rách  ');
      await tester.ensureVisible(find.byKey(const Key('ret_submit')));
      await tester.tap(find.byKey(const Key('ret_submit')));
      await tester.pumpAndSettle();

      final c = h.returns.lastCreate!;
      expect(c.orderId, 'o1');
      expect(c.note, '  Bao bị rách  ');
      expect(c.lines.map((l) => (l.deliveryItemLotAllocationId, l.baseQuantity, l.reasonCode)), [
        ('al0', 30, 'DAMAGED_PRODUCT'),
        ('al1', 20, 'DAMAGED_PRODUCT'),
      ]);
      expect(find.byType(ReturnDetailScreen), findsOneWidget);
      expect(find.text('Chờ cửa hàng duyệt'), findsWidgets);
      expect(find.textContaining('Đã gửi yêu cầu trả hàng'), findsOneWidget);
    });

    testWidgets('đang gửi: nút khoá, không gửi đúp', (tester) async {
      final gate = gate0();
      final h = await open(tester, '/orders/o1/return', setup: (h) => h.returns.createGate = gate.future);
      await tester.tap(find.byKey(const Key('ret_plus_oi1')));
      await tester.pump();
      await choose(tester, 'ret_reason_oi1', 'Giao sai sản phẩm');
      await tester.ensureVisible(find.byKey(const Key('ret_submit')));
      await tester.tap(find.byKey(const Key('ret_submit')));
      await tester.pump();

      expect(tester.widget<ElevatedButton>(find.byKey(const Key('ret_submit'))).onPressed, isNull);
      expect(h.returns.calls.where((c) => c == 'create').length, 1);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('server từ chối (422): hiện lỗi, tải lại số liệu, vẫn gửi lại được', (tester) async {
      final h = await open(tester, '/orders/o1/return', setup: (h) {
        h.returns.createError = const ApiException(
            kind: ApiErrorKind.businessRule,
            statusCode: 422,
            message: 'Số lượng trả vượt quá số lượng có thể trả. Vui lòng tải lại và chọn lại.');
      });
      await tester.tap(find.byKey(const Key('ret_plus_oi1')));
      await tester.pump();
      await choose(tester, 'ret_reason_oi1', 'Hết hạn sử dụng');
      await tester.ensureVisible(find.byKey(const Key('ret_submit')));
      await tester.tap(find.byKey(const Key('ret_submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ret_error')), findsOneWidget);
      expect(find.textContaining('vượt quá số lượng có thể trả'), findsOneWidget);
      expect(h.returns.calls.where((c) => c == 'returnable:o1').length, 2, reason: 'đã tải lại');
      expect(find.byType(ReturnRequestScreen), findsOneWidget);
    });

    testWidgets('không còn món nào trả được: thông báo', (tester) async {
      await open(tester, '/orders/o1/return', setup: (h) {
        h.returns.returnables['o1'] = returnableOf(fulfilled: 50, returned: 50);
      });
      expect(find.textContaining('chưa có hàng nào có thể trả'), findsOneWidget);
      expect(find.byKey(const Key('ret_submit')), findsNothing);
    });

    testWidgets('chỉ còn phần lẻ: giải thích, không có nút +/−', (tester) async {
      await open(tester, '/orders/o1/return', setup: (h) {
        h.returns.returnables['o1'] = returnableOf(fulfilled: 50, returned: 40);
      });
      expect(find.byKey(const Key('ret_fraction_oi1')), findsOneWidget);
      expect(find.byKey(const Key('ret_plus_oi1')), findsNothing);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, '/orders/o1/return', setup: (h) => h.returns.returnableError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      h.returns.returnableError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Lúa giống ST25'), findsOneWidget);
    });
  });

  group('Danh sách yêu cầu trả hàng', () {
    testWidgets('hiện số phiếu, trạng thái, đơn, giá trị; bấm mở chi tiết', (tester) async {
      await open(tester, '/returns', setup: (h) {
        h.returns.list0 = [
          returnSummaryOf('a', status: 'APPROVED', total: 780000),
          returnSummaryOf('b', status: 'COMPLETED', total: 500000),
        ];
        h.returns.details['a'] = returnOf('a', status: 'APPROVED');
      });
      expect(find.text('TH-a'), findsOneWidget);
      expect(find.text('Đã duyệt'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);
      expect(find.text('780.000đ'), findsOneWidget);
      expect(find.text('Đơn hàng DH-o1'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('return_a')));
      await tester.pumpAndSettle();
      expect(find.byType(ReturnDetailScreen), findsOneWidget);
    });

    testWidgets('trống: hướng dẫn cách trả hàng', (tester) async {
      await open(tester, '/returns');
      expect(find.textContaining('Bạn chưa có yêu cầu trả hàng nào'), findsOneWidget);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, '/returns', setup: (h) => h.returns.listError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      h.returns.listError = null;
      h.returns.list0 = [returnSummaryOf('a')];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('return_a')), findsOneWidget);
    });

    testWidgets('nhiều trang: Xem thêm', (tester) async {
      final h = await open(tester, '/returns', setup: (h) {
        h.returns.pageSize0 = 2;
        h.returns.list0 = [for (var i = 1; i <= 3; i++) returnSummaryOf('r$i')];
      });
      expect(find.byKey(const Key('return_r3')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('returns_load_more')));
      await tester.tap(find.byKey(const Key('returns_load_more')));
      await tester.pumpAndSettle();
      expect(h.returns.calls, contains('list:2'));
      expect(find.byKey(const Key('return_r3')), findsOneWidget);
    });
  });

  group('Chi tiết yêu cầu trả hàng', () {
    testWidgets('chờ duyệt: trạng thái, gợi ý, tên hàng + số lượng theo bao, nút huỷ', (tester) async {
      await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1', note: 'Bao bị rách');
      });

      expect(find.text('TH-r1'), findsOneWidget);
      expect(textOf(tester, 'return_status'), 'Chờ cửa hàng duyệt');
      expect(find.textContaining('Cửa hàng sẽ xem xét'), findsOneWidget);
      expect(find.text('Lúa giống ST25'), findsOneWidget);
      expect(find.text('Số lượng: 1 Bao 25 kg'), findsOneWidget);
      expect(find.text('Lý do: Sản phẩm bị hư hỏng'), findsOneWidget);
      expect(find.text('Bao bị rách'), findsOneWidget);
      expect(textOf(tester, 'return_total'), '780.000đ');
      expect(find.byKey(const Key('item_condition_ri1')), findsNothing);
      expect(find.byKey(const Key('return_cancel')), findsOneWidget);
      expect(find.text('Gửi yêu cầu'), findsOneWidget);
      expect(find.text('Cửa hàng duyệt'), findsOneWidget);
    });

    testWidgets('đã duyệt: hướng dẫn mang hàng về, KHÔNG còn nút huỷ', (tester) async {
      await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1', status: 'APPROVED');
      });
      expect(find.textContaining('mang hàng trả về cửa hàng'), findsOneWidget);
      expect(find.byKey(const Key('return_cancel')), findsNothing);
    });

    testWidgets('hoàn tất: kết quả kiểm tra, trừ công nợ, hoàn tiền', (tester) async {
      await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1',
            status: 'COMPLETED',
            total: 800000,
            debt: 500000,
            refund: 300000,
            condition: 'RESELLABLE',
            refunds: [
              {
                'refundNumber': 'HT-1',
                'refundMethod': 'BANK_TRANSFER',
                'amount': 300000,
                'status': 'COMPLETED',
                'requestedAt': '2026-10-14T03:00:00Z',
                'completedAt': '2026-10-14T04:00:00Z',
                'externalReference': 'FT123',
              }
            ]);
      });

      expect(textOf(tester, 'item_condition_ri1'), 'Kết quả kiểm tra: Còn bán được');
      expect(find.text('"Bao rách nhẹ"'), findsOneWidget);
      expect(textOf(tester, 'return_total'), '800.000đ');
      expect(textOf(tester, 'return_debt'), '500.000đ');
      expect(textOf(tester, 'return_refund'), '300.000đ');
      expect(find.text('Chuyển khoản · Đã hoàn tiền'), findsOneWidget);
      expect(find.text('Mã tham chiếu: FT123'), findsOneWidget);
      expect(find.byKey(const Key('return_cancel')), findsNothing);
      expect(find.textContaining('Số tiền hoàn chính thức được tính sau'), findsNothing);
    });

    testWidgets('không có công nợ bị trừ thì ẩn dòng "Trừ vào công nợ"', (tester) async {
      await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1', status: 'INSPECTED', refund: 780000);
      });
      expect(find.byKey(const Key('return_debt')), findsNothing);
      expect(textOf(tester, 'return_refund'), '780.000đ');
    });

    testWidgets('bị từ chối: tiến trình dừng với bước đỏ', (tester) async {
      await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1', status: 'REJECTED');
      });
      expect(textOf(tester, 'return_status'), 'Bị từ chối');
      expect(find.text('Cửa hàng từ chối'), findsOneWidget);
      expect(find.byKey(const Key('return_refund')), findsNothing, reason: 'không có tiền hoàn');
      expect(find.text('Hoàn tất'), findsNothing);
      expect(find.byKey(const Key('return_cancel')), findsNothing);
    });

    testWidgets('khiếu nại huỷ: hiện lý do huỷ', (tester) async {
      await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1', status: 'CANCELLED', cancelReason: 'Đổi ý');
      });
      expect(find.text('Đã huỷ yêu cầu'), findsOneWidget);
      expect(find.text('Lý do huỷ: Đổi ý'), findsOneWidget);
    });

    testWidgets('huỷ: bỏ trống lý do thì báo lỗi, không gọi API', (tester) async {
      final h = await open(tester, '/returns/r1', setup: (h) => h.returns.details['r1'] = returnOf('r1'));
      await tester.tap(find.byKey(const Key('return_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('return_cancel_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do huỷ'), findsOneWidget);
      expect(h.returns.lastCancel, isNull);
    });

    testWidgets('huỷ thành công: gọi API với lý do, trạng thái đổi, hết nút huỷ', (tester) async {
      final h = await open(tester, '/returns/r1', setup: (h) => h.returns.details['r1'] = returnOf('r1'));
      await tester.tap(find.byKey(const Key('return_cancel')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('return_cancel_reason')), '  Đổi ý  ');
      await tester.tap(find.byKey(const Key('return_cancel_submit')));
      await tester.pumpAndSettle();

      expect(h.returns.lastCancel, (id: 'r1', reason: 'Đổi ý'));
      expect(textOf(tester, 'return_status'), 'Đã huỷ');
      expect(find.byKey(const Key('return_cancel')), findsNothing);
      expect(find.textContaining('Đã huỷ yêu cầu trả hàng'), findsOneWidget);
    });

    testWidgets('đóng hộp thoại huỷ: không gọi API', (tester) async {
      final h = await open(tester, '/returns/r1', setup: (h) => h.returns.details['r1'] = returnOf('r1'));
      await tester.tap(find.byKey(const Key('return_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('return_cancel_close')));
      await tester.pumpAndSettle();
      expect(h.returns.lastCancel, isNull);
      expect(find.byKey(const Key('return_cancel')), findsOneWidget);
    });

    testWidgets('huỷ khi cửa hàng vừa duyệt (422): báo lỗi, tải lại, hết nút huỷ', (tester) async {
      final h = await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1');
        h.returns.cancelError = const ApiException(
            kind: ApiErrorKind.businessRule,
            statusCode: 422,
            message: 'Cửa hàng đã xử lý yêu cầu này nên không thể huỷ.');
      });
      await tester.tap(find.byKey(const Key('return_cancel')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('return_cancel_reason')), 'Đổi ý');
      h.returns.details['r1'] = returnOf('r1', status: 'APPROVED'); // server đã duyệt
      await tester.tap(find.byKey(const Key('return_cancel_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('đã xử lý yêu cầu này'), findsOneWidget);
      expect(textOf(tester, 'return_status'), 'Đã duyệt');
      expect(find.byKey(const Key('return_cancel')), findsNothing);
    });

    testWidgets('không tìm thấy (404): báo lỗi tiếng Việt', (tester) async {
      await open(tester, '/returns/zzz');
      expect(find.text('Không tìm thấy yêu cầu trả hàng.'), findsOneWidget);
    });

    testWidgets('bấm tên đơn mở chi tiết đơn', (tester) async {
      await open(tester, '/returns/r1', setup: (h) => h.returns.details['r1'] = returnOf('r1'));
      await tester.tap(find.byKey(const Key('return_open_order')));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
    });

    testWidgets('đang cuộn: tên hàng vẫn hiện "Sản phẩm" nếu không tải được đơn', (tester) async {
      await open(tester, '/returns/r1', setup: (h) {
        h.returns.details['r1'] = returnOf('r1');
        h.orders.orders.remove('o1');
      });
      expect(find.text('Sản phẩm'), findsOneWidget);
      expect(find.text('Số lượng: 25 (đơn vị nhỏ nhất)'), findsNothing,
          reason: 'chia hết 25/25 nên vẫn là 1');
    });
  });
}

void unexpectedErrorTests() {
  testWidgets('lỗi ngoài dự kiến khi gửi: không kẹt ở trạng thái đang gửi', (tester) async {
    await open(tester, '/orders/o1/return', setup: (h) => h.returns.createError = StateError('boom'));
    await tester.tap(find.byKey(const Key('ret_plus_oi1')));
    await tester.pump();
    await choose(tester, 'ret_reason_oi1', 'Giao sai sản phẩm');
    await tester.ensureVisible(find.byKey(const Key('ret_submit')));
    await tester.tap(find.byKey(const Key('ret_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ret_error')), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('ret_submit'))).onPressed, isNotNull);
  });
}

// Chụp ảnh các màn trả hàng bằng font thật (cần mạng để tải font Google).
//
//   SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/returns_screenshots_test.dart
//
// Ảnh ra ở test/visual/shots/ (xem xong thì xoá thư mục). Test cũng thất bại nếu
// có lỗi tràn layout với font thật ở cả khung 390px và 320px.
import 'dart:io';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/order_fakes.dart';
import '../helpers/return_fakes.dart';
import 'auth_screenshots_test.dart' show shoot, useRealFonts;

final _on = Platform.environment['SCREENSHOTS'] == '1';

final _refunds = [
  {
    'refundNumber': 'HT-1',
    'refundMethod': 'BANK_TRANSFER',
    'amount': 300000,
    'status': 'COMPLETED',
    'requestedAt': '2026-10-14T03:00:00Z',
    'completedAt': '2026-10-14T04:00:00Z',
    'externalReference': 'FT123456789',
  }
];

void main() {
  for (final width in [390.0, 320.0]) {
    final tag = width.toInt();

    Future<AppHarness> open(WidgetTester tester, String route,
        {void Function(AppHarness)? setup}) async {
      await useRealFonts(tester);
      final h = AppHarness()..signIn();
      h.orders.orders['o1'] = orderOf(id: 'o1', status: 'COMPLETED');
      h.returns.returnables['o1'] = returnableOf();
      h.returns.list0 = [
        returnSummaryOf('a', status: 'REQUESTED', total: 780000),
        returnSummaryOf('b', status: 'APPROVED', total: 1560000),
        returnSummaryOf('c', status: 'COMPLETED', total: 800000),
        returnSummaryOf('d', status: 'REJECTED', total: 500000),
      ];
      h.returns.details['a'] = returnOf('a', note: 'Bao bị rách, lúa lẫn nhiều tạp chất');
      h.returns.details['b'] = returnOf('b', status: 'APPROVED');
      h.returns.details['c'] = returnOf('c',
          status: 'COMPLETED',
          total: 800000,
          debt: 500000,
          refund: 300000,
          condition: 'RESELLABLE',
          refunds: _refunds);
      h.returns.details['d'] = returnOf('d', status: 'REJECTED');
      h.returns.details['e'] =
          returnOf('e', status: 'CANCELLED', cancelReason: 'Tôi đổi ý, không cần trả nữa');
      setup?.call(h);
      await h.pump(tester, initial: route);
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpAndSettle();
      return h;
    }

    group('ảnh trả hàng $tag px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      testWidgets('chi tiết đơn: mục trả hàng', (tester) async {
        await open(tester, '/orders/o1');
        await tester.scrollUntilVisible(find.byKey(const Key('order_return')), 300,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_ret_order_section');
      });

      testWidgets('tạo yêu cầu: trống → đã chọn → thiếu lý do → có lỗi server', (tester) async {
        final h = await open(tester, '/orders/o1/return');
        await shoot(tester, '${tag}_ret_request_empty');
        await tester.tap(find.byKey(const Key('ret_plus_oi1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('ret_plus_oi1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('ret_submit')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_ret_request_no_reason');
        await tester.tap(find.byKey(const Key('ret_reason_oi1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hư hỏng khi vận chuyển').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('ret_note')), 'Bao bị rách khi giao');
        await tester.pump();
        h.returns.createError = const ApiException(
            kind: ApiErrorKind.businessRule,
            statusCode: 422,
            message: 'Số lượng trả vượt quá số lượng có thể trả. Vui lòng tải lại và chọn lại.');
        await tester.ensureVisible(find.byKey(const Key('ret_submit')));
        await tester.tap(find.byKey(const Key('ret_submit')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_ret_request_error');
      });

      testWidgets('tạo yêu cầu: chỉ còn phần lẻ', (tester) async {
        await open(tester, '/orders/o1/return', setup: (h) {
          h.returns.returnables['o1'] = returnableOf(fulfilled: 50, returned: 40);
        });
        await shoot(tester, '${tag}_ret_request_fraction');
      });

      testWidgets('danh sách', (tester) async {
        await open(tester, '/returns');
        await shoot(tester, '${tag}_ret_list');
      });

      testWidgets('danh sách trống', (tester) async {
        await open(tester, '/returns', setup: (h) => h.returns.list0 = []);
        await shoot(tester, '${tag}_ret_list_empty');
      });

      testWidgets('chi tiết: chờ duyệt', (tester) async {
        await open(tester, '/returns/a');
        await shoot(tester, '${tag}_ret_detail_requested');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_ret_detail_requested_bottom');
      });

      testWidgets('chi tiết: đã duyệt', (tester) async {
        await open(tester, '/returns/b');
        await shoot(tester, '${tag}_ret_detail_approved');
      });

      testWidgets('chi tiết: hoàn tất (hoàn tiền + trừ nợ)', (tester) async {
        await open(tester, '/returns/c');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_ret_detail_completed');
      });

      testWidgets('chi tiết: bị từ chối', (tester) async {
        await open(tester, '/returns/d');
        await shoot(tester, '${tag}_ret_detail_rejected');
      });

      testWidgets('chi tiết: đã huỷ', (tester) async {
        await open(tester, '/returns/e');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_ret_detail_cancelled');
      });

      testWidgets('hộp thoại huỷ', (tester) async {
        await open(tester, '/returns/a');
        await tester.tap(find.byKey(const Key('return_cancel')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('return_cancel_submit')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_ret_cancel_dialog_error');
      });
    });
  }
}

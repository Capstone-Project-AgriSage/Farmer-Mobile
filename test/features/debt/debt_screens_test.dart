import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:farmer_mobile/features/debt/screens/debt_detail_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_history_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_list_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_repay_screen.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/debt_fakes.dart';
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

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void seed(AppHarness h, List<DebtEntrySummary> entries) {
  h.debt.entries0 = entries;
  for (final e in entries) {
    h.debt.details[e.id] = detailOf(e.id,
        status: e.status,
        original: e.originalAmount,
        paid: e.totalPaid,
        overdue: e.isOverdue,
        overdueDays: e.overdueDays);
  }
}

void main() {
  group('Tổng quan công nợ', () {
    testWidgets('chưa có hạn mức và chưa có sổ nợ: hướng dẫn liên hệ cửa hàng', (tester) async {
      await open(tester, '/debt', setup: (h) {
        h.credit.credit = null;
        h.debt.account0 = null;
      });

      expect(find.textContaining('Bạn chưa có hạn mức mua ghi nợ'), findsOneWidget);
      expect(find.byKey(const Key('debt_repay')), findsNothing);
      expect(find.byKey(const Key('credit_card')), findsNothing);
    });

    testWidgets('hiện hạn mức, dư nợ lấy từ sổ nợ, còn mua chịu được, kỳ hạn', (tester) async {
      await open(tester, '/debt', setup: (h) {
        h.credit.credit = creditOf(available: 7000000, term: 30);
        h.debt.account0 = accountOf(balance: 3000000, open: 2);
        seed(h, [entryOf('a', due: DateTime(2026, 10, 25))]);
      });

      expect(textOf(tester, 'credit_limit'), '10.000.000đ');
      expect(textOf(tester, 'credit_owing'), '3.000.000đ',
          reason: 'ưu tiên số nợ từ sổ nợ');
      expect(textOf(tester, 'credit_available'), '7.000.000đ');
      expect(find.text('Kỳ hạn 30 ngày'), findsOneWidget);
      expect(textOf(tester, 'debt_balance'), '3.000.000đ');
      expect(find.byKey(const Key('debt_overdue_banner')), findsNothing);
      expect(find.byKey(const Key('debt_repay')), findsOneWidget);
      expect(find.text('CN-a'), findsOneWidget);
    });

    testWidgets('có nợ quá hạn: banner đỏ với số tiền quá hạn', (tester) async {
      await open(tester, '/debt', setup: (h) {
        h.credit.credit = creditOf();
        h.debt.account0 = accountOf(balance: 3000000, overdue: 1200000);
        seed(h, [entryOf('a', overdue: true, overdueDays: 4)]);
      });

      expect(find.byKey(const Key('debt_overdue_banner')), findsOneWidget);
      expect(find.textContaining('1.200.000đ đã quá hạn'), findsOneWidget);
      expect(find.text('Quá hạn 4 ngày'), findsOneWidget);
    });

    testWidgets('hạn mức bị khoá: cảnh báo và còn mua chịu = 0', (tester) async {
      await open(tester, '/debt', setup: (h) {
        h.credit.credit = creditOf(status: 'SUSPENDED', available: 5000000);
        h.debt.account0 = accountOf(balance: 0, open: 0);
      });

      expect(find.text('Hạn mức đang tạm khoá'), findsOneWidget);
      expect(textOf(tester, 'credit_available'), '0đ');
    });

    testWidgets('không còn nợ: ẩn nút Trả nợ, báo không có khoản nào', (tester) async {
      await open(tester, '/debt', setup: (h) {
        h.credit.credit = creditOf(available: 10000000);
        h.debt.account0 = accountOf(balance: 0, open: 0);
      });

      expect(find.byKey(const Key('debt_repay')), findsNothing);
      expect(find.byKey(const Key('debt_none')), findsOneWidget);
    });

    testWidgets('có hạn mức nhưng chưa có sổ nợ vẫn hiện thẻ hạn mức', (tester) async {
      await open(tester, '/debt', setup: (h) {
        h.credit.credit = creditOf(available: 10000000);
        h.debt.account0 = null;
      });

      expect(find.byKey(const Key('credit_card')), findsOneWidget);
      expect(find.byKey(const Key('debt_balance')), findsNothing);
    });

    testWidgets('lỗi mạng: Thử lại tải được dữ liệu', (tester) async {
      final h = await open(tester, '/debt', setup: (h) => h.debt.accountError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);

      h.debt.accountError = null;
      h.credit.credit = creditOf();
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('credit_card')), findsOneWidget);
    });

    testWidgets('bấm Trả nợ mở màn trả nợ; bấm khoản nợ mở chi tiết; Xem tất cả mở danh sách',
        (tester) async {
      final h = await open(tester, '/debt', setup: (h) {
        h.credit.credit = creditOf();
        h.debt.account0 = accountOf();
        seed(h, [entryOf('a')]);
      });

      await tester.tap(find.byKey(const Key('debt_view_all')));
      await tester.pumpAndSettle();
      expect(find.byType(DebtListScreen), findsOneWidget);
      h.router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('CN-a'));
      await tester.pumpAndSettle();
      expect(find.byType(DebtDetailScreen), findsOneWidget);
      h.router.pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('debt_repay')));
      await tester.tap(find.byKey(const Key('debt_repay')));
      await tester.pumpAndSettle();
      expect(find.byType(DebtRepayScreen), findsOneWidget);
    });

    testWidgets('nút lịch sử mở màn lịch sử (không bị nhầm là mã khoản nợ)', (tester) async {
      await open(tester, '/debt', setup: (h) {
        h.credit.credit = creditOf();
        h.debt.account0 = accountOf();
      });
      await tester.tap(find.byKey(const Key('debt_history')));
      await tester.pumpAndSettle();
      expect(find.byType(DebtHistoryScreen), findsOneWidget);
      expect(find.byType(DebtDetailScreen), findsNothing);
    });
  });

  group('Danh sách khoản nợ', () {
    testWidgets('hiện số khoản nợ, trạng thái, còn phải trả, đã trả một phần', (tester) async {
      await open(tester, '/debt/list', setup: (h) {
        seed(h, [
          entryOf('a', status: 'OPEN', original: 2000000),
          entryOf('b', status: 'PARTIALLY_PAID', original: 1000000, paid: 400000),
          entryOf('c', status: 'PAID', original: 500000, paid: 500000, outstanding: 0),
        ]);
      });

      expect(find.text('CN-a'), findsOneWidget);
      expect(find.text('Chưa trả'), findsWidgets);
      expect(find.text('Đã trả một phần'), findsWidgets);
      expect(find.text('Đã thanh toán'), findsWidgets);
      expect(find.text('2.000.000đ'), findsOneWidget);
      expect(find.text('600.000đ'), findsOneWidget, reason: 'còn phải trả của khoản trả một phần');
      expect(find.text('Đã trả 400.000đ'), findsOneWidget);
    });

    testWidgets('lọc Quá hạn gọi API đúng; khoản quá hạn hiện nhãn số ngày', (tester) async {
      final h = await open(tester, '/debt/list', setup: (h) {
        seed(h, [
          entryOf('a'),
          entryOf('b', overdue: true, overdueDays: 5),
        ]);
      });

      await tester.ensureVisible(find.byKey(const Key('debt_filter_OVERDUE')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('debt_filter_OVERDUE')));
      await tester.pumpAndSettle();

      expect(h.debt.entryCalls.last, (page: 1, status: 'OVERDUE'));
      expect(find.byKey(const Key('debt_b')), findsOneWidget);
      expect(find.byKey(const Key('debt_a')), findsNothing);
      expect(find.text('Quá hạn 5 ngày'), findsOneWidget);
    });

    testWidgets('trống: thông báo theo bộ lọc', (tester) async {
      await open(tester, '/debt/list');
      expect(find.text('Bạn chưa có khoản nợ nào.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('debt_filter_DISPUTED')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('debt_filter_DISPUTED')));
      await tester.pumpAndSettle();
      expect(find.text('Không có khoản nợ "Đang khiếu nại".'), findsOneWidget);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, '/debt/list', setup: (h) => h.debt.entriesError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);

      h.debt.entriesError = null;
      seed(h, [entryOf('a')]);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debt_a')), findsOneWidget);
    });

    testWidgets('nhiều trang: Xem thêm nối thêm, không trùng', (tester) async {
      final h = await open(tester, '/debt/list', setup: (h) {
        h.debt.pageSize0 = 2;
        seed(h, [for (var i = 1; i <= 3; i++) entryOf('e$i')]);
      });
      expect(find.byKey(const Key('debt_e1')), findsOneWidget);
      expect(find.byKey(const Key('debt_e3')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('debts_load_more')));
      await tester.tap(find.byKey(const Key('debts_load_more')));
      await tester.pumpAndSettle();

      expect(h.debt.entryCalls.last.page, 2);
      expect(find.byKey(const Key('debt_e3')), findsOneWidget);
      expect(find.byKey(const Key('debts_load_more')), findsNothing);
    });

    testWidgets('bấm khoản nợ mở chi tiết', (tester) async {
      await open(tester, '/debt/list', setup: (h) => seed(h, [entryOf('a')]));
      await tester.tap(find.byKey(const Key('debt_a')));
      await tester.pumpAndSettle();
      expect(find.byType(DebtDetailScreen), findsOneWidget);
    });
  });

  group('Chi tiết khoản nợ', () {
    testWidgets('hiện số tiền còn phải trả, hạn, sản phẩm, biến động', (tester) async {
      await open(tester, '/debt/a', setup: (h) {
        h.debt.details['a'] = detailOf('a', status: 'PARTIALLY_PAID', original: 2000000, paid: 500000);
      });

      expect(textOf(tester, 'debt_amount'), '1.500.000đ');
      expect(find.text('CN-a'), findsOneWidget);
      expect(find.text('DH-a'), findsOneWidget);
      expect(find.text('30/10/2026'), findsOneWidget);
      expect(find.text('Phân NPK 20-20-15'), findsOneWidget);
      expect(find.text('Bao 50 kg × 2'), findsOneWidget);
      expect(find.text('Ghi nợ'), findsOneWidget);
      expect(find.text('Thanh toán'), findsOneWidget);
      expect(find.text('+2.000.000đ'), findsOneWidget);
      expect(find.text('−500.000đ'), findsOneWidget);
      expect(find.byKey(const Key('debt_dispute')), findsOneWidget);
      expect(find.byKey(const Key('debt_pay')), findsOneWidget);
    });

    testWidgets('quá hạn: banner nêu số ngày', (tester) async {
      await open(tester, '/debt/a', setup: (h) {
        h.debt.details['a'] = detailOf('a', overdue: true, overdueDays: 7);
      });
      expect(find.textContaining('quá hạn 7 ngày'), findsOneWidget);
    });

    testWidgets('đã thanh toán đủ: không còn nút Trả nợ / Khiếu nại', (tester) async {
      await open(tester, '/debt/a', setup: (h) {
        h.debt.details['a'] = detailOf('a', status: 'PAID', original: 2000000, paid: 2000000);
      });
      expect(find.byKey(const Key('debt_pay')), findsNothing);
      expect(find.byKey(const Key('debt_dispute')), findsNothing);
      expect(find.text('GIÁ TRỊ KHOẢN NỢ'), findsOneWidget);
    });

    testWidgets('đang khiếu nại: ẩn nút Khiếu nại, vẫn trả nợ được, có ghi chú', (tester) async {
      await open(tester, '/debt/a', setup: (h) {
        h.debt.details['a'] = DebtEntryDetail.fromJson(entryDetailJson('a', status: 'DISPUTED', actions: [
          {'actionType': 'DISPUTE', 'reason': 'Sai số lượng', 'createdAt': '2026-10-06T02:00:00Z'}
        ]));
      });
      expect(find.byKey(const Key('debt_dispute')), findsNothing);
      expect(find.byKey(const Key('debt_pay')), findsOneWidget);
      expect(find.byKey(const Key('debt_disputed_note')), findsOneWidget);
      expect(find.text('Bạn khiếu nại khoản nợ'), findsOneWidget);
      expect(find.text('"Sai số lượng"'), findsOneWidget);
    });

    testWidgets('khiếu nại: bỏ trống lý do thì báo lỗi, không gọi API', (tester) async {
      final h = await open(tester, '/debt/a',
          setup: (h) => h.debt.details['a'] = detailOf('a'));

      await tester.tap(find.byKey(const Key('debt_dispute')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dispute_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập lý do khiếu nại'), findsOneWidget);
      expect(h.debt.disputes, isEmpty);
    });

    testWidgets('khiếu nại thành công: gọi API với lý do, hiện trạng thái mới', (tester) async {
      final h = await open(tester, '/debt/a',
          setup: (h) => h.debt.details['a'] = detailOf('a'));

      await tester.tap(find.byKey(const Key('debt_dispute')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dispute_reason')), '  Chưa nhận đủ hàng ');
      await tester.tap(find.byKey(const Key('dispute_submit')));
      await tester.pumpAndSettle();

      expect(h.debt.disputes.single, (id: 'a', reason: 'Chưa nhận đủ hàng'));
      expect(find.textContaining('Đã gửi khiếu nại'), findsOneWidget);
      expect(find.byKey(const Key('debt_disputed_note')), findsOneWidget);
      expect(find.byKey(const Key('debt_dispute')), findsNothing);
    });

    testWidgets('khiếu nại: đóng hộp thoại thì không gọi API', (tester) async {
      final h = await open(tester, '/debt/a',
          setup: (h) => h.debt.details['a'] = detailOf('a'));

      await tester.tap(find.byKey(const Key('debt_dispute')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dispute_cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dispute_reason')), findsNothing);
      expect(h.debt.disputes, isEmpty);
    });

    testWidgets('khiếu nại thất bại: giữ nguyên màn, hiện lỗi', (tester) async {
      final h = await open(tester, '/debt/a', setup: (h) {
        h.debt.details['a'] = detailOf('a');
        h.debt.disputeError = const ApiException(
            kind: ApiErrorKind.businessRule,
            statusCode: 422,
            message: 'Khoản nợ này đã được khiếu nại, đang chờ cửa hàng xử lý.');
      });

      await tester.tap(find.byKey(const Key('debt_dispute')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dispute_reason')), 'Sai');
      await tester.tap(find.byKey(const Key('dispute_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('đã được khiếu nại'), findsOneWidget);
      expect(find.byKey(const Key('debt_dispute')), findsOneWidget);
      expect(h.debt.disputes.length, 1);
    });

    testWidgets('bấm Trả nợ: mở màn trả nợ với số còn nợ của khoản này', (tester) async {
      await open(tester, '/debt/a', setup: (h) {
        seed(h, [entryOf('a', original: 2000000, paid: 500000, status: 'PARTIALLY_PAID')]);
        h.debt.account0 = accountOf(balance: 1500000);
      });

      await tester.tap(find.byKey(const Key('debt_pay')));
      await tester.pumpAndSettle();

      expect(find.byType(DebtRepayScreen), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('repay_amount'))).controller!.text,
          '1500000');
    });

    testWidgets('không tìm thấy (404): báo lỗi tiếng Việt', (tester) async {
      await open(tester, '/debt/zzz');
      expect(find.text('Không tìm thấy khoản nợ.'), findsOneWidget);
    });
  });

  group('Trả nợ', () {
    Future<AppHarness> repay(WidgetTester tester,
        {String route = '/debt/repay', double balance = 3000000, double overdue = 0}) =>
        open(tester, route, setup: (h) {
          h.debt.account0 = accountOf(balance: balance, overdue: overdue);
          seed(h, [
            entryOf('a', original: 2000000, due: DateTime(2026, 10, 20)),
            entryOf('b', original: 1000000, due: DateTime(2026, 11, 20)),
          ]);
        });

    testWidgets('không có nợ: báo không còn khoản nào, không có nút thanh toán', (tester) async {
      await open(tester, '/debt/repay', setup: (h) => h.debt.account0 = accountOf(balance: 0));
      expect(find.text('Bạn không còn khoản nợ nào cần thanh toán.'), findsOneWidget);
      expect(find.byKey(const Key('repay_submit')), findsNothing);
    });

    testWidgets('chưa nhập: nút thanh toán bị khoá, có hướng dẫn', (tester) async {
      await repay(tester);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('repay_submit'))).onPressed, isNull);
      expect(find.textContaining('Nhập số tiền để xem khoản nợ nào'), findsOneWidget);
      expect(textOf(tester, 'repay_balance'), '3.000.000đ');
    });

    testWidgets('nhập số tiền: sau khi dừng gõ mới xem trước, trừ khoản sớm nhất trước', (tester) async {
      final h = await repay(tester);

      await tester.enterText(find.byKey(const Key('repay_amount')), '2500000');
      await tester.pump();
      expect(h.debt.previews, isEmpty, reason: 'chưa hết thời gian chờ gõ');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(h.debt.previews, [2500000]);
      expect(find.byKey(const Key('repay_preview')), findsOneWidget);
      expect(find.text('CN-a'), findsOneWidget);
      expect(find.text('−2.000.000đ'), findsOneWidget);
      expect(find.text('Trả hết'), findsOneWidget);
      expect(find.text('CN-b'), findsOneWidget);
      expect(find.text('−500.000đ'), findsOneWidget);
      expect(find.text('Trả một phần'), findsOneWidget);
      expect(textOf(tester, 'repay_amount_text'), '2.500.000đ');
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('repay_submit'))).onPressed,
          isNotNull);
    });

    testWidgets('gõ liên tục chỉ xem trước cho giá trị cuối', (tester) async {
      final h = await repay(tester);
      await tester.enterText(find.byKey(const Key('repay_amount')), '1');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.enterText(find.byKey(const Key('repay_amount')), '10');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.enterText(find.byKey(const Key('repay_amount')), '100000');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(h.debt.previews, [100000]);
    });

    testWidgets('vượt tổng nợ: báo lỗi, khoá nút, không xem trước', (tester) async {
      final h = await repay(tester);
      await tester.enterText(find.byKey(const Key('repay_amount')), '3000001');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.textContaining('vượt quá tổng nợ (3.000.000đ)'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('repay_submit'))).onPressed, isNull);
      expect(h.debt.previews, isEmpty);
    });

    testWidgets('chỉ nhận chữ số (dán chữ/dấu chấm bị loại)', (tester) async {
      await repay(tester);
      await tester.enterText(find.byKey(const Key('repay_amount')), '1.5a00');
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('repay_amount'))).controller!.text, '1500');
    });

    testWidgets('số 0 không hợp lệ', (tester) async {
      await repay(tester);
      await tester.enterText(find.byKey(const Key('repay_amount')), '0');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('repay_submit'))).onPressed, isNull);
    });

    testWidgets('chip "Trả hết nợ" điền tổng nợ và xem trước ngay', (tester) async {
      final h = await repay(tester);
      await tester.tap(find.byKey(const Key('repay_full')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byKey(const Key('repay_amount'))).controller!.text,
          '3000000');
      expect(h.debt.previews, [3000000]);
      expect(find.text('Trả hết'), findsNWidgets(2));
    });

    testWidgets('chip "Trả khoản quá hạn" chỉ hiện khi có nợ quá hạn', (tester) async {
      await repay(tester);
      expect(find.byKey(const Key('repay_overdue')), findsNothing);
    });

    testWidgets('có nợ quá hạn: chip điền đúng số quá hạn', (tester) async {
      await repay(tester, overdue: 1200000);
      await tester.tap(find.byKey(const Key('repay_overdue')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('repay_amount'))).controller!.text,
          '1200000');
    });

    testWidgets('mở với số gợi ý (từ chi tiết) thì xem trước ngay, không cần gõ', (tester) async {
      final h = await repay(tester, route: '/debt/repay?amount=2000000');
      expect(h.debt.previews, [2000000]);
      expect(find.byKey(const Key('repay_preview')), findsOneWidget);
    });

    testWidgets('lỗi xem trước: Thử lại', (tester) async {
      final h = await repay(tester, route: '/debt/repay?amount=1000000');
      h.debt.previewError = _net;
      await tester.tap(find.byKey(const Key('repay_full')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);

      h.debt.previewError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('repay_preview')), findsOneWidget);
    });

    testWidgets('bấm Thanh toán: tạo link trả nợ đúng số tiền, lưu khoản dở, mở trang payOS', (tester) async {
      final h = await repay(tester);
      await tester.enterText(find.byKey(const Key('repay_amount')), '1200000');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.textContaining('Thanh toán 1.200.000đ qua payOS'), findsOneWidget);
      await tester.tap(find.byKey(const Key('repay_submit')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('payos_stub')), findsOneWidget);
      expect(find.text('PAYOS pay1'), findsOneWidget);
      expect(h.payments.calls, contains('createDebt:1200000'));
      // Khoản thanh toán dở đã được nhớ TRƯỚC khi trang payOS mở.
      final saved = h.container.read(pendingPaymentProvider);
      expect(saved?.paymentId, 'pay1');
      expect(saved?.isDebtRepayment, isTrue);
      expect(saved?.amount, 1200000);
    });
  });

  group('Lịch sử trả nợ', () {
    testWidgets('hiện các lần trả với trạng thái và số tiền', (tester) async {
      await open(tester, '/debt/history', setup: (h) {
        h.debt.repayments0 = [
          repaymentOf('1', amount: 1000000),
          repaymentOf('2', status: 'PENDING', amount: 300000),
          repaymentOf('3', status: 'CANCELLED', amount: 200000),
        ];
      });

      expect(find.text('Trả nợ PM-1'), findsOneWidget);
      expect(find.text('1.000.000đ'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsOneWidget);
      expect(find.text('Chờ thanh toán'), findsOneWidget);
      expect(find.text('Đã huỷ'), findsOneWidget);
      expect(find.text('payOS (VietQR)'), findsNWidgets(3));
    });

    testWidgets('trống: thông báo chưa có lần trả nợ nào', (tester) async {
      await open(tester, '/debt/history');
      expect(find.text('Chưa có lần trả nợ nào.'), findsOneWidget);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, '/debt/history', setup: (h) => h.debt.repaymentsError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      h.debt.repaymentsError = null;
      h.debt.repayments0 = [repaymentOf('1')];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('repayment_1')), findsOneWidget);
    });

    testWidgets('nhiều trang: Xem thêm', (tester) async {
      final h = await open(tester, '/debt/history', setup: (h) {
        h.debt.pageSize0 = 2;
        h.debt.repayments0 = [for (var i = 1; i <= 3; i++) repaymentOf('$i')];
      });
      expect(find.byKey(const Key('repayment_3')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('repayments_load_more')));
      await tester.tap(find.byKey(const Key('repayments_load_more')));
      await tester.pumpAndSettle();
      expect(h.debt.calls, contains('repayments:2'));
      expect(find.byKey(const Key('repayment_3')), findsOneWidget);
    });
  });
}

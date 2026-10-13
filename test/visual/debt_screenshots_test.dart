// Chụp ảnh các màn công nợ bằng font thật (cần mạng để tải font Google).
//
//   SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/debt_screenshots_test.dart
//
// Ảnh ra ở test/visual/shots/ (xem xong thì xoá thư mục). Test cũng thất bại nếu
// có lỗi tràn layout với font thật ở cả khung 390px và 320px.
import 'dart:io';

import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/debt_fakes.dart';
import '../helpers/order_fakes.dart';
import 'auth_screenshots_test.dart' show shoot, useRealFonts;

final _on = Platform.environment['SCREENSHOTS'] == '1';

void seedMixed(AppHarness h) {
  final entries = [
    entryOf('a', original: 2350000, due: DateTime(2026, 10, 5), overdue: true, overdueDays: 7),
    entryOf('b',
        status: 'PARTIALLY_PAID', original: 1800000, paid: 600000, due: DateTime(2026, 10, 25)),
    entryOf('c', status: 'DISPUTED', original: 950000, due: DateTime(2026, 11, 8)),
    entryOf('d', status: 'PAID', original: 500000, paid: 500000, outstanding: 0),
  ];
  h.debt.entries0 = entries;
  for (final e in entries) {
    h.debt.details[e.id] = detailOf(e.id,
        status: e.status,
        original: e.originalAmount,
        paid: e.totalPaid,
        overdue: e.isOverdue,
        overdueDays: e.overdueDays);
  }
  h.debt.details['c'] = DebtEntryDetail.fromJson(entryDetailJson('c', status: 'DISPUTED', original: 950000, actions: [
    {
      'actionType': 'DISPUTE',
      'reason': 'Tôi chỉ nhận 1 bao, không phải 2 bao như trong đơn',
      'createdAt': '2026-10-06T02:00:00Z',
    },
  ]));
  h.debt.account0 = accountOf(balance: 4100000, overdue: 2350000, open: 3, oldest: DateTime(2026, 10, 5));
  h.credit.credit = creditOf(available: 5900000, term: 30);
  h.debt.repayments0 = [
    repaymentOf('1', amount: 1500000),
    repaymentOf('2', status: 'PENDING', amount: 300000),
    repaymentOf('3', status: 'CANCELLED', amount: 200000),
  ];
}

void main() {
  for (final width in [390.0, 320.0]) {
    final tag = width.toInt();

    Future<AppHarness> open(WidgetTester tester, String route,
        {void Function(AppHarness)? setup, bool settle = true}) async {
      await useRealFonts(tester);
      final h = AppHarness()..signIn();
      seedMixed(h);
      setup?.call(h);
      await h.pump(tester, initial: route);
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        // Màn có đồng hồ chạy mãi (QR): không chờ yên lặng được.
        await tester.pump();
        await tester.pump();
      }
      return h;
    }

    group('ảnh công nợ $tag px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      testWidgets('tổng quan', (tester) async {
        await open(tester, '/debt');
        await shoot(tester, '${tag}_debt_overview');
      });

      testWidgets('tổng quan: chưa có hạn mức', (tester) async {
        await open(tester, '/debt', setup: (h) {
          h.credit.credit = null;
          h.debt.account0 = null;
        });
        await shoot(tester, '${tag}_debt_overview_empty');
      });

      testWidgets('tổng quan: hạn mức bị khoá, hết nợ', (tester) async {
        await open(tester, '/debt', setup: (h) {
          h.credit.credit = creditOf(status: 'SUSPENDED', available: 5000000);
          h.debt.account0 = accountOf(balance: 0, open: 0);
          h.debt.entries0 = [];
        });
        await shoot(tester, '${tag}_debt_overview_suspended');
      });

      testWidgets('danh sách', (tester) async {
        await open(tester, '/debt/list');
        await shoot(tester, '${tag}_debt_list');
      });

      testWidgets('chi tiết: quá hạn', (tester) async {
        await open(tester, '/debt/a');
        await shoot(tester, '${tag}_debt_detail_overdue');
      });

      testWidgets('chi tiết: trả một phần (cuộn xuống)', (tester) async {
        await open(tester, '/debt/b');
        await shoot(tester, '${tag}_debt_detail_partial');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_debt_detail_partial_bottom');
      });

      testWidgets('chi tiết: đang khiếu nại', (tester) async {
        await open(tester, '/debt/c');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_debt_detail_disputed');
      });

      testWidgets('hộp thoại khiếu nại', (tester) async {
        await open(tester, '/debt/a');
        await tester.tap(find.byKey(const Key('debt_dispute')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_debt_dispute_dialog');
        await tester.tap(find.byKey(const Key('dispute_submit')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_debt_dispute_dialog_error');
      });

      testWidgets('trả nợ: trống → có xem trước → vượt nợ', (tester) async {
        await open(tester, '/debt/repay');
        await shoot(tester, '${tag}_debt_repay_empty');
        await tester.enterText(find.byKey(const Key('repay_amount')), '3000000');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_debt_repay_preview');
        await tester.enterText(find.byKey(const Key('repay_amount')), '9999999');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_debt_repay_over');
      });

      testWidgets('trả nợ: lỗi xem trước', (tester) async {
        await open(tester, '/debt/repay?amount=1000000',
            setup: (h) => h.debt.previewError = Exception('x'));
        await shoot(tester, '${tag}_debt_repay_preview_error');
      });

      testWidgets('lịch sử trả nợ', (tester) async {
        await open(tester, '/debt/history');
        await shoot(tester, '${tag}_debt_history');
      });
    });
  }
}

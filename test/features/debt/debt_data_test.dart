import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/labels/debt_labels.dart';
import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';
import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../support/checkout_fixtures.dart' show credit;
import '../../support/debt_fixtures.dart';

DebtSummary summaryOf({
  double balance = 3000000,
  double overdue = 0,
  String? due = '2026-11-20',
  bool withCredit = true,
  List<PaymentListItem> repayments = const [],
}) =>
    DebtSummary(
      credit: withCredit ? credit() : null,
      account: DebtAccount.fromJson(debtAccountJson(balance: balance, overdue: overdue, oldestDue: due)),
      repayments: repayments,
    );

void main() {
  group('models', () {
    test('an entry reads its amounts, due date and the order it came from', () {
      final e = DebtEntryListItem.fromJson(debtEntryRow(order: 'OD-1', overdue: true, overdueDays: 3));
      expect(e.title, 'OD-1');
      expect(e.outstandingAmount, 1500000);
      expect(e.dueDate, DateTime.utc(2026, 11, 20));
      expect(e.isOverdue, isTrue);
      expect(e.overdueDays, 3);
      expect(DebtEntryListItem.fromJson(debtEntryRow(order: null)).title, 'DE-20261007-0001', reason: 'no order: its own number');
    });

    test('an entry detail carries its history', () {
      final d = DebtEntryDetail.fromJson(debtEntryDetailJson(actions: [disputeActionJson]));
      expect(d.entry.entryNumber, 'DE-20261007-0001');
      expect(d.fulfillmentValue, 2000000);
      expect(d.actions.single.actionType, 'DISPUTE');
      expect(d.transactions, hasLength(2));
      expect(d.transactions.last.amountDelta, -500000);
    });

    test('a preview lists what an amount would settle', () {
      final p = AllocationPreview.fromJson(previewJson(1000000));
      expect(p.allocations.single.allocatedAmount, 1000000);
      expect(p.unallocatedAmount, 0);
    });
  });

  group('DebtSummary', () {
    test('a farmer with neither a credit line nor a debt account has no debt book', () {
      expect(const DebtSummary().hasDebtBook, isFalse);
      expect(const DebtSummary().balance, 0);
      expect(summaryOf().hasDebtBook, isTrue);
      expect(DebtSummary(credit: credit()).hasDebtBook, isTrue, reason: 'a credit line alone is a book (no debt yet)');
    });

    test('the balance is the account balance, else what the credit line says is owed', () {
      expect(summaryOf(balance: 123456.7).balance, 123456.7);
      expect(DebtSummary(credit: credit()).balance, 3000000, reason: 'outstandingReceivable of the credit fixture');
    });

    test('a repayment can be at most the whole debt, in whole đồng', () {
      expect(summaryOf(balance: 1234567.9).maxRepayable, 1234567);
      expect(summaryOf(balance: 0.4).maxRepayable, 0);
    });

    test('only paid repayments count as repaid', () {
      final s = summaryOf(repayments: [
        PaymentListItem.fromJson(repaymentJson(id: 'a', amount: 500000)),
        PaymentListItem.fromJson(repaymentJson(id: 'b', status: 'PENDING', amount: 900000)),
        PaymentListItem.fromJson(repaymentJson(id: 'c', status: 'CANCELLED', amount: 700000)),
        PaymentListItem.fromJson(repaymentJson(id: 'd', amount: 250000)),
      ]);
      expect(s.totalRepaid, 750000);
    });

    test('days to the nearest due date are counted in Vietnam days', () {
      final s = summaryOf(due: '2026-11-20');
      // 20:00 UTC on 19/11 is already 03:00 on 20/11 in Vietnam: due today.
      expect(s.daysToDue(DateTime.utc(2026, 11, 19, 20)), 0);
      expect(s.daysToDue(DateTime.utc(2026, 11, 19, 10)), 1);
      expect(s.daysToDue(DateTime.utc(2026, 11, 21, 10)), -1, reason: 'a day late');
    });

    test('nothing owed means nothing is due', () {
      expect(summaryOf(balance: 0).daysToDue(DateTime.utc(2026, 11, 1)), isNull);
      expect(summaryOf(due: null).daysToDue(DateTime.utc(2026, 11, 1)), isNull);
    });

    test('due soon is within a week and only when nothing is overdue yet', () {
      expect(summaryOf(due: '2026-11-20').dueSoon(DateTime.utc(2026, 11, 13, 10)), isTrue, reason: '7 days left');
      expect(summaryOf(due: '2026-11-20').dueSoon(DateTime.utc(2026, 11, 12, 10)), isFalse, reason: '8 days left');
      expect(summaryOf(due: '2026-11-20', overdue: 100000).dueSoon(DateTime.utc(2026, 11, 19, 10)), isFalse, reason: 'already overdue: the other banner');
    });
  });

  group('readRepayAmount', () {
    test('whole numbers from 1 to the whole debt are accepted', () {
      expect(readRepayAmount('1', 1000).value, 1);
      expect(readRepayAmount('1000', 1000).value, 1000);
      expect(readRepayAmount(' 500 ', 1000).value, 500);
    });

    test('thousands separators typed by the farmer are ignored', () {
      expect(readRepayAmount('1.500.000', 2000000).value, 1500000);
      expect(readRepayAmount('1,500,000', 2000000).value, 1500000);
    });

    test('nothing, zero, decimals, letters and too much are refused with a reason', () {
      expect(readRepayAmount('', 1000).error, contains('nhập'));
      expect(readRepayAmount('0', 1000).isValid, isFalse);
      expect(readRepayAmount('12abc', 1000).isValid, isFalse);
      expect(readRepayAmount('-5', 1000).isValid, isFalse);
      final tooMuch = readRepayAmount('1001', 1000);
      expect(tooMuch.isValid, isFalse);
      expect(tooMuch.error, contains('không được vượt quá 1.000'));
    });
  });

  group('labels', () {
    test('only entries that are open, partly paid or adjusted can be disputed', () {
      for (final ok in ['OPEN', 'PARTIALLY_PAID', 'ADJUSTED']) {
        expect(canDisputeDebtEntry(ok), isTrue, reason: ok);
      }
      for (final no in ['PAID', 'DISPUTED', 'CANCELLED']) {
        expect(canDisputeDebtEntry(no), isFalse, reason: no);
      }
    });

    test('codes the app does not know show as themselves', () {
      expect(debtTransactionLabel('PAYMENT'), 'Trả nợ');
      expect(debtTransactionLabel('NEW_KIND'), 'NEW_KIND');
      expect(debtActionLabel('KEEP'), 'Cửa hàng giữ nguyên số nợ');
      expect(debtSourceLabel('DELIVERY'), 'Mua chịu, giao hàng');
      expect(repaymentMethodLabel('CASH'), 'Tiền mặt tại quầy');
    });
  });

  group('DebtRepository', () {
    late DioAdapter adapter;
    late DebtRepository repo;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      adapter = DioAdapter(dio: dio);
      repo = DebtRepository(dio);
    });

    Map<String, dynamic> notFound() => {'detail': "Customer debt account 'x' was not found."};

    test('no credit profile (404) means no account', () async {
      adapter.onGet('/api/me/debt', (server) => server.reply(404, notFound()));
      expect(await repo.account(), isNull);
    });

    test('the account reads', () async {
      adapter.onGet('/api/me/debt', (server) => server.reply(200, debtAccountJson()));
      expect((await repo.account())?.openEntryCount, 2);
    });

    test('the list asks for a status and a page, and 404 is an empty list', () async {
      adapter.onGet(
        '/api/me/debt-entries',
        (server) => server.reply(200, {'items': [debtEntryRow()], 'page': 1, 'pageSize': 20, 'totalCount': 1}),
        queryParameters: {'status': 'DISPUTED', 'page': 1, 'pageSize': 20},
      );
      expect((await repo.entries(status: 'DISPUTED')).items, hasLength(1));

      adapter.onGet('/api/me/debt-entries', (server) => server.reply(404, notFound()), queryParameters: {'page': 1, 'pageSize': 20});
      expect((await repo.entries()).items, isEmpty);
    });

    test('an entry, a dispute (reason trimmed) and a preview', () async {
      adapter.onGet('/api/me/debt-entries/e-1', (server) => server.reply(200, debtEntryDetailJson()));
      adapter.onPost('/api/me/debt-entries/e-1/dispute', (server) => server.reply(200, debtEntryDetailJson(status: 'DISPUTED')),
          data: {'reason': 'Chưa đúng'});
      adapter.onGet('/api/me/debt/allocation-preview', (server) => server.reply(200, previewJson(500000)), queryParameters: {'amount': 500000});

      expect((await repo.entry('e-1')).entry.status, 'OPEN');
      expect((await repo.dispute('e-1', '  Chưa đúng ')).entry.status, 'DISPUTED');
      expect((await repo.allocationPreview(500000)).allocations, hasLength(1));
    });
  });
}

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/debt_fakes.dart';

Map<String, dynamic> pageOf(List<Map<String, dynamic>> items,
        {int page = 1, int totalPages = 1}) =>
    {
      'items': items,
      'page': page,
      'pageSize': 20,
      'totalCount': items.length,
      'totalPages': totalPages,
    };

Map<String, dynamic> itemJson(String id,
        {String status = 'OPEN', bool overdue = false, double outstanding = 2000000}) =>
    {
      'id': id,
      'entryNumber': 'CN-$id',
      'orderNumber': 'DH-$id',
      'sourceType': 'DELIVERY',
      'originalAmount': 2000000,
      'totalPaid': 2000000 - outstanding,
      'outstandingAmount': outstanding,
      'dueDate': '2026-10-30',
      'isOverdue': overdue,
      'overdueDays': overdue ? 3 : 0,
      'status': status,
      'createdAt': '2026-10-01T02:00:00Z',
    };

void main() {
  late FakeAdapter adapter;
  late DebtRepository repo;
  late PaymentRepository pay;

  void use(FakeHandler h) {
    adapter = FakeAdapter(h);
    final dio = createApiDio(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      onSessionExpired: () async {},
      adapter: adapter,
    );
    repo = DebtRepository(dio);
    pay = PaymentRepository(dio);
  }

  group('tài khoản công nợ', () {
    test('đọc đủ số liệu', () async {
      use((o) => jsonBody(200, {
            'id': 'acc',
            'status': 'ACTIVE',
            'currentBalance': 3000000.0,
            'overdueAmount': 500000,
            'openEntryCount': 2,
            'oldestDueDate': '2026-10-05',
          }));

      final a = (await repo.account())!;
      expect(adapter.requests.single.path, '/api/me/debt');
      expect(a.currentBalance, 3000000);
      expect(a.overdueAmount, 500000);
      expect(a.hasOverdue, isTrue);
      expect(a.openEntryCount, 2);
      expect(a.oldestDueDate, DateTime(2026, 10, 5));
    });

    test('404 (chưa mở sổ nợ) → null, không phải lỗi', () async {
      use((o) => jsonBody(404, {'status': 404, 'detail': 'Customer debt account not found.'}));
      expect(await repo.account(), isNull);
    });

    test('lỗi khác 404 vẫn ném ApiException', () async {
      use((o) => jsonBody(500, {'status': 500}));
      expect(repo.account(), throwsA(isA<ApiException>()));
    });

    test('nợ bằng 0 → hasDebt false', () {
      final a = DebtAccount.fromJson({'status': 'ACTIVE', 'currentBalance': 0});
      expect(a.hasDebt, isFalse);
      expect(a.hasOverdue, isFalse);
      expect(a.oldestDueDate, isNull);
    });
  });

  group('danh sách khoản nợ', () {
    test('mặc định: trang 1, 20 dòng, không lọc, không ép thứ tự', () async {
      use((o) => jsonBody(200, pageOf([itemJson('a')])));
      final r = await repo.entries();

      expect(adapter.requests.single.path, '/api/me/debt-entries');
      expect(adapter.requests.single.queryParameters, {'page': 1, 'pageSize': 20});
      expect(r.items.single.entryNumber, 'CN-a');
      expect(r.items.single.dueDate, DateTime(2026, 10, 30));
    });

    test('lọc trạng thái: gửi status + xếp theo hạn trả tăng dần', () async {
      use((o) => jsonBody(200, pageOf([])));
      await repo.entries(status: DebtStatus.open, page: 2);

      expect(adapter.requests.single.queryParameters, {
        'page': 2,
        'pageSize': 20,
        'status': 'OPEN',
        'sortBy': 'DueDate',
        'descending': false,
      });
    });

    test('lọc Quá hạn: dùng overdueOnly, KHÔNG gửi status giả', () async {
      use((o) => jsonBody(200, pageOf([])));
      await repo.entries(status: DebtStatus.overdueFilter);

      final q = adapter.requests.single.queryParameters;
      expect(q['overdueOnly'], true);
      expect(q.containsKey('status'), isFalse);
      expect(q['sortBy'], 'DueDate');
    });

    test('lọc Đã thanh toán: mới nhất trước (không ép DueDate)', () async {
      use((o) => jsonBody(200, pageOf([])));
      await repo.entries(status: DebtStatus.paid);

      final q = adapter.requests.single.queryParameters;
      expect(q['status'], 'PAID');
      expect(q.containsKey('sortBy'), isFalse);
    });

    test('isClosed: PAID / CANCELLED / hết nợ', () {
      expect(DebtEntrySummary.fromJson(itemJson('a', status: 'PAID', outstanding: 0)).isClosed, isTrue);
      expect(DebtEntrySummary.fromJson(itemJson('a', status: 'CANCELLED')).isClosed, isTrue);
      expect(DebtEntrySummary.fromJson(itemJson('a', status: 'OPEN', outstanding: 0)).isClosed, isTrue);
      expect(DebtEntrySummary.fromJson(itemJson('a', status: 'PARTIALLY_PAID', outstanding: 500)).isClosed, isFalse);
      expect(DebtEntrySummary.fromJson(itemJson('a', status: 'DISPUTED')).isClosed, isFalse);
    });

    test('upcoming: gộp 3 trạng thái chưa trả, sắp theo hạn, cắt đúng số lượng', () async {
      use((o) {
        final status = o.queryParameters['status'];
        final due = {'OPEN': '2026-11-03', 'PARTIALLY_PAID': '2026-10-01', 'DISPUTED': '2026-10-15'}[status]!;
        return jsonBody(200, pageOf([
          {...itemJson('x-$status', status: status as String), 'dueDate': due},
        ]));
      });

      final r = await repo.upcoming(limit: 2);
      expect(adapter.requests.length, 3);
      expect(r.map((e) => e.id), ['x-PARTIALLY_PAID', 'x-DISPUTED']);
    });
  });

  group('chi tiết khoản nợ', () {
    test('đọc sản phẩm của đơn, biến động, khiếu nại, phần tiền trừ vào khoản này', () async {
      use((o) => jsonBody(
          200,
          entryDetailJson('e1', status: 'PARTIALLY_PAID', paid: 500000, actions: [
            {
              'actionType': 'DISPUTE',
              'reason': 'Chưa nhận đủ hàng',
              'createdAt': '2026-10-06T02:00:00Z',
            }
          ], payments: [
            {
              'paymentNumber': 'PM-1',
              'paymentMethod': 'PAYOS',
              'status': 'PAID',
              'amount': 800000,
              'confirmedAt': '2026-10-05T02:00:00Z',
              'allocations': [
                {'debtEntryId': 'e1', 'allocatedAmount': 500000},
                {'debtEntryId': 'other', 'allocatedAmount': 300000},
              ],
            }
          ])));

      final d = await repo.entry('e1');
      expect(adapter.requests.single.path, '/api/me/debt-entries/e1');
      expect(d.status, 'PARTIALLY_PAID');
      expect(d.outstandingAmount, 1500000);
      expect(d.orderLines.single.productName, 'Phân NPK 20-20-15');
      expect(d.transactions.map((t) => t.type), ['CREDIT_SALE', 'PAYMENT']);
      expect(d.transactions.last.amountDelta, -500000);
      expect(d.actions.single.reason, 'Chưa nhận đủ hàng');
      expect(d.payments.single.allocatedToEntry, 500000,
          reason: 'chỉ tính phần phân vào khoản này, không tính khoản khác');
      expect(d.canDispute, isTrue);
    });

    test('order = null (khoản ghi tay) → không có sản phẩm', () async {
      use((o) => jsonBody(200, entryDetailJson('e1', withOrder: false)));
      expect((await repo.entry('e1')).orderLines, isEmpty);
    });

    test('canDispute: không cho khi đã khiếu nại hoặc đã đóng', () {
      expect(detailOf('a', status: 'DISPUTED').canDispute, isFalse);
      expect(detailOf('a', status: 'PAID', paid: 2000000).canDispute, isFalse);
      expect(detailOf('a', status: 'CANCELLED').canDispute, isFalse);
      expect(detailOf('a', status: 'OPEN').canDispute, isTrue);
    });

    test('404 → thông báo tiếng Việt', () async {
      use((o) => jsonBody(404, {'status': 404, 'detail': 'Debt entry not found'}));
      expect(
        repo.entry('x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Không tìm thấy khoản nợ.')),
      );
    });
  });

  group('khiếu nại', () {
    test('gửi lý do đã trim vào đúng URL', () async {
      use((o) => jsonBody(200, entryDetailJson('e1', status: 'DISPUTED')));
      final d = await repo.dispute('e1', '  Sai số tiền  ');

      expect(adapter.requests.single.path, '/api/me/debt-entries/e1/dispute');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {'reason': 'Sai số tiền'});
      expect(d.status, 'DISPUTED');
    });

    test('đã khiếu nại rồi (422) → thông báo cụ thể', () async {
      use((o) => jsonBody(422, {'status': 422, 'detail': "Debt entry 'CN-1' is already disputed."}));
      expect(
        repo.dispute('e1', 'x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('đã được khiếu nại'))),
      );
    });

    test('khoản đã đóng (422 khác) → thông báo đã đóng', () async {
      use((o) => jsonBody(422, {'status': 422, 'detail': "Debt entry 'CN-1' is closed."}));
      expect(
        repo.dispute('e1', 'x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('đã đóng'))),
      );
    });

    test('400 (lý do trống/quá dài) → nhắc nhập lý do', () async {
      use((o) => jsonBody(400, {'status': 400, 'errors': {'Reason': ['x']}}));
      expect(
        repo.dispute('e1', 'x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('lý do'))),
      );
    });
  });

  group('xem trước phân bổ', () {
    test('số nguyên gửi dạng số nguyên; đọc từng khoản và phần dư', () async {
      use((o) => jsonBody(200, {
            'amount': 2500000,
            'allocations': [
              {
                'debtEntryId': 'a',
                'entryNumber': 'CN-a',
                'dueDate': '2026-10-05',
                'outstandingAmount': 2000000,
                'allocatedAmount': 2000000,
              },
              {
                'debtEntryId': 'b',
                'entryNumber': 'CN-b',
                'dueDate': '2026-10-20',
                'outstandingAmount': 1000000,
                'allocatedAmount': 500000,
              },
            ],
            'unallocatedAmount': 0,
          }));

      final p = await repo.preview(2500000);
      expect(adapter.requests.single.path, '/api/me/debt/allocation-preview');
      expect(adapter.requests.single.queryParameters, {'amount': 2500000});
      expect(p.allocations.length, 2);
      expect(p.allocations[0].clearsEntry, isTrue);
      expect(p.allocations[1].clearsEntry, isFalse);
      expect(p.unallocatedAmount, 0);
    });

    test('số lẻ giữ phần lẻ', () async {
      use((o) => jsonBody(200, {'amount': 1000.5, 'allocations': [], 'unallocatedAmount': 1000.5}));
      await repo.preview(1000.5);
      expect(adapter.requests.single.queryParameters, {'amount': 1000.5});
    });

    test('404 → chưa có công nợ', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(
        repo.preview(1000),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('chưa có công nợ'))),
      );
    });
  });

  group('lịch sử trả nợ', () {
    Map<String, dynamic> pay0(String id, String ctx, {String status = 'PAID'}) => {
          'id': id,
          'paymentNumber': 'PM-$id',
          'paymentContext': ctx,
          'paymentMethod': 'PAYOS',
          'amount': 1000000,
          'status': status,
          'initiatedAt': '2026-10-12T02:31:00Z',
          'confirmedAt': status == 'PAID' ? '2026-10-12T02:35:00Z' : null,
        };

    test('chỉ giữ DEBT_REPAYMENT, bỏ thanh toán đơn hàng; giữ phân trang gốc', () async {
      use((o) => jsonBody(200, {
            'items': [
              pay0('1', 'ORDER_PAYMENT'),
              pay0('2', 'DEBT_REPAYMENT'),
              pay0('3', 'DEBT_REPAYMENT', status: 'PENDING'),
            ],
            'page': 1,
            'pageSize': 50,
            'totalCount': 120,
            'totalPages': 3,
          }));

      final r = await repo.repayments();
      expect(adapter.requests.single.path, '/api/me/payments');
      expect(adapter.requests.single.queryParameters, {'page': 1, 'pageSize': 50});
      expect(r.items.map((p) => p.id), ['2', '3']);
      expect(r.hasMore, isTrue, reason: 'còn trang gốc dù trang này đã lọc bớt');
      expect(r.items.first.when, DateTime.utc(2026, 10, 12, 2, 35).toLocal());
    });
  });

  group('trả nợ qua payOS', () {
    Map<String, dynamic> link() => {
          'paymentId': 'p1',
          'paymentNumber': 'PM-20261012-0001',
          'amount': 1500000,
          'checkoutUrl': 'https://pay.payos.vn/web/p1',
          'qrCode': '000201',
          'expiresAt': '2026-10-12T03:00:00Z',
          'status': 'PENDING',
        };

    test('gửi DEBT_REPAYMENT + số tiền nguyên, KHÔNG gửi orderId', () async {
      use((o) => jsonBody(201, link()));
      final l = await pay.createForDebt(1500000);

      expect(adapter.requests.single.path, '/api/me/payments/payos');
      expect(adapter.requests.single.data,
          {'paymentContext': 'DEBT_REPAYMENT', 'amount': 1500000});
      expect(l.paymentId, 'p1');
      expect(l.amount, 1500000);
    });

    test('số tiền vượt nợ (422 owes) → thông báo', () async {
      use((o) => jsonBody(422, {'status': 422, 'detail': 'The customer owes 1000; the payment is 2000.'}));
      expect(
        pay.createForDebt(2000),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('vượt quá số nợ'))),
      );
    });

    test('payOS chưa cấu hình (503) → báo gián đoạn', () async {
      use((o) => jsonBody(503, {'status': 503, 'detail': 'PayOS is not configured'}));
      expect(
        pay.createForDebt(1000),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('gián đoạn'))),
      );
    });

    test('404 (không có sổ nợ) → thông báo chưa có công nợ', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(
        pay.createForDebt(1000),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('chưa có công nợ'))),
      );
    });
  });

  group('nhãn trạng thái', () {
    test('mọi trạng thái backend có nhãn tiếng Việt', () {
      for (final s in ['OPEN', 'PARTIALLY_PAID', 'PAID', 'DISPUTED', 'ADJUSTED', 'CANCELLED']) {
        expect(DebtStatus.label(s), isNot(s), reason: s);
      }
      for (final t in ['CREDIT_SALE', 'PAYMENT', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'RETURN', 'REVERSAL']) {
        expect(DebtTransaction.label(t), isNot(t), reason: t);
      }
      for (final a in ['DISPUTE', 'KEEP', 'ADJUST', 'CANCEL', 'CHANGE_DUE_DATE']) {
        expect(DebtAction.label(a), isNot(a), reason: a);
      }
    });
  });
}

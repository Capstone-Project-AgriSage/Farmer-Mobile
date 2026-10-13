import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';

DebtAccount accountOf({
  double balance = 3000000,
  double overdue = 0,
  int open = 2,
  DateTime? oldest,
}) =>
    DebtAccount(
      status: 'ACTIVE',
      currentBalance: balance,
      overdueAmount: overdue,
      openEntryCount: open,
      oldestDueDate: oldest ?? DateTime(2026, 10, 20),
    );

DebtEntrySummary entryOf(
  String id, {
  String status = 'OPEN',
  double original = 2000000,
  double paid = 0,
  double? outstanding,
  DateTime? due,
  bool overdue = false,
  int overdueDays = 0,
}) =>
    DebtEntrySummary(
      id: id,
      entryNumber: 'CN-$id',
      orderNumber: 'DH-$id',
      originalAmount: original,
      totalPaid: paid,
      outstandingAmount: outstanding ?? original - paid,
      dueDate: due ?? DateTime(2026, 10, 30),
      isOverdue: overdue,
      overdueDays: overdueDays,
      status: status,
      createdAt: DateTime(2026, 10, 1),
    );

Map<String, dynamic> entryDetailJson(
  String id, {
  String status = 'OPEN',
  double original = 2000000,
  double paid = 0,
  bool overdue = false,
  int overdueDays = 0,
  bool withOrder = true,
  List<Map<String, dynamic>> actions = const [],
  List<Map<String, dynamic>> payments = const [],
}) =>
    {
      'id': id,
      'entryNumber': 'CN-$id',
      'sourceType': 'DELIVERY',
      'orderId': 'o-$id',
      'orderNumber': 'DH-$id',
      'originalAmount': original,
      'totalPaid': paid,
      'outstandingAmount': original - paid,
      'dueDate': '2026-10-30',
      'isOverdue': overdue,
      'overdueDays': overdueDays,
      'status': status,
      'createdAt': '2026-10-01T02:00:00Z',
      'order': withOrder
          ? {
              'items': [
                {
                  'id': 'oi1',
                  'productName': 'Phân NPK 20-20-15',
                  'packagingName': 'Bao 50 kg',
                  'quantity': 2,
                  'unitPrice': 1000000,
                  'lineTotalAmount': 2000000,
                  'status': 'OPEN',
                }
              ]
            }
          : null,
      'actions': actions,
      'transactions': [
        {
          'transactionType': 'CREDIT_SALE',
          'amountDelta': original,
          'balanceAfter': original,
          'occurredAt': '2026-10-01T02:00:00Z',
          'note': null,
        },
        if (paid > 0)
          {
            'transactionType': 'PAYMENT',
            'amountDelta': -paid,
            'balanceAfter': original - paid,
            'occurredAt': '2026-10-05T02:00:00Z',
            'note': null,
          },
      ],
      'payments': payments,
    };

DebtEntryDetail detailOf(
  String id, {
  String status = 'OPEN',
  double original = 2000000,
  double paid = 0,
  bool overdue = false,
  int overdueDays = 0,
  List<Map<String, dynamic>> actions = const [],
}) =>
    DebtEntryDetail.fromJson(entryDetailJson(id,
        status: status,
        original: original,
        paid: paid,
        overdue: overdue,
        overdueDays: overdueDays,
        actions: actions));

DebtPayment repaymentOf(String id,
        {String status = 'PAID', double amount = 1000000}) =>
    DebtPayment(
      id: id,
      paymentNumber: 'PM-$id',
      method: 'PAYOS',
      amount: amount,
      status: status,
      initiatedAt: DateTime.utc(2026, 10, 12, 2, 31),
      confirmedAt: status == 'PAID' ? DateTime.utc(2026, 10, 12, 2, 35) : null,
    );

class FakeDebtRepository extends DebtRepository {
  FakeDebtRepository() : super(Dio());

  final List<String> calls = [];
  DebtAccount? account0 = accountOf();
  List<DebtEntrySummary> entries0 = [];
  Map<String, DebtEntryDetail> details = {};
  List<DebtPayment> repayments0 = [];

  Object? accountError;
  Object? entriesError;
  Object? entryError;
  Object? disputeError;
  Object? previewError;
  Object? repaymentsError;
  Future<void>? entriesGate;
  int pageSize0 = 20;

  final List<({int page, String? status})> entryCalls = [];
  final List<({String id, String reason})> disputes = [];
  final List<double> previews = [];

  @override
  Future<DebtAccount?> account() async {
    calls.add('account');
    if (accountError != null) throw accountError!;
    return account0;
  }

  @override
  Future<PagedResult<DebtEntrySummary>> entries({
    int page = 1,
    int size = DebtRepository.pageSize,
    String? status,
  }) async {
    calls.add('entries');
    entryCalls.add((page: page, status: status));
    await entriesGate;
    if (entriesError != null) throw entriesError!;
    final filtered = entries0.where((e) {
      if (status == null) return true;
      if (status == DebtStatus.overdueFilter) return e.isOverdue && !e.isClosed;
      return e.status == status;
    }).toList();
    final per = size == DebtRepository.pageSize ? pageSize0 : size;
    return PagedResult(
      items: filtered.skip((page - 1) * per).take(per).toList(),
      page: page,
      pageSize: per,
      totalCount: filtered.length,
      totalPages: (filtered.length + per - 1) ~/ per,
    );
  }

  @override
  Future<List<DebtEntrySummary>> upcoming({int limit = 5}) async {
    calls.add('upcoming');
    if (entriesError != null) throw entriesError!;
    final open = entries0.where((e) => !e.isClosed).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return open.take(limit).toList();
  }

  @override
  Future<DebtEntryDetail> entry(String id) async {
    calls.add('entry:$id');
    if (entryError != null) throw entryError!;
    final d = details[id];
    if (d == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound, statusCode: 404, message: 'Không tìm thấy khoản nợ.');
    }
    return d;
  }

  @override
  Future<DebtEntryDetail> dispute(String id, String reason) async {
    calls.add('dispute:$id');
    disputes.add((id: id, reason: reason.trim()));
    if (disputeError != null) throw disputeError!;
    final old = details[id]!;
    final updated = DebtEntryDetail.fromJson(entryDetailJson(
      id,
      status: DebtStatus.disputed,
      original: old.originalAmount,
      paid: old.totalPaid,
      actions: [
        {
          'actionType': 'DISPUTE',
          'reason': reason.trim(),
          'createdAt': '2026-10-12T03:00:00Z',
        }
      ],
    ));
    details[id] = updated;
    return updated;
  }

  @override
  Future<AllocationPreview> preview(double amount) async {
    calls.add('preview');
    previews.add(amount);
    if (previewError != null) throw previewError!;
    var left = amount;
    final items = <AllocationItem>[];
    final open = entries0.where((e) => !e.isClosed).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    for (final e in open) {
      if (left <= 0) break;
      final take = left < e.outstandingAmount ? left : e.outstandingAmount;
      items.add(AllocationItem(
        debtEntryId: e.id,
        entryNumber: e.entryNumber,
        dueDate: e.dueDate,
        outstandingAmount: e.outstandingAmount,
        allocatedAmount: take,
      ));
      left -= take;
    }
    return AllocationPreview(amount: amount, allocations: items, unallocatedAmount: left);
  }

  @override
  Future<PagedResult<DebtPayment>> repayments({int page = 1}) async {
    calls.add('repayments:$page');
    if (repaymentsError != null) throw repaymentsError!;
    final per = pageSize0;
    final items = repayments0.skip((page - 1) * per).take(per).toList();
    return PagedResult(
      items: items,
      page: page,
      pageSize: per,
      totalCount: repayments0.length,
      totalPages: (repayments0.length + per - 1) ~/ per,
    );
  }
}

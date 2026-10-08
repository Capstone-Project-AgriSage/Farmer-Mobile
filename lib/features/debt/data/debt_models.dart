import '../../../core/utils/formatters.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/vn_time.dart';
import '../../credit/data/credit_models.dart';
import '../../payment/data/payment_models.dart';

/// `GET /api/me/debt`: what the farmer owes the store in total.
class DebtAccount {
  const DebtAccount({
    required this.id,
    required this.status,
    required this.currentBalance,
    required this.overdueAmount,
    required this.openEntryCount,
    this.oldestDueDate,
    this.lastTransactionAt,
  });

  final String id;
  final String status;
  final double currentBalance;
  final double overdueAmount;
  final int openEntryCount;
  final DateTime? oldestDueDate;
  final DateTime? lastTransactionAt;

  factory DebtAccount.fromJson(Map<String, dynamic> json) => DebtAccount(
        id: asString(json['id']),
        status: asString(json['status']),
        currentBalance: asDouble(json['currentBalance']),
        overdueAmount: asDouble(json['overdueAmount']),
        openEntryCount: asInt(json['openEntryCount']),
        oldestDueDate: asDateTime(json['oldestDueDate']),
        lastTransactionAt: asDateTime(json['lastTransactionAt']),
      );
}

/// One debt: the unpaid value of one credit order that was delivered.
class DebtEntryListItem {
  const DebtEntryListItem({
    required this.id,
    required this.entryNumber,
    required this.sourceType,
    required this.originalAmount,
    required this.totalPaid,
    required this.outstandingAmount,
    required this.dueDate,
    required this.isOverdue,
    required this.overdueDays,
    required this.status,
    this.orderNumber,
    this.createdAt,
  });

  final String id;
  final String entryNumber;
  final String sourceType;
  final String? orderNumber;
  final double originalAmount;
  final double totalPaid;
  final double outstandingAmount;
  final DateTime dueDate;
  final bool isOverdue;
  final int overdueDays;
  final String status;
  final DateTime? createdAt;

  /// What the farmer recognises it by: the order it came from, else its own number.
  String get title => orderNumber ?? entryNumber;

  factory DebtEntryListItem.fromJson(Map<String, dynamic> json) => DebtEntryListItem(
        id: asString(json['id']),
        entryNumber: asString(json['entryNumber']),
        sourceType: asString(json['sourceType']),
        orderNumber: asStringOrNull(json['orderNumber']),
        originalAmount: asDouble(json['originalAmount']),
        totalPaid: asDouble(json['totalPaid']),
        outstandingAmount: asDouble(json['outstandingAmount']),
        dueDate: asDateTime(json['dueDate']) ?? DateTime.now().toUtc(),
        isOverdue: asBool(json['isOverdue']),
        overdueDays: asInt(json['overdueDays']),
        status: asString(json['status']),
        createdAt: asDateTime(json['createdAt']),
      );
}

class DebtAction {
  const DebtAction({
    required this.id,
    required this.actionType,
    required this.reason,
    this.adjustmentAmount,
    this.oldDueDate,
    this.newDueDate,
    this.createdAt,
  });

  final String id;
  final String actionType;
  final String reason;
  final double? adjustmentAmount;
  final DateTime? oldDueDate;
  final DateTime? newDueDate;
  final DateTime? createdAt;

  factory DebtAction.fromJson(Map<String, dynamic> json) => DebtAction(
        id: asString(json['id']),
        actionType: asString(json['actionType']),
        reason: asString(json['reason']),
        adjustmentAmount: asDoubleOrNull(json['adjustmentAmount']),
        oldDueDate: asDateTime(json['oldDueDate']),
        newDueDate: asDateTime(json['newDueDate']),
        createdAt: asDateTime(json['createdAt']),
      );
}

/// One line of the debt ledger: how the balance moved.
class DebtTransaction {
  const DebtTransaction({
    required this.id,
    required this.transactionType,
    required this.amountDelta,
    required this.balanceAfter,
    required this.status,
    this.occurredAt,
    this.note,
  });

  final String id;
  final String transactionType;

  /// Positive: the debt grew. Negative: it shrank (a payment, a return, an adjustment down).
  final double amountDelta;
  final double balanceAfter;
  final String status;
  final DateTime? occurredAt;
  final String? note;

  factory DebtTransaction.fromJson(Map<String, dynamic> json) => DebtTransaction(
        id: asString(json['id']),
        transactionType: asString(json['transactionType']),
        amountDelta: asDouble(json['amountDelta']),
        balanceAfter: asDouble(json['balanceAfter']),
        status: asString(json['status']),
        occurredAt: asDateTime(json['occurredAt']),
        note: asStringOrNull(json['note']),
      );
}

/// `GET /api/me/debt-entries/{id}`: an entry with its history.
class DebtEntryDetail {
  const DebtEntryDetail({
    required this.entry,
    required this.fulfillmentValue,
    required this.prepaymentAppliedAmount,
    required this.actions,
    required this.transactions,
    this.orderId,
  });

  final DebtEntryListItem entry;
  final String? orderId;
  final double fulfillmentValue;
  final double prepaymentAppliedAmount;
  final List<DebtAction> actions;
  final List<DebtTransaction> transactions;

  factory DebtEntryDetail.fromJson(Map<String, dynamic> json) => DebtEntryDetail(
        entry: DebtEntryListItem.fromJson(json),
        orderId: asStringOrNull(json['orderId']),
        fulfillmentValue: asDouble(json['fulfillmentValue']),
        prepaymentAppliedAmount: asDouble(json['prepaymentAppliedAmount']),
        actions: asObjectList(json['actions']).map(DebtAction.fromJson).toList(growable: false),
        transactions: asObjectList(json['transactions']).map(DebtTransaction.fromJson).toList(growable: false),
      );
}

class AllocationItem {
  const AllocationItem({
    required this.debtEntryId,
    required this.entryNumber,
    required this.dueDate,
    required this.outstandingAmount,
    required this.allocatedAmount,
  });

  final String debtEntryId;
  final String entryNumber;
  final DateTime dueDate;
  final double outstandingAmount;
  final double allocatedAmount;

  factory AllocationItem.fromJson(Map<String, dynamic> json) => AllocationItem(
        debtEntryId: asString(json['debtEntryId']),
        entryNumber: asString(json['entryNumber']),
        dueDate: asDateTime(json['dueDate']) ?? DateTime.now().toUtc(),
        outstandingAmount: asDouble(json['outstandingAmount']),
        allocatedAmount: asDouble(json['allocatedAmount']),
      );
}

/// Which entries a repayment of `amount` would settle, oldest due date first.
class AllocationPreview {
  const AllocationPreview({required this.amount, required this.allocations, required this.unallocatedAmount});

  final double amount;
  final List<AllocationItem> allocations;
  final double unallocatedAmount;

  factory AllocationPreview.fromJson(Map<String, dynamic> json) => AllocationPreview(
        amount: asDouble(json['amount']),
        allocations: asObjectList(json['allocations']).map(AllocationItem.fromJson).toList(growable: false),
        unallocatedAmount: asDouble(json['unallocatedAmount']),
      );
}

/// The top of the debt screen: the credit line, the debt account and the repayments, read together.
class DebtSummary {
  const DebtSummary({this.credit, this.account, this.repayments = const []});

  /// Null when the farmer has no credit profile (the server answers 404).
  final MyCredit? credit;
  final DebtAccount? account;

  /// The farmer's own debt repayments, newest first.
  final List<PaymentListItem> repayments;

  /// A farmer with neither a credit line nor a debt account has no debt book: the store has not opened one.
  bool get hasDebtBook => credit != null || account != null;

  double get balance => account?.currentBalance ?? credit?.outstandingReceivable ?? 0;
  double get overdueAmount => account?.overdueAmount ?? 0;

  /// What a repayment can be: whole VND only (payOS takes nothing else), up to the whole debt.
  int get maxRepayable => balance.floor();

  double get totalRepaid => repayments.where((p) => p.status == PaymentStatus.paid).fold(0.0, (sum, p) => sum + p.amount);

  /// Days from today (Vietnam) to the nearest due date; negative when it has passed. Null when nothing is due.
  int? daysToDue([DateTime? now]) {
    final due = account?.oldestDueDate;
    if (due == null || balance <= 0) return null;
    final today = vnToday(now);
    final dueDay = DateTime.utc(due.year, due.month, due.day);
    return dueDay.difference(today).inDays;
  }

  /// Nothing overdue, but the nearest due date is within a week.
  bool dueSoon([DateTime? now]) {
    final days = daysToDue(now);
    return overdueAmount == 0 && balance > 0 && days != null && days <= 7;
  }
}

/// The result of reading what the farmer typed as a repayment.
class RepayAmount {
  const RepayAmount.valid(int this.value) : error = null;
  const RepayAmount.invalid(String this.error) : value = null;

  final int? value;
  final String? error;

  bool get isValid => value != null;
}

/// A repayment is a whole number of VND, more than 0 and at most the whole debt.
RepayAmount readRepayAmount(String text, int maxRepayable) {
  final cleaned = text.trim().replaceAll(RegExp(r'[.,\s]'), '');
  if (cleaned.isEmpty) return const RepayAmount.invalid('Vui lòng nhập số tiền');
  final value = int.tryParse(cleaned);
  if (value == null || value <= 0) return const RepayAmount.invalid('Nhập số tiền là số nguyên, lớn hơn 0');
  if (value > maxRepayable) return RepayAmount.invalid('Số tiền không được vượt quá ${formatVnd(maxRepayable)}');
  return RepayAmount.valid(value);
}

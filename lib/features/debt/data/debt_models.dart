import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/json_utils.dart';
import '../../orders/data/order_models.dart';

/// Trạng thái khoản nợ (`DebtEntryStatus` của backend).
abstract class DebtStatus {
  static const open = 'OPEN';
  static const partiallyPaid = 'PARTIALLY_PAID';
  static const paid = 'PAID';
  static const disputed = 'DISPUTED';
  static const adjusted = 'ADJUSTED';
  static const cancelled = 'CANCELLED';

  /// Bộ lọc ở danh sách. `overdue` không phải trạng thái của backend mà là
  /// tham số `overdueOnly`.
  static const overdueFilter = 'OVERDUE';
  static const filters = <String?>[
    null,
    open,
    partiallyPaid,
    overdueFilter,
    disputed,
    paid,
  ];

  static String label(String? s) => switch (s) {
        null => 'Tất cả',
        open => 'Chưa trả',
        partiallyPaid => 'Đã trả một phần',
        paid => 'Đã thanh toán',
        disputed => 'Đang khiếu nại',
        adjusted => 'Đã điều chỉnh',
        cancelled => 'Đã huỷ',
        overdueFilter => 'Quá hạn',
        _ => s,
      };

  /// Khoản nợ đã đóng: không trả thêm, không khiếu nại được nữa.
  static bool isClosed(String s) => s == paid || s == cancelled;

  /// (màu chữ, màu nền)
  static (Color, Color) colors(String s) => switch (s) {
        open => (AppColors.debtNormal, AppColors.primaryLight),
        partiallyPaid => (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
        disputed => (AppColors.debtDue, AppColors.statusWarningSurface),
        paid => (AppColors.debtPaid, const Color(0xFFF1F3F1)),
        cancelled => (AppColors.debtPaid, const Color(0xFFF1F3F1)),
        adjusted => (const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
        _ => (AppColors.textSecondary, AppColors.surfaceSubtle),
      };
}

/// Tài khoản công nợ (`GET /api/me/debt`).
class DebtAccount {
  const DebtAccount({
    required this.status,
    required this.currentBalance,
    required this.overdueAmount,
    required this.openEntryCount,
    this.oldestDueDate,
  });

  final String status;
  final double currentBalance;
  final double overdueAmount;
  final int openEntryCount;
  final DateTime? oldestDueDate;

  bool get hasDebt => currentBalance > 0;
  bool get hasOverdue => overdueAmount > 0;

  factory DebtAccount.fromJson(Map<String, dynamic> json) => DebtAccount(
        status: json['status'] as String? ?? '',
        currentBalance: asDoubleOr0(json['currentBalance']),
        overdueAmount: asDoubleOr0(json['overdueAmount']),
        openEntryCount: asInt(json['openEntryCount']) ?? 0,
        oldestDueDate: asDate(json['oldestDueDate']),
      );
}

/// Dòng trong danh sách khoản nợ (`DebtEntryListItem`).
class DebtEntrySummary {
  const DebtEntrySummary({
    required this.id,
    required this.entryNumber,
    required this.originalAmount,
    required this.totalPaid,
    required this.outstandingAmount,
    required this.dueDate,
    required this.isOverdue,
    required this.overdueDays,
    required this.status,
    required this.createdAt,
    this.orderNumber,
  });

  final String id;
  final String entryNumber;
  final String? orderNumber;
  final double originalAmount;
  final double totalPaid;
  final double outstandingAmount;
  final DateTime dueDate;
  final bool isOverdue;
  final int overdueDays;
  final String status;
  final DateTime createdAt;

  bool get isClosed => DebtStatus.isClosed(status) || outstandingAmount <= 0;

  factory DebtEntrySummary.fromJson(Map<String, dynamic> json) =>
      DebtEntrySummary(
        id: json['id'] as String,
        entryNumber: json['entryNumber'] as String? ?? '',
        orderNumber: json['orderNumber'] as String?,
        originalAmount: asDoubleOr0(json['originalAmount']),
        totalPaid: asDoubleOr0(json['totalPaid']),
        outstandingAmount: asDoubleOr0(json['outstandingAmount']),
        dueDate: asDate(json['dueDate']) ?? DateTime.now(),
        isOverdue: json['isOverdue'] as bool? ?? false,
        overdueDays: asInt(json['overdueDays']) ?? 0,
        status: json['status'] as String? ?? '',
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      );
}

/// Một biến động trong sổ nợ của khoản nợ (`DebtTransactionResponse`).
class DebtTransaction {
  const DebtTransaction({
    required this.type,
    required this.amountDelta,
    required this.balanceAfter,
    required this.occurredAt,
    this.note,
  });

  final String type;

  /// Dương = nợ tăng, âm = nợ giảm (trả tiền, trả hàng...).
  final double amountDelta;
  final double balanceAfter;
  final DateTime occurredAt;
  final String? note;

  static String label(String type) => switch (type) {
        'CREDIT_SALE' => 'Ghi nợ',
        'PAYMENT' => 'Thanh toán',
        'ADJUSTMENT_IN' => 'Điều chỉnh tăng',
        'ADJUSTMENT_OUT' => 'Điều chỉnh giảm',
        'RETURN' => 'Trả hàng',
        'REVERSAL' => 'Đảo bút toán',
        _ => type,
      };

  factory DebtTransaction.fromJson(Map<String, dynamic> json) =>
      DebtTransaction(
        type: json['transactionType'] as String? ?? '',
        amountDelta: asDoubleOr0(json['amountDelta']),
        balanceAfter: asDoubleOr0(json['balanceAfter']),
        occurredAt: asDate(json['occurredAt']) ?? DateTime.now(),
        note: json['note'] as String?,
      );
}

/// Việc đã làm trên khoản nợ (khiếu nại, giữ nguyên, đổi hạn...).
class DebtAction {
  const DebtAction({
    required this.type,
    required this.reason,
    required this.createdAt,
    this.newDueDate,
  });

  final String type;
  final String reason;
  final DateTime createdAt;
  final DateTime? newDueDate;

  static String label(String type) => switch (type) {
        'DISPUTE' => 'Bạn khiếu nại khoản nợ',
        'KEEP' => 'Cửa hàng giữ nguyên số tiền',
        'ADJUST' => 'Cửa hàng điều chỉnh số tiền',
        'CANCEL' => 'Cửa hàng huỷ khoản nợ',
        'CHANGE_DUE_DATE' => 'Cửa hàng đổi hạn trả',
        _ => type,
      };

  factory DebtAction.fromJson(Map<String, dynamic> json) => DebtAction(
        type: json['actionType'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        newDueDate: asDate(json['newDueDate']),
      );
}

/// Một lần trả nợ được phân vào khoản nợ này.
class DebtPaymentRef {
  const DebtPaymentRef({
    required this.paymentNumber,
    required this.method,
    required this.status,
    required this.amount,
    this.allocatedToEntry,
    this.paidAt,
  });

  final String paymentNumber;
  final String method;
  final String status;
  final double amount;

  /// Phần của lần trả này đã trừ vào khoản nợ đang xem.
  final double? allocatedToEntry;
  final DateTime? paidAt;

  factory DebtPaymentRef.fromJson(Map<String, dynamic> json, String entryId) {
    double? allocated;
    for (final a in (json['allocations'] as List? ?? const [])) {
      final m = a as Map<String, dynamic>;
      if (m['debtEntryId'] == entryId) {
        allocated = (allocated ?? 0) + asDoubleOr0(m['allocatedAmount']);
      }
    }
    return DebtPaymentRef(
      paymentNumber: json['paymentNumber'] as String? ?? '',
      method: json['paymentMethod'] as String? ?? '',
      status: json['status'] as String? ?? '',
      amount: asDoubleOr0(json['amount']),
      allocatedToEntry: allocated,
      paidAt: asDate(json['confirmedAt']) ?? asDate(json['initiatedAt']),
    );
  }
}

/// Chi tiết một khoản nợ (`DebtEntryResponse`).
class DebtEntryDetail {
  const DebtEntryDetail({
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
    required this.createdAt,
    required this.orderLines,
    required this.actions,
    required this.transactions,
    required this.payments,
    this.orderId,
    this.orderNumber,
  });

  final String id;
  final String entryNumber;
  final String sourceType;
  final String? orderId;
  final String? orderNumber;
  final double originalAmount;
  final double totalPaid;
  final double outstandingAmount;
  final DateTime dueDate;
  final bool isOverdue;
  final int overdueDays;
  final String status;
  final DateTime createdAt;
  final List<OrderLine> orderLines;
  final List<DebtAction> actions;
  final List<DebtTransaction> transactions;
  final List<DebtPaymentRef> payments;

  bool get isClosed => DebtStatus.isClosed(status) || outstandingAmount <= 0;

  /// Đang khiếu nại hoặc đã đóng thì không khiếu nại thêm được.
  bool get canDispute => !isClosed && status != DebtStatus.disputed;

  static String sourceLabel(String s) => switch (s) {
        'DELIVERY' => 'Giao hàng tận nơi',
        'PICKUP' => 'Nhận tại cửa hàng',
        'MANUAL_ADJUSTMENT' => 'Cửa hàng ghi nhận',
        _ => s,
      };

  factory DebtEntryDetail.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final order = json['order'] as Map<String, dynamic>?;
    return DebtEntryDetail(
      id: id,
      entryNumber: json['entryNumber'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? '',
      orderId: json['orderId'] as String?,
      orderNumber: json['orderNumber'] as String?,
      originalAmount: asDoubleOr0(json['originalAmount']),
      totalPaid: asDoubleOr0(json['totalPaid']),
      outstandingAmount: asDoubleOr0(json['outstandingAmount']),
      dueDate: asDate(json['dueDate']) ?? DateTime.now(),
      isOverdue: json['isOverdue'] as bool? ?? false,
      overdueDays: asInt(json['overdueDays']) ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      orderLines: [
        for (final l in (order?['items'] as List? ?? const []))
          OrderLine.fromJson(l as Map<String, dynamic>),
      ],
      actions: [
        for (final a in (json['actions'] as List? ?? const []))
          DebtAction.fromJson(a as Map<String, dynamic>),
      ],
      transactions: [
        for (final t in (json['transactions'] as List? ?? const []))
          DebtTransaction.fromJson(t as Map<String, dynamic>),
      ],
      payments: [
        for (final p in (json['payments'] as List? ?? const []))
          DebtPaymentRef.fromJson(p as Map<String, dynamic>, id),
      ],
    );
  }
}

/// Một khoản nợ sẽ được trừ khi trả [AllocationPreview.amount].
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

  bool get clearsEntry => allocatedAmount >= outstandingAmount;

  factory AllocationItem.fromJson(Map<String, dynamic> json) => AllocationItem(
        debtEntryId: json['debtEntryId'] as String,
        entryNumber: json['entryNumber'] as String? ?? '',
        dueDate: asDate(json['dueDate']) ?? DateTime.now(),
        outstandingAmount: asDoubleOr0(json['outstandingAmount']),
        allocatedAmount: asDoubleOr0(json['allocatedAmount']),
      );
}

/// Kết quả xem trước phân bổ tiền trả nợ (khoản đến hạn sớm nhất trừ trước).
class AllocationPreview {
  const AllocationPreview({
    required this.amount,
    required this.allocations,
    required this.unallocatedAmount,
  });

  final double amount;
  final List<AllocationItem> allocations;

  /// Phần tiền vượt quá tổng nợ, không được trừ vào đâu.
  final double unallocatedAmount;

  factory AllocationPreview.fromJson(Map<String, dynamic> json) =>
      AllocationPreview(
        amount: asDoubleOr0(json['amount']),
        allocations: [
          for (final a in (json['allocations'] as List? ?? const []))
            AllocationItem.fromJson(a as Map<String, dynamic>),
        ],
        unallocatedAmount: asDoubleOr0(json['unallocatedAmount']),
      );
}

/// Một lần trả nợ trong lịch sử (`PaymentListItem` có ngữ cảnh DEBT_REPAYMENT).
class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.paymentNumber,
    required this.method,
    required this.amount,
    required this.status,
    required this.initiatedAt,
    this.confirmedAt,
  });

  final String id;
  final String paymentNumber;
  final String method;
  final double amount;
  final String status;
  final DateTime initiatedAt;
  final DateTime? confirmedAt;

  DateTime get when => confirmedAt ?? initiatedAt;

  factory DebtPayment.fromJson(Map<String, dynamic> json) => DebtPayment(
        id: json['id'] as String,
        paymentNumber: json['paymentNumber'] as String? ?? '',
        method: json['paymentMethod'] as String? ?? '',
        amount: asDoubleOr0(json['amount']),
        status: json['status'] as String? ?? '',
        initiatedAt: asDate(json['initiatedAt']) ?? DateTime.now(),
        confirmedAt: asDate(json['confirmedAt']),
      );
}

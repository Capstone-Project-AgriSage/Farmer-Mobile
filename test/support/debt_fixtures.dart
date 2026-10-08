// Shapes follow DebtAccountResponse, DebtEntryListItem, DebtEntryResponse and AllocationPreviewResponse (FLOW_3).

Map<String, dynamic> debtAccountJson({
  double balance = 3000000,
  double overdue = 0,
  int open = 2,
  String? oldestDue = '2026-11-20',
}) =>
    {
      'id': 'acc-1',
      'farmerProfileId': 'f-1',
      'status': 'ACTIVE',
      'currentBalance': balance,
      'overdueAmount': overdue,
      'openEntryCount': open,
      'oldestDueDate': oldestDue,
      'lastTransactionAt': '2026-10-07T07:45:00+00:00',
      'version': 3,
    };

Map<String, dynamic> debtEntryRow({
  String id = 'e-1',
  String number = 'DE-20261007-0001',
  String? order = 'OD-20261007-0064',
  String status = 'OPEN',
  double original = 2000000,
  double paid = 500000,
  double outstanding = 1500000,
  String due = '2026-11-20',
  bool overdue = false,
  int overdueDays = 0,
}) =>
    {
      'id': id,
      'entryNumber': number,
      'farmerProfileId': 'f-1',
      'fullName': 'Nông dân E2E 170679',
      'phoneNumber': '0917067932',
      'sourceType': 'DELIVERY',
      'orderNumber': order,
      'originalAmount': original,
      'totalPaid': paid,
      'outstandingAmount': outstanding,
      'dueDate': due,
      'isOverdue': overdue,
      'overdueDays': overdueDays,
      'status': status,
      'createdAt': '2026-10-07T07:45:00+00:00',
    };

Map<String, dynamic> debtEntryDetailJson({String status = 'OPEN', List<Map<String, dynamic>> actions = const []}) => {
      ...debtEntryRow(status: status),
      'orderId': 'o-64',
      'deliveryId': 'd-1',
      'fulfillmentValue': 2000000.0,
      'prepaymentAppliedAmount': 0,
      'actions': actions,
      'transactions': [
        {
          'id': 't-1',
          'transactionType': 'CREDIT_SALE',
          'amountDelta': 2000000.0,
          'balanceBefore': 0,
          'balanceAfter': 2000000.0,
          'occurredAt': '2026-10-07T07:45:00+00:00',
          'status': 'POSTED',
          'note': null,
        },
        {
          'id': 't-2',
          'transactionType': 'PAYMENT',
          'amountDelta': -500000.0,
          'balanceBefore': 2000000.0,
          'balanceAfter': 1500000.0,
          'occurredAt': '2026-10-08T03:00:00+00:00',
          'status': 'POSTED',
          'note': 'Trả qua payOS',
        },
      ],
    };

const disputeActionJson = {
  'id': 'a-1',
  'actionType': 'DISPUTE',
  'reason': 'Số lượng giao chưa đủ',
  'adjustmentAmount': null,
  'oldDueDate': null,
  'newDueDate': null,
  'createdAt': '2026-10-08T04:00:00+00:00',
};

Map<String, dynamic> repaymentJson({String id = 'r-1', String status = 'PAID', double amount = 500000, String method = 'PAYOS'}) => {
      'id': id,
      'paymentNumber': 'PM-$id',
      'paymentContext': 'DEBT_REPAYMENT',
      'paymentMethod': method,
      'amount': amount,
      'status': status,
      'payerName': 'Nông dân E2E 170679',
      'confirmedAt': '2026-10-08T03:00:00+00:00',
      'initiatedAt': '2026-10-08T02:55:00+00:00',
    };

const orderPaymentJson = {
  'id': 'p-order',
  'paymentNumber': 'PM-ORDER',
  'paymentContext': 'ORDER_PAYMENT',
  'paymentMethod': 'PAYOS',
  'amount': 780000.0,
  'status': 'PAID',
  'payerName': 'x',
  'confirmedAt': '2026-10-08T03:00:00+00:00',
  'initiatedAt': '2026-10-08T02:55:00+00:00',
};

Map<String, dynamic> previewJson(int amount) => {
      'amount': amount,
      'allocations': [
        {
          'debtEntryId': 'e-1',
          'entryNumber': 'DE-20261007-0001',
          'dueDate': '2026-11-20',
          'outstandingAmount': 1500000.0,
          'allocatedAmount': amount > 1500000 ? 1500000.0 : amount.toDouble(),
        },
      ],
      'unallocatedAmount': 0,
    };

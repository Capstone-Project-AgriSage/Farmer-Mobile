import 'checkout_fixtures.dart';

// Shapes follow OrderListItem, OrderPaymentSummary and MyDeliveryResponse (FLOW_2 §5-§7).

Map<String, dynamic> orderListRow({
  String id = 'o-1',
  String number = 'OD-20261008-0002',
  String status = 'PENDING_CONFIRMATION',
  String settlement = 'FULL_PAYMENT',
  double total = 1560000,
}) =>
    {
      'id': id,
      'orderNumber': number,
      'source': 'FARMER_MOBILE',
      'customerType': 'REGISTERED',
      'customerName': 'Nông dân E2E 170679',
      'customerPhone': '0917067932',
      'settlementType': settlement,
      'fulfillmentType': 'DELIVERY',
      'status': status,
      'totalAmount': total,
      'itemCount': 1,
      'createdAt': '2026-10-08T09:10:00+00:00',
      'confirmedAt': null,
    };

Map<String, dynamic> orderWith({String status = 'PENDING_CONFIRMATION', String settlement = 'FULL_PAYMENT', String? cancelReason}) =>
    {...orderJson, 'status': status, 'settlementType': settlement, 'cancelReason': cancelReason};

Map<String, dynamic> paymentSummaryJson({double paid = 0, double remaining = 1560000, List<Map<String, dynamic>>? payments, List<Map<String, dynamic>>? refunds}) => {
      'orderId': 'o-1',
      'orderTotal': 1560000.0,
      'paidAmount': paid,
      'availablePrepayment': 0,
      'consumedPrepayment': 0,
      'remainingToPay': remaining,
      'payments': payments ?? [],
      'refunds': refunds ?? [],
    };

const paidPaymentJson = {
  'id': 'pay-1',
  'paymentNumber': 'PM-20261008-0002',
  'paymentContext': 'ORDER_PAYMENT',
  'paymentMethod': 'PAYOS',
  'amount': 780000.0,
  'status': 'PAID',
  'payerName': 'Nông dân E2E 170679',
  'confirmedAt': '2026-10-08T09:30:00+00:00',
  'initiatedAt': '2026-10-08T09:20:00+00:00',
};

const cancelledPaymentJson = {
  'id': 'pay-0',
  'paymentNumber': 'PM-20261008-0001',
  'paymentContext': 'ORDER_PAYMENT',
  'paymentMethod': 'PAYOS',
  'amount': 780000.0,
  'status': 'CANCELLED',
  'payerName': null,
  'confirmedAt': null,
  'initiatedAt': '2026-10-08T09:15:00+00:00',
};

const retryDeliveryJson = {
  'id': 'd-1',
  'deliveryNumber': 'DL-20261008-0001',
  'status': 'RETRY_PENDING',
  'scheduledAt': '2026-10-09T01:00:00+00:00',
  'dispatchedAt': null,
  'completedAt': null,
  'assignedTo': {'fullName': 'Anh Tài Xế', 'phoneNumber': '0987654321'},
  'items': [
    {
      'orderItemId': 'i-1',
      'productName': 'Lúa giống ST25 (bao 25 kg)',
      'packagingName': 'Bao 25 kg',
      'plannedQuantity': 2,
      'deliveredQuantity': 1,
      'remainingQuantity': 1,
    },
  ],
  'attempts': [
    {
      'attemptNumber': 1,
      'status': 'PARTIAL_SUCCESS',
      'startedAt': '2026-10-09T02:00:00+00:00',
      'completedAt': '2026-10-09T02:30:00+00:00',
      'receiverName': 'Chị Hai',
      'proofImageUrl': null,
      'failureReasonCode': null,
    },
    {
      'attemptNumber': 2,
      'status': 'FAILED',
      'startedAt': '2026-10-09T03:00:00+00:00',
      'completedAt': '2026-10-09T03:20:00+00:00',
      'receiverName': null,
      'proofImageUrl': null,
      'failureReasonCode': 'CUSTOMER_ABSENT',
    },
  ],
};

Map<String, dynamic> pageOf(List<Map<String, dynamic>> items, {int page = 1, int pageSize = 20, int? total}) => {
      'items': items,
      'page': page,
      'pageSize': pageSize,
      'totalCount': total ?? items.length,
      'totalPages': 1,
    };

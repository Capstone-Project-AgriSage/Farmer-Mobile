import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';

Map<String, dynamic> orderJson({
  String id = 'o1',
  String number = 'DH-20261012-0001',
  String status = 'PENDING_CONFIRMATION',
  String settlement = 'FULL_PAYMENT',
  String fulfillment = 'DELIVERY',
  double total = 1560000,
  String? note,
  String? cancelReason,
  int? creditTermDays,
  bool withAddress = true,
}) =>
    {
      'id': id,
      'orderNumber': number,
      'source': 'FARMER_MOBILE',
      'customerType': 'REGISTERED',
      'customerName': 'Trần Văn Hải',
      'settlementType': settlement,
      'creditTermDays': creditTermDays,
      'fulfillmentType': fulfillment,
      'deliveryAddress': (fulfillment == 'DELIVERY' && withAddress)
          ? {
              'recipientName': 'Trần Văn Hải',
              'recipientPhone': '0912345678',
              'addressLine': 'Ấp 3',
              'ward': 'Tân Phú',
              'district': 'Cái Răng',
              'province': 'Cần Thơ',
              'latitude': null,
              'longitude': null,
            }
          : null,
      'status': status,
      'subtotalAmount': total,
      'totalAmount': total,
      'note': note,
      'createdAt': '2026-10-12T02:30:00Z',
      'confirmedAt': status == 'PENDING_CONFIRMATION' ? null : '2026-10-12T03:00:00Z',
      'completedAt': status == 'COMPLETED' ? '2026-10-13T03:00:00Z' : null,
      'cancelledAt': status == 'CANCELLED' ? '2026-10-12T04:00:00Z' : null,
      'cancelReason': cancelReason,
      'version': 1,
      'items': [
        {
          'id': 'oi1',
          'storeProductId': 'p1',
          'productPackagingId': 'bao',
          'sku': 'ST25',
          'productName': 'Lúa giống ST25',
          'packagingName': 'Bao 25 kg',
          'quantity': 2,
          'conversionToBase': 25,
          'baseQuantity': 50,
          'suggestedUnitPrice': total / 2,
          'unitPrice': total / 2,
          'lineTotalAmount': total,
          'priceOverridden': false,
          'status': 'OPEN',
        }
      ],
    };

OrderDetail orderOf({
  String id = 'o1',
  String status = 'PENDING_CONFIRMATION',
  String settlement = 'FULL_PAYMENT',
  String fulfillment = 'DELIVERY',
  double total = 1560000,
  String? note,
  String? cancelReason,
  int? creditTermDays,
}) =>
    OrderDetail.fromJson(orderJson(
        id: id,
        number: 'DH-$id',
        status: status,
        settlement: settlement,
        fulfillment: fulfillment,
        total: total,
        note: note,
        cancelReason: cancelReason,
        creditTermDays: creditTermDays));

OrderSummary summaryOf(String id,
        {String status = 'PENDING_CONFIRMATION',
        double total = 1560000,
        String settlement = 'FULL_PAYMENT',
        String fulfillment = 'DELIVERY'}) =>
    OrderSummary(
      id: id,
      orderNumber: 'DH-$id',
      status: status,
      settlementType: settlement,
      fulfillmentType: fulfillment,
      totalAmount: total,
      itemCount: 1,
      createdAt: DateTime.utc(2026, 10, 12, 2, 30),
    );

OrderPayments paymentsOf({
  double total = 1560000,
  double paid = 0,
  List<PaymentItem> items = const [],
  int refunds = 0,
}) =>
    OrderPayments(
      orderTotal: total,
      paidAmount: paid,
      remainingToPay: total - paid < 0 ? 0 : total - paid,
      payments: items,
      refundCount: refunds,
    );

PaymentItem paymentItem(String id,
        {String status = 'PAID', String method = 'PAYOS', double amount = 1560000}) =>
    PaymentItem(
      id: id,
      paymentNumber: 'PM-$id',
      method: method,
      amount: amount,
      status: status,
      initiatedAt: DateTime.utc(2026, 10, 12, 2, 31),
      confirmedAt: status == 'PAID' ? DateTime.utc(2026, 10, 12, 2, 35) : null,
    );

class FakeOrderRepository extends OrderRepository {
  FakeOrderRepository() : super(Dio());

  final List<String> calls = [];
  Map<String, OrderDetail> orders = {};
  Map<String, OrderPayments> paymentsByOrder = {};
  Map<String, List<Delivery>> deliveriesByOrder = {};
  List<OrderSummary> list0 = [];

  Object? checkoutError;
  Object? listError;
  Object? cancelError;
  Future<void>? checkoutGate;
  Future<void>? listGate;
  OrderDetail? nextOrder;
  int pageSize0 = 20;

  ({String settlement, String fulfillment, String? addressId, String? note})? lastCheckout;
  String? lastCancelReason;
  final List<({int page, String? status})> listCalls = [];

  @override
  Future<OrderDetail> checkout({
    required String settlementType,
    required String fulfillmentType,
    String? addressId,
    String? note,
  }) async {
    calls.add('checkout');
    lastCheckout = (
      settlement: settlementType,
      fulfillment: fulfillmentType,
      addressId: addressId,
      note: note
    );
    await checkoutGate;
    if (checkoutError != null) throw checkoutError!;
    final o = nextOrder ??
        orderOf(id: 'new', settlement: settlementType, fulfillment: fulfillmentType);
    orders[o.id] = o;
    paymentsByOrder.putIfAbsent(o.id, () => paymentsOf(total: o.totalAmount));
    return o;
  }

  @override
  Future<PagedResult<OrderSummary>> list({int page = 1, String? status}) async {
    listCalls.add((page: page, status: status));
    await listGate;
    if (listError != null) throw listError!;
    final filtered = list0.where((o) => status == null || o.status == status).toList();
    final items = filtered.skip((page - 1) * pageSize0).take(pageSize0).toList();
    return PagedResult(
      items: items,
      page: page,
      pageSize: pageSize0,
      totalCount: filtered.length,
      totalPages: (filtered.length + pageSize0 - 1) ~/ pageSize0,
    );
  }

  @override
  Future<OrderDetail> get(String id) async {
    calls.add('get:$id');
    final o = orders[id];
    if (o == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound, statusCode: 404, message: 'Không tìm thấy đơn hàng.');
    }
    return o;
  }

  @override
  Future<OrderDetail> cancel(String id, {String? reason}) async {
    calls.add('cancel:$id');
    lastCancelReason = reason;
    if (cancelError != null) throw cancelError!;
    final o = orders[id]!;
    final cancelled = orderOf(
        id: o.id,
        status: OrderStatus.cancelled,
        settlement: o.settlementType,
        fulfillment: o.fulfillmentType,
        total: o.totalAmount,
        cancelReason: (reason == null || reason.trim().isEmpty)
            ? 'Khách huỷ đơn'
            : reason.trim());
    orders[id] = cancelled;
    return cancelled;
  }

  @override
  Future<List<Delivery>> deliveries(String orderId) async {
    calls.add('deliveries:$orderId');
    return deliveriesByOrder[orderId] ?? const [];
  }

  @override
  Future<OrderPayments> payments(String orderId) async {
    calls.add('payments:$orderId');
    return paymentsByOrder[orderId] ?? paymentsOf();
  }
}

class FakePaymentRepository extends PaymentRepository {
  FakePaymentRepository() : super(Dio());

  final List<String> calls = [];
  Object? createError;
  int _seq = 0;

  /// Trạng thái trả về ở lần get/sync tiếp theo, theo thứ tự (hết thì PENDING).
  final List<String> statuses = [];
  Object? getError;
  DateTime? expiresAt;
  String? qrCode = '00020101021238570010A000000727012700069704220113VQRQ00000000208QRIBFTTA53037045405150005802VN62110807PM0000016304ABCD';

  String? lastPaymentId;

  Payment _payment(String id, String status) =>
      Payment(id: id, paymentNumber: 'PM-$id', status: status, amount: 1560000);

  @override
  Future<PayOsLink> createForOrder(String orderId) async {
    calls.add('create:$orderId');
    if (createError != null) throw createError!;
    final id = 'pay${++_seq}';
    lastPaymentId = id;
    return PayOsLink(
      paymentId: id,
      paymentNumber: 'PM-20261012-000$_seq',
      amount: 1560000,
      checkoutUrl: 'https://pay.payos.vn/web/$id',
      qrCode: qrCode,
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 30)),
      status: 'PENDING',
    );
  }

  String _next() => statuses.isEmpty ? PaymentStatus.pending : statuses.removeAt(0);

  @override
  Future<Payment> get(String paymentId) async {
    calls.add('get:$paymentId');
    if (getError != null) throw getError!;
    return _payment(paymentId, _next());
  }

  @override
  Future<Payment> sync(String paymentId) async {
    calls.add('sync:$paymentId');
    if (getError != null) throw getError!;
    return _payment(paymentId, _next());
  }

  @override
  Future<Payment> cancel(String paymentId) async {
    calls.add('cancel:$paymentId');
    return _payment(paymentId, PaymentStatus.cancelled);
  }

  @override
  Future<Payment> simulatePaid(String paymentId) async {
    calls.add('simulate:$paymentId');
    return _payment(paymentId, PaymentStatus.paid);
  }
}

class FakeCreditRepository extends CreditRepository {
  FakeCreditRepository() : super(Dio());

  CreditSummary? credit;
  Object? error;

  @override
  Future<CreditSummary?> mine() async {
    if (error != null) throw error!;
    return credit;
  }
}

CreditSummary creditOf({double available = 5000000, String status = 'ACTIVE', int? term = 30}) =>
    CreditSummary(
      status: status,
      creditLimit: 10000000,
      availableCredit: available,
      outstanding: 10000000 - available,
      paymentTermDays: term,
    );

Delivery deliveryOf(String id,
        {String status = 'OUT_FOR_DELIVERY',
        String? driver = 'Trần Văn B',
        String? phone = '0912000111',
        List<DeliveryAttempt> attempts = const []}) =>
    Delivery(
      id: id,
      deliveryNumber: 'DL-$id',
      status: status,
      dispatchedAt: DateTime.utc(2026, 10, 12, 5),
      driverName: driver,
      driverPhone: phone,
      lines: const [
        DeliveryLine(
            productName: 'Lúa giống ST25',
            packagingName: 'Bao 25 kg',
            planned: 2,
            delivered: 1,
            remaining: 1),
      ],
      attempts: attempts,
    );

Completer<void> gate0() => Completer<void>();

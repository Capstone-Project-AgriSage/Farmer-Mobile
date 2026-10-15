import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/features/returns/data/return_models.dart';
import 'package:farmer_mobile/features/returns/data/return_repository.dart';

/// Phản hồi `GET /api/me/orders/{id}/returnable`. Mặc định: món `oi1`
/// (1 bao = 25 đơn vị nhỏ nhất) đã nhận 50, có thể trả [returnable], chia 2 lô.
Map<String, dynamic> returnableJson({
  String orderId = 'o1',
  int fulfilled = 50,
  int returned = 0,
  int? returnable,
  int conversion = 25,
  List<int>? sourceQty,
  bool pickup = false,
}) {
  final avail = returnable ?? fulfilled - returned;
  final qty = sourceQty ?? [30, 20];
  return {
    'orderId': orderId,
    'orderNumber': 'DH-$orderId',
    'fulfillmentType': pickup ? 'PICKUP' : 'DELIVERY',
    'items': [
      {
        'orderItemId': 'oi1',
        'sku': 'ST25',
        'productName': 'Lúa giống ST25',
        'fulfilledBaseQuantity': fulfilled,
        'alreadyReturnedBaseQuantity': returned,
        'returnableBaseQuantity': avail,
        'unitPrice': 780000,
        'conversionToBase': conversion,
        'sources': [
          for (var i = 0; i < qty.length; i++)
            {
              if (pickup)
                'originalStockMovementItemId': 'mv$i'
              else
                'deliveryItemLotAllocationId': 'al$i',
              'inventoryLotId': 'lot$i',
              'lotNumber': 'L$i',
              'fulfilledBaseQuantity': qty[i],
              'alreadyReturnedBaseQuantity': 0,
              'returnableBaseQuantity': qty[i] < avail ? qty[i] : avail,
              'unitPrice': 780000,
              'conversionToBase': conversion,
              'originalCogsUnitCost': null,
            }
        ],
      },
      {
        'orderItemId': 'oi2',
        'sku': 'NPK',
        'productName': 'Phân NPK',
        'fulfilledBaseQuantity': 10,
        'alreadyReturnedBaseQuantity': 10,
        'returnableBaseQuantity': 0,
        'unitPrice': 500000,
        'conversionToBase': 1,
        'sources': [],
      },
    ],
  };
}

Returnable returnableOf({int fulfilled = 50, int returned = 0, List<int>? sourceQty}) =>
    Returnable.fromJson(returnableJson(fulfilled: fulfilled, returned: returned, sourceQty: sourceQty));

Map<String, dynamic> returnJson(
  String id, {
  String status = 'REQUESTED',
  String orderId = 'o1',
  double total = 780000,
  double debt = 0,
  double refund = 0,
  String? cancelReason,
  String? note,
  String condition = 'PENDING_INSPECTION',
  List<Map<String, dynamic>> refunds = const [],
}) =>
    {
      'id': id,
      'returnNumber': 'TH-$id',
      'orderId': orderId,
      'orderNumber': 'DH-$orderId',
      'status': status,
      'requestedAt': '2026-10-12T02:00:00Z',
      'approvedAt': ['APPROVED', 'RECEIVED', 'INSPECTED', 'COMPLETED'].contains(status)
          ? '2026-10-12T03:00:00Z'
          : null,
      'receivedAt': ['RECEIVED', 'INSPECTED', 'COMPLETED'].contains(status)
          ? '2026-10-13T03:00:00Z'
          : null,
      'inspectedAt':
          ['INSPECTED', 'COMPLETED'].contains(status) ? '2026-10-13T04:00:00Z' : null,
      'completedAt': status == 'COMPLETED' ? '2026-10-14T04:00:00Z' : null,
      'cancelledAt': ['CANCELLED', 'REJECTED'].contains(status) ? '2026-10-12T05:00:00Z' : null,
      'cancelReason': cancelReason,
      'note': note,
      'totalReturnAmount': total,
      'totalDebtAdjustment': debt,
      'totalRefundAmount': refund,
      'items': [
        {
          'id': 'ri1',
          'orderItemId': 'oi1',
          'returnedBaseQuantity': 25,
          'sellingUnitPriceSnapshot': 780000,
          'conversionToBaseSnapshot': 25,
          'returnValue': total,
          'reasonCode': 'DAMAGED_PRODUCT',
          'conditionStatus': condition,
          'inspectionNote': condition == 'PENDING_INSPECTION' ? null : 'Bao rách nhẹ',
        }
      ],
      'refunds': refunds,
    };

ReturnDetail returnOf(String id,
        {String status = 'REQUESTED',
        double total = 780000,
        double debt = 0,
        double refund = 0,
        String? cancelReason,
        String? note,
        String condition = 'PENDING_INSPECTION',
        List<Map<String, dynamic>> refunds = const []}) =>
    ReturnDetail.fromJson(returnJson(id,
        status: status,
        total: total,
        debt: debt,
        refund: refund,
        cancelReason: cancelReason,
        note: note,
        condition: condition,
        refunds: refunds));

ReturnSummary returnSummaryOf(String id, {String status = 'REQUESTED', double total = 780000}) =>
    ReturnSummary(
      id: id,
      returnNumber: 'TH-$id',
      orderId: 'o1',
      orderNumber: 'DH-o1',
      status: status,
      totalReturnAmount: total,
      totalRefundAmount: 0,
      requestedAt: DateTime.utc(2026, 10, 12, 2),
    );

class FakeReturnRepository extends ReturnRepository {
  FakeReturnRepository() : super(Dio());

  final List<String> calls = [];
  Map<String, Returnable> returnables = {};
  Map<String, ReturnDetail> details = {};
  List<ReturnSummary> list0 = [];
  int pageSize0 = 20;

  Object? returnableError;
  Object? createError;
  Object? listError;
  Object? getError;
  Object? cancelError;
  Future<void>? createGate;

  ({String orderId, List<ReturnLineRequest> lines, String? note})? lastCreate;
  ({String id, String reason})? lastCancel;

  @override
  Future<Returnable> returnable(String orderId) async {
    calls.add('returnable:$orderId');
    if (returnableError != null) throw returnableError!;
    final r = returnables[orderId];
    if (r == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound, statusCode: 404, message: 'Không tìm thấy đơn hàng.');
    }
    return r;
  }

  @override
  Future<ReturnDetail> create({
    required String orderId,
    required List<ReturnLineRequest> lines,
    String? note,
  }) async {
    calls.add('create');
    lastCreate = (orderId: orderId, lines: lines, note: note);
    await createGate;
    if (createError != null) throw createError!;
    final d = returnOf('new');
    details['new'] = d;
    return d;
  }

  @override
  Future<PagedResult<ReturnSummary>> list({int page = 1}) async {
    calls.add('list:$page');
    if (listError != null) throw listError!;
    final items = list0.skip((page - 1) * pageSize0).take(pageSize0).toList();
    return PagedResult(
      items: items,
      page: page,
      pageSize: pageSize0,
      totalCount: list0.length,
      totalPages: (list0.length + pageSize0 - 1) ~/ pageSize0,
    );
  }

  @override
  Future<ReturnDetail> get(String id) async {
    calls.add('get:$id');
    if (getError != null) throw getError!;
    final d = details[id];
    if (d == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound,
          statusCode: 404,
          message: 'Không tìm thấy yêu cầu trả hàng.');
    }
    return d;
  }

  @override
  Future<ReturnDetail> cancel(String id, String reason) async {
    calls.add('cancel:$id');
    lastCancel = (id: id, reason: reason.trim());
    if (cancelError != null) throw cancelError!;
    final d = returnOf(id, status: 'CANCELLED', cancelReason: reason.trim());
    details[id] = d;
    return d;
  }
}

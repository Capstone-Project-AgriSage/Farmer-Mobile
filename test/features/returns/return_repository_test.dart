import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/returns/data/return_models.dart';
import 'package:farmer_mobile/features/returns/data/return_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/return_fakes.dart';

void main() {
  late FakeAdapter adapter;
  late ReturnRepository repo;

  void use(FakeHandler h) {
    adapter = FakeAdapter(h);
    repo = ReturnRepository(createApiDio(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      onSessionExpired: () async {},
      adapter: adapter,
    ));
  }

  Matcher failsWith(String part) => throwsA(
      isA<ApiException>().having((e) => e.message, 'message', contains(part)));

  group('hàng có thể trả', () {
    test('đọc món, số lượng nhỏ nhất, quy đổi, các lô', () async {
      use((o) => jsonBody(200, returnableJson()));
      final r = await repo.returnable('o1');

      expect(adapter.requests.single.path, '/api/me/orders/o1/returnable');
      expect(r.orderNumber, 'DH-o1');
      expect(r.items.length, 2);
      expect(r.available.length, 1, reason: 'món đã trả hết bị ẩn');
      final i = r.available.single;
      expect(i.productName, 'Lúa giống ST25');
      expect(i.returnable, 50);
      expect(i.conversion, 25);
      expect(i.maxUnits, 2);
      expect(i.unitPrice, 780000);
      expect(i.sources.length, 2);
      expect(i.sources.first.deliveryItemLotAllocationId, 'al0');
    });

    test('đơn nhận tại cửa hàng: nguồn là dòng phiếu xuất', () async {
      use((o) => jsonBody(200, returnableJson(pickup: true)));
      final s = (await repo.returnable('o1')).available.single.sources.first;
      expect(s.deliveryItemLotAllocationId, isNull);
      expect(s.originalStockMovementItemId, 'mv0');
    });

    test('chỉ còn phần lẻ (< 1 đơn vị bán) → onlyFraction, không chọn được', () async {
      use((o) => jsonBody(200, returnableJson(fulfilled: 50, returned: 40)));
      final i = (await repo.returnable('o1')).available.single;
      expect(i.returnable, 10);
      expect(i.maxUnits, 0);
      expect(i.onlyFraction, isTrue);
    });

    test('404 → thông báo tiếng Việt', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(repo.returnable('x'), failsWith('Không tìm thấy đơn hàng'));
    });
  });

  group('chia số lượng qua các lô', () {
    ReturnSelection pick(int units, {List<int>? sources, String reason = 'DAMAGED_PRODUCT'}) {
      final item = ReturnableItem.fromJson({
        'orderItemId': 'oi1',
        'productName': 'X',
        'fulfilledBaseQuantity': 100,
        'alreadyReturnedBaseQuantity': 0,
        'returnableBaseQuantity': (sources ?? [30, 20]).fold<int>(0, (a, b) => a + b),
        'unitPrice': 1000,
        'conversionToBase': 25,
        'sources': [
          for (var i = 0; i < (sources ?? [30, 20]).length; i++)
            {
              'deliveryItemLotAllocationId': 'al$i',
              'returnableBaseQuantity': (sources ?? [30, 20])[i],
            }
        ],
      });
      return ReturnSelection(item, units, reason);
    }

    test('vừa trong lô đầu → một dòng', () {
      final lines = ReturnLineRequest.allocate(pick(1)); // 25 base
      expect(lines.length, 1);
      expect(lines.single.baseQuantity, 25);
      expect(lines.single.deliveryItemLotAllocationId, 'al0');
    });

    test('vượt lô đầu → tràn sang lô sau, tổng đúng', () {
      final lines = ReturnLineRequest.allocate(pick(2)); // 50 base = 30 + 20
      expect(lines.map((l) => (l.deliveryItemLotAllocationId, l.baseQuantity)),
          [('al0', 30), ('al1', 20)]);
      expect(lines.fold<int>(0, (a, l) => a + l.baseQuantity), 50);
    });

    test('nguồn không đủ → rỗng (không gửi dữ liệu sai)', () {
      expect(ReturnLineRequest.allocate(pick(3, sources: [30, 20])), isEmpty);
    });

    test('bỏ qua lô đã hết hàng', () {
      final lines = ReturnLineRequest.allocate(pick(1, sources: [0, 40]));
      expect(lines.single.deliveryItemLotAllocationId, 'al1');
    });

    test('toJson: đúng MỘT nguồn (lô giao hàng HOẶC dòng phiếu xuất)', () {
      final a = const ReturnLineRequest(
              orderItemId: 'i', baseQuantity: 5, reasonCode: 'OTHER', deliveryItemLotAllocationId: 'al')
          .toJson();
      expect(a.containsKey('originalStockMovementItemId'), isFalse);
      expect(a['deliveryItemLotAllocationId'], 'al');
      final b = const ReturnLineRequest(
              orderItemId: 'i', baseQuantity: 5, reasonCode: 'OTHER', originalStockMovementItemId: 'mv')
          .toJson();
      expect(b.containsKey('deliveryItemLotAllocationId'), isFalse);
      expect(b['originalStockMovementItemId'], 'mv');
      expect(b['returnedBaseQuantity'], 5);
    });

    test('đơn pickup: dòng chia ra dùng originalStockMovementItemId', () {
      final item = ReturnableItem.fromJson(returnableJson(pickup: true)['items'][0] as Map<String, dynamic>);
      final lines = ReturnLineRequest.allocate(ReturnSelection(item, 2, 'OTHER'));
      expect(lines.map((l) => l.originalStockMovementItemId), ['mv0', 'mv1']);
      expect(lines.every((l) => l.deliveryItemLotAllocationId == null), isTrue);
    });
  });

  group('tạo yêu cầu', () {
    const line = ReturnLineRequest(
        orderItemId: 'oi1',
        baseQuantity: 25,
        reasonCode: 'DAMAGED_PRODUCT',
        deliveryItemLotAllocationId: 'al0');

    test('gửi đúng body, ghi chú đã trim', () async {
      use((o) => jsonBody(201, returnJson('r1')));
      final d = await repo.create(orderId: 'o1', lines: [line], note: '  Bao bị rách  ');

      expect(adapter.requests.single.path, '/api/me/returns');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {
        'orderId': 'o1',
        'items': [
          {
            'orderItemId': 'oi1',
            'returnedBaseQuantity': 25,
            'reasonCode': 'DAMAGED_PRODUCT',
            'deliveryItemLotAllocationId': 'al0',
          }
        ],
        'note': 'Bao bị rách',
      });
      expect(d.returnNumber, 'TH-r1');
      expect(d.status, 'REQUESTED');
    });

    test('ghi chú trống thì bỏ khỏi body', () async {
      use((o) => jsonBody(201, returnJson('r1')));
      await repo.create(orderId: 'o1', lines: [line], note: '   ');
      expect((adapter.requests.single.data as Map).containsKey('note'), isFalse);
    });

    test('vượt số lượng (422 exceeds) → thông báo', () async {
      use((o) => jsonBody(422, {
            'status': 422,
            'detail': "The returned quantity exceeds the fulfillment source's remaining quantity."
          }));
      expect(repo.create(orderId: 'o1', lines: [line]), failsWith('vượt quá số lượng có thể trả'));
    });

    test('nguồn không hợp lệ (422 source) → thông báo', () async {
      use((o) => jsonBody(422, {
            'status': 422,
            'detail': 'The fulfillment source does not belong to this fulfilled order item.'
          }));
      expect(repo.create(orderId: 'o1', lines: [line]), failsWith('chưa được giao'));
    });

    test('400 (validate) → nhắc kiểm tra', () async {
      use((o) => jsonBody(400, {'status': 400, 'errors': {'Items': ['x']}}));
      expect(repo.create(orderId: 'o1', lines: [line]), failsWith('chưa hợp lệ'));
    });

    test('đơn không phải của mình (404) → thông báo', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(repo.create(orderId: 'o1', lines: [line]), failsWith('Không tìm thấy đơn hàng'));
    });
  });

  group('danh sách / chi tiết / huỷ', () {
    test('danh sách: phân trang, đọc từng dòng', () async {
      use((o) => jsonBody(200, {
            'items': [
              {
                'id': 'r1',
                'returnNumber': 'TH-1',
                'orderId': 'o1',
                'orderNumber': 'DH-1',
                'status': 'APPROVED',
                'totalReturnAmount': 780000,
                'totalRefundAmount': 0,
                'requestedAt': '2026-10-12T02:00:00Z',
              }
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 45,
            'totalPages': 3,
          }));
      final r = await repo.list(page: 1);
      expect(adapter.requests.single.queryParameters, {'page': 1, 'pageSize': 20});
      expect(r.items.single.status, 'APPROVED');
      expect(r.hasMore, isTrue);
    });

    test('chi tiết: đã kiểm tra + hoàn tiền + trừ công nợ', () async {
      use((o) => jsonBody(
          200,
          returnJson('r1',
              status: 'COMPLETED',
              total: 800000,
              debt: 500000,
              refund: 300000,
              condition: 'RESELLABLE',
              refunds: [
                {
                  'refundNumber': 'HT-1',
                  'refundMethod': 'BANK_TRANSFER',
                  'amount': 300000,
                  'status': 'COMPLETED',
                  'requestedAt': '2026-10-14T03:00:00Z',
                  'completedAt': '2026-10-14T04:00:00Z',
                  'externalReference': 'FT123',
                }
              ])));
      final d = await repo.get('r1');
      expect(adapter.requests.single.path, '/api/me/returns/r1');
      expect(d.totalDebtAdjustment, 500000);
      expect(d.totalRefundAmount, 300000);
      expect(d.items.single.inspected, isTrue);
      expect(d.items.single.condition, 'RESELLABLE');
      expect(d.refunds.single.reference, 'FT123');
      expect(d.canCancel, isFalse);
    });

    test('chi tiết 404', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(repo.get('x'), failsWith('Không tìm thấy yêu cầu trả hàng'));
    });

    test('huỷ: gửi lý do đã trim', () async {
      use((o) => jsonBody(200, returnJson('r1', status: 'CANCELLED', cancelReason: 'Đổi ý')));
      final d = await repo.cancel('r1', '  Đổi ý ');
      expect(adapter.requests.single.path, '/api/me/returns/r1/cancel');
      expect(adapter.requests.single.data, {'reason': 'Đổi ý'});
      expect(d.status, 'CANCELLED');
    });

    test('huỷ khi cửa hàng đã duyệt (422) → thông báo', () async {
      use((o) => jsonBody(422, {
            'status': 422,
            'detail': 'A customer can cancel only a REQUESTED return.'
          }));
      expect(repo.cancel('r1', 'x'), failsWith('đã xử lý yêu cầu'));
    });

    test('huỷ thiếu lý do (400) → nhắc nhập', () async {
      use((o) => jsonBody(400, {'status': 400}));
      expect(repo.cancel('r1', ''), failsWith('lý do huỷ'));
    });
  });

  group('nhãn tiếng Việt', () {
    test('mọi trạng thái / lý do / tình trạng / hoàn tiền đều có nhãn', () {
      for (final s in [
        'REQUESTED', 'APPROVED', 'REJECTED', 'RECEIVED', 'INSPECTED',
        'PARTIALLY_RESOLVED', 'COMPLETED', 'CANCELLED'
      ]) {
        expect(ReturnStatus.label(s), isNot(s), reason: s);
        expect(ReturnStatus.hint(s), isNotEmpty, reason: s);
      }
      for (final r in ReturnReason.all) {
        expect(ReturnReason.label(r), isNot(r), reason: r);
      }
      for (final c in ['PENDING_INSPECTION', 'RESELLABLE', 'DAMAGED', 'EXPIRED', 'UNUSABLE']) {
        expect(conditionLabel(c), isNot(c), reason: c);
      }
      for (final m in ['CASH', 'BANK_TRANSFER', 'OTHER_EXTERNAL']) {
        expect(refundMethodLabel(m), isNot(m), reason: m);
      }
      for (final s in ['PENDING', 'COMPLETED', 'FAILED', 'CANCELLED']) {
        expect(refundStatusLabel(s), isNot(s), reason: s);
      }
    });

    test('formatReturnQty: chia hết thì theo đơn vị bán, không thì nói rõ đơn vị nhỏ nhất', () {
      expect(formatReturnQty(50, 25, 'Bao 25 kg'), '2 Bao 25 kg');
      expect(formatReturnQty(10, 25, 'Bao 25 kg'), '10 (đơn vị nhỏ nhất)');
      expect(formatReturnQty(7, 1, 'Chai'), '7 Chai');
      expect(formatReturnQty(50, 25, null), '2');
    });

    test('chỉ huỷ được khi REQUESTED', () {
      expect(ReturnStatus.canCancel('REQUESTED'), isTrue);
      for (final s in ['APPROVED', 'REJECTED', 'RECEIVED', 'COMPLETED', 'CANCELLED']) {
        expect(ReturnStatus.canCancel(s), isFalse, reason: s);
      }
    });
  });
}

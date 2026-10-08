import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/features/credit/data/credit_models.dart';
import 'package:farmer_mobile/features/credit/data/credit_repository.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/profile/data/address_models.dart';
import 'package:farmer_mobile/features/profile/data/address_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../support/checkout_fixtures.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
    adapter = DioAdapter(dio: dio);
  });

  group('addresses', () {
    test('an address reads from the server answer and joins only the parts that are filled in', () {
      final a = Address.fromJson(addressJson);
      expect(a.isDefault, isTrue);
      expect(a.longitude, 105.7123456);
      expect(a.latitude, isNull);
      expect(a.fullAddress, 'Ấp 2, Thới Lai, Cần Thơ'); // no ward, so no empty comma
      expect(farmAddress.fullAddress, 'Ruộng số 7, Xã Thới Đông, Thới Lai, Cần Thơ');
    });

    test('what is sent is trimmed and a blank ward or district becomes null', () {
      final json = const AddressInput(
        recipientName: ' Anh Ba ',
        recipientPhone: '0912345678',
        addressLine: ' Ruộng 7 ',
        province: ' Cần Thơ ',
        ward: '  ',
        district: 'Thới Lai',
        addressType: AddressType.farm,
        isDefault: true,
      ).toJson();
      expect(json['recipientName'], 'Anh Ba');
      expect(json['addressLine'], 'Ruộng 7');
      expect(json['province'], 'Cần Thơ');
      expect(json['ward'], isNull);
      expect(json['district'], 'Thới Lai');
      expect(json['addressType'], 'FARM');
      expect(json['isDefault'], isTrue);
    });

    test('the repository calls the address endpoints', () async {
      final repo = AddressRepository(dio);
      adapter.onGet('/api/me/addresses', (server) => server.reply(200, [addressJson]));
      adapter.onPost('/api/me/addresses', (server) => server.reply(201, addressJson), data: Matchers.any);
      adapter.onPut('/api/me/addresses/a-home', (server) => server.reply(200, addressJson), data: Matchers.any);
      adapter.onDelete('/api/me/addresses/a-home', (server) => server.reply(204, null));
      adapter.onPost('/api/me/addresses/a-home/set-default', (server) => server.reply(200, addressJson));

      expect((await repo.list()).single.id, 'a-home');
      expect((await repo.create(const AddressInput(recipientName: 'a', recipientPhone: '0912345678', addressLine: 'b', province: 'c'))).id, 'a-home');
      await repo.update('a-home', const AddressInput(recipientName: 'a', recipientPhone: '0912345678', addressLine: 'b', province: 'c'));
      await repo.delete('a-home');
      expect((await repo.setDefault('a-home')).isDefault, isTrue);
    });

    test('a farmer can keep ten addresses', () => expect(Address.maxPerFarmer, 10));
  });

  group('credit', () {
    test('the credit line reads from the server answer', () {
      final c = MyCredit.fromJson({
        'status': 'ACTIVE',
        'creditLimit': 5000000,
        'availableCredit': 1988000.0,
        'outstandingReceivable': 3000000,
        'reservedCredit': 12000,
        'paymentTermDays': 30,
      });
      expect(c.isActive, isTrue);
      expect(c.availableCredit, 1988000);
      expect(c.paymentTermDays, 30);
    });

    test('credit is offered only for an active line with enough room', () {
      expect(creditChoiceFor(null, 100000), CreditChoice.noProfile);
      expect(creditChoiceFor(credit(status: 'SUSPENDED'), 100000), CreditChoice.notActive);
      expect(creditChoiceFor(credit(available: 100000), 100001), CreditChoice.notEnough);
      expect(creditChoiceFor(credit(available: 100000), 100000), CreditChoice.available);
      expect(creditChoiceFor(credit(status: 'active'), 1), CreditChoice.available);
    });

    test('a farmer with no credit profile (404) simply has no credit', () async {
      final repo = CreditRepository(dio);
      adapter.onGet('/api/me/credit', (server) => server.reply(404, {'detail': "Customer credit profile 'x' was not found."}));
      expect(await repo.myCredit(), isNull);
    });

    test('any other failure is reported, not mistaken for "no credit"', () async {
      final repo = CreditRepository(dio);
      adapter.onGet('/api/me/credit', (server) => server.reply(500, {'detail': 'An unexpected error occurred.'}));
      await expectLater(repo.myCredit(), throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.server)));
    });
  });

  group('checkout', () {
    test('the order is sent as a delivery order from the mobile app, with the note only when there is one', () {
      expect(
        const CheckoutInput(settlementType: SettlementType.fullPayment, addressId: 'a-home', note: '  Giao buổi sáng ').toJson(),
        {
          'source': 'FARMER_MOBILE',
          'settlementType': 'FULL_PAYMENT',
          'fulfillmentType': 'DELIVERY',
          'addressId': 'a-home',
          'note': 'Giao buổi sáng',
        },
      );
      expect(
        const CheckoutInput(settlementType: SettlementType.credit, addressId: 'a-home', note: '   ').toJson().containsKey('note'),
        isFalse,
      );
    });

    test('the repository posts the order and reads it back', () async {
      final repo = OrderRepository(dio);
      adapter.onPost(
        '/api/me/orders',
        (server) => server.reply(201, orderJson),
        data: {
          'source': 'FARMER_MOBILE',
          'settlementType': 'FULL_PAYMENT',
          'fulfillmentType': 'DELIVERY',
          'addressId': 'a-home',
          'note': 'Giao buổi sáng',
        },
      );

      final order = await repo.checkout(
        const CheckoutInput(settlementType: SettlementType.fullPayment, addressId: 'a-home', note: 'Giao buổi sáng'),
      );

      expect(order.orderNumber, 'ON-20261008-0001');
      expect(order.status, OrderStatus.pendingConfirmation);
      expect(order.isCredit, isFalse);
      expect(order.totalAmount, 1560000);
      expect(order.items.single.quantity, 2);
      expect(order.deliveryAddress?.fullAddress, 'Ấp 2, Thới Lai, Cần Thơ');
    });

    test('a refused credit order comes back in Vietnamese', () async {
      final repo = OrderRepository(dio);
      adapter.onPost(
        '/api/me/orders',
        (server) => server.reply(422, {'detail': 'Credit refused: OVERDUE_DEBT.'}),
        data: Matchers.any,
      );
      await expectLater(
        repo.checkout(const CheckoutInput(settlementType: SettlementType.credit, addressId: 'a')),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('nợ quá hạn'))),
      );
    });
  });
}

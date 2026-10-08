import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/cart/data/cart_repository.dart';
import 'package:farmer_mobile/features/credit/data/credit_repository.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/orders/screens/order_success_screen.dart';
import 'package:farmer_mobile/features/products/screens/order_confirm_screen.dart';
import 'package:farmer_mobile/features/profile/data/address_models.dart';
import 'package:farmer_mobile/features/profile/data/address_repository.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/cart_fixtures.dart';
import '../../support/checkout_fixtures.dart';
import '../../support/fakes.dart';
import '../cart/cart_controller_test.dart' show MockCartRepository, TestUserId;
import 'checkout_controller_test.dart' show MockOrderRepository;

class MockAddressRepository extends Mock implements AddressRepository {}

class MockCreditRepository extends Mock implements CreditRepository {}

void main() {
  late MockCartRepository carts;
  late MockAddressRepository addresses;
  late MockCreditRepository credits;
  late MockOrderRepository orders;

  setUpAll(() {
    registerFallbackValue(const CheckoutInput(settlementType: SettlementType.fullPayment, addressId: 'x'));
    registerFallbackValue(const AddressInput(recipientName: 'a', recipientPhone: '0912345678', addressLine: 'b', province: 'c'));
  });

  setUp(() {
    carts = MockCartRepository();
    addresses = MockAddressRepository();
    credits = MockCreditRepository();
    orders = MockOrderRepository();
    when(() => carts.get()).thenAnswer((_) async => cartOf([bao25]));
    when(() => addresses.list()).thenAnswer((_) async => [farmAddress, homeAddress]); // server order: default is not first
    when(() => credits.myCredit()).thenAnswer((_) async => credit());
  });

  Future<GoRouter> pumpCheckout(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const OrderConfirmScreen()),
        GoRoute(
          path: AppRoutes.orderSuccess,
          builder: (_, state) => OrderSuccessScreen(order: state.extra as Order?),
        ),
        GoRoute(path: AppRoutes.orderList, builder: (_, __) => const Scaffold(body: Text('ORDER LIST'))),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(carts),
          addressRepositoryProvider.overrideWithValue(addresses),
          creditRepositoryProvider.overrideWithValue(credits),
          orderRepositoryProvider.overrideWithValue(orders),
          sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
          sessionManagerProvider.overrideWithValue(
            SessionManager(store: InMemoryTokenStore())
              ..signIn(
                accessToken: 't',
                expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
                user: const SessionUser(id: 'u1', fullName: 'Nông dân E2E 170679', role: 'FARMER', phoneNumber: '0917067932'),
              ),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tickAgreement(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.byType(Checkbox), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Finder orderButton() => find.widgetWithText(ElevatedButton, 'Đặt hàng');

  testWidgets('shows the default address first, the lines, and both payment choices', (tester) async {
    await pumpCheckout(tester);

    expect(find.text('Nông dân E2E 170679'), findsWidgets);
    expect(find.text('Ấp 2, Thới Lai, Cần Thơ'), findsOneWidget); // the default one, though the server listed it second
    expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
    expect(find.text('Bao 25 kg • SL: 2'), findsOneWidget);
    expect(find.text('Thanh toán qua payOS'), findsOneWidget);
    expect(find.text('Mua hàng ghi nợ'), findsOneWidget);
    expect(find.textContaining('1.988.000'), findsOneWidget); // the real credit left
  });

  testWidgets('the order button waits for the farmer to tick the agreement', (tester) async {
    await pumpCheckout(tester);
    expect(tester.widget<ElevatedButton>(orderButton()).onPressed, isNull);

    await tickAgreement(tester);
    expect(tester.widget<ElevatedButton>(orderButton()).onPressed, isNotNull);
  });

  testWidgets('a payOS order is a FULL_PAYMENT delivery order to the chosen address, with the note', (tester) async {
    when(() => orders.checkout(any())).thenAnswer((_) async => Order.fromJson(orderJson));
    await pumpCheckout(tester);

    await tester.enterText(find.byType(TextField), 'Giao buổi sáng');
    await tickAgreement(tester);
    await tester.tap(orderButton());
    await tester.pumpAndSettle();

    final sent = verify(() => orders.checkout(captureAny())).captured.single as CheckoutInput;
    expect(sent.settlementType, 'FULL_PAYMENT');
    expect(sent.addressId, 'a-home');
    expect(sent.note, 'Giao buổi sáng');
    // It lands on the success screen, which says the order waits for payment.
    expect(find.text('Đã tạo đơn hàng'), findsOneWidget);
    expect(find.text('Mã đơn ON-20261008-0001'), findsOneWidget);
    expect(find.textContaining('chờ thanh toán'), findsOneWidget);
  });

  testWidgets('choosing credit sends a CREDIT order', (tester) async {
    when(() => orders.checkout(any())).thenAnswer((_) async => Order.fromJson({...orderJson, 'settlementType': 'CREDIT'}));
    await pumpCheckout(tester);

    await tester.scrollUntilVisible(find.text('Mua hàng ghi nợ'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Mua hàng ghi nợ'));
    await tester.pump();
    await tickAgreement(tester);
    await tester.tap(orderButton());
    await tester.pumpAndSettle();

    final sent = verify(() => orders.checkout(captureAny())).captured.single as CheckoutInput;
    expect(sent.settlementType, 'CREDIT');
    expect(find.textContaining('chờ cửa hàng xác nhận'), findsOneWidget);
  });

  testWidgets('a farmer with no credit profile cannot pick credit and is told why', (tester) async {
    when(() => credits.myCredit()).thenAnswer((_) async => null);
    await pumpCheckout(tester);

    await tester.scrollUntilVisible(find.text('Mua hàng ghi nợ'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Bác chưa có hạn mức mua ghi nợ ở cửa hàng.'), findsOneWidget);

    await tester.tap(find.text('Mua hàng ghi nợ'));
    await tester.pump();
    await tickAgreement(tester);
    when(() => orders.checkout(any())).thenAnswer((_) async => Order.fromJson(orderJson));
    await tester.tap(orderButton());
    await tester.pumpAndSettle();
    final sent = verify(() => orders.checkout(captureAny())).captured.single as CheckoutInput;
    expect(sent.settlementType, 'FULL_PAYMENT', reason: 'tapping a disabled credit option must not select it');
  });

  testWidgets('credit is blocked when the order is bigger than what is left of the limit', (tester) async {
    when(() => credits.myCredit()).thenAnswer((_) async => credit(available: 1000000));
    await pumpCheckout(tester);

    await tester.scrollUntilVisible(find.text('Mua hàng ghi nợ'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('chưa đủ cho đơn này'), findsOneWidget);
    expect(find.textContaining('1.000.000'), findsOneWidget);
  });

  testWidgets('with no saved address the farmer is asked to add one and cannot order', (tester) async {
    when(() => addresses.list()).thenAnswer((_) async => []);
    await pumpCheckout(tester);

    expect(find.text('Thêm địa chỉ giao hàng'), findsOneWidget);
    await tickAgreement(tester);
    expect(tester.widget<ElevatedButton>(orderButton()).onPressed, isNull);
  });

  testWidgets('adding an address saves it to the book and selects it', (tester) async {
    var saved = false;
    when(() => addresses.list()).thenAnswer((_) async => saved ? [farmAddress] : []);
    when(() => addresses.create(any())).thenAnswer((_) async {
      saved = true;
      return farmAddress;
    });
    await pumpCheckout(tester);

    await tester.tap(find.text('Thêm địa chỉ giao hàng'));
    await tester.pumpAndSettle();
    // The form is pre-filled with the farmer's own name and phone.
    expect(find.text('Nông dân E2E 170679'), findsWidgets);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Anh Ba');
    await tester.enterText(fields.at(1), '0912 345 678');
    await tester.enterText(fields.at(2), 'Ruộng số 7');
    await tester.enterText(fields.at(5), 'Cần Thơ');
    await tester.ensureVisible(find.text('Lưu địa chỉ')); // the sheet scrolls on a small screen
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu địa chỉ'));
    await tester.pumpAndSettle();

    final sent = verify(() => addresses.create(captureAny())).captured.single as AddressInput;
    expect(sent.recipientName, 'Anh Ba');
    expect(sent.recipientPhone, '0912345678'); // separators removed
    expect(sent.province, 'Cần Thơ');
    expect(sent.isDefault, isTrue, reason: 'the first address becomes the default');
    expect(find.text('Ruộng số 7, Xã Thới Đông, Thới Lai, Cần Thơ'), findsOneWidget);
  });

  testWidgets('a wrong phone is caught before anything is sent', (tester) async {
    when(() => addresses.list()).thenAnswer((_) async => []);
    await pumpCheckout(tester);

    await tester.tap(find.text('Thêm địa chỉ giao hàng'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Anh Ba');
    await tester.enterText(fields.at(1), '12345');
    await tester.enterText(fields.at(2), 'Ruộng số 7');
    await tester.enterText(fields.at(5), 'Cần Thơ');
    await tester.ensureVisible(find.text('Lưu địa chỉ')); // the sheet scrolls on a small screen
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu địa chỉ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Số điện thoại chưa hợp lệ'), findsOneWidget);
    verifyNever(() => addresses.create(any()));
  });

  testWidgets('a refused credit order shows the reason and falls back to payOS', (tester) async {
    when(() => orders.checkout(any())).thenThrow(const AppException(
      kind: AppErrorKind.businessRule,
      message: 'Bác đang có nợ quá hạn nên chưa mua ghi nợ được. Bác thanh toán khoản quá hạn hoặc chọn trả bằng payOS.',
      statusCode: 422,
    ));
    await pumpCheckout(tester);

    await tester.scrollUntilVisible(find.text('Mua hàng ghi nợ'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Mua hàng ghi nợ'));
    await tester.pump();
    await tickAgreement(tester);
    await tester.tap(orderButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('nợ quá hạn'), findsOneWidget);
    expect(find.text('Đặt hàng'), findsWidgets); // still on the checkout
    verify(() => credits.myCredit()).called(2); // asked again after the refusal
  });

  testWidgets('a timeout warns about a possible duplicate instead of inviting a retry', (tester) async {
    when(() => orders.checkout(any())).thenThrow(const AppException.timeout());
    final router = await pumpCheckout(tester);

    await tickAgreement(tester);
    await tester.tap(orderButton());
    await tester.pumpAndSettle();

    expect(find.text('Chưa nhận được phản hồi'), findsOneWidget);
    expect(find.textContaining('tránh tạo đơn trùng'), findsOneWidget);
    verify(() => orders.checkout(any())).called(1);

    await tester.tap(find.text('Xem đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ORDER LIST'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.orderList);
  });
}

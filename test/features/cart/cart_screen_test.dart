import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/features/cart/data/cart_models.dart';
import 'package:farmer_mobile/features/cart/data/cart_repository.dart';
import 'package:farmer_mobile/features/products/screens/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/cart_fixtures.dart';
import 'cart_controller_test.dart' show MockCartRepository, TestUserId;

void main() {
  late MockCartRepository repo;

  setUp(() => repo = MockCartRepository());

  Future<void> pumpCart(WidgetTester tester) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartRepositoryProvider.overrideWithValue(repo),
            sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
          ],
          // The real theme matters: it makes buttons full width, which breaks a button inside a Row.
          child: MaterialApp(theme: AppTheme.light, home: const CartScreen()),
        ),
      );

  testWidgets('shows the lines and the subtotal the server calculated', (tester) async {
    when(() => repo.get()).thenAnswer((_) async => cartOf([bao25]));
    await pumpCart(tester);
    await tester.pumpAndSettle();

    expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
    expect(find.text('1.560.000 ₫'), findsWidgets); // line total, summary and bottom bar
    expect(find.text('780.000 ₫ / Bao 25 kg'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Tiếp tục thanh toán'), findsOneWidget);
  });

  testWidgets('an empty cart invites the farmer to keep shopping', (tester) async {
    when(() => repo.get()).thenAnswer((_) async => const Cart.empty());
    await pumpCart(tester);
    await tester.pumpAndSettle();

    expect(find.text('Giỏ hàng đang trống'), findsOneWidget);
    expect(find.text('Tiếp tục mua vật tư'), findsOneWidget);
  });

  testWidgets('a line that cannot be bought shows why and blocks checkout', (tester) async {
    when(() => repo.get()).thenAnswer((_) async => cartOf([bao25, noPriceLine]));
    await pumpCart(tester);
    await tester.pumpAndSettle();

    expect(find.text('Sản phẩm này chưa có giá bán'), findsOneWidget);
    expect(find.textContaining('hãy xóa chúng khỏi giỏ'), findsOneWidget);
    final checkout = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tiếp tục thanh toán'));
    expect(checkout.onPressed, isNull);
  });

  testWidgets('the plus button asks the server for quantity + 1 and shows its answer', (tester) async {
    when(() => repo.get()).thenAnswer((_) async => cartOf([bao25]));
    when(() => repo.updateQuantity('l-bao25', 3)).thenAnswer((_) async => const Cart(
          id: 'cart-1',
          items: [
            CartLine(
              id: 'l-bao25',
              storeProductId: 'p-st25',
              productPackagingId: 'k-bao',
              productName: 'Lúa giống ST25 (bao 25 kg)',
              packagingName: 'Bao 25 kg',
              quantity: 3,
              unitPrice: 780000,
              lineTotalAmount: 2340000,
              isAvailable: true,
            ),
          ],
          subtotalAmount: 2340000,
        ));
    await pumpCart(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    verify(() => repo.updateQuantity('l-bao25', 3)).called(1);
    expect(find.text('2.340.000 ₫'), findsWidgets);
  });

  testWidgets('a failed change shows the message and keeps the cart', (tester) async {
    when(() => repo.get()).thenAnswer((_) async => cartOf([bao25]));
    when(() => repo.updateQuantity(any(), any())).thenThrow(const AppException(
      kind: AppErrorKind.businessRule,
      message: 'Không thực hiện được thao tác này ở trạng thái hiện tại.',
      statusCode: 422,
    ));
    await pumpCart(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Không thực hiện được thao tác này ở trạng thái hiện tại.'), findsOneWidget);
    expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
  });

  testWidgets('removing the last line leaves the empty state', (tester) async {
    when(() => repo.get()).thenAnswer((_) async => cartOf([bao25]));
    when(() => repo.removeItem('l-bao25')).thenAnswer((_) async => const Cart.empty());
    await pumpCart(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Giỏ hàng đang trống'), findsOneWidget);
  });

  testWidgets('clear all asks first, then empties the cart', (tester) async {
    when(() => repo.get()).thenAnswer((_) async => cartOf([bao25]));
    when(() => repo.clear()).thenAnswer((_) async {});
    await pumpCart(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Xóa tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa tất cả sản phẩm?'), findsOneWidget);
    verifyNever(() => repo.clear());

    await tester.tap(find.widgetWithText(TextButton, 'Xóa tất cả'));
    await tester.pumpAndSettle();
    verify(() => repo.clear()).called(1);
    expect(find.text('Giỏ hàng đang trống'), findsOneWidget);
  });

  testWidgets('a failed load shows the error and retries', (tester) async {
    var fail = true;
    when(() => repo.get()).thenAnswer((_) async {
      if (fail) throw const AppException.offline();
      return cartOf([bao25]);
    });
    await pumpCart(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
  });
}

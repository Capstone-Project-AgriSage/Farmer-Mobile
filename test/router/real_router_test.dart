import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/app_harness.dart';
import '../helpers/catalog_fakes.dart';

/// The harness router is flat; the app's real router puts the profile pages inside a ShellRoute. These tests run the
/// REAL router (`appRouterProvider`) so a navigation that only breaks with the shell is caught here, not on a phone.
void main() {
  Future<(AppHarness, GoRouter)> openReal(WidgetTester tester, String location,
      {void Function(AppHarness)? setup, List<String> thenPush = const []}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final h = AppHarness()..signIn();
    h.cart.cart = cartOf([line('a', quantity: 2)]);
    h.profile.addresses = [];
    setup?.call(h);
    addTearDown(h.container.dispose);

    final router = h.container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ));
    await tester.pump();
    router.go(location);
    await tester.pumpAndSettle();
    for (final next in thenPush) {
      router.push(next);
      await tester.pumpAndSettle();
    }
    return (h, router);
  }

  testWidgets('checkout without an address: "Thêm địa chỉ" opens the address form without a navigator error',
      (tester) async {
    // How a farmer gets to the checkout: a tab of the shell is underneath, then the cart, then the checkout.
    final (_, router) = await openReal(tester, '/products', thenPush: ['/cart', '/order-confirm']);
    expect(find.text('Xác nhận đặt hàng'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('address_add_first')));
    await tester.tap(find.byKey(const Key('address_add_first')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('addr_name')), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/profile/addresses/add');
  });

  testWidgets('from the profile: addresses list -> add form still works and returns to the list', (tester) async {
    final (_, router) = await openReal(tester, '/profile', thenPush: ['/profile/addresses']);
    expect(tester.takeException(), isNull);

    final add = find.text('Thêm địa chỉ');
    expect(add, findsWidgets);
    await tester.tap(add.first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('addr_name')), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/profile/addresses/add');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addr_name')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving the new address returns to the checkout with it selected', (tester) async {
    await openReal(tester, '/products', thenPush: ['/cart', '/order-confirm']);
    await tester.ensureVisible(find.byKey(const Key('address_add_first')));
    await tester.tap(find.byKey(const Key('address_add_first')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('addr_name')), 'Nguyễn A');
    await tester.enterText(find.byKey(const Key('addr_phone')), '0912345678');
    await tester.enterText(find.byKey(const Key('addr_province')), 'Cần Thơ');
    await tester.enterText(find.byKey(const Key('addr_line')), 'Số 1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu địa chỉ'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Xác nhận đặt hàng'), findsOneWidget);
    expect(find.text('Nguyễn A · 0912345678'), findsOneWidget);
  });
}

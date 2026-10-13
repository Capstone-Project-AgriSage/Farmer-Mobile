import 'dart:async';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmer_mobile/features/products/screens/order_detail_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/catalog_fakes.dart';
import '../../helpers/order_fakes.dart';
import '../../helpers/profile_fakes.dart';

Future<AppHarness> openCheckout(WidgetTester tester,
    {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  h.cart.cart = cartOf([line('a', quantity: 2)]);
  h.profile.addresses = [
    makeAddress('home', isDefault: true, name: 'Trần Văn Hải', line: 'Ấp 3'),
    makeAddress('farm', name: 'Lê Văn Tư', line: 'Ruộng lô 5', type: 'FARM'),
  ];
  setup?.call(h);
  await h.pump(tester, initial: '/order-confirm');
  await tester.pumpAndSettle();
  return h;
}

Finder get _submit => find.byKey(const Key('checkout_submit'));

bool submitEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_submit).onPressed != null;

Future<void> agree(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('order_agree')));
  await tester.tap(find.byKey(const Key('order_agree')));
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mở màn chỉ tải lại giỏ một lần; có thanh bước Giỏ hàng → Xác nhận → Thanh toán',
      (tester) async {
    final h = await openCheckout(tester);
    // 1 lần khi provider giỏ khởi tạo + 1 lần làm mới khi mở màn (trước đây bị gọi 2 lần).
    expect(h.cart.calls.where((c) => c == 'get').length, lessThanOrEqualTo(2));
    for (final step in ['Giỏ hàng', 'Xác nhận', 'Thanh toán']) {
      expect(find.text(step), findsWidgets, reason: step);
    }
  });

  testWidgets('hiện sản phẩm, tổng tiền từ giỏ, địa chỉ mặc định được chọn sẵn', (tester) async {
    final h = await openCheckout(tester);

    expect(find.text('Lúa giống ST25'), findsOneWidget);
    expect(find.text('Bao 25 kg × 2'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('checkout_total'))).data, '1.560.000đ');
    expect(find.text('Trần Văn Hải · 0912345678'), findsOneWidget);
    // Mở màn luôn tải lại giỏ (giá mới nhất).
    expect(h.cart.calls.where((c) => c == 'get').length, greaterThanOrEqualTo(1));
  });

  testWidgets('phải tick "đã kiểm tra" mới đặt được', (tester) async {
    await openCheckout(tester);
    expect(submitEnabled(tester), isFalse);
    await agree(tester);
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('đổi địa chỉ qua bảng chọn', (tester) async {
    final h = await openCheckout(tester);

    await tapKey(tester, 'address_change');
    expect(find.text('Chọn địa chỉ nhận hàng'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick_farm')));
    await tester.pumpAndSettle();

    expect(find.text('Lê Văn Tư · 0912345678'), findsOneWidget);
    await agree(tester);
    await tester.tap(_submit);
    await tester.pump();
    await tester.pump();
    expect(h.orders.lastCheckout?.addressId, 'farm');
  });

  testWidgets('chưa có địa chỉ: nút Thêm địa chỉ; không đặt được (giao hàng)', (tester) async {
    final h = await openCheckout(tester, setup: (h) => h.profile.addresses = []);

    expect(find.text('Bạn chưa có địa chỉ nhận hàng.'), findsOneWidget);
    await agree(tester);
    expect(submitEnabled(tester), isFalse);

    await tapKey(tester, 'address_add_first');
    expect(find.byKey(const Key('addr_name')), findsOneWidget); // form địa chỉ
    expect(h.profile.addresses, isEmpty);
  });

  testWidgets('thêm địa chỉ mới rồi quay lại: địa chỉ đầu tiên tự được chọn', (tester) async {
    final h = await openCheckout(tester, setup: (h) => h.profile.addresses = []);

    await tapKey(tester, 'address_add_first');
    await tester.enterText(find.byKey(const Key('addr_name')), 'Nguyễn A');
    await tester.enterText(find.byKey(const Key('addr_phone')), '0912345678');
    await tester.enterText(find.byKey(const Key('addr_province')), 'Cần Thơ');
    await tester.enterText(find.byKey(const Key('addr_line')), 'Số 1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu địa chỉ'));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận đặt hàng'), findsOneWidget);
    expect(find.text('Nguyễn A · 0912345678'), findsOneWidget);
    await agree(tester);
    expect(submitEnabled(tester), isTrue);
    expect(h.profile.addresses.single.isDefault, isTrue);
  });

  testWidgets('không có địa chỉ mặc định (đã xoá): bắt chọn trước khi đặt', (tester) async {
    await openCheckout(tester, setup: (h) => h.profile.addresses = [makeAddress('x')]);

    expect(find.byKey(const Key('address_none')), findsOneWidget);
    await agree(tester);
    expect(submitEnabled(tester), isFalse);

    await tapKey(tester, 'address_change');
    await tester.tap(find.byKey(const Key('pick_x')));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('nhận tại cửa hàng: ẩn địa chỉ, không cần địa chỉ, không gửi addressId', (tester) async {
    final h = await openCheckout(tester, setup: (h) => h.profile.addresses = []);

    await tapKey(tester, 'opt_pickup');
    expect(find.text('Địa chỉ nhận hàng'), findsNothing);
    await agree(tester);
    expect(submitEnabled(tester), isTrue);

    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(h.orders.lastCheckout?.fulfillment, 'PICKUP');
    expect(h.orders.lastCheckout?.addressId, isNull);
    // Nhận tại cửa hàng: không tự mở thanh toán (có thể trả tiền mặt).
    expect(h.location, '/orders/new');
  });

  group('mua ghi nợ', () {
    testWidgets('chưa được cấp hạn mức: lựa chọn bị khoá kèm lý do', (tester) async {
      await openCheckout(tester, setup: (h) => h.credit.credit = null);
      expect(find.text('Bạn chưa được cửa hàng cấp hạn mức mua ghi nợ.'), findsOneWidget);
      await tapKey(tester, 'opt_credit');
      // Bấm không có tác dụng: vẫn là trả ngay.
      await agree(tester);
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('hạn mức bị khoá', (tester) async {
      await openCheckout(tester, setup: (h) => h.credit.credit = creditOf(status: 'SUSPENDED'));
      expect(find.text('Hạn mức mua ghi nợ của bạn đang tạm khoá.'), findsOneWidget);
    });

    testWidgets('hạn mức còn lại không đủ cho tổng đơn', (tester) async {
      await openCheckout(tester, setup: (h) => h.credit.credit = creditOf(available: 1000000));
      expect(find.text('Hạn mức còn lại 1.000.000đ không đủ cho đơn này.'), findsOneWidget);
    });

    testWidgets('đủ hạn mức: chọn được, hiện hạn mức và kỳ hạn; đặt gửi CREDIT, không mở thanh toán',
        (tester) async {
      final h = await openCheckout(tester, setup: (h) => h.credit.credit = creditOf());

      expect(find.text('Hạn mức còn lại 5.000.000đ · trả trong 30 ngày.'), findsOneWidget);
      await tapKey(tester, 'opt_credit');
      await agree(tester);
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(h.orders.lastCheckout?.settlement, 'CREDIT');
      expect(h.location, '/orders/new');
      expect(h.payments.calls, isEmpty);
    });

    testWidgets('lỗi kiểm tra hạn mức: khoá ghi nợ, vẫn trả ngay được', (tester) async {
      await openCheckout(tester, setup: (h) => h.credit.error =
          const ApiException(kind: ApiErrorKind.network, message: 'mạng'));
      expect(find.textContaining('Không kiểm tra được hạn mức'), findsOneWidget);
      await agree(tester);
      expect(submitEnabled(tester), isTrue);
    });
  });

  testWidgets('trả ngay + giao hàng: đặt xong mở chi tiết đơn rồi màn thanh toán; giỏ được làm mới',
      (tester) async {
    final h = await openCheckout(tester);
    await tester.enterText(find.byKey(const Key('order_note')), 'Giao buổi sáng');
    await agree(tester);
    await tester.tap(_submit);
    await tester.pump();
    await tester.pump();

    expect(h.orders.lastCheckout?.settlement, 'FULL_PAYMENT');
    expect(h.orders.lastCheckout?.fulfillment, 'DELIVERY');
    expect(h.orders.lastCheckout?.addressId, 'home');
    expect(h.orders.lastCheckout?.note, 'Giao buổi sáng');
    expect(find.byKey(const Key('payos_stub')), findsOneWidget);
    expect(h.payments.calls, contains('create:new'));
    expect(find.text('Đặt hàng thành công: DH-new'), findsOneWidget);
    // Màn thanh toán đè lên chi tiết đơn: quay lại sẽ thấy đơn.
    // Đóng trang thanh toán (quay lại) thì thấy đơn vừa đặt.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailScreen), findsOneWidget);
  });

  testWidgets('đang đặt: nút khoá, bấm đúp chỉ tạo một đơn', (tester) async {
    final gate = Completer<void>();
    final h = await openCheckout(tester, setup: (h) => h.orders.checkoutGate = gate.future);
    await tapKey(tester, 'opt_pickup');
    await agree(tester);

    await tester.tap(_submit);
    await tester.pump();
    expect(submitEnabled(tester), isFalse);
    await tester.tap(_submit, warnIfMissed: false);
    await tester.pump();
    expect(h.orders.calls.where((c) => c == 'checkout'), hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('đặt lỗi (422): hiện lý do, ở lại màn, tải lại giỏ', (tester) async {
    final h = await openCheckout(tester, setup: (h) => h.orders.checkoutError = const ApiException(
        kind: ApiErrorKind.businessRule,
        statusCode: 422,
        message: 'Có sản phẩm trong giỏ không còn đặt được. Vui lòng kiểm tra lại giỏ hàng.'));
    final getsBefore = h.cart.calls.where((c) => c == 'get').length;

    await agree(tester);
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.textContaining('không còn đặt được'), findsOneWidget);
    expect(find.text('Xác nhận đặt hàng'), findsOneWidget);
    expect(h.cart.calls.where((c) => c == 'get').length, greaterThan(getsBefore));
  });

  testWidgets('đặt bị timeout: KHÔNG mời đặt lại, cảnh báo có thể đã tạo đơn, dẫn tới Đơn hàng',
      (tester) async {
    final h = await openCheckout(tester, setup: (h) => h.orders.checkoutError = const ApiException(
        kind: ApiErrorKind.timeout,
        message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.'));

    await agree(tester);
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.text('Chưa nhận được phản hồi'), findsOneWidget);
    expect(find.textContaining('tránh tạo đơn trùng'), findsOneWidget);
    expect(find.textContaining('quá lâu'), findsNothing);
    expect(h.orders.calls.where((c) => c == 'checkout'), hasLength(1));

    await tester.tap(find.byKey(const Key('maybe_created_orders')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.location, '/orders');
  });

  testWidgets('giỏ có dòng không đặt được: cảnh báo, khoá nút Đặt hàng', (tester) async {
    await openCheckout(tester, setup: (h) => h.cart.cart = cartOf([
          line('a'),
          line('b', packagingId: 'k', available: false, reason: 'NO_PRICE'),
        ]));
    await agree(tester);
    expect(find.textContaining('không còn đặt được'), findsOneWidget);
    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('giỏ trống: thông báo + nút xem sản phẩm, không có nút đặt', (tester) async {
    await openCheckout(tester, setup: (h) => h.cart.cart = cartOf([]));
    expect(find.text('Giỏ hàng đang trống, chưa có gì để đặt.'), findsOneWidget);
    expect(_submit, findsNothing);
  });
}

import 'dart:async';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/products/data/catalog_models.dart';
import 'package:farmer_mobile/features/products/screens/product_list_screen.dart';
import 'package:farmer_mobile/shared/widgets/shimmer_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/catalog_fakes.dart';

const _net = ApiException(
    kind: ApiErrorKind.network,
    message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');

Future<AppHarness> open(WidgetTester tester, String route,
    {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  setup?.call(h);
  await h.pump(tester, initial: route);
  await tester.pumpAndSettle();
  return h;
}

/// Vùng cuộn chính của danh sách sản phẩm (bên cạnh thanh danh mục cuộn ngang).
Finder get _mainScroll => find.descendant(
    of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;

int _qty(WidgetTester tester, Finder within) => int.parse(tester
    .widget<Text>(find.descendant(of: within, matching: find.byKey(const Key('qty_value'))))
    .data!);

void main() {
  group('Danh sách sản phẩm', () {
    void seed(AppHarness h, {int n = 5}) {
      h.catalog.all = [
        for (var i = 0; i < n; i++)
          product('p$i',
              name: i == 1 ? 'Phân hữu cơ (chưa có giá)' : 'Phân NPK số $i',
              fromPrice: i == 1 ? null : 100000.0 + i * 1000,
              categoryId: i < 3 ? 'c1' : 'c2',
              categoryName: i < 3 ? 'Phân bón' : 'Thuốc bảo vệ thực vật'),
      ];
    }

    testWidgets('đang tải: khung xương; xong: thẻ sản phẩm, số lượng, giá', (tester) async {
      final h = AppHarness()..signIn();
      seed(h);
      final gate = Completer<void>();
      h.catalog.productsDelay = (_) => gate.future;
      await h.pump(tester, initial: '/products');
      await tester.pump();

      expect(find.byType(ShimmerLoadingWidget), findsWidgets);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerLoadingWidget), findsNothing);
      expect(find.text('5 sản phẩm'), findsOneWidget);
      expect(find.text('Phân NPK số 0'), findsOneWidget);
      expect(find.text('Từ 100.000đ', findRichText: true), findsOneWidget);
      // Sản phẩm chưa có giá hiển thị rõ ràng.
      expect(find.text('Chưa có giá'), findsOneWidget);
    });

    testWidgets('danh mục từ API; chọn danh mục lọc danh sách', (tester) async {
      final h = await open(tester, '/products', setup: seed);

      expect(find.byKey(const Key('category_all')), findsOneWidget);
      expect(find.text('Thuốc bảo vệ thực vật'), findsWidgets);

      await tester.tap(find.byKey(const Key('category_c2')));
      await tester.pumpAndSettle();

      expect(h.catalog.productCalls.last.categoryId, 'c2');
      expect(find.text('2 sản phẩm'), findsOneWidget);
      expect(find.text('Phân NPK số 0'), findsNothing);

      await tester.tap(find.byKey(const Key('category_all')));
      await tester.pumpAndSettle();
      expect(find.text('5 sản phẩm'), findsOneWidget);
    });

    testWidgets('tìm kiếm có debounce: gõ nhiều ký tự chỉ gọi API một lần', (tester) async {
      final h = await open(tester, '/products', setup: seed);
      final before = h.catalog.productCalls.length;

      await tester.enterText(find.byKey(const Key('product_search')), 'N');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('product_search')), 'NP');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('product_search')), 'NPK số 2');
      expect(h.catalog.productCalls.length, before);

      await tester.pump(ProductListScreen.searchDebounce);
      await tester.pumpAndSettle();

      expect(h.catalog.productCalls.length, before + 1);
      expect(h.catalog.productCalls.last.search, 'NPK số 2');
      expect(find.text('1 sản phẩm'), findsOneWidget);
    });

    testWidgets('không có kết quả: thông báo + nút xoá tìm kiếm', (tester) async {
      final h = await open(tester, '/products', setup: seed);

      await tester.enterText(find.byKey(const Key('product_search')), 'xyz');
      await tester.pump(ProductListScreen.searchDebounce);
      await tester.pumpAndSettle();

      expect(find.textContaining('Không tìm thấy sản phẩm phù hợp'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xoá tìm kiếm'));
      await tester.pumpAndSettle();

      expect(find.text('5 sản phẩm'), findsOneWidget);
      expect(h.catalog.productCalls.last.search, '');
    });

    testWidgets('nút X trong ô tìm kiếm xoá ngay, không chờ debounce', (tester) async {
      final h = await open(tester, '/products', setup: seed);
      await tester.enterText(find.byKey(const Key('product_search')), 'số 3');
      await tester.pump(ProductListScreen.searchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('1 sản phẩm'), findsOneWidget);

      await tester.tap(find.byTooltip('Xoá tìm kiếm'));
      await tester.pumpAndSettle();

      expect(find.text('5 sản phẩm'), findsOneWidget);
      expect(h.catalog.productCalls.last.search, '');
    });

    testWidgets('lỗi mạng: thông báo + Thử lại', (tester) async {
      final h = await open(tester, '/products', setup: (h) {
        seed(h);
        h.catalog.productsError = _net;
      });
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);

      h.catalog.productsError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('5 sản phẩm'), findsOneWidget);
    });

    testWidgets('không tải được danh mục: vẫn xem sản phẩm, có chip tải lại', (tester) async {
      final h = await open(tester, '/products', setup: (h) {
        seed(h);
        h.catalog.categoriesError = _net;
      });
      expect(find.text('5 sản phẩm'), findsOneWidget);
      expect(find.byKey(const Key('category_retry')), findsOneWidget);

      h.catalog.categoriesError = null;
      await tester.tap(find.byKey(const Key('category_retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category_c1')), findsOneWidget);
    });

    testWidgets('cuộn tới cuối tự tải trang tiếp; lỗi thì có nút thử lại', (tester) async {
      final h = await open(tester, '/products', setup: (h) => seed(h, n: 25));
      expect(find.text('25 sản phẩm'), findsOneWidget);
      expect(find.text('Phân NPK số 24'), findsNothing); // chỉ có trang 1 (20)

      h.catalog.nextPageError = _net;
      // Cuộn gần cuối → app tự gọi trang 2 (lỗi) → hiện nút thử lại.
      await tester.scrollUntilVisible(find.byKey(const Key('load_more_retry')), 300,
          scrollable: _mainScroll);
      expect(h.catalog.productCalls.where((c) => c.page == 2), hasLength(1));
      expect(find.text('Không tải thêm được. Thử lại'), findsOneWidget);

      h.catalog.nextPageError = null;
      await tester.tap(find.byKey(const Key('load_more_retry')));
      await tester.pumpAndSettle();
      expect(h.catalog.productCalls.where((c) => c.page == 2), hasLength(2));
      await tester.scrollUntilVisible(find.text('Phân NPK số 24'), 300,
          scrollable: _mainScroll);
      expect(find.text('Phân NPK số 24'), findsOneWidget);
      // Đã hết trang: không còn nút tải thêm, không gọi trang 3.
      expect(find.byKey(const Key('load_more')), findsNothing);
      expect(h.catalog.productCalls.where((c) => c.page == 3), isEmpty);
    });

    testWidgets('màn hình dài hơn nội dung: nút "Xem thêm" tải trang tiếp', (tester) async {
      final h = AppHarness()..signIn();
      seed(h, n: 25);
      await h.pump(tester, initial: '/products');
      // Màn rất cao: 20 sản phẩm không lấp đầy nên không cuộn được.
      tester.view.physicalSize = const Size(900, 4000);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('load_more')), findsOneWidget);
      await tester.tap(find.byKey(const Key('load_more')));
      await tester.pumpAndSettle();

      expect(find.text('Phân NPK số 24'), findsOneWidget);
      expect(find.byKey(const Key('load_more')), findsNothing);
    });

    testWidgets('bấm thẻ mở chi tiết đúng sản phẩm', (tester) async {
      final h = await open(tester, '/products', setup: (h) {
        seed(h);
        h.catalog.details['p2'] = ProductDetail.fromJson(detailJson(id: 'p2', name: 'Phân NPK số 2'));
      });

      await tester.tap(find.byKey(const Key('product_p2')));
      await tester.pumpAndSettle();

      expect(h.catalog.detailCalls, ['p2']);
      expect(find.text('Chi tiết sản phẩm'), findsOneWidget);
    });

    testWidgets('badge giỏ hàng hiện số dòng và mở giỏ', (tester) async {
      await open(tester, '/products', setup: (h) {
        seed(h);
        h.cart.cart = cartOf([line('a'), line('b', packagingId: 'kg')]);
      });

      expect(find.descendant(of: find.byKey(const Key('cart_button')), matching: find.text('2')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('cart_button')));
      await tester.pumpAndSettle();
      expect(find.text('Giỏ hàng'), findsOneWidget);
    });
  });

  group('Chi tiết sản phẩm', () {
    void seedDetail(AppHarness h, {Map<String, dynamic>? json}) {
      h.catalog.details['p1'] = ProductDetail.fromJson(json ??
          detailJson(
            ingredients: [
              {'name': 'Difenoconazole', 'concentration': '150 g/L'}
            ],
            brand: 'Syngenta',
          ));
      h.catalog.all = [
        product('p1', categoryId: 'c1'),
        product('p9', name: 'Sản phẩm liên quan A', categoryId: 'c1'),
      ];
    }

    testWidgets('hiện thông tin thật: tên, mã, danh mục, thương hiệu, giá rẻ nhất, mô tả, HDSD, hoạt chất',
        (tester) async {
      await open(tester, '/products/p1', setup: seedDetail);

      expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
      expect(find.text('Mã: SKU-p1'), findsOneWidget);
      expect(find.text('Giống cây trồng'), findsOneWidget);
      expect(find.text('Syngenta'), findsOneWidget);
      // Quy cách rẻ nhất được chọn sẵn: kg 32.000đ.
      expect(find.byKey(const Key('detail_price')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('detail_price'))).data, '32.000đ');
      expect(find.text('Lúa giống xác nhận ST25.'), findsOneWidget);
      expect(find.text('Gieo sạ 80-100 kg/ha.'), findsOneWidget);
      expect(find.text('Difenoconazole'), findsOneWidget);
      expect(find.text('150 g/L'), findsOneWidget);
      // Không còn dữ liệu giả (đánh giá, tồn kho).
      expect(find.textContaining('đánh giá'), findsNothing);
      expect(find.text('Còn hàng'), findsNothing);
    });

    testWidgets('đổi quy cách: giá và quy đổi cập nhật', (tester) async {
      await open(tester, '/products/p1', setup: seedDetail);

      expect(find.byKey(const Key('detail_conversion')), findsNothing); // kg là đơn vị cơ sở
      await tester.tap(find.byKey(const Key('pack_bao')));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('detail_price'))).data, '780.000đ');
      expect(find.text('/ Bao 25 kg'), findsOneWidget);
      expect(find.text('1 Bao 25 kg = 25 kg'), findsOneWidget);
    });

    testWidgets('tạm tính = giá quy cách đang chọn × số lượng', (tester) async {
      await open(tester, '/products/p1', setup: seedDetail);
      String subtotal() =>
          tester.widget<Text>(find.byKey(const Key('detail_subtotal'))).data!;

      expect(subtotal(), '32.000đ');
      await tester.tap(find.byKey(const Key('pack_bao')));
      await tester.pumpAndSettle();
      expect(subtotal(), '780.000đ');
      await tester.tap(find.byKey(const Key('qty_plus')));
      await tester.pumpAndSettle();
      expect(subtotal(), '1.560.000đ');
    });

    testWidgets('chưa có giá: không hiện tạm tính', (tester) async {
      await open(tester, '/products/p1', setup: (h) => seedDetail(h,
          json: detailJson(packagings: [
            {'id': 'kg', 'unitName': 'Kilogram', 'symbol': 'kg', 'conversionToBase': 1, 'isBaseUnit': true, 'price': null},
          ])));
      expect(find.byKey(const Key('detail_subtotal')), findsNothing);
    });

    testWidgets('thêm vào giỏ: gửi đúng quy cách + số lượng, badge tăng, có nút "Xem giỏ"',
        (tester) async {
      final h = await open(tester, '/products/p1', setup: seedDetail);

      await tester.tap(find.byKey(const Key('pack_bao')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('qty_plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('qty_plus')));
      await tester.pump();
      expect(_qty(tester, find.byType(Scaffold).first), 3);

      await tester.tap(find.byKey(const Key('add_to_cart')));
      await tester.pumpAndSettle();

      expect(h.cart.calls, contains('add:p1:bao:3'));
      expect(find.text('Đã thêm 3 Bao 25 kg vào giỏ hàng.'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('cart_button')), matching: find.text('1')),
          findsOneWidget);
      // Số lượng về 1 sau khi thêm.
      expect(_qty(tester, find.byType(Scaffold).first), 1);

      await tester.tap(find.text('Xem giỏ'));
      await tester.pumpAndSettle();
      expect(find.text('Giỏ hàng'), findsOneWidget);
    });

    testWidgets('nút giảm bị khoá ở 1', (tester) async {
      await open(tester, '/products/p1', setup: seedDetail);
      expect(tester.widget<IconButton>(find.byKey(const Key('qty_minus'))).onPressed, isNull);
    });

    testWidgets('đang thêm: nút khoá, bấm đúp chỉ gửi một lần', (tester) async {
      final gate = Completer<void>();
      final h = await open(tester, '/products/p1', setup: (h) {
        seedDetail(h);
        h.cart.gate = gate.future;
      });

      await tester.tap(find.byKey(const Key('add_to_cart')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_to_cart')), warnIfMissed: false);
      await tester.pump();

      expect(h.cart.calls.where((c) => c.startsWith('add')), hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('thêm lỗi (422): báo lỗi, không đổi badge', (tester) async {
      final h = await open(tester, '/products/p1', setup: (h) {
        seedDetail(h);
        h.cart.writeError = const ApiException(
            kind: ApiErrorKind.businessRule,
            statusCode: 422,
            message: 'Sản phẩm hoặc quy cách này hiện không thể đặt mua.');
      });

      await tester.tap(find.byKey(const Key('add_to_cart')));
      await tester.pumpAndSettle();

      expect(find.text('Sản phẩm hoặc quy cách này hiện không thể đặt mua.'), findsOneWidget);
      expect(h.cart.cart.isEmpty, isTrue);
    });

    testWidgets('sản phẩm chưa có giá: không chọn quy cách, nút "Chưa có giá" bị khoá',
        (tester) async {
      final h = await open(tester, '/products/p1', setup: (h) => seedDetail(h,
          json: detailJson(packagings: [
            {'id': 'bao', 'unitName': 'Bao', 'packagingName': 'Bao 20 kg', 'conversionToBase': 20, 'isBaseUnit': false, 'price': null},
            {'id': 'kg', 'unitName': 'Kilogram', 'symbol': 'kg', 'conversionToBase': 1, 'isBaseUnit': true, 'price': null},
          ])));

      expect(find.byKey(const Key('detail_no_price')), findsOneWidget);
      expect(find.textContaining('liên hệ cửa hàng'), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('add_to_cart')));
      expect(btn.onPressed, isNull);
      expect(find.descendant(of: find.byKey(const Key('add_to_cart')), matching: find.text('Chưa có giá')),
          findsOneWidget);
      expect(h.cart.calls.where((c) => c.startsWith('add')), isEmpty);
    });

    testWidgets('sản phẩm liên quan: cùng danh mục, không có chính nó', (tester) async {
      await open(tester, '/products/p1', setup: seedDetail);
      await tester.scrollUntilVisible(find.text('Sản phẩm liên quan A'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Sản phẩm cùng danh mục'), findsOneWidget);
      expect(find.byKey(const Key('product_p1')), findsNothing);
      expect(find.byKey(const Key('product_p9')), findsOneWidget);
    });

    testWidgets('sản phẩm không còn bán (404): thông báo, không có nút thêm', (tester) async {
      await open(tester, '/products/khong-co');
      expect(find.text('Sản phẩm không còn được bán hoặc không tồn tại.'), findsOneWidget);
      expect(find.byKey(const Key('add_to_cart')), findsNothing);
    });

    testWidgets('đang tải: khung xương, chưa có nút thêm; tải xong mới có', (tester) async {
      final h = AppHarness()..signIn();
      seedDetail(h);
      final gate = Completer<void>();
      h.catalog.detailGate = gate.future;
      await h.pump(tester, initial: '/products/p1');
      await tester.pump();
      expect(find.byType(ShimmerLoadingWidget), findsWidgets);
      expect(find.byKey(const Key('add_to_cart')), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add_to_cart')), findsOneWidget);
    });
  });

  group('Giỏ hàng', () {
    Finder lineTile(String id) => find.byKey(Key('cart_line_$id'));
    Finder inLine(String id, Key key) => find.descendant(of: lineTile(id), matching: find.byKey(key));

    testWidgets('mở giỏ luôn tải lại từ server (giá mới nhất)', (tester) async {
      final h = await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([line('a')]));
      expect(h.cart.calls.where((c) => c == 'get').length, greaterThanOrEqualTo(1));
      expect(lineTile('a'), findsOneWidget);
    });

    testWidgets('giỏ trống: thông báo + "Xem sản phẩm" mở danh sách', (tester) async {
      final h = await open(tester, '/cart');
      expect(find.text('Giỏ hàng của bạn đang trống.'), findsOneWidget);
      expect(find.byKey(const Key('cart_checkout')), findsNothing);
      expect(find.byKey(const Key('cart_clear')), findsNothing);

      await tester.tap(find.text('Xem sản phẩm'));
      await tester.pumpAndSettle();
      expect(h.location, '/products');
    });

    testWidgets('hiện dòng: tên, quy cách · đơn giá, thành tiền, tạm tính của server', (tester) async {
      await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([
            line('a', name: 'Lúa ST25', quantity: 2),
            line('b', name: 'Kali', packaging: 'Bao 50 kg', unitPrice: 800000, packagingId: 'k'),
          ]));

      expect(find.text('Lúa ST25'), findsOneWidget);
      expect(find.text('Bao 25 kg · 780.000đ'), findsOneWidget);
      expect(find.text('1.560.000đ'), findsOneWidget);
      expect(find.text('Tạm tính (2 sản phẩm)'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('cart_subtotal'))).data, '2.360.000đ');
    });

    testWidgets('tăng/giảm số lượng gọi PUT với số mới; giảm khoá ở 1', (tester) async {
      final h = await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([line('a', quantity: 1)]));

      expect(tester.widget<IconButton>(inLine('a', const Key('qty_minus'))).onPressed, isNull);
      await tester.tap(inLine('a', const Key('qty_plus')));
      await tester.pumpAndSettle();

      expect(h.cart.calls, contains('set:a:2'));
      expect(_qty(tester, lineTile('a')), 2);
      expect(tester.widget<Text>(find.byKey(const Key('cart_subtotal'))).data, '1.560.000đ');

      await tester.tap(inLine('a', const Key('qty_minus')));
      await tester.pumpAndSettle();
      expect(h.cart.calls, contains('set:a:1'));
    });

    testWidgets('đang cập nhật dòng: khoá nút dòng đó và nút Đặt hàng', (tester) async {
      final gate = Completer<void>();
      final h = await open(tester, '/cart', setup: (h) {
        h.cart.cart = cartOf([line('a')]);
        h.cart.gate = gate.future;
      });

      await tester.tap(inLine('a', const Key('qty_plus')));
      await tester.pump();
      await tester.tap(inLine('a', const Key('qty_plus')), warnIfMissed: false);
      await tester.pump();

      expect(h.cart.calls.where((c) => c.startsWith('set')), hasLength(1));
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('cart_checkout'))).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('cart_checkout'))).onPressed, isNotNull);
    });

    testWidgets('xoá một dòng', (tester) async {
      final h = await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([
            line('a'),
            line('b', packagingId: 'k'),
          ]));

      await tester.tap(find.byKey(const Key('cart_remove_a')));
      await tester.pumpAndSettle();

      expect(h.cart.calls, contains('remove:a'));
      expect(lineTile('a'), findsNothing);
      expect(lineTile('b'), findsOneWidget);
    });

    testWidgets('xoá dòng cuối: về trạng thái giỏ trống', (tester) async {
      await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([line('a')]));
      await tester.tap(find.byKey(const Key('cart_remove_a')));
      await tester.pumpAndSettle();
      expect(find.text('Giỏ hàng của bạn đang trống.'), findsOneWidget);
    });

    testWidgets('dòng không đặt được: lý do, cảnh báo, chặn Đặt hàng; xoá đi thì mở lại', (tester) async {
      await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([
            line('a'),
            line('b', packagingId: 'k', available: false, reason: 'NOT_SELLABLE'),
          ]));

      expect(find.byKey(const Key('cart_unavailable_banner')), findsOneWidget);
      expect(find.text('Sản phẩm ngừng bán'), findsOneWidget);
      expect(tester.widget<IconButton>(inLine('b', const Key('qty_plus'))).onPressed, isNull);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('cart_checkout'))).onPressed, isNull);
      // Dòng không bán được không có giá, không tính vào tạm tính.
      expect(tester.widget<Text>(find.byKey(const Key('cart_subtotal'))).data, '780.000đ');

      await tester.tap(find.byKey(const Key('cart_remove_b')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cart_unavailable_banner')), findsNothing);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('cart_checkout'))).onPressed, isNotNull);
    });

    testWidgets('dòng đã bị xoá ở máy khác (404): báo lỗi và đồng bộ lại', (tester) async {
      final h = await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([
            line('a'),
            line('b', packagingId: 'k'),
          ]));
      h.cart.cart = cartOf([line('a')]);

      await tester.tap(inLine('b', const Key('qty_plus')));
      await tester.pumpAndSettle();

      expect(find.textContaining('không còn trong giỏ'), findsOneWidget);
      expect(lineTile('b'), findsNothing);
    });

    testWidgets('lỗi mạng khi đổi số lượng: báo lỗi, số lượng giữ nguyên', (tester) async {
      final h = await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([line('a', quantity: 2)]));
      h.cart.writeError = _net;

      await tester.tap(inLine('a', const Key('qty_plus')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      expect(_qty(tester, lineTile('a')), 2);
    });

    testWidgets('xoá tất cả: hỏi xác nhận; Huỷ thì giữ, đồng ý thì xoá', (tester) async {
      final h = await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([line('a'), line('b', packagingId: 'k')]));

      await tester.tap(find.byKey(const Key('cart_clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(h.cart.calls.contains('clear'), isFalse);
      expect(lineTile('a'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cart_clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cart_clear_confirm')));
      await tester.pumpAndSettle();

      expect(h.cart.calls, contains('clear'));
      expect(find.text('Giỏ hàng của bạn đang trống.'), findsOneWidget);
      expect(find.text('Đã xoá toàn bộ giỏ hàng.'), findsOneWidget);
    });

    testWidgets('lỗi tải giỏ: Thử lại', (tester) async {
      final h = await open(tester, '/cart', setup: (h) => h.cart.getError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);

      h.cart.getError = null;
      h.cart.cart = cartOf([line('a')]);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(lineTile('a'), findsOneWidget);
    });

    testWidgets('Đặt hàng mở màn xác nhận đơn', (tester) async {
      await open(tester, '/cart', setup: (h) => h.cart.cart = cartOf([line('a')]));
      await tester.tap(find.byKey(const Key('cart_checkout')));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận đặt hàng'), findsOneWidget);
    });
  });

  testWidgets('luồng đầy đủ: danh sách → chi tiết → thêm 2 lần (cộng dồn) → giỏ', (tester) async {
    final h = await open(tester, '/products', setup: (h) {
      h.catalog.all = [product('p1', name: 'Lúa giống ST25')];
      h.catalog.details['p1'] = ProductDetail.fromJson(detailJson());
    });

    await tester.tap(find.byKey(const Key('product_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pack_bao')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add_to_cart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('qty_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add_to_cart')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cart_button')));
    await tester.pumpAndSettle();

    expect(h.cart.cart.lines.single.quantity, 3);
    expect(find.text('Bao 25 kg · 780.000đ'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('cart_subtotal'))).data, '2.340.000đ');
  });
}

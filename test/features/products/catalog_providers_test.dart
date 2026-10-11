import 'dart:async';

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/products/data/catalog_models.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';
import 'package:farmer_mobile/features/products/providers/catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/catalog_fakes.dart';

const _net = ApiException(kind: ApiErrorKind.network, message: 'mạng');

void main() {
  late FakeCatalogRepository catalog;
  late FakeCartRepository cart;
  late ProviderContainer c;

  setUp(() {
    catalog = FakeCatalogRepository();
    cart = FakeCartRepository();
    c = ProviderContainer(overrides: [
      catalogRepositoryProvider.overrideWithValue(catalog),
      cartRepositoryProvider.overrideWithValue(cart),
    ]);
    addTearDown(c.dispose);
  });

  ProductListState s() => c.read(productListProvider);
  ProductListController list() => c.read(productListProvider.notifier);

  /// Đợi lần tải đầu (chạy trong microtask) xong.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('danh sách sản phẩm', () {
    setUp(() {
      catalog.all = [
        for (var i = 0; i < 45; i++)
          product('p$i',
              name: i.isEven ? 'Phân NPK $i' : 'Thuốc trừ sâu $i',
              categoryId: i.isEven ? 'c1' : 'c2'),
      ];
    });

    test('tải trang đầu khi mở', () async {
      s();
      expect(s().isLoading, isTrue);
      await settle();

      expect(s().isLoading, isFalse);
      expect(s().items, hasLength(20));
      expect(s().totalCount, 45);
      expect(s().hasMore, isTrue);
      expect(catalog.productCalls.single.page, 1);
    });

    test('cuộn: tải trang 2, 3 rồi hết; không gọi thêm khi đã hết', () async {
      s();
      await settle();
      await list().loadMore();
      await list().loadMore();

      expect(s().items, hasLength(45));
      expect(s().hasMore, isFalse);
      expect(catalog.productCalls.map((x) => x.page), [1, 2, 3]);

      await list().loadMore();
      expect(catalog.productCalls, hasLength(3));
    });

    test('gọi loadMore dồn dập chỉ tải một trang', () async {
      s();
      await settle();
      await Future.wait([list().loadMore(), list().loadMore(), list().loadMore()]);
      expect(catalog.productCalls.map((x) => x.page), [1, 2]);
    });

    test('lọc danh mục và tìm kiếm gửi đúng tham số, về trang 1', () async {
      s();
      await settle();
      await list().loadMore();

      await list().setCategory('c2');
      expect(s().items.every((p) => p.categoryId == 'c2'), isTrue);
      expect(catalog.productCalls.last, (page: 1, categoryId: 'c2', search: ''));

      await list().setSearch('  sâu 1 ');
      expect(catalog.productCalls.last.search, 'sâu 1');
      expect(catalog.productCalls.last.categoryId, 'c2');
      expect(s().items.every((p) => p.name.contains('sâu 1')), isTrue);

      await list().setCategory(null);
      expect(catalog.productCalls.last.categoryId, isNull);
    });

    test('đặt lại cùng từ khoá / cùng danh mục thì không gọi lại', () async {
      s();
      await settle();
      await list().setSearch('');
      await list().setCategory(null);
      expect(catalog.productCalls, hasLength(1));
    });

    test('phản hồi CŨ đến sau phản hồi mới thì bị bỏ qua (gõ nhanh)', () async {
      s();
      await settle();
      final slow = Completer<void>();
      catalog.productsDelay = (n) => n == 2 ? slow.future : Future.value();

      final first = list().setSearch('Phân'); // gọi lần 2: chậm
      final second = list().setSearch('Thuốc'); // gọi lần 3: nhanh
      await second;
      expect(s().items.every((p) => p.name.startsWith('Thuốc')), isTrue);

      slow.complete();
      await first;
      // Kết quả "Phân" về muộn không được ghi đè.
      expect(s().search, 'Thuốc');
      expect(s().items.every((p) => p.name.startsWith('Thuốc')), isTrue);
    });

    test('lỗi trang đầu → error; refresh thành công thì xoá lỗi', () async {
      catalog.productsError = _net;
      s();
      await settle();
      expect(s().error, isA<ApiException>());
      expect(s().items, isEmpty);

      catalog.productsError = null;
      await list().refresh();
      expect(s().error, isNull);
      expect(s().items, hasLength(20));
    });

    test('lỗi khi tải thêm: giữ danh sách cũ, có loadMoreError, thử lại được', () async {
      s();
      await settle();
      catalog.nextPageError = _net;

      await list().loadMore();
      expect(s().items, hasLength(20));
      expect(s().loadMoreError, isNotNull);
      expect(s().error, isNull);

      catalog.nextPageError = null;
      await list().loadMore();
      expect(s().items, hasLength(40));
      expect(s().loadMoreError, isNull);
    });

    test('bỏ sản phẩm trùng giữa hai trang', () async {
      s();
      await settle();
      // Dữ liệu dịch đi 1 giữa hai lần gọi: phần tử cuối trang 1 xuất hiện lại ở trang 2.
      catalog.all = [product('moi'), ...catalog.all];
      await list().loadMore();
      final ids = s().items.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('giỏ hàng', () {
    void signIn([String id = 'u1']) => c.read(sessionProvider.notifier)
        .setAuthenticated(SessionUser.fromJson({...meJson(), 'id': id}));

    test('chưa đăng nhập: giỏ rỗng, không gọi server', () async {
      final value = await c.read(cartProvider.future);
      expect(value.isEmpty, isTrue);
      expect(cart.calls, isEmpty);
    });

    test('đăng nhập: tải giỏ; thêm cập nhật state và số badge', () async {
      signIn();
      await c.read(cartProvider.future);
      expect(c.read(cartCountProvider), 0);

      await c.read(cartProvider.notifier)
          .add(storeProductId: 'p1', packagingId: 'bao', quantity: 2);

      expect(c.read(cartProvider).value!.lines.single.quantity, 2);
      expect(c.read(cartProvider).value!.subtotal, 1560000);
      expect(c.read(cartCountProvider), 1);
    });

    test('thêm trùng sản phẩm + quy cách thì cộng dồn (1 dòng)', () async {
      signIn();
      await c.read(cartProvider.future);
      final n = c.read(cartProvider.notifier);
      await n.add(storeProductId: 'p1', packagingId: 'bao', quantity: 2);
      await n.add(storeProductId: 'p1', packagingId: 'bao', quantity: 3);
      await n.add(storeProductId: 'p1', packagingId: 'kg', quantity: 1);

      final lines = c.read(cartProvider).value!.lines;
      expect(lines, hasLength(2));
      expect(lines.first.quantity, 5);
    });

    test('dòng đã mất (404): tải lại giỏ rồi báo lỗi', () async {
      signIn();
      cart.cart = cartOf([line('a'), line('b', packagingId: 'kg')]);
      await c.read(cartProvider.future);
      // Ở máy khác đã xoá dòng b.
      cart.cart = cartOf([line('a')]);

      await expectLater(c.read(cartProvider.notifier).setQuantity('b', 3),
          throwsA(isA<ApiException>().having((e) => e.kind, 'k', ApiErrorKind.notFound)));

      expect(c.read(cartProvider).value!.lines.map((l) => l.id), ['a']);
    });

    test('lỗi khác (mạng): GIỮ giỏ cũ, không tải lại', () async {
      signIn();
      cart.cart = cartOf([line('a')]);
      await c.read(cartProvider.future);
      cart.writeError = _net;

      await expectLater(c.read(cartProvider.notifier).remove('a'),
          throwsA(isA<ApiException>()));

      expect(c.read(cartProvider).value!.lines, hasLength(1));
      expect(cart.calls.where((x) => x == 'get'), hasLength(1));
    });

    test('xoá cả giỏ → rỗng', () async {
      signIn();
      cart.cart = cartOf([line('a'), line('b')]);
      await c.read(cartProvider.future);

      await c.read(cartProvider.notifier).clear();

      expect(c.read(cartProvider).value!.isEmpty, isTrue);
      expect(c.read(cartCountProvider), 0);
    });

    test('đổi tài khoản: tải giỏ của người mới; đăng xuất: giỏ rỗng', () async {
      signIn('u1');
      cart.cart = cartOf([line('cua-u1')]);
      expect((await c.read(cartProvider.future)).lines.single.id, 'cua-u1');

      cart.cart = cartOf([line('cua-u2')]);
      signIn('u2');
      expect((await c.read(cartProvider.future)).lines.single.id, 'cua-u2');

      c.read(sessionProvider.notifier).markUnauthenticated();
      expect((await c.read(cartProvider.future)).isEmpty, isTrue);
    });

    test('refresh lỗi → AsyncError; refresh lại thành công', () async {
      signIn();
      await c.read(cartProvider.future);
      cart.getError = _net;
      await c.read(cartProvider.notifier).refresh();
      expect(c.read(cartProvider).hasError, isTrue);

      cart.getError = null;
      cart.cart = cartOf([line('a')]);
      await c.read(cartProvider.notifier).refresh();
      expect(c.read(cartProvider).value!.lines, hasLength(1));
    });
  });

  test('sản phẩm liên quan: cùng danh mục, bỏ chính nó, tối đa 6', () async {
    catalog.all = [for (var i = 0; i < 10; i++) product('p$i', categoryId: 'c1')];
    final related = await c.read(
        relatedProductsProvider((categoryId: 'c1', excludeId: 'p0')).future);
    expect(related, hasLength(6));
    expect(related.any((p) => p.id == 'p0'), isFalse);
    expect(catalog.productCalls.single.categoryId, 'c1');
  });

  test('ProductDetail.purchasable bỏ quy cách không có giá', () {
    final d = ProductDetail.fromJson(detailJson());
    expect(d.purchasable.map((p) => p.id), ['kg', 'bao']);
    expect(d.packagings.firstWhere((p) => p.id == 'bao').conversionToBase, 25);
  });
}

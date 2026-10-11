// Test tích hợp catalog + giỏ hàng với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/catalog_live_test.dart
//
// Phần giỏ hàng TẠO HAI tài khoản nông dân mới ("TEST Mobile Cart <mã>" và
// "... B") trên DB dev dùng chung; giỏ hàng được xoá ở cuối, tài khoản thì không.
@Timeout(Duration(minutes: 10))
library;

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:farmer_mobile/features/products/data/catalog_models.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';
import 'package:farmer_mobile/features/products/providers/catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

Future<ApiException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  fail('Cần ApiException nhưng không có lỗi');
}

void main() {
  late ProviderContainer a;
  late ProviderContainer b;
  late CatalogRepository catalog;
  late CartRepository cartA;
  late CartRepository cartB;

  /// Sản phẩm có ít nhất một quy cách đặt được, và sản phẩm chưa có giá.
  late ProductDetail priced;
  ProductDetail? unpriced;

  Future<ProviderContainer> signUp(String name) async {
    final storage = MemoryTokenStorage();
    final c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWith((ref) => createApiDio(
            baseUrl: liveBaseUrl,
            storage: storage,
            onSessionExpired: () async =>
                ref.read(sessionProvider.notifier).markUnauthenticated(),
            adapter: liveAdapter,
          )),
    ]);
    addTearDown(c.dispose);
    final phone = randomPhone();
    await c.read(authControllerProvider).register(
        fullName: name, phoneNumber: phone, password: 'Test@12345678');
    // ignore: avoid_print
    print('Đã tạo tài khoản test: $name / $phone');
    return c;
  }

  setUpAll(() async {
    if (!liveEnabled) return;
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    a = await signUp('TEST Mobile Cart $code');
    b = await signUp('TEST Mobile Cart $code B');
    catalog = a.read(catalogRepositoryProvider);
    cartA = a.read(cartRepositoryProvider);
    cartB = b.read(cartRepositoryProvider);

    final all = await catalog.products(pageSize: 100);
    final details = [for (final p in all.items) await catalog.product(p.id)];
    priced = details.firstWhere((d) => d.purchasable.isNotEmpty);
    final noPrice = details.where((d) => d.purchasable.isEmpty);
    unpriced = noPrice.isEmpty ? null : noPrice.first;
  });

  group('catalog', skip: !liveEnabled ? 'đặt LIVE_API=1 để chạy' : false, () {
    test('danh mục: có dữ liệu, mỗi nút có id và tên', () async {
      final cats = await catalog.categories();
      expect(cats, isNotEmpty);
      for (final c in cats) {
        expect(c.id, isNotEmpty);
        expect(c.name, isNotEmpty);
      }
    });

    test('phân trang: tổng số đúng, hai trang không trùng nhau', () async {
      final p1 = await catalog.products(page: 1, pageSize: 3);
      final p2 = await catalog.products(page: 2, pageSize: 3);

      expect(p1.items, hasLength(3));
      expect(p1.totalCount, greaterThanOrEqualTo(3));
      expect(p1.totalPages, (p1.totalCount + 2) ~/ 3);
      expect(p1.hasMore, p1.totalCount > 3);
      final ids1 = p1.items.map((p) => p.id).toSet();
      expect(p2.items.where((p) => ids1.contains(p.id)), isEmpty);
    });

    test('lọc danh mục: mọi sản phẩm thuộc danh mục đó', () async {
      final cats = await catalog.categories();
      for (final c in cats) {
        final page = await catalog.products(categoryId: c.id, pageSize: 100);
        final ids = {c.id, for (final child in c.children) child.id};
        expect(page.items.every((p) => ids.contains(p.categoryId)), isTrue,
            reason: c.name);
      }
    });

    test('tìm kiếm theo tên (không phân biệt hoa thường) và theo mã SKU', () async {
      final byName = await catalog.products(search: 'PHÂN', pageSize: 100);
      expect(byName.items, isNotEmpty);
      for (final p in byName.items) {
        expect('${p.name} ${p.sku}'.toLowerCase(), contains('phân'));
      }

      final sku = priced.sku;
      final bySku = await catalog.products(search: sku.toLowerCase());
      expect(bySku.items.map((p) => p.sku), contains(sku));
    });

    test('từ khoá không khớp → rỗng; từ khoá > 100 ký tự không làm lỗi', () async {
      final none = await catalog.products(search: 'khong-co-san-pham-nao-xyz-123');
      expect(none.items, isEmpty);
      expect(none.totalCount, 0);
      final long = await catalog.products(search: 'a' * 150);
      expect(long.items, isEmpty);
    });

    test('giá "từ" ở danh sách = giá thấp nhất đặt được ở chi tiết (mọi sản phẩm)',
        () async {
      final all = await catalog.products(pageSize: 100);
      for (final item in all.items) {
        final d = await catalog.product(item.id);
        final cheapest = d.purchasable.isEmpty ? null : d.purchasable.first.price;
        expect(item.fromPrice, cheapest, reason: item.name);
        expect(d.name, item.name);
        expect(d.categoryId, item.categoryId);
      }
    });

    test('chi tiết: quy cách có tên hiển thị, quy đổi ≥ 1, đúng một đơn vị cơ sở', () async {
      expect(priced.packagings, isNotEmpty);
      expect(priced.packagings.where((p) => p.isBaseUnit), hasLength(1));
      for (final p in priced.packagings) {
        expect(p.label, isNotEmpty);
        expect(p.conversionToBase, greaterThanOrEqualTo(1));
      }
    });

    test('sản phẩm không tồn tại → 404 tiếng Việt', () async {
      final e = await _failure(
          () => catalog.product('00000000-0000-0000-0000-000000000000'));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, contains('không còn được bán'));
    });

    test('catalog gọi được khi CHƯA đăng nhập (không gửi token)', () async {
      final anon = rawLiveDio();
      final res = await anon.get<List<dynamic>>('/api/catalog/categories');
      expect(res.statusCode, 200);
    });
  });

  group('giỏ hàng', skip: !liveEnabled ? 'đặt LIVE_API=1 để chạy' : false, () {
    late Packaging pack;
    late String lineId;

    setUpAll(() => pack = priced.purchasable.first);

    test('tài khoản mới: giỏ rỗng, chưa có id', () async {
      final c = await cartA.get();
      expect(c.isEmpty, isTrue);
      expect(c.id, isNull);
      expect(c.subtotal, 0);
    });

    test('thêm 2: một dòng, có đơn giá, thành tiền = đơn giá × 2', () async {
      final c = await cartA.add(
          storeProductId: priced.id, packagingId: pack.id, quantity: 2);

      expect(c.id, isNotNull);
      final l = c.lines.single;
      lineId = l.id;
      expect(l.storeProductId, priced.id);
      expect(l.productPackagingId, pack.id);
      expect(l.productName, priced.name);
      expect(l.quantity, 2);
      expect(l.isAvailable, isTrue);
      expect(l.unitPrice, isNotNull);
      expect(l.lineTotal, l.unitPrice! * 2);
      expect(c.subtotal, l.lineTotal);
      // Giá giỏ tính theo nhóm khách hàng; ghi lại để so với giá catalog.
      // ignore: avoid_print
      print('giá catalog ${pack.price} – giá trong giỏ ${l.unitPrice}');
    });

    test('thêm lại cùng sản phẩm + quy cách: CỘNG DỒN (vẫn một dòng)', () async {
      final c = await cartA.add(
          storeProductId: priced.id, packagingId: pack.id, quantity: 3);
      expect(c.lines, hasLength(1));
      expect(c.lines.single.quantity, 5);
      expect(c.lines.single.id, lineId);
    });

    test('quy cách khác của cùng sản phẩm: thêm dòng mới', () async {
      if (priced.purchasable.length < 2) {
        markTestSkipped('sản phẩm chỉ có một quy cách đặt được');
        return;
      }
      final other = priced.purchasable[1];
      final c = await cartA.add(
          storeProductId: priced.id, packagingId: other.id, quantity: 1);
      expect(c.lines, hasLength(2));
      expect(c.subtotal, c.lines.fold<double>(0, (s, l) => s + l.lineTotal!));
    });

    test('đổi số lượng: THAY (không cộng); tổng cập nhật', () async {
      final c = await cartA.setQuantity(lineId, 7);
      final l = c.lines.firstWhere((x) => x.id == lineId);
      expect(l.quantity, 7);
      expect(l.lineTotal, l.unitPrice! * 7);
      expect(c.subtotal, c.lines.fold<double>(0, (s, x) => s + x.lineTotal!));
    });

    test('số lượng 0 / âm / quá lớn → 400', () async {
      for (final q in [0, -1]) {
        expect((await _failure(() => cartA.setQuantity(lineId, q))).kind,
            ApiErrorKind.validation, reason: '$q');
      }
      expect(
          (await _failure(() => cartA.add(
                  storeProductId: priced.id,
                  packagingId: pack.id,
                  quantity: 100000001)))
              .kind,
          ApiErrorKind.validation);
    });

    // Tài liệu FE của backend ghi "thêm quy cách chưa có giá → 422", nhưng code
    // thật cho thêm và đánh dấu dòng NO_PRICE. App không cho chọn quy cách chưa
    // có giá; test này giữ hành vi thật và kiểm tra giỏ chặn đặt hàng đúng.
    test('quy cách bán nhưng chưa có giá: vào giỏ dạng NO_PRICE, không tính tiền, chặn đặt hàng',
        () async {
      final u = unpriced;
      if (u == null) {
        markTestSkipped('dữ liệu dev không có sản phẩm chưa có giá');
        return;
      }
      final before = await cartA.get();
      Cart? after;
      for (final p in u.packagings) {
        try {
          after = await cartA.add(storeProductId: u.id, packagingId: p.id, quantity: 1);
          break;
        } on ApiException catch (e) {
          // Đơn vị cơ sở không phải quy cách bán → 422 (đúng), thử quy cách khác.
          expect(e.statusCode, 422);
        }
      }
      if (after == null) {
        markTestSkipped('mọi quy cách của sản phẩm chưa có giá đều không bán');
        return;
      }
      final noPrice = after.lines.firstWhere((l) => l.storeProductId == u.id);
      expect(noPrice.isAvailable, isFalse);
      expect(noPrice.unavailableReason, CartUnavailableReason.noPrice);
      expect(noPrice.unitPrice, isNull);
      expect(noPrice.lineTotal, isNull);
      expect(after.subtotal, before.subtotal, reason: 'dòng không giá không tính tiền');
      expect(after.canCheckout, isFalse);

      final cleaned = await cartA.remove(noPrice.id);
      expect(cleaned.hasUnavailable, isFalse);
    });

    test('quy cách của sản phẩm KHÁC → 422', () async {
      final all = await catalog.products(pageSize: 100);
      final other = all.items.firstWhere((p) => p.id != priced.id);
      final e = await _failure(() => cartA.add(
          storeProductId: other.id, packagingId: pack.id, quantity: 1));
      expect(e.statusCode, 422);
    });

    test('nông dân B không đụng được dòng trong giỏ của A (404)', () async {
      for (final call in <Future<Object?> Function()>[
        () => cartB.setQuantity(lineId, 1),
        () => cartB.remove(lineId),
      ]) {
        expect((await _failure(call)).kind, ApiErrorKind.notFound);
      }
      final aCart = await cartA.get();
      expect(aCart.lines.firstWhere((l) => l.id == lineId).quantity, 7);
      expect((await cartB.get()).isEmpty, isTrue);
    });

    test('xoá một dòng', () async {
      final c = await cartA.remove(lineId);
      expect(c.lines.any((l) => l.id == lineId), isFalse);
    });

    test('xoá dòng đã xoá → 404 tiếng Việt', () async {
      final e = await _failure(() => cartA.remove(lineId));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, contains('không còn trong giỏ'));
    });

    test('xoá cả giỏ → rỗng; xoá khi không có giỏ vẫn OK', () async {
      await cartA.add(storeProductId: priced.id, packagingId: pack.id, quantity: 1);
      await cartA.clear();
      final c = await cartA.get();
      expect(c.isEmpty, isTrue);
      expect(c.id, isNull);
      await cartA.clear();
    });

    test('CartNotifier + badge chạy với API thật', () async {
      await a.read(cartProvider.future);
      final n = a.read(cartProvider.notifier);
      await n.add(storeProductId: priced.id, packagingId: pack.id, quantity: 2);
      expect(a.read(cartCountProvider), 1);
      await n.setQuantity(a.read(cartProvider).value!.lines.single.id, 4);
      expect(a.read(cartProvider).value!.lines.single.quantity, 4);
      await n.clear();
      expect(a.read(cartCountProvider), 0);
      expect((await cartA.get()).isEmpty, isTrue);
    });
  });
}

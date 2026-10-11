import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/features/products/data/catalog_models.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';

CatalogProduct product(String id,
        {String name = 'Sản phẩm',
        String categoryId = 'c1',
        String categoryName = 'Phân bón',
        double? fromPrice = 100000,
        String? imageUrl}) =>
    CatalogProduct(
      id: id,
      sku: 'SKU-$id',
      name: name,
      categoryId: categoryId,
      categoryName: categoryName,
      fromPrice: fromPrice,
      imageUrl: imageUrl,
    );

Map<String, dynamic> detailJson({
  String id = 'p1',
  String name = 'Lúa giống ST25 (bao 25 kg)',
  String categoryId = 'c1',
  List<Map<String, dynamic>>? packagings,
  List<Map<String, dynamic>> ingredients = const [],
  String? description = 'Lúa giống xác nhận ST25.',
  String? usage = 'Gieo sạ 80-100 kg/ha.',
  String? brand,
}) =>
    {
      'id': id,
      'sku': 'SKU-$id',
      'name': name,
      'description': description,
      'usageInstructions': usage,
      'imageUrl': null,
      'categoryId': categoryId,
      'categoryName': 'Giống cây trồng',
      'brandId': null,
      'brandName': brand,
      'packagings': packagings ??
          [
            {
              'id': 'kg',
              'unitName': 'Kilogram',
              'symbol': 'kg',
              'packagingName': null,
              'conversionToBase': 1,
              'isBaseUnit': true,
              'barcode': null,
              'price': 32000.0,
            },
            {
              'id': 'bao',
              'unitName': 'Bao',
              'symbol': 'bao',
              'packagingName': 'Bao 25 kg',
              'conversionToBase': 25,
              'isBaseUnit': false,
              'barcode': null,
              'price': 780000.0,
            },
          ],
      'ingredients': ingredients,
    };

CartLine line(String id,
        {String productId = 'p1',
        String packagingId = 'bao',
        String name = 'Lúa giống ST25',
        String packaging = 'Bao 25 kg',
        int quantity = 1,
        double? unitPrice = 780000,
        bool available = true,
        String? reason}) =>
    CartLine(
      id: id,
      storeProductId: productId,
      productPackagingId: packagingId,
      sku: 'SKU',
      productName: name,
      packagingName: packaging,
      quantity: quantity,
      unitPrice: available ? unitPrice : null,
      lineTotal: available && unitPrice != null ? unitPrice * quantity : null,
      isAvailable: available,
      unavailableReason: reason,
    );

Cart cartOf(List<CartLine> lines) => Cart(
      id: lines.isEmpty ? null : 'cart1',
      lines: lines,
      subtotal: lines.fold(0, (s, l) => s + (l.lineTotal ?? 0)),
    );

/// Catalog giả: lọc/tìm/phân trang trên danh sách trong RAM.
class FakeCatalogRepository extends CatalogRepository {
  FakeCatalogRepository() : super(Dio());

  List<CategoryNode> categoryList = const [
    CategoryNode(id: 'c1', name: 'Phân bón'),
    CategoryNode(id: 'c2', name: 'Thuốc bảo vệ thực vật'),
  ];
  List<CatalogProduct> all = [];
  Map<String, ProductDetail> details = {};

  final List<({int page, String? categoryId, String? search})> productCalls = [];
  final List<String> detailCalls = [];

  Object? categoriesError;
  Object? productsError;

  /// Lỗi chỉ cho trang > 1.
  Object? nextPageError;

  /// Trì hoãn từng lần gọi danh sách (để test phản hồi cũ / trạng thái tải).
  Future<void> Function(int call)? productsDelay;
  Future<void>? detailGate;

  @override
  Future<List<CategoryNode>> categories() async {
    if (categoriesError != null) throw categoriesError!;
    return categoryList;
  }

  @override
  Future<PagedResult<CatalogProduct>> products({
    int page = 1,
    int pageSize = CatalogRepository.pageSize,
    String? categoryId,
    String? search,
  }) async {
    productCalls.add((page: page, categoryId: categoryId, search: search));
    final n = productCalls.length;
    await productsDelay?.call(n);
    if (productsError != null) throw productsError!;
    if (page > 1 && nextPageError != null) throw nextPageError!;
    final term = (search ?? '').trim().toLowerCase();
    final filtered = all
        .where((p) => categoryId == null || p.categoryId == categoryId)
        .where((p) =>
            term.isEmpty ||
            p.name.toLowerCase().contains(term) ||
            p.sku.toLowerCase().contains(term))
        .toList();
    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();
    return PagedResult(
      items: items,
      page: page,
      pageSize: pageSize,
      totalCount: filtered.length,
      totalPages: (filtered.length + pageSize - 1) ~/ pageSize,
    );
  }

  @override
  Future<ProductDetail> product(String id) async {
    detailCalls.add(id);
    await detailGate;
    final d = details[id];
    if (d == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound,
          statusCode: 404,
          message: 'Sản phẩm không còn được bán hoặc không tồn tại.');
    }
    return d;
  }
}

/// Giỏ giả mô phỏng backend: cộng dồn khi thêm trùng, thay khi đổi số lượng.
class FakeCartRepository extends CartRepository {
  FakeCartRepository() : super(Dio());

  Cart cart = Cart.empty;
  final List<String> calls = [];
  Object? getError;
  Object? writeError;
  Future<void>? gate;
  int _seq = 0;

  /// Giá theo (sản phẩm, quy cách) dùng khi thêm.
  Map<String, double> prices = {'p1|bao': 780000, 'p1|kg': 32000};

  Cart _recompute(List<CartLine> lines) => cartOf(lines);

  @override
  Future<Cart> get() async {
    calls.add('get');
    if (getError != null) throw getError!;
    return cart;
  }

  @override
  Future<Cart> add({
    required String storeProductId,
    required String packagingId,
    required int quantity,
  }) async {
    calls.add('add:$storeProductId:$packagingId:$quantity');
    await gate;
    if (writeError != null) throw writeError!;
    final lines = [...cart.lines];
    final i = lines.indexWhere((l) =>
        l.storeProductId == storeProductId &&
        l.productPackagingId == packagingId);
    final price = prices['$storeProductId|$packagingId'];
    if (i >= 0) {
      final old = lines[i];
      lines[i] = line(old.id,
          productId: old.storeProductId,
          packagingId: old.productPackagingId,
          name: old.productName,
          packaging: old.packagingName,
          quantity: old.quantity + quantity,
          unitPrice: price);
    } else {
      lines.add(line('l${++_seq}',
          productId: storeProductId,
          packagingId: packagingId,
          quantity: quantity,
          unitPrice: price));
    }
    return cart = _recompute(lines);
  }

  CartLine _find(String id) {
    final l = cart.lines.where((x) => x.id == id);
    if (l.isEmpty) {
      throw const ApiException(
          kind: ApiErrorKind.notFound,
          statusCode: 404,
          message: 'Sản phẩm này không còn trong giỏ. Giỏ hàng đã được tải lại.');
    }
    return l.first;
  }

  @override
  Future<Cart> setQuantity(String itemId, int quantity) async {
    calls.add('set:$itemId:$quantity');
    await gate;
    if (writeError != null) throw writeError!;
    final old = _find(itemId);
    return cart = _recompute([
      for (final l in cart.lines)
        l.id == itemId
            ? line(old.id,
                productId: old.storeProductId,
                packagingId: old.productPackagingId,
                name: old.productName,
                packaging: old.packagingName,
                quantity: quantity,
                unitPrice: old.unitPrice,
                available: old.isAvailable,
                reason: old.unavailableReason)
            : l,
    ]);
  }

  @override
  Future<Cart> remove(String itemId) async {
    calls.add('remove:$itemId');
    await gate;
    if (writeError != null) throw writeError!;
    _find(itemId);
    return cart = _recompute(cart.lines.where((l) => l.id != itemId).toList());
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    await gate;
    if (writeError != null) throw writeError!;
    cart = Cart.empty;
  }
}

/// Completer tiện cho các test chờ.
Completer<void> gateOpen() => Completer<void>();

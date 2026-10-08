import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../router/app_router.dart';
import '../../cart/providers/cart_providers.dart';
import '../../cart/widgets/cart_icon_button.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../catalog/widgets/product_card.dart';
import '../../catalog/widgets/product_image.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  String? _selectedPackagingId;
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: const [
          CartIconButton(),
          SizedBox(width: 8),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(productDetailProvider(widget.productId)),
        ),
        data: _buildProduct,
      ),
    );
  }

  Widget _buildProduct(CatalogProduct product) {
    final sellable = product.sellablePackagings;
    final selected = sellable.where((p) => p.id == _selectedPackagingId).firstOrNull ?? sellable.firstOrNull;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Container(
                height: 250,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: ProductImage(url: product.imageUrl, fit: BoxFit.contain, iconSize: 80),
              ),

              // Product info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (product.categoryName != null)
                          _Pill(
                            text: product.categoryName!,
                            color: AppColors.primary,
                            background: AppColors.primaryLight,
                          ),
                        product.isSellable
                            ? const _Pill(text: 'Đang bán', color: AppColors.statusSuccess, outlined: true, dot: true)
                            : const _Pill(text: 'Chưa có giá', color: AppColors.statusWarning, outlined: true, dot: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(product.name, style: AppTextStyles.h3),
                    if (product.brandName != null) ...[
                      const SizedBox(height: 4),
                      Text('Thương hiệu: ${product.brandName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                    if (product.ingredientsText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Hoạt chất: ${product.ingredientsText}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 16),
                    _buildPriceBlock(sellable, selected),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),

              // Specs
              _buildSection(
                icon: Icons.tune,
                title: 'Thông số',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: _buildSpecs(product),
                ),
              ),

              if (product.description != null)
                _buildSection(
                  icon: Icons.description_outlined,
                  title: 'Thông tin sản phẩm',
                  child: Text(
                    product.description!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6),
                  ),
                ),

              if (product.usageInstructions != null)
                _buildSection(
                  icon: Icons.menu_book_outlined,
                  title: 'Hướng dẫn sử dụng',
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusWarningSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.statusWarning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bác tham khảo hướng dẫn trên bao bì và khuyến cáo của cửa hàng vật tư nông nghiệp.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.statusWarning.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          product.usageInstructions!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildRelated(product),
              const SizedBox(height: 120), // room for the bottom bar
            ],
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar(product, selected)),
      ],
    );
  }

  Widget _buildPriceBlock(List<CatalogPackaging> sellable, CatalogPackaging? selected) {
    if (selected == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.statusWarningSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Sản phẩm này chưa có giá bán online. Bác vui lòng liên hệ cửa hàng để được báo giá.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusWarning),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatVnd(selected.price!), style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('/ ${selected.label}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Chọn quy cách', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in sellable)
              GestureDetector(
                onTap: () => setState(() => _selectedPackagingId = p.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.id == selected.id ? AppColors.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.id == selected.id ? AppColors.primary : AppColors.borderSubtle,
                      width: p.id == selected.id ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                      Text(formatVnd(p.price!), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Giá theo bảng giá hiện hành của cửa hàng, được tính lại khi Bác đặt hàng.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSpecs(CatalogProduct product) {
    final rows = <(String, String)>[
      if (product.categoryName != null) ('Danh mục', product.categoryName!),
      if (product.brandName != null) ('Thương hiệu', product.brandName!),
      if (product.sku != null) ('Mã SKU', product.sku!),
      if (product.ingredientsText.isNotEmpty) ('Thành phần', product.ingredientsText),
      if (product.packagings.isNotEmpty) ('Quy cách', product.packagings.map((p) => p.label).join(', ')),
    ];
    if (rows.isEmpty) {
      return Text('Chưa có thông số.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted));
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildSpecRow(rows[i].$1, rows[i].$2),
        ],
      ],
    );
  }

  Widget _buildRelated(CatalogProduct product) {
    final related = ref.watch(relatedProductsProvider((categoryId: product.categoryId, excludeId: product.id)));
    final items = related.valueOrNull ?? const <CatalogProductListItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('Sản phẩm liên quan', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 240,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: 160,
              child: ProductCard(
                product: items[i],
                radius: 12,
                onTap: () => context.push('/products/${items[i].id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(CatalogProduct product, CatalogPackaging? selected) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Quantity selector
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => setState(() {
                    if (_quantity > 1) _quantity--;
                  }),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                SizedBox(
                  width: 30,
                  child: Text('$_quantity', textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => setState(() => _quantity++),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Add to cart
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (selected == null || _adding) ? null : () => _addToCart(product, selected),
              icon: _adding
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
              label: Text(
                selected == null ? 'Chưa có giá' : 'Thêm vào giỏ',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.borderStrong,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(CatalogProduct product, CatalogPackaging packaging) async {
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(cartProvider.notifier).add(
            storeProductId: product.id,
            productPackagingId: packaging.id,
            quantity: _quantity,
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Đã thêm vào giỏ hàng'),
            action: SnackBarAction(
              label: 'Xem giỏ',
              onPressed: () {
                if (mounted) context.push(AppRoutes.cart);
              },
            ),
          ),
        );
    } on AppException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _buildSection({required IconData icon, required String title, required Widget child, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.background, this.outlined = false, this.dot = false});

  final String text;
  final Color color;
  final Color? background;
  final bool outlined;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.white : background,
        border: outlined ? Border.all(color: color) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[Icon(Icons.circle, size: 8, color: color), const SizedBox(width: 4)],
          Text(text, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

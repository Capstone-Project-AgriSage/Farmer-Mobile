import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A product photo with a quiet placeholder while it loads and when the product has no photo (or it fails to load).
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover, this.iconSize = 48});

  final String? url;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Icon(Icons.inventory_2_outlined, size: iconSize, color: AppColors.borderStrong),
    );
    final address = url;
    if (address == null || address.isEmpty) return placeholder;

    return CachedNetworkImage(
      imageUrl: address,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../router/app_router.dart';
import '../providers/cart_providers.dart';

/// The cart icon for an app bar, with the number of cart lines on it.
class CartIconButton extends ConsumerWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartBadgeCountProvider);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Giỏ hàng',
          icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
          onPressed: () => context.push(AppRoutes.cart),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(color: AppColors.statusError, shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(9))),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

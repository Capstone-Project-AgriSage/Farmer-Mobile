import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../cart/providers/cart_providers.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';

/// Places the order. The state is the result of the last attempt: loading while the request is out, the order when it
/// worked, the [AppException] when it did not.
///
/// One request, never retried by the app: if it times out the order may still have been created, so the farmer is
/// told to look in "Đơn hàng" instead of being offered a second attempt that could duplicate it.
class CheckoutController extends AsyncNotifier<Order?> {
  @override
  FutureOr<Order?> build() => null;

  /// The created order, or null when it failed (the reason is in [state]).
  Future<Order?> place(CheckoutInput input) async {
    if (state.isLoading) return null; // a double tap must not send the order twice
    state = const AsyncLoading();
    try {
      final order = await ref.read(orderRepositoryProvider).checkout(input);
      // The server emptied the cart as part of creating the order: show that without another call.
      ref.read(cartProvider.notifier).markEmptied();
      state = AsyncData(order);
      return order;
    } on AppException catch (error, stack) {
      state = AsyncError(error, stack);
      // After a timeout we do not know whether the cart was emptied; ask the server.
      if (error.outcomeUnknown) ref.invalidate(cartProvider);
      return null;
    }
  }

  /// Back to the idle state (for example when the farmer leaves the checkout screen).
  void reset() => state = const AsyncData(null);
}

final checkoutProvider = AsyncNotifierProvider<CheckoutController, Order?>(CheckoutController.new);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../data/cart_models.dart';
import '../data/cart_repository.dart';

/// The cart plus how many changes are still on their way to the server.
class CartState {
  const CartState({this.cart = const Cart.empty(), this.pending = 0});

  final Cart cart;
  final int pending;

  /// Controls are dimmed while a change is in flight, so the farmer cannot stack a second one on a stale view.
  bool get busy => pending > 0;
}

/// The farmer's server-side cart. Every change replaces the whole state with the server's answer (it re-prices),
/// changes run one after another so answers cannot arrive out of order, and a failed change throws an
/// [AppException] to the caller while the cart on screen stays as it was.
class CartController extends AsyncNotifier<CartState> {
  Future<void> _queue = Future.value();

  @override
  Future<CartState> build() async {
    // A different user (or none) means a different cart: start again instead of showing the old one.
    final userId = ref.watch(sessionUserIdProvider);
    if (userId == null) return const CartState();
    final cart = await ref.watch(cartRepositoryProvider).get();
    return CartState(cart: cart);
  }

  Future<void> reload() async {
    final cart = await ref.read(cartRepositoryProvider).get();
    state = AsyncData(CartState(cart: cart, pending: state.valueOrNull?.pending ?? 0));
  }

  Future<void> add({required String storeProductId, required String productPackagingId, required int quantity}) =>
      _change(() => ref.read(cartRepositoryProvider).addItem(
            storeProductId: storeProductId,
            productPackagingId: productPackagingId,
            quantity: quantity,
          ));

  Future<void> setQuantity(String itemId, int quantity) =>
      _change(() => ref.read(cartRepositoryProvider).updateQuantity(itemId, quantity));

  Future<void> remove(String itemId) => _change(() => ref.read(cartRepositoryProvider).removeItem(itemId));

  Future<void> clear() => _change(() async {
        await ref.read(cartRepositoryProvider).clear();
        return const Cart.empty();
      });

  /// After checkout the server has emptied the cart itself: show that without another round trip.
  void markEmptied() {
    state = const AsyncData(CartState());
  }

  Future<void> _change(Future<Cart> Function() call) {
    _bump(1);
    final run = _queue.then((_) async {
      try {
        // Let the first load finish, or its (older) answer could overwrite this change's.
        try {
          await future;
        } catch (_) {
          // The first load failed; the change itself can still go through.
        }
        final cart = await call();
        state = AsyncData(CartState(cart: cart, pending: state.valueOrNull?.pending ?? 1));
      } finally {
        _bump(-1);
      }
    });
    // The queue must keep going after a failure; the caller still sees the error through `run`.
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  void _bump(int delta) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(CartState(cart: current.cart, pending: (current.pending + delta).clamp(0, 1 << 20)));
  }
}

final cartProvider = AsyncNotifierProvider<CartController, CartState>(CartController.new);

/// How many lines the badge shows. Zero while loading, signed out or on error: a badge must never get in the way.
final cartBadgeCountProvider = Provider<int>((ref) => ref.watch(cartProvider).valueOrNull?.cart.lineCount ?? 0);

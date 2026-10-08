import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paged.dart';
import '../../../core/network/paged_list.dart';
import '../../payment/data/payment_models.dart';
import '../data/delivery_models.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';

/// The farmer's orders for one status (null = all), loaded a page at a time. The order list belongs to one user, so it
/// starts again when someone else signs in.
class OrderListController extends PagedListNotifier<OrderListItem, String?> {
  @override
  Future<PagedListState<OrderListItem>> build(String? arg) {
    ref.watch(sessionUserIdProvider);
    return super.build(arg);
  }

  @override
  Future<Paged<OrderListItem>> fetchPage(String? arg, int page) =>
      ref.read(orderRepositoryProvider).list(status: arg, page: page, pageSize: PagedListNotifier.pageSize);
}

final orderListProvider = AsyncNotifierProvider.autoDispose
    .family<OrderListController, PagedListState<OrderListItem>, String?>(OrderListController.new);

/// Everything the order screen shows: the order, its deliveries and its payments. Only the order itself is required: if
/// deliveries or payments cannot be read the screen still opens and says so where they would be.
class OrderDetail {
  const OrderDetail({required this.order, required this.deliveries, required this.payments, this.deliveriesFailed = false});

  final Order order;
  final List<MyDelivery> deliveries;

  /// Null when the payment summary could not be read.
  final OrderPaymentSummary? payments;
  final bool deliveriesFailed;

  /// Whether a payOS payment can still be started for it: not a credit order, something left to pay, not closed.
  bool get canPay =>
      !order.isCredit && payments != null && payments!.remainingToPay > 0 && !OrderStatus.isClosed(order.status);

  /// Only an order still waiting for the store can be cancelled online.
  bool get canCancel => order.status == OrderStatus.pendingConfirmation;
}

final orderDetailProvider = FutureProvider.autoDispose.family<OrderDetail, String>((ref, id) async {
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(orderRepositoryProvider);

  Future<List<MyDelivery>?> deliveries() async {
    try {
      return await repo.deliveries(id);
    } on AppException {
      return null;
    }
  }

  Future<OrderPaymentSummary?> payments() async {
    try {
      return await repo.payments(id);
    } on AppException {
      return null;
    }
  }

  final results = await Future.wait<Object?>([repo.get(id), deliveries(), payments()]);
  final delivered = results[1] as List<MyDelivery>?;
  return OrderDetail(
    order: results[0]! as Order,
    deliveries: delivered ?? const [],
    deliveriesFailed: delivered == null,
    payments: results[2] as OrderPaymentSummary?,
  );
});

/// Cancelling an order, then making every screen that shows orders ask again.
class OrderActions {
  OrderActions(this._ref);

  final Ref _ref;

  Future<Order> cancel(String id, {String? reason}) async {
    final order = await _ref.read(orderRepositoryProvider).cancel(id, reason: reason);
    refreshOrders();
    return order;
  }

  /// After anything that changes an order (a payment, a cancel): the list and the open detail must not be stale.
  void refreshOrders() {
    _ref.invalidate(orderListProvider);
    _ref.invalidate(orderDetailProvider);
  }
}

final orderActionsProvider = Provider<OrderActions>(OrderActions.new);

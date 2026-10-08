import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/paged.dart';
import '../../../core/network/paged_list.dart';
import '../../credit/data/credit_models.dart';
import '../../credit/data/credit_repository.dart';
import '../../payment/data/payment_models.dart';
import '../../payment/data/payment_repository.dart';
import '../data/debt_models.dart';
import '../data/debt_repository.dart';

/// The credit line, the debt account and the farmer's repayments, read together. A farmer with no credit profile gets a
/// summary with neither (the store has not opened a debt book); any other failure is an error to retry.
final debtSummaryProvider = FutureProvider.autoDispose<DebtSummary>((ref) async {
  if (ref.watch(sessionUserIdProvider) == null) return const DebtSummary();

  final credit = ref.watch(creditRepositoryProvider).myCredit();
  final account = ref.watch(debtRepositoryProvider).account();
  final payments = ref.watch(paymentRepositoryProvider).myPayments(pageSize: 100);

  final results = await Future.wait<Object?>([credit, account, payments]);
  final page = results[2]! as Paged<PaymentListItem>;
  return DebtSummary(
    credit: results[0] as MyCredit?,
    account: results[1] as DebtAccount?,
    // Debt repayments are picked out of the farmer's payments here, the server only filters by status.
    repayments: page.items.where((p) => p.paymentContext == PaymentContext.debtRepayment).toList(growable: false),
  );
});

/// The farmer's debts for one status (null = all), a page at a time.
class DebtEntriesController extends PagedListNotifier<DebtEntryListItem, String?> {
  @override
  Future<PagedListState<DebtEntryListItem>> build(String? arg) {
    ref.watch(sessionUserIdProvider);
    return super.build(arg);
  }

  @override
  Future<Paged<DebtEntryListItem>> fetchPage(String? arg, int page) =>
      ref.read(debtRepositoryProvider).entries(status: arg, page: page, pageSize: PagedListNotifier.pageSize);
}

final debtEntriesProvider = AsyncNotifierProvider.autoDispose
    .family<DebtEntriesController, PagedListState<DebtEntryListItem>, String?>(DebtEntriesController.new);

final debtEntryProvider = FutureProvider.autoDispose.family<DebtEntryDetail, String>((ref, id) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(debtRepositoryProvider).entry(id);
});

/// Which debts a repayment of `amount` would settle (asked while the farmer types).
final allocationPreviewProvider = FutureProvider.autoDispose.family<AllocationPreview, int>(
  (ref, amount) => ref.watch(debtRepositoryProvider).allocationPreview(amount),
);

class DebtActions {
  DebtActions(this._ref);

  final Ref _ref;

  /// Sends the dispute, then makes every debt screen ask the server again.
  Future<DebtEntryDetail> dispute(String id, String reason) async {
    final detail = await _ref.read(debtRepositoryProvider).dispute(id, reason);
    refreshDebt();
    return detail;
  }

  /// After anything that changes the debt (a repayment, a dispute): nothing on screen may be stale.
  void refreshDebt() {
    // Invalidating a provider nobody has read would start it (and call the server for nothing): only refresh what exists.
    if (_ref.exists(debtSummaryProvider)) _ref.invalidate(debtSummaryProvider);
    _ref.invalidate(debtEntriesProvider);
    _ref.invalidate(debtEntryProvider);
  }
}

final debtActionsProvider = Provider<DebtActions>(DebtActions.new);

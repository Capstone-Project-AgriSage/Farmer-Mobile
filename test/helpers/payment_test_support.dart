import 'package:farmer_mobile/features/payment/data/pending_payment.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kho khoá-giá trị trong bộ nhớ, thay cho `shared_preferences` ở test.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  String? getString(String key) => data[key];

  @override
  Future<void> setString(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Cặp override dùng chung: kho thanh toán dở trong bộ nhớ + hỏi lại ngay không chờ.
List<Override> paymentTestOverrides(
  MemoryKeyValueStore store, {
  PaymentPolling polling = const PaymentPolling(interval: Duration.zero, maxAttempts: 3),
}) =>
    [
      pendingPaymentStoreProvider.overrideWithValue(PendingPaymentStore(store)),
      paymentPollingProvider.overrideWithValue(polling),
    ];

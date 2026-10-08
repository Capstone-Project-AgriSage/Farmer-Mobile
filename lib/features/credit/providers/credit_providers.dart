import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../data/credit_models.dart';
import '../data/credit_repository.dart';

/// The signed-in farmer's credit line, or null when they have none. Refreshed whenever the user changes.
final myCreditProvider = FutureProvider.autoDispose<MyCredit?>((ref) async {
  if (ref.watch(sessionUserIdProvider) == null) return null;
  return ref.watch(creditRepositoryProvider).myCredit();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/paged.dart';
import '../../../core/network/paged_list.dart';
import '../data/diagnosis_models.dart';
import '../data/diagnosis_photo.dart';
import '../data/diagnosis_repository.dart';

/// The farmer's cases for one status (null = all), loaded a page at a time. The list belongs to one user, so it starts
/// again when someone else signs in.
class DiagnosisListController extends PagedListNotifier<DiagnosisCaseListItem, String?> {
  @override
  Future<PagedListState<DiagnosisCaseListItem>> build(String? arg) {
    ref.watch(sessionUserIdProvider);
    return super.build(arg);
  }

  @override
  Future<Paged<DiagnosisCaseListItem>> fetchPage(String? arg, int page) =>
      ref.read(diagnosisRepositoryProvider).list(status: arg, page: page, pageSize: PagedListNotifier.pageSize);
}

final diagnosisListProvider = AsyncNotifierProvider.autoDispose
    .family<DiagnosisListController, PagedListState<DiagnosisCaseListItem>, String?>(DiagnosisListController.new);

/// One case. Reloaded when a reviewer may have decided it: the farmer pulls to refresh or reopens the screen.
final diagnosisDetailProvider = FutureProvider.autoDispose.family<DiagnosisCase, String>((ref, id) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(diagnosisRepositoryProvider).get(id);
});

/// Sending a photo and withdrawing a case, then making every screen that shows cases ask again.
class DiagnosisActions {
  DiagnosisActions(this._ref);

  final Ref _ref;

  Future<DiagnosisCase> send(DiagnosisPhotoFile photo, {String? note}) async {
    final created = await _ref.read(diagnosisRepositoryProvider).create(photo, note: note);
    refreshCases();
    return created;
  }

  Future<DiagnosisCase> cancel(String id, {String? reason}) async {
    final cancelled = await _ref.read(diagnosisRepositoryProvider).cancel(id, reason: reason);
    refreshCases();
    return cancelled;
  }

  void refreshCases() {
    _ref.invalidate(diagnosisListProvider);
    _ref.invalidate(diagnosisDetailProvider);
  }
}

final diagnosisActionsProvider = Provider<DiagnosisActions>(DiagnosisActions.new);

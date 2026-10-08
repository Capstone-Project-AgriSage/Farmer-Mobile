import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/session/session_manager.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

/// The signed-in farmer's profile (own account only).
final profileProvider = FutureProvider.autoDispose<FarmerProfile>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(profileRepositoryProvider).profile();
});

class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  /// Saves the change, then updates the name the rest of the app shows (home, account header).
  Future<FarmerProfile> save(ProfileUpdate update) async {
    final saved = await _ref.read(profileRepositoryProvider).update(update);
    final session = _ref.read(sessionManagerProvider);
    final user = session.user;
    if (user != null) {
      session.updateUser(
        SessionUser(
          id: user.id,
          fullName: saved.fullName,
          role: user.role,
          phoneNumber: user.phoneNumber,
          email: user.email,
        ),
      );
    }
    // Only refresh a profile somebody is looking at; invalidating an unread provider would start it for nothing.
    if (_ref.exists(profileProvider)) _ref.invalidate(profileProvider);
    return saved;
  }
}

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);

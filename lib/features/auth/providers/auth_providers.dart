import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_identity.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../data/auth_repository.dart';

/// Runs once at start-up: reads the stored token and asks the server who it belongs to. The splash screen shows
/// while this is pending; an offline failure is rethrown so the splash can offer "Thử lại".
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final session = ref.read(sessionManagerProvider);
  await session.restore();
  if (!session.hasStoredToken) return;

  try {
    final user = await ref.read(authRepositoryProvider).me();
    if (user.role != AppIdentity.requiredRole) {
      await session.rejectRestored(message: AppIdentity.wrongRoleMessage);
      return;
    }
    session.completeRestore(user);
  } on AppException catch (error) {
    if (error.isAuthFailure) {
      await session.expire(); // normally the interceptor has already done it; this is idempotent
      return;
    }
    if (error.kind == AppErrorKind.forbidden) {
      await session.rejectRestored(message: error.message);
      return;
    }
    rethrow;
  }
});

/// Sign-in, sign-up and sign-out. The state is the result of the last submit; the screens read `isLoading` and the
/// [AppException] from `error`.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> login({required String identifier, required String password}) => _run(
        () => ref.read(authRepositoryProvider).login(identifier: identifier.trim(), password: password),
      );

  Future<bool> register({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
  }) =>
      _run(
        () => ref.read(authRepositoryProvider).register(
              fullName: fullName.trim(),
              phoneNumber: phoneNumber.trim().isEmpty ? null : phoneNumber.trim(),
              email: email.trim().isEmpty ? null : email.trim(),
              password: password,
            ),
      );

  Future<void> logout() => ref.read(sessionManagerProvider).signOut();

  Future<bool> _run(Future<AuthResult> Function() call) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await call();
      if (result.user.role != AppIdentity.requiredRole) {
        throw const AppException(kind: AppErrorKind.wrongRole, message: AppIdentity.wrongRoleMessage);
      }
      await ref.read(sessionManagerProvider).signIn(
            accessToken: result.accessToken,
            expiresAt: result.expiresAt,
            user: result.user,
          );
    });
    return !state.hasError;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);

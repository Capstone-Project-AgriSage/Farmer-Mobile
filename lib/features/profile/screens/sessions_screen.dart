import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../core/utils/time_ago.dart';
import '../../orders/widgets/order_widgets.dart';

/// Các phiên đăng nhập còn hiệu lực của tài khoản (`/api/auth/sessions`).
final authSessionsProvider = FutureProvider.autoDispose<List<AuthSession>>(
    (ref) => ref.watch(authRepositoryProvider).sessions());

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final Set<String> _revoking = {};
  bool _loggingOutAll = false;

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            key: const Key('sessions_confirm_no'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            key: const Key('sessions_confirm_yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action, style: const TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _revoke(AuthSession s) async {
    if (!await _confirm(
      'Đăng xuất thiết bị này?',
      'Thiết bị đó sẽ bị đăng xuất khỏi tài khoản của bạn.',
      'Đăng xuất',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _revoking.add(s.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).revokeSession(s.id);
      if (!mounted) return;
      ref.invalidate(authSessionsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã đăng xuất thiết bị.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiException.from(e).message)));
      if (mounted) ref.invalidate(authSessionsProvider);
    } finally {
      if (mounted) setState(() => _revoking.remove(s.id));
    }
  }

  Future<void> _logoutAll() async {
    if (!await _confirm(
      'Đăng xuất khỏi tất cả thiết bị?',
      'Mọi thiết bị, kể cả thiết bị này, sẽ bị đăng xuất. Bạn cần đăng nhập lại.',
      'Đăng xuất tất cả',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _loggingOutAll = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Router guard đưa về màn Chào mừng khi phiên bị xoá.
      await ref.read(authControllerProvider).logoutAll();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiException.from(e).message)));
      if (mounted) setState(() => _loggingOutAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(authSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Thiết bị đăng nhập')),
      body: sessions.when(
        skipLoadingOnRefresh: true,
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerLoadingWidget(height: 110, borderRadius: 18),
            SizedBox(height: 12),
            ShimmerLoadingWidget(height: 200, borderRadius: 18),
            SizedBox(height: 12),
            ShimmerLoadingWidget(height: 120, borderRadius: 18),
          ],
        ),
        error: (e, _) => ErrorRetryWidget(
            error: e, onRetry: () => ref.invalidate(authSessionsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyDataWidget(
              message: 'Không có phiên đăng nhập nào.',
              fallbackIcon: Icons.devices_outlined,
            );
          }
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(authSessionsProvider);
                    await ref.read(authSessionsProvider.future).then((_) {}, onError: (_) {});
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Những thiết bị đang đăng nhập tài khoản của bạn. Nếu thấy thiết bị lạ, hãy đăng xuất thiết bị đó rồi đổi mật khẩu.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      for (final s in list) ...[
                        _SessionCard(
                          session: s,
                          busy: _revoking.contains(s.id),
                          onRevoke: s.isCurrent ? null : () => _revoke(s),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.borderSubtle)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('sessions_logout_all'),
                      onPressed: _loggingOutAll ? null : _logoutAll,
                      icon: _loggingOutAll
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.logout),
                      label: const FittedBox(child: Text('Đăng xuất khỏi tất cả thiết bị')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusError,
                        side: const BorderSide(color: AppColors.statusError),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.busy, required this.onRevoke});

  final AuthSession session;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Container(
      key: Key('session_${s.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: s.isCurrent ? Border.all(color: AppColors.primary, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: s.isCurrent ? AppColors.primaryLight : AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              s.isCurrent ? Icons.smartphone : Icons.devices_other_outlined,
              color: s.isCurrent ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(s.isCurrent ? 'Thiết bị này' : 'Thiết bị khác',
                        style: AppTextStyles.labelLarge),
                    if (s.isCurrent)
                      const StatusChip(
                          text: 'Đang dùng',
                          fg: AppColors.primaryDark,
                          bg: AppColors.primaryLight),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Đăng nhập lúc ${formatDateTime(s.createdAt)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                Text('Hoạt động gần nhất: ${formatTimeAgo(s.lastUsedAt)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                Text('Hết hạn ${formatDate(s.expiresAt)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                if (onRevoke != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: Key('session_revoke_${s.id}'),
                    onPressed: busy ? null : onRevoke,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      side: const BorderSide(color: AppColors.statusError),
                      minimumSize: const Size(0, 36),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const FittedBox(child: Text('Đăng xuất thiết bị')),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

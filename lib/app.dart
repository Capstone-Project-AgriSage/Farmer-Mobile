import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'core/network/realtime_events.dart';
import 'features/auth/providers/auth_controller.dart';

class AgriSageApp extends ConsumerWidget {
  const AgriSageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.listen(realtimeEventsProvider, (_, event) {
      if (event.valueOrNull == 'permissions' || event.valueOrNull == 'resync') {
        // Revalidate through the existing auth flow, including revoked sessions and changed roles.
        ref.read(authControllerProvider).bootstrap();
      }
    });

    return MaterialApp.router(
      title: 'AgriSage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Hộp chọn ngày, nút Huỷ/OK, chọn văn bản... của hệ thống bằng tiếng Việt.
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        );
      },
    );
  }
}

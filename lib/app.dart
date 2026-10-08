import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class AgriSageApp extends ConsumerWidget {
  const AgriSageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AgriSage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Vietnamese for everything Material draws itself: date picker, dialog buttons, the text selection menu.
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
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

import 'package:farmer_mobile/app.dart';
import 'package:farmer_mobile/core/config/app_config.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/auth/screens/onboarding_screen.dart';
import 'package:farmer_mobile/features/auth/screens/splash_screen.dart';
import 'package:farmer_mobile/shared/widgets/missing_config_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_fakes.dart';

void main() {
  configTests();
  testWidgets('khởi động app thật: Splash → Onboarding khi chưa đăng nhập',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Không đụng secure storage thật; không có token nên không gọi mạng.
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
      ],
      child: const AgriSageApp(),
    ));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('AgriSage'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}

void configTests() {
  testWidgets('MissingConfigApp: nói rõ cần API_BASE_URL (bản release quên cấu hình)', (tester) async {
    await tester.pumpWidget(const MissingConfigApp());
    expect(find.byKey(const Key('missing_config_title')), findsOneWidget);
    expect(find.textContaining('API_BASE_URL'), findsOneWidget);
  });

  test('bản debug/test luôn được coi là đã cấu hình (có địa chỉ dev mặc định)', () {
    expect(AppConfig.isConfigured, isTrue);
    expect(AppConfig.apiBaseUrl, startsWith('http'));
  });
}

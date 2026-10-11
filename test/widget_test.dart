import 'package:farmer_mobile/app.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/auth/screens/onboarding_screen.dart';
import 'package:farmer_mobile/features/auth/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_fakes.dart';

void main() {
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

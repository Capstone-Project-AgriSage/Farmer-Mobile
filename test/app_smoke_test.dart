import 'package:farmer_mobile/app.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

Future<ProviderScope> _app({required bool onboardingSeen}) async {
  SharedPreferences.setMockInitialValues({if (onboardingSeen) 'onboarding_seen': true});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: const AgriSageApp(),
  );
}

void main() {
  testWidgets('a first launch with no session shows the onboarding', (tester) async {
    await tester.pumpWidget(await _app(onboardingSeen: false));
    await tester.pumpAndSettle();

    expect(find.text('Bỏ qua'), findsOneWidget);
  });

  testWidgets('a later launch with no session goes to the welcome screen', (tester) async {
    await tester.pumpWidget(await _app(onboardingSeen: true));
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
  });
}

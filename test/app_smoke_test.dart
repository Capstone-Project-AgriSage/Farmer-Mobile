import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmer_mobile/app.dart';

void main() {
  testWidgets('the app starts, shows the splash and moves on', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AgriSageApp()));
    expect(find.byType(MaterialApp), findsOneWidget);

    // The splash waits 2.5 s before it navigates; let that timer finish so no timer is left pending.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
  });
}

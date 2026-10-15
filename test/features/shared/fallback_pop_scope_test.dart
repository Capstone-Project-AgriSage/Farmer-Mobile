import 'package:farmer_mobile/shared/widgets/fallback_pop_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter routerAt(String initial) => GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/list', builder: (_, __) => const Scaffold(body: Text('LIST'))),
          GoRoute(
            path: '/detail',
            builder: (_, __) => const FallbackPopScope(
              fallback: '/list',
              child: Scaffold(body: Text('DETAIL')),
            ),
          ),
        ],
      );

  testWidgets('mở bằng go (không có màn dưới): Back hệ thống về màn dự phòng, không thoát app',
      (tester) async {
    final router = routerAt('/detail');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue, reason: 'true = app tự xử lý, KHÔNG thoát ra ngoài');
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('mở bằng push (có màn dưới): Back hệ thống quay lại bình thường', (tester) async {
    final router = routerAt('/list');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}

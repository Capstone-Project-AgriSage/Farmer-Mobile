import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';

const _before = SessionUser(id: 'u1', fullName: 'Tên cũ', role: 'FARMER', phoneNumber: '0912345678');
const _after = SessionUser(id: 'u1', fullName: 'Tên mới', role: 'FARMER', phoneNumber: '0912345678');

Future<SessionManager> _signedIn() async {
  final session = SessionManager(store: InMemoryTokenStore());
  await session.signIn(accessToken: 't', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)), user: _before);
  return session;
}

void main() {
  // The real router refreshes whenever the session notifies. A page pushed on top of the tab shell that is still there
  // after a refresh cannot be closed, so a form that changes the user's name must not make the router refresh.
  testWidgets('a page pushed inside the shell still closes after the user updated their own name', (tester) async {
    final session = await _signedIn();
    addTearDown(session.dispose);
    final router = GoRouter(
      refreshListenable: session,
      initialLocation: '/profile',
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const Text('ACCOUNT'),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, __) => TextButton(
                    onPressed: () {
                      session.updateUser(_after);
                      context.pop();
                    },
                    child: const Text('SAVE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/profile/edit');
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('SAVE'), findsNothing);
  });

  test('updating the user does not notify the router, but tells the people who show the name', () async {
    final session = await _signedIn();
    addTearDown(session.dispose);
    var routerNotified = 0;
    var profileNotified = 0;
    session.addListener(() => routerNotified++);
    session.profileChanges.addListener(() => profileNotified++);

    session.updateUser(_after);

    expect(session.user?.fullName, 'Tên mới');
    expect(routerNotified, 0);
    expect(profileNotified, 1);
  });

  testWidgets('screens that watch sessionUserProvider show the new name straight away', (tester) async {
    final session = await _signedIn();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionManagerProvider.overrideWithValue(session)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Consumer(builder: (context, ref, _) => Text(ref.watch(sessionUserProvider)?.fullName ?? 'nobody')),
        ),
      ),
    );
    expect(find.text('Tên cũ'), findsOneWidget);

    session.updateUser(_after);
    await tester.pump();

    expect(find.text('Tên mới'), findsOneWidget);
  });

  test('signing out empties sessionUserProvider', () async {
    final session = await _signedIn();
    addTearDown(session.dispose);
    final container = ProviderContainer(overrides: [sessionManagerProvider.overrideWithValue(session)]);
    addTearDown(container.dispose);
    expect(container.read(sessionUserProvider)?.fullName, 'Tên cũ');

    await session.signOut();

    expect(container.read(sessionUserProvider), isNull);
  });
}

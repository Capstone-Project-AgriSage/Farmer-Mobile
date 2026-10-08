import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:farmer_mobile/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _user = SessionUser(id: 'u1', fullName: 'Trần Văn Hải', role: 'FARMER', phoneNumber: '0912345678');

void main() {
  final now = DateTime.utc(2026, 10, 8, 3);
  late FakeClock clock;

  setUp(() => clock = FakeClock(now));

  SessionManager manager(InMemoryTokenStore store) => SessionManager(store: store, clock: clock.call);

  test('with nothing stored the user is signed out', () async {
    final session = manager(InMemoryTokenStore());
    await session.restore();
    expect(session.status, SessionStatus.signedOut);
    expect(session.message, isNull);
  });

  test('a stored token that is still good is held while the server confirms it', () async {
    final store = InMemoryTokenStore(StoredSession(accessToken: 't', expiresAt: now.add(const Duration(hours: 5))));
    final session = manager(store);
    await session.restore();
    expect(session.status, SessionStatus.restoring);
    expect(session.hasStoredToken, isTrue);
    expect(session.token, 't');

    session.completeRestore(_user);
    expect(session.status, SessionStatus.signedIn);
    expect(session.user?.fullName, 'Trần Văn Hải');
  });

  test('a stored token that has expired is dropped with a message', () async {
    final store = InMemoryTokenStore(StoredSession(accessToken: 't', expiresAt: now.subtract(const Duration(minutes: 1))));
    final session = manager(store);
    await session.restore();
    expect(session.status, SessionStatus.signedOut);
    expect(session.message, contains('hết hạn'));
    expect(store.stored, isNull);
    expect(session.token, isNull);
  });

  test('a token is treated as expired 30 seconds early', () async {
    final session = manager(InMemoryTokenStore());
    await session.signIn(accessToken: 't', expiresAt: now.add(const Duration(seconds: 31)), user: _user);
    expect(session.isExpired, isFalse);
    clock.now = now.add(const Duration(seconds: 2));
    expect(session.isExpired, isTrue);
  });

  test('signIn stores the token and notifies the router', () async {
    final store = InMemoryTokenStore();
    final session = manager(store);
    var notified = 0;
    session.addListener(() => notified++);

    await session.signIn(accessToken: 'abc', expiresAt: now.add(const Duration(hours: 1)), user: _user);

    expect(session.isSignedIn, isTrue);
    expect(store.stored?.accessToken, 'abc');
    expect(notified, 1);
  });

  test('expire clears everything, leaves a message and is safe to repeat', () async {
    final store = InMemoryTokenStore();
    final session = manager(store);
    await session.signIn(accessToken: 'abc', expiresAt: now.add(const Duration(hours: 1)), user: _user);
    var notified = 0;
    session.addListener(() => notified++);

    await session.expire();
    await session.expire(); // a second request failing with 401 at the same time

    expect(session.status, SessionStatus.signedOut);
    expect(session.token, isNull);
    expect(session.user, isNull);
    expect(store.stored, isNull);
    expect(session.message, contains('hết hạn'));
    expect(notified, 1);
  });

  test('signOut by choice leaves no message', () async {
    final session = manager(InMemoryTokenStore());
    await session.signIn(accessToken: 'abc', expiresAt: now.add(const Duration(hours: 1)), user: _user);
    await session.signOut();
    expect(session.status, SessionStatus.signedOut);
    expect(session.message, isNull);
  });

  test('rejectRestored (wrong role) drops the stored token with the given message', () async {
    final store = InMemoryTokenStore(StoredSession(accessToken: 't', expiresAt: now.add(const Duration(hours: 5))));
    final session = manager(store);
    await session.restore();
    await session.rejectRestored(message: 'sai vai trò');
    expect(session.status, SessionStatus.signedOut);
    expect(session.message, 'sai vai trò');
    expect(store.stored, isNull);
  });
}

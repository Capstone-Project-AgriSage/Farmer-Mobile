import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:farmer_mobile/core/storage/token_store.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:farmer_mobile/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

SessionUser user(String role) => SessionUser(id: 'u1', fullName: 'Trần Văn Hải', role: role, phoneNumber: '0912345678');

AuthResult result(String role) => AuthResult(
      accessToken: 'tok',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
      user: user(role),
    );

void main() {
  late MockAuthRepository repo;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  setUp(() {
    repo = MockAuthRepository();
    store = InMemoryTokenStore();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
  });

  SessionManager session() => container.read(sessionManagerProvider);

  group('AuthController', () {
    test('a farmer who signs in gets a session', () async {
      when(() => repo.login(identifier: any(named: 'identifier'), password: any(named: 'password')))
          .thenAnswer((_) async => result('FARMER'));

      final ok = await container.read(authControllerProvider.notifier).login(identifier: ' 0912345678 ', password: 'pw');

      expect(ok, isTrue);
      expect(session().isSignedIn, isTrue);
      expect(store.stored?.accessToken, 'tok');
      verify(() => repo.login(identifier: '0912345678', password: 'pw')).called(1); // the identifier is trimmed
    });

    test('an account with another role is refused and never stored', () async {
      when(() => repo.login(identifier: any(named: 'identifier'), password: any(named: 'password')))
          .thenAnswer((_) async => result('DELIVERY_STAFF'));

      final ok = await container.read(authControllerProvider.notifier).login(identifier: 'tx', password: 'pw');

      expect(ok, isFalse);
      final error = container.read(authControllerProvider).error as AppException;
      expect(error.kind, AppErrorKind.wrongRole);
      expect(session().isSignedIn, isFalse);
      expect(store.writes, 0);
    });

    test('a wrong password shows the server message in Vietnamese', () async {
      when(() => repo.login(identifier: any(named: 'identifier'), password: any(named: 'password')))
          .thenThrow(const AppException(
        kind: AppErrorKind.unauthorized,
        message: 'Số điện thoại/email hoặc mật khẩu chưa đúng.',
        statusCode: 401,
      ));

      final ok = await container.read(authControllerProvider.notifier).login(identifier: 'a', password: 'b');

      expect(ok, isFalse);
      expect(messageOf(container.read(authControllerProvider).error!), 'Số điện thoại/email hoặc mật khẩu chưa đúng.');
      expect(session().isSignedIn, isFalse);
    });

    test('register sends a blank email as null and signs the new farmer in', () async {
      when(() => repo.register(
            fullName: any(named: 'fullName'),
            phoneNumber: any(named: 'phoneNumber'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => result('FARMER'));

      final ok = await container.read(authControllerProvider.notifier).register(
            fullName: ' Hải ',
            phoneNumber: '0912345678',
            email: '  ',
            password: 'pw12345678',
          );

      expect(ok, isTrue);
      expect(session().isSignedIn, isTrue);
      verify(() => repo.register(fullName: 'Hải', phoneNumber: '0912345678', email: null, password: 'pw12345678'))
          .called(1);
    });

    test('logout signs out and clears the stored token', () async {
      when(() => repo.login(identifier: any(named: 'identifier'), password: any(named: 'password')))
          .thenAnswer((_) async => result('FARMER'));
      await container.read(authControllerProvider.notifier).login(identifier: 'a', password: 'b');

      await container.read(authControllerProvider.notifier).logout();

      expect(session().status, SessionStatus.signedOut);
      expect(store.stored, isNull);
    });
  });

  group('sessionBootstrapProvider', () {
    StoredSession good() => StoredSession(accessToken: 't', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 5)));

    test('with no stored token the user is signed out and the server is not asked', () async {
      await container.read(sessionBootstrapProvider.future);
      expect(session().status, SessionStatus.signedOut);
      verifyNever(() => repo.me());
    });

    test('a stored token the server accepts restores the session', () async {
      store.stored = good();
      when(() => repo.me()).thenAnswer((_) async => user('FARMER'));

      await container.read(sessionBootstrapProvider.future);

      expect(session().isSignedIn, isTrue);
      expect(session().user?.fullName, 'Trần Văn Hải');
    });

    test('a stored token that belongs to another role is dropped with a message', () async {
      store.stored = good();
      when(() => repo.me()).thenAnswer((_) async => user('DELIVERY_STAFF'));

      await container.read(sessionBootstrapProvider.future);

      expect(session().status, SessionStatus.signedOut);
      expect(session().message, contains('Nông dân'));
      expect(store.stored, isNull);
    });

    test('a token the server rejects ends the session', () async {
      store.stored = good();
      when(() => repo.me()).thenThrow(const AppException.sessionExpired());

      await container.read(sessionBootstrapProvider.future);

      expect(session().status, SessionStatus.signedOut);
      expect(store.stored, isNull);
    });

    test('with no network the splash gets an error to retry and the token is kept', () async {
      store.stored = good();
      when(() => repo.me()).thenThrow(const AppException.offline());

      await expectLater(container.read(sessionBootstrapProvider.future), throwsA(isA<AppException>()));

      expect(session().status, SessionStatus.restoring);
      expect(store.stored, isNotNull);
    });
  });
}

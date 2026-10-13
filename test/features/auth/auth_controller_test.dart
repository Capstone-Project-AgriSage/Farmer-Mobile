import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/core/network/token_storage.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

ApiException _err(ApiErrorKind kind, [int? status]) =>
    ApiException(kind: kind, statusCode: status, message: 'lỗi');

void main() {
  keystoreFailureTests();
  late FakeAuthRepository repo;
  late MemoryTokenStorage storage;
  late ProviderContainer container;

  AuthController controller() => container.read(authControllerProvider);
  SessionState session() => container.read(sessionProvider);

  setUp(() {
    repo = FakeAuthRepository();
    storage = MemoryTokenStorage();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);
  });

  group('login', () {
    test('thành công: lưu token (ghi nhớ), lấy /me, phiên authenticated', () async {
      repo.onLogin = (_, __) async => fakeAuthResult();
      repo.onMe = () async => SessionUser.fromJson(meJson(phoneVerified: true));

      await controller().login('0912345678', 'matkhau123');

      expect(storage.tokens?.accessToken, 'acc1');
      expect(storage.lastPersist, isTrue);
      expect(session().status, SessionStatus.authenticated);
      expect(session().user?.phoneVerified, isTrue);
      expect(repo.calls, ['login', 'me']);
    });

    test('không tick "Ghi nhớ" thì truyền persist=false', () async {
      repo.onLogin = (_, __) async => fakeAuthResult();
      repo.onMe = () async => SessionUser.fromJson(meJson());

      await controller().login('0912345678', 'x', rememberMe: false);

      expect(storage.lastPersist, isFalse);
    });

    test('/me lỗi vẫn đăng nhập được bằng thông tin từ phản hồi login', () async {
      repo.onLogin = (_, __) async => fakeAuthResult();
      repo.onMe = () async => throw _err(ApiErrorKind.network);

      await controller().login('0912345678', 'x');

      expect(session().status, SessionStatus.authenticated);
      expect(session().user?.fullName, 'Trần Văn Hải');
    });

    test('sai mật khẩu: ném lỗi, không lưu token, phiên không đổi', () async {
      repo.onLogin = (_, __) async => throw _err(ApiErrorKind.unauthorized, 401);

      await expectLater(controller().login('0912345678', 'x'),
          throwsA(isA<ApiException>()));

      expect(storage.tokens, isNull);
      expect(session().status, SessionStatus.unknown);
    });

    test('tài khoản nhân viên bị từ chối và phiên vừa mở bị đóng', () async {
      repo.onLogin = (_, __) async => fakeAuthResult(role: 'SALES_STAFF');

      await expectLater(
        controller().login('0912345678', 'x'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('nông dân'))),
      );

      expect(storage.tokens, isNull);
      expect(session().isAuthenticated, isFalse);
      expect(repo.calls, ['login', 'logout']);
      expect(repo.lastLogoutToken, 'acc1');
    });
  });

  group('register', () {
    test('thành công: đăng nhập luôn, luôn ghi nhớ', () async {
      repo.onRegister = () async => fakeAuthResult();
      repo.onMe = () async => SessionUser.fromJson(meJson());

      await controller().register(
        fullName: 'A',
        phoneNumber: '0912345678',
        password: 'matkhau123',
      );

      expect(session().isAuthenticated, isTrue);
      expect(storage.lastPersist, isTrue);
      expect(storage.tokens?.refreshToken, 'ref1');
    });

    test('409 trùng tài khoản: không đăng nhập', () async {
      repo.onRegister = () async => throw _err(ApiErrorKind.conflict, 409);

      await expectLater(
        controller().register(
            fullName: 'A', phoneNumber: '0912345678', password: 'matkhau123'),
        throwsA(isA<ApiException>()),
      );

      expect(session().isAuthenticated, isFalse);
      expect(storage.tokens, isNull);
    });
  });

  group('bootstrap (splash)', () {
    test('không có token → unauthenticated, không gọi server', () async {
      final r = await controller().bootstrap();

      expect(r, BootstrapResult.unauthenticated);
      expect(session().status, SessionStatus.unauthenticated);
      expect(repo.calls, isEmpty);
    });

    test('token còn dùng được → authenticated', () async {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      repo.onMe = () async => SessionUser.fromJson(meJson());

      final r = await controller().bootstrap();

      expect(r, BootstrapResult.authenticated);
      expect(session().user?.id, 'u1');
    });

    test('server từ chối (401 sau refresh) → xoá token, unauthenticated', () async {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      repo.onMe = () async => throw _err(ApiErrorKind.unauthorized, 401);

      final r = await controller().bootstrap();

      expect(r, BootstrapResult.unauthenticated);
      expect(storage.tokens, isNull);
      expect(session().status, SessionStatus.unauthenticated);
    });

    test('mất mạng → offline, GIỮ token và trạng thái unknown', () async {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      repo.onMe = () async => throw _err(ApiErrorKind.network);

      final r = await controller().bootstrap();

      expect(r, BootstrapResult.offline);
      expect(storage.tokens, isNotNull);
      expect(session().status, SessionStatus.unknown);
    });

    test('server 5xx cũng là offline (cho thử lại)', () async {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      repo.onMe = () async => throw _err(ApiErrorKind.server, 500);
      expect(await controller().bootstrap(), BootstrapResult.offline);
    });

    test('token của tài khoản không phải nông dân bị bỏ', () async {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      repo.onMe = () async => SessionUser.fromJson(meJson(role: 'STORE_OWNER'));

      final r = await controller().bootstrap();

      expect(r, BootstrapResult.unauthenticated);
      expect(storage.tokens, isNull);
    });
  });

  group('logout / đổi mật khẩu', () {
    setUp(() {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      container.read(sessionProvider.notifier)
          .setAuthenticated(SessionUser.fromJson(meJson()));
    });

    test('logout: gọi server rồi xoá token, phiên unauthenticated', () async {
      await controller().logout();

      expect(repo.calls, ['logout']);
      expect(storage.tokens, isNull);
      expect(session().status, SessionStatus.unauthenticated);
    });

    test('logout vẫn xoá phiên cục bộ khi server lỗi (offline)', () async {
      repo.onLogout = ({accessToken}) async => throw _err(ApiErrorKind.network);

      await controller().logout();

      expect(storage.tokens, isNull);
      expect(session().status, SessionStatus.unauthenticated);
    });

    test('đổi mật khẩu thành công: đăng xuất cục bộ (backend huỷ mọi phiên)',
        () async {
      await controller().changePassword('cu', 'moi12345');

      expect(repo.calls, ['changePassword']);
      expect(storage.tokens, isNull);
      expect(session().status, SessionStatus.unauthenticated);
    });

    test('đổi mật khẩu thất bại: GIỮ phiên', () async {
      repo.onChangePassword = () async => throw _err(ApiErrorKind.unauthorized, 401);

      await expectLater(controller().changePassword('sai', 'moi12345'),
          throwsA(isA<ApiException>()));

      expect(storage.tokens, isNotNull);
      expect(session().isAuthenticated, isTrue);
    });

    test('refreshUser cập nhật cờ đã xác minh', () async {
      repo.onMe = () async => SessionUser.fromJson(meJson(phoneVerified: true));

      await controller().refreshUser();

      expect(session().user?.phoneVerified, isTrue);
      expect(session().isAuthenticated, isTrue);
    });
  });

  group('SessionUser.initials', () {
    SessionUser named(String n) => SessionUser(id: '1', fullName: n, role: 'FARMER');
    test('lấy chữ đầu họ và tên', () {
      expect(named('Trần Văn Hải').initials, 'TH');
      expect(named('Hải').initials, 'H');
      expect(named('  nguyễn   a ').initials, 'NA');
      expect(named('').initials, '?');
    });
  });

  group('authRedirect (router guard)', () {
    test('unknown: chỉ ở splash', () {
      expect(authRedirect(SessionStatus.unknown, '/'), isNull);
      expect(authRedirect(SessionStatus.unknown, '/home'), '/');
      expect(authRedirect(SessionStatus.unknown, '/login'), '/');
    });

    test('chưa đăng nhập: được vào luồng auth, còn lại về /welcome', () {
      for (final p in [
        '/', '/onboarding', '/welcome', '/login', '/register',
        '/forgot-password', '/reset-password',
      ]) {
        expect(authRedirect(SessionStatus.unauthenticated, p), isNull, reason: p);
      }
      for (final p in [
        '/home', '/products', '/cart', '/orders/123', '/profile',
        '/profile/password', '/otp-verify?channel=phone', '/debt/list',
        '/ai-scan', '/notifications',
      ]) {
        expect(authRedirect(SessionStatus.unauthenticated, p), '/welcome', reason: p);
      }
    });

    test('đã đăng nhập: rời các màn auth về /home, còn lại giữ nguyên', () {
      for (final p in [
        '/', '/onboarding', '/welcome', '/login', '/register',
        '/forgot-password', '/reset-password',
      ]) {
        expect(authRedirect(SessionStatus.authenticated, p), '/home', reason: p);
      }
      for (final p in ['/home', '/profile', '/otp-verify?channel=email&to=a%40b.com', '/orders/1']) {
        expect(authRedirect(SessionStatus.authenticated, p), isNull, reason: p);
      }
    });

    test('query string không làm sai đường dẫn', () {
      expect(authRedirect(SessionStatus.unauthenticated, '/login?x=1'), isNull);
      expect(authRedirect(SessionStatus.authenticated, '/login?x=1'), '/home');
    });
  });
}

void keystoreFailureTests() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  ProviderContainer build(MemoryTokenStorage storage) {
    repo = FakeAuthRepository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('kho token (keystore) bị lỗi', () {
    test('không đọc được token lúc khởi động: coi như chưa đăng nhập, không kẹt', () async {
      final c = build(BrokenTokenStorage(failRead: true));
      final result = await c.read(authControllerProvider).bootstrap();
      expect(result, BootstrapResult.unauthenticated);
      expect(c.read(sessionProvider).status, SessionStatus.unauthenticated);
      expect(repo.calls, isEmpty, reason: 'không gọi /me khi không có token');
    });

    test('đăng nhập OK nhưng không lưu được token: báo lỗi tiếng Việt, đóng phiên trên server, không đăng nhập',
        () async {
      final c = build(BrokenTokenStorage(failSave: true));
      repo.onLogin = (_, __) async => fakeAuthResult();

      await expectLater(
        c.read(authControllerProvider).login('0912345678', 'matkhau123'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('Không lưu được phiên'))),
      );
      expect(repo.calls, ['login', 'logout']);
      expect(repo.lastLogoutToken, 'acc1', reason: 'đóng đúng phiên vừa mở');
      expect(c.read(sessionProvider).isAuthenticated, isFalse);
    });

    test('đăng xuất khi không xoá được khỏi keystore: vẫn đăng xuất khỏi app', () async {
      final c = build(BrokenTokenStorage(failClear: true));
      c.read(sessionProvider.notifier).setAuthenticated(SessionUser.fromJson(meJson()));
      await c.read(authControllerProvider).logout();
      expect(c.read(sessionProvider).status, SessionStatus.unauthenticated);
    });
  });
}

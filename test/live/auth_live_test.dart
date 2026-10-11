// Test tích hợp với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/auth_live_test.dart
//   (đổi địa chỉ: LIVE_API_URL=http://192.168.1.10:5206)
//
// Mỗi lần chạy TẠO MỘT tài khoản nông dân mới trên DB dev dùng chung, tên
// "TEST Mobile Auth <mã>". Backend chưa có API xoá tài khoản nên không dọn được.
@Timeout(Duration(minutes: 10))
library;


import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/core/network/token_storage.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

final _live = liveEnabled;
final _baseUrl = liveBaseUrl;
final _adapter = liveAdapter;
Dio _rawDio() => rawLiveDio();
String _randomPhone() => randomPhone();

const _password = 'Test@12345678';
const _newPassword = 'Test@87654321';


void main() {
  late MemoryTokenStorage storage;
  late ProviderContainer container;
  late AuthController auth;
  late AuthRepository repo;
  late String phone;
  late String email;
  late String name;

  ProviderContainer newContainer(MemoryTokenStorage s) {
    final c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(s),
      // Dio thật, trỏ về backend thật.
      dioProvider.overrideWith((ref) => createApiDio(
            baseUrl: _baseUrl,
            storage: s,
            onSessionExpired: () async =>
                ref.read(sessionProvider.notifier).markUnauthenticated(),
            adapter: _adapter,
          )),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUpAll(() {
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    phone = _randomPhone();
    email = 'mobile-test-$code@example.com';
    name = 'TEST Mobile Auth $code';
    storage = MemoryTokenStorage();
    container = newContainer(storage);
    auth = container.read(authControllerProvider);
    repo = container.read(authRepositoryProvider);
  });

  SessionState session() => container.read(sessionProvider);

  group(
      'auth với backend thật',
      skip: !_live ? 'đặt LIVE_API=1 để chạy' : false,
      () {
    test('catalog công khai truy cập được không cần đăng nhập', () async {
      final dio = container.read(dioProvider);
      final cats = await dio.get<List<dynamic>>('/api/catalog/categories');
      final products = await dio.get<Map<String, dynamic>>(
          '/api/catalog/products',
          queryParameters: {'pageSize': 2});

      expect(cats.statusCode, 200);
      expect(products.data!['items'], isA<List>());
      expect(products.requestOptions.headers.containsKey('Authorization'),
          isFalse);
    });

    test('đăng ký bằng mật khẩu quá ngắn → 400 validation (tiếng Việt)', () async {
      final e = await repo
          .register(fullName: name, phoneNumber: phone, password: '1234567')
          .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

      expect(e, isNotNull);
      expect(e!.kind, ApiErrorKind.validation);
      expect(e.statusCode, 400);
      expect(e.message, 'Dữ liệu không hợp lệ.');
      expect(e.fieldErrors, isNotEmpty);
    });

    test('đăng ký SĐT sai định dạng → 400', () async {
      await expectLater(
        repo.register(fullName: name, phoneNumber: '12345', password: _password),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    test('đăng ký thành công → đăng nhập luôn, role FARMER, lưu token', () async {
      await auth.register(
          fullName: name, phoneNumber: phone, email: email, password: _password);

      expect(session().isAuthenticated, isTrue);
      expect(session().user?.role, 'FARMER');
      expect(session().user?.fullName, name);
      expect(session().user?.phoneNumber, phone);
      expect(session().user?.email, email);
      expect(session().user?.phoneVerified, isFalse);
      expect(storage.tokens?.refreshToken, isNotEmpty);
      expect(storage.tokens?.sessionId, isNotNull);
    });

    test('đăng ký trùng SĐT → 409 + thông báo tiếng Việt', () async {
      await expectLater(
        repo.register(fullName: 'Khác', phoneNumber: phone, password: _password),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
            .having((e) => e.message, 'message', contains('đã được đăng ký'))),
      );
    });

    test('đăng ký trùng email (SĐT khác) → 409', () async {
      await expectLater(
        repo.register(
            fullName: 'Khác',
            phoneNumber: _randomPhone(),
            email: email.toUpperCase(), // backend chuẩn hoá chữ thường
            password: _password),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.conflict)),
      );
    });

    test('đăng nhập sai mật khẩu và tài khoản không tồn tại cho CÙNG thông báo',
        () async {
      Future<ApiException> fail1(String id, String pw) async {
        try {
          await repo.login(id, pw);
        } on ApiException catch (e) {
          return e;
        }
        throw StateError('phải lỗi');
      }

      final wrongPw = await fail1(phone, 'SaiMatKhau!1');
      final unknown = await fail1(_randomPhone(), _password);

      expect(wrongPw.kind, ApiErrorKind.unauthorized);
      expect(unknown.kind, ApiErrorKind.unauthorized);
      expect(wrongPw.message, unknown.message);
      expect(wrongPw.message, contains('không đúng'));
    });

    test('đăng nhập bằng SĐT ở nhiều định dạng và bằng email (hoa/thường)',
        () async {
      for (final id in [
        phone,
        '+84${phone.substring(1)}',
        '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}',
        email,
        email.toUpperCase(),
      ]) {
        final r = await repo.login(id, _password);
        expect(r.user.role, 'FARMER', reason: id);
        await repo.logout(accessToken: r.tokens.accessToken);
      }
    });

    test('/me, hồ sơ và giỏ hàng của nông dân gọi được với token', () async {
      final me = await repo.me();
      expect(me.id, session().user?.id);

      final dio = container.read(dioProvider);
      final profile = await dio.get<Map<String, dynamic>>('/api/me/profile');
      final cart = await dio.get<Map<String, dynamic>>('/api/me/cart');
      expect(profile.data!['fullName'], name);
      expect(cart.data!['items'], isEmpty);
    });

    test('route cần đăng nhập không có token → 401 (không crash)', () async {
      final anon = _rawDio();
      await expectLater(
        anon.get<dynamic>('/api/me/profile'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
    });

    test('token hỏng → interceptor tự refresh, gọi lại thành công, token xoay vòng',
        () async {
      final before = storage.tokens!;
      storage.tokens = AuthTokens(
          accessToken: 'token.hong.roi',
          refreshToken: before.refreshToken,
          sessionId: before.sessionId);

      final me = await repo.me();

      expect(me.fullName, name);
      expect(storage.tokens!.accessToken, isNot('token.hong.roi'));
      expect(storage.tokens!.refreshToken, isNot(before.refreshToken),
          reason: 'refresh token phải xoay vòng');
      expect(session().isAuthenticated, isTrue);
    });

    test('3 request song song khi token hỏng đều thành công (refresh một lần)',
        () async {
      final cur = storage.tokens!;
      storage.tokens = AuthTokens(
          accessToken: 'token.hong.roi',
          refreshToken: cur.refreshToken,
          sessionId: cur.sessionId);
      final dio = container.read(dioProvider);

      final results = await Future.wait([
        dio.get<dynamic>('/api/me/profile'),
        dio.get<dynamic>('/api/me/cart'),
        dio.get<dynamic>('/api/auth/me'),
      ]);

      expect(results.map((r) => r.statusCode), [200, 200, 200]);
      expect(session().isAuthenticated, isTrue);
    });

    test('refresh token cũ (đã xoay) không dùng lại được', () async {
      final fresh = newContainer(MemoryTokenStorage());
      final freshRepo = fresh.read(authRepositoryProvider);
      final r1 = await freshRepo.login(phone, _password);

      final dio = _rawDio();
      final ok = await dio.post<Map<String, dynamic>>('/api/auth/refresh',
          data: {'refreshToken': r1.tokens.refreshToken});
      expect(ok.statusCode, 200);

      await expectLater(
        dio.post<dynamic>('/api/auth/refresh',
            data: {'refreshToken': r1.tokens.refreshToken}),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
    });

    test('danh sách phiên có phiên hiện tại', () async {
      final sessions = await repo.sessions();
      expect(sessions, isNotEmpty);
      expect(sessions.where((s) => s.isCurrent), hasLength(1));
    });

    test('quên mật khẩu: 202 hoặc 503 (chưa cấu hình SMTP/SMS), không lỗi khác',
        () async {
      try {
        await repo.forgotPassword(email);
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.unavailable);
        expect(e.message, contains('chưa gửi được'));
      }
    });

    test('quên mật khẩu với tài khoản không tồn tại: kết quả y như tài khoản có thật',
        () async {
      Object? real;
      Object? ghost;
      try {
        await repo.forgotPassword(email);
      } on ApiException catch (e) {
        real = e.statusCode;
      }
      try {
        await repo.forgotPassword('khong-ton-tai-$phone@example.com');
      } on ApiException catch (e) {
        ghost = e.statusCode;
      }
      expect(ghost, real, reason: 'không được lộ tài khoản có tồn tại hay không');
    });

    test('đặt lại mật khẩu với mã bịa → lỗi, mật khẩu không đổi', () async {
      final fake = '${'ab' * 16}.${'A' * 43}';
      await expectLater(
        repo.resetPassword(fake, _newPassword),
        throwsA(isA<ApiException>()),
      );
      final r = await repo.login(phone, _password); // vẫn dùng mật khẩu cũ
      await repo.logout(accessToken: r.tokens.accessToken);
    });

    test('xác minh SĐT: yêu cầu mã (503 nếu chưa cấu hình SMS); xác nhận mã sai → lỗi',
        () async {
      try {
        await repo.requestPhoneVerification();
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.unavailable);
      }
      await expectLater(repo.confirmPhone('000000'), throwsA(isA<ApiException>()));
      final me = await repo.me();
      expect(me.phoneVerified, isFalse);
    });

    test('đổi mật khẩu sai mật khẩu hiện tại → báo đúng lỗi, VẪN đăng nhập',
        () async {
      await expectLater(
        auth.changePassword('SaiMatKhau!1', _newPassword),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Mật khẩu hiện tại không đúng.')),
      );

      expect(session().isAuthenticated, isTrue);
      expect(storage.tokens, isNotNull);
      expect((await repo.me()).id, session().user?.id);
    });

    test('đổi mật khẩu trùng mật khẩu cũ → 422', () async {
      await expectLater(
        auth.changePassword(_password, _password),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
      expect(session().isAuthenticated, isTrue);
    });

    test('đổi mật khẩu thành công → mọi phiên bị huỷ; mật khẩu cũ hết hiệu lực',
        () async {
      // Một phiên khác (thiết bị khác) để chắc chắn bị huỷ theo.
      final other = newContainer(MemoryTokenStorage());
      await other.read(authRepositoryProvider).login(phone, _password);
      final otherStorage = other.read(tokenStorageProvider) as MemoryTokenStorage;
      final otherTokens = otherStorage.tokens;

      await auth.changePassword(_password, _newPassword);

      expect(session().status, SessionStatus.unauthenticated);
      expect(storage.tokens, isNull);

      // Phiên ở "thiết bị khác" cũng không dùng được nữa.
      final dio = _rawDio();
      await expectLater(
        dio.post<dynamic>('/api/auth/refresh', data: {
          'refreshToken': otherTokens?.refreshToken ?? 'x' * 43,
        }),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );

      await expectLater(
        repo.login(phone, _password),
        throwsA(isA<ApiException>().having((e) => e.kind, 'k', ApiErrorKind.unauthorized)),
      );
      final ok = await repo.login(phone, _newPassword);
      expect(ok.user.role, 'FARMER');
      await repo.logout(accessToken: ok.tokens.accessToken);
    });

    test('đăng xuất → token cũ vô hiệu, app tự về trạng thái chưa đăng nhập',
        () async {
      await auth.login(phone, _newPassword);
      final old = storage.tokens!;
      expect(session().isAuthenticated, isTrue);

      await auth.logout();

      expect(session().status, SessionStatus.unauthenticated);
      expect(storage.tokens, isNull);

      // Dùng lại access token và refresh token cũ: server phải từ chối.
      final dio = _rawDio();
      await expectLater(
        dio.get<dynamic>('/api/auth/me',
            options: Options(headers: {'Authorization': 'Bearer ${old.accessToken}'})),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
      await expectLater(
        dio.post<dynamic>('/api/auth/refresh', data: {'refreshToken': old.refreshToken}),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
    });

    test('bootstrap: có token hợp lệ → authenticated; token bị thu hồi → unauthenticated',
        () async {
      // Phiên hợp lệ lưu sẵn (như đã đăng nhập lần trước, bật "ghi nhớ").
      final seed = await repo.login(phone, _newPassword);
      final s2 = MemoryTokenStorage(seed.tokens);
      final c2 = newContainer(s2);

      expect(await c2.read(authControllerProvider).bootstrap(),
          BootstrapResult.authenticated);
      expect(c2.read(sessionProvider).user?.fullName, name);

      // Thu hồi phiên rồi khởi động lại app với cùng token.
      await c2.read(authControllerProvider).logout();
      final s3 = MemoryTokenStorage(seed.tokens);
      final c3 = newContainer(s3);

      expect(await c3.read(authControllerProvider).bootstrap(),
          BootstrapResult.unauthenticated);
      expect(s3.tokens, isNull);
    });

    test('bootstrap khi server không chạy → offline, giữ token', () async {
      final s = MemoryTokenStorage(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'));
      final c = ProviderContainer(overrides: [
        tokenStorageProvider.overrideWithValue(s),
        dioProvider.overrideWith((ref) => createApiDio(
              baseUrl: 'http://localhost:1', // không có ai lắng nghe
              storage: s,
              onSessionExpired: () async {},
            )),
      ]);
      addTearDown(c.dispose);

      expect(await c.read(authControllerProvider).bootstrap(),
          BootstrapResult.offline);
      expect(s.tokens, isNotNull);
    });
  });
}

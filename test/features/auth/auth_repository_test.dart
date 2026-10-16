import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late FakeAdapter adapter;
  late AuthRepository repo;
  late MemoryTokenStorage storage;

  void useAdapter(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final Dio dio = createApiDio(
      baseUrl: 'http://test',
      storage: storage,
      onSessionExpired: () async {},
      adapter: adapter,
    );
    repo = AuthRepository(dio);
  }

  setUp(() => storage = MemoryTokenStorage());

  group('login', () {
    test('gửi identifier đã trim và parse phản hồi', () async {
      useAdapter((o) => jsonBody(200, authJson()));

      final result = await repo.login('  0912345678 ', 'secret123');

      expect(adapter.requests.single.path, '/api/auth/login');
      expect(adapter.requests.single.data,
          {'identifier': '0912345678', 'password': 'secret123'});
      expect(result.tokens.accessToken, 'acc1');
      expect(result.tokens.refreshToken, 'ref1');
      expect(result.tokens.sessionId, 'sess-1');
      expect(result.user.fullName, 'Trần Văn Hải');
      expect(result.user.role, 'FARMER');
    });

    test('401 thành "sai thông tin", không phải "hết phiên"', () async {
      useAdapter((o) => jsonBody(401, problem(401, 'Invalid phone number')));

      final e = await repo.login('0912345678', 'x').then<ApiException?>((_) => null,
          onError: (Object e) => e as ApiException);

      expect(e, isNotNull);
      expect(e!.kind, ApiErrorKind.unauthorized);
      expect(e.message, contains('không đúng'));
      expect(e.message, isNot(contains('hết hạn')));
    });

    test('403 tài khoản bị khoá', () async {
      useAdapter((o) => jsonBody(403, problem(403, 'This account is not active.')));
      await expectLater(
        repo.login('0912345678', 'x'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('không hoạt động'))),
      );
    });

    test('mất mạng → ApiException network', () async {
      adapter = FakeAdapter((o) => throw DioException.connectionError(
          requestOptions: o, reason: 'refused'));
      repo = AuthRepository(createApiDio(
        baseUrl: 'http://test',
        storage: storage,
        onSessionExpired: () async {},
        adapter: adapter,
      ));

      await expectLater(
        repo.login('0912345678', 'x'),
        throwsA(isA<ApiException>().having((e) => e.isConnectivity, 'conn', true)),
      );
    });
  });

  group('register', () {
    test('chỉ gửi email khi có, và trim các trường', () async {
      useAdapter((o) => jsonBody(201, authJson()));

      await repo.register(
        fullName: '  Nguyễn Văn A ',
        phoneNumber: '0912345678',
        email: '  ',
        password: 'matkhau123',
      );

      expect(adapter.requests.single.data, {
        'fullName': 'Nguyễn Văn A',
        'phoneNumber': '0912345678',
        'password': 'matkhau123',
      });
    });

    test('gửi email khi có', () async {
      useAdapter((o) => jsonBody(201, authJson()));
      await repo.register(
        fullName: 'A',
        phoneNumber: '0912345678',
        email: ' a@b.com ',
        password: 'matkhau123',
      );
      expect((adapter.requests.single.data as Map)['email'], 'a@b.com');
    });

    test('409 trùng SĐT/email → thông báo tiếng Việt', () async {
      useAdapter((o) => jsonBody(409, problem(409, 'An account with this phone number or email already exists.')));

      await expectLater(
        repo.register(
            fullName: 'A', phoneNumber: '0912345678', password: 'matkhau123'),
        throwsA(isA<ApiException>()
            .having((e) => e.isConflict, 'conflict', true)
            .having((e) => e.message, 'message', contains('đã được đăng ký'))),
      );
    });
  });

  test('me parse cờ xác minh', () async {
    useAdapter((o) => jsonBody(200, meJson(phoneVerified: true, email: 'a@b.com')));

    final u = await repo.me();

    expect(adapter.requests.single.method, 'GET');
    expect(u.phoneVerified, isTrue);
    expect(u.emailVerified, isFalse);
    expect(u.email, 'a@b.com');
  });

  test('logout với token tường minh dùng token đó', () async {
    useAdapter((o) => emptyBody(204));
    await repo.logout(accessToken: 'tok-x');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-x');
  });

  group('đổi mật khẩu', () {
    test('gửi đúng tên trường', () async {
      useAdapter((o) => emptyBody(204));
      await repo.changePassword('cu12345678', 'moi12345678');
      expect(adapter.requests.single.data,
          {'currentPassword': 'cu12345678', 'newPassword': 'moi12345678'});
    });

    test('401 = sai mật khẩu hiện tại (không refresh token)', () async {
      storage.tokens = null;
      useAdapter((o) => jsonBody(401, problem(401, 'The current password is incorrect.')));
      await expectLater(
        repo.changePassword('sai', 'moi12345678'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Mật khẩu hiện tại không đúng.')),
      );
      expect(adapter.requests.length, 1);
    });
  });

  group('quên / đặt lại mật khẩu', () {
    test('forgot gửi identifier', () async {
      useAdapter((o) => emptyBody(202));
      await repo.forgotPassword(' a@b.com ');
      expect(adapter.requests.single.data, {'identifier': 'a@b.com'});
    });

    test('forgot 503 khi server chưa cấu hình SMTP/SMS', () async {
      useAdapter((o) => jsonBody(503, problem(503, 'Verification message delivery is unavailable.')));
      await expectLater(
        repo.forgotPassword('a@b.com'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unavailable)
            .having((e) => e.message, 'message', contains('chưa gửi được'))),
      );
    });

    test('reset gửi token + newPassword; 422 = mã sai/hết hạn', () async {
      useAdapter((o) => jsonBody(422, problem(422, 'The verification token is invalid or expired.')));
      await expectLater(
        repo.resetPassword(' tok ', 'matkhaumoi1'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('không đúng hoặc đã hết hạn'))),
      );
      expect(adapter.requests.single.data,
          {'token': 'tok', 'newPassword': 'matkhaumoi1'});
    });

    test('reset bằng mã 6 số gửi identifier (chuẩn hoá 0xxxxxxxxx) + code', () async {
      useAdapter((o) => emptyBody(204));
      await repo.resetPasswordWithCode(' +84 912 345 678 ', ' 123456 ', 'matkhaumoi1');
      expect(adapter.requests.single.path, '/api/auth/reset-password');
      expect(adapter.requests.single.data, {
        'identifier': '0912345678',
        'code': '123456',
        'newPassword': 'matkhaumoi1',
      });
    });

    test('reset bằng mã 6 số: 422 = mã sai/hết hạn/số lạ', () async {
      useAdapter((o) => jsonBody(422, problem(422, 'The verification token is invalid or expired.')));
      await expectLater(
        repo.resetPasswordWithCode('0912345678', '123456', 'matkhaumoi1'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('không đúng hoặc đã hết hạn'))),
      );
    });
  });

  group('kiểm tra mã đặt lại (chưa đặt mật khẩu)', () {
    test('gửi identifier (chuẩn hoá 0xxxxxxxxx) + code tới verify-code', () async {
      useAdapter((o) => emptyBody(204));
      await repo.verifyResetCode(' +84 912 345 678 ', ' 123456 ');
      expect(adapter.requests.single.path, '/api/auth/reset-password/verify-code');
      expect(adapter.requests.single.data, {
        'identifier': '0912345678',
        'code': '123456',
      });
    });

    test('422 = mã sai/hết hạn/số lạ', () async {
      useAdapter((o) => jsonBody(422, problem(422, 'The verification token is invalid or expired.')));
      await expectLater(
        repo.verifyResetCode('0912345678', '123456'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.message, 'message', contains('không đúng hoặc đã hết hạn'))),
      );
    });
  });

  group('xác minh', () {
    test('phone confirm gửi {code}', () async {
      useAdapter((o) => emptyBody(204));
      await repo.confirmPhone(' 123456 ');
      expect(adapter.requests.single.path, '/api/auth/phone-verification/confirm');
      expect(adapter.requests.single.data, {'code': '123456'});
    });

    test('email confirm gửi {token}', () async {
      useAdapter((o) => emptyBody(204));
      await repo.confirmEmail('t');
      expect(adapter.requests.single.path, '/api/auth/email-verification/confirm');
      expect(adapter.requests.single.data, {'token': 't'});
    });

    test('request phone 503 → thông báo SMS', () async {
      useAdapter((o) => jsonBody(503, problem(503, 'unavailable')));
      await expectLater(
        repo.requestPhoneVerification(),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('SMS'))),
      );
    });
  });

  test('sessions parse danh sách và revoke gọi DELETE', () async {
    useAdapter((o) => o.method == 'GET'
        ? jsonBody(200, [
            {
              'id': 's1',
              'createdAt': '2026-10-12T01:00:00Z',
              'lastUsedAt': '2026-10-12T02:00:00Z',
              'expiresAt': '2026-11-12T01:00:00Z',
              'isCurrent': true,
            }
          ])
        : emptyBody(204));

    final list = await repo.sessions();
    await repo.revokeSession('s1');

    expect(list.single.isCurrent, isTrue);
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, '/api/auth/sessions/s1');
  });
}

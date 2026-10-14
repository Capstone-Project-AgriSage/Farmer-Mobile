import 'package:farmer_mobile/features/auth/data/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone (khớp ContactNormalizer của backend)', () {
    test('các định dạng hợp lệ về dạng 0xxxxxxxxx', () {
      expect(AuthValidators.normalizePhone('0912345678'), '0912345678');
      expect(AuthValidators.normalizePhone('0912 345 678'), '0912345678');
      expect(AuthValidators.normalizePhone('0912.345.678'), '0912345678');
      expect(AuthValidators.normalizePhone('(091) 234-5678'), '0912345678');
      expect(AuthValidators.normalizePhone('+84912345678'), '0912345678');
      expect(AuthValidators.normalizePhone('84912345678'), '0912345678');
    });

    test('đầu số 03/05/07/08/09 hợp lệ, các đầu số khác bị từ chối', () {
      for (final p in ['0321234567', '0521234567', '0721234567', '0821234567']) {
        expect(AuthValidators.normalizePhone(p), p);
      }
      expect(AuthValidators.normalizePhone('0121234567'), isNull);
      expect(AuthValidators.normalizePhone('0421234567'), isNull);
      expect(AuthValidators.normalizePhone('0621234567'), isNull);
    });

    test('sai độ dài hoặc không phải số', () {
      expect(AuthValidators.normalizePhone('091234567'), isNull);
      expect(AuthValidators.normalizePhone('09123456789'), isNull);
      expect(AuthValidators.normalizePhone('abcdefghij'), isNull);
      expect(AuthValidators.normalizePhone(''), isNull);
      expect(AuthValidators.normalizePhone(null), isNull);
      // "84" + 9 số chưa đủ 11 ký tự nên không được đổi thành 0.
      expect(AuthValidators.normalizePhone('84912345'), isNull);
    });
  });

  group('identifier', () {
    test('email hoặc số điện thoại hợp lệ', () {
      expect(AuthValidators.identifier('a@b.com'), isNull);
      expect(AuthValidators.identifier('  a@b.com  '), isNull);
      expect(AuthValidators.identifier('0912345678'), isNull);
    });

    test('rỗng, email sai, số sai', () {
      expect(AuthValidators.identifier(''), isNotNull);
      expect(AuthValidators.identifier('   '), isNotNull);
      expect(AuthValidators.identifier('a@b'), 'Email không hợp lệ');
      expect(AuthValidators.identifier('12345'), isNotNull);
    });
  });

  group('mật khẩu (8–128 ký tự như PasswordRules của backend)', () {
    test('newPassword', () {
      expect(AuthValidators.newPassword(''), isNotNull);
      expect(AuthValidators.newPassword(null), isNotNull);
      expect(AuthValidators.newPassword('1234567'), contains('8'));
      expect(AuthValidators.newPassword('12345678'), isNull);
      expect(AuthValidators.newPassword('a' * 128), isNull);
      expect(AuthValidators.newPassword('a' * 129), isNotNull);
    });

    test('existingPassword không áp độ dài (không chặn tài khoản cũ)', () {
      expect(AuthValidators.existingPassword('1'), isNull);
      expect(AuthValidators.existingPassword(''), isNotNull);
    });

    test('confirmPassword', () {
      final check = AuthValidators.confirmPassword(() => 'abcdefgh');
      expect(check('abcdefgh'), isNull);
      expect(check('abcdefgx'), isNotNull);
      expect(check(''), isNotNull);
    });
  });

  group('các trường khác', () {
    test('fullName', () {
      expect(AuthValidators.fullName('  '), isNotNull);
      expect(AuthValidators.fullName('Nguyễn Văn A'), isNull);
      expect(AuthValidators.fullName('a' * 151), isNotNull);
    });

    test('optionalEmail: rỗng hợp lệ', () {
      expect(AuthValidators.optionalEmail(''), isNull);
      expect(AuthValidators.optionalEmail(null), isNull);
      expect(AuthValidators.optionalEmail('x@y.vn'), isNull);
      expect(AuthValidators.optionalEmail('x@y'), isNotNull);
    });

    test('mã đặt lại mật khẩu: 32 hex + "." + 43 ký tự base64url', () {
      final good = '${'a1' * 16}.${'A' * 43}';
      expect(AuthValidators.isResetToken(good), isTrue);
      expect(AuthValidators.isResetToken(' $good '), isTrue);
      expect(AuthValidators.resetToken(good), isNull);
      expect(AuthValidators.resetToken(''), isNotNull);
      expect(AuthValidators.resetToken('abc'), isNotNull);
      expect(AuthValidators.resetToken('${'zz' * 16}.${'A' * 43}'), isNotNull);
      expect(AuthValidators.resetToken('${'a1' * 16}.${'A' * 42}'), isNotNull);
    });

    test('OTP 6 số', () {
      expect(AuthValidators.isOtp('123456'), isTrue);
      expect(AuthValidators.isOtp('12345'), isFalse);
      expect(AuthValidators.isOtp('1234567'), isFalse);
      expect(AuthValidators.isOtp('12345a'), isFalse);
    });

    test('resetCode: mã 6 số (SMS) hoặc token dài (email)', () {
      final token = '${'a1' * 16}.${'A' * 43}';
      expect(AuthValidators.resetCode('123456'), isNull);
      expect(AuthValidators.resetCode(' 123456 '), isNull);
      expect(AuthValidators.resetCode(token), isNull);
      expect(AuthValidators.resetCode(''), isNotNull);
      expect(AuthValidators.resetCode(null), isNotNull);
      expect(AuthValidators.resetCode('12345'), isNotNull);
      expect(AuthValidators.resetCode('1234567'), isNotNull);
      expect(AuthValidators.resetCode('abc'), isNotNull);
    });

    test('phoneForSmsCode: cần số điện thoại di động, không nhận email', () {
      expect(AuthValidators.phoneForSmsCode('0912345678'), isNull);
      expect(AuthValidators.phoneForSmsCode('+84 912 345 678'), isNull);
      expect(AuthValidators.phoneForSmsCode(''), isNotNull);
      expect(AuthValidators.phoneForSmsCode(null), isNotNull);
      expect(AuthValidators.phoneForSmsCode('a@b.vn'), isNotNull);
      expect(AuthValidators.phoneForSmsCode('0112345678'), isNotNull);
    });
  });
}

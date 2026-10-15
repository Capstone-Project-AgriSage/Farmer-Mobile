// Test tích hợp công nợ với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/debt_live_test.dart
//
// Tạo 1 tài khoản nông dân ("TEST Mobile Debt <mã>") trên DB dev dùng chung.
// Tài khoản mới KHÔNG có hồ sơ tín dụng nên ở đây chỉ kiểm tra được trạng thái
// "chưa có công nợ" và cách app xử lý lỗi; luồng có số liệu công nợ thật cần
// một tài khoản đã được cửa hàng cấp hạn mức và tạo khoản nợ.
@Timeout(Duration(minutes: 5))
library;

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

const _ghost = '0198a0f0-1111-7000-8000-000000000000';

Future<ApiException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  fail('Cần ApiException nhưng không có lỗi');
}

void main() {
  late ProviderContainer c;
  late DebtRepository debt;
  late PaymentRepository pay;
  late CreditRepository credit;

  setUpAll(() async {
    if (!liveEnabled) return;
    final storage = MemoryTokenStorage();
    c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWith((ref) => createApiDio(
            baseUrl: liveBaseUrl,
            storage: storage,
            onSessionExpired: () async =>
                ref.read(sessionProvider.notifier).markUnauthenticated(),
            adapter: liveAdapter,
          )),
    ]);
    addTearDown(c.dispose);
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final phone = randomPhone();
    await c.read(authControllerProvider).register(
        fullName: 'TEST Mobile Debt $code', phoneNumber: phone, password: 'Test@12345678');
    // ignore: avoid_print
    print('Đã tạo tài khoản test: TEST Mobile Debt $code / $phone');

    debt = c.read(debtRepositoryProvider);
    pay = c.read(paymentRepositoryProvider);
    credit = c.read(creditRepositoryProvider);
  });

  final skip = liveEnabled ? null : 'Đặt LIVE_API=1 để chạy test với backend thật';

  group('Tài khoản chưa có hạn mức (thực tế backend)', () {
    test('hạn mức: 404 → null', () async {
      expect(await credit.mine(), isNull);
    }, skip: skip);

    test('sổ nợ: chưa có → null (app hiện hướng dẫn, không báo lỗi)', () async {
      expect(await debt.account(), isNull);
    }, skip: skip);

    test('danh sách khoản nợ: trống, đúng cấu trúc phân trang', () async {
      final r = await debt.entries();
      expect(r.items, isEmpty);
      expect(r.totalCount, 0);
      expect(r.hasMore, isFalse);
    }, skip: skip);

    test('mọi bộ lọc của app đều được backend chấp nhận (không 400)', () async {
      for (final s in DebtStatus.filters) {
        final r = await debt.entries(status: s);
        expect(r.items, isEmpty, reason: 'lọc ${s ?? 'tất cả'}');
      }
    }, skip: skip);

    test('upcoming (3 lệnh song song) chạy được và rỗng', () async {
      expect(await debt.upcoming(), isEmpty);
    }, skip: skip);

    test('chi tiết khoản nợ không tồn tại → 404 tiếng Việt', () async {
      final e = await _failure(() => debt.entry(_ghost));
      expect(e.statusCode, 404);
      expect(e.message, 'Không tìm thấy khoản nợ.');
    }, skip: skip);

    test('khiếu nại khoản nợ không tồn tại → 404 tiếng Việt', () async {
      final e = await _failure(() => debt.dispute(_ghost, 'Sai số tiền'));
      expect(e.statusCode, 404);
      expect(e.message, 'Không tìm thấy khoản nợ.');
    }, skip: skip);

    test('khiếu nại thiếu lý do → báo nhập lý do (400)', () async {
      final e = await _failure(() => debt.dispute(_ghost, '   '));
      expect(e.statusCode, 400);
      expect(e.message, contains('lý do'));
    }, skip: skip);

    test('xem trước phân bổ khi chưa có sổ nợ → lỗi tiếng Việt, không crash', () async {
      final e = await _failure(() => debt.preview(100000));
      expect(e.statusCode, anyOf(404, 422));
      expect(e.message, anyOf(contains('chưa có công nợ'), contains('không hợp lệ')));
    }, skip: skip);

    test('lịch sử trả nợ: rỗng, phân trang hợp lệ', () async {
      final r = await debt.repayments();
      expect(r.items, isEmpty);
      expect(r.page, 1);
    }, skip: skip);

    test('trả nợ khi không có nợ → bị từ chối, không tạo link, có thông báo tiếng Việt', () async {
      final e = await _failure(() => pay.createForDebt(100000));
      // 422 (vượt số nợ = 0) hoặc 404 hoặc 503 (payOS chưa cấu hình).
      expect(e.statusCode, anyOf(404, 422, 503));
      expect(e.message, isNot(contains('The customer')));
      expect(e.message, isNotEmpty);
      // ignore: avoid_print
      print('createForDebt khi không có nợ → ${e.statusCode}: ${e.message} (detail: ${e.detail})');
    }, skip: skip);
  });
}

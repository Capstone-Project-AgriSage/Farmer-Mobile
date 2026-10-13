// Test tích hợp chẩn đoán AI với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/diagnosis_live_test.dart
//
// Tạo 1 tài khoản nông dân ("TEST Mobile Diagnosis <mã>") và 1 CA CHẨN ĐOÁN thật
// (ảnh PNG 1x1) trên DB dev dùng chung; ca được huỷ ở cuối. Server dev chưa có model
// AI nên ca thường ở trạng thái FAILED (vẫn là "chờ chuyên gia"). Đường đi đến
// VERIFIED cần chuyên gia duyệt nên không kiểm tra được ở đây.
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_models.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

const _ghost = '0198a0f0-3333-7000-8000-000000000000';

// PNG 1x1 hợp lệ.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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
  late DiagnosisRepository repo;
  late Directory tmp;
  late PickedPhoto photo;
  late DiagnosisCase created;

  setUpAll(() async {
    if (!liveEnabled) return;
    tmp = Directory.systemTemp.createTempSync('diaglive');
    final file = File('${tmp.path}/leaf.png')..writeAsBytesSync(base64Decode(_png));
    photo = PickedPhoto(path: file.path, name: 'leaf.png', sizeBytes: file.lengthSync());

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
        fullName: 'TEST Mobile Diagnosis $code', phoneNumber: phone, password: 'Test@12345678');
    // ignore: avoid_print
    print('Đã tạo tài khoản test: TEST Mobile Diagnosis $code / $phone');

    repo = c.read(diagnosisRepositoryProvider);
  });

  tearDownAll(() async {
    if (!liveEnabled) return;
    try {
      await repo.cancel(created.id, reason: 'Dọn test');
    } on ApiException {
      // đã huỷ trong test
    }
    tmp.deleteSync(recursive: true);
  });

  final skip = liveEnabled ? null : 'Đặt LIVE_API=1 để chạy test với backend thật';

  group('Gửi ảnh thật', () {
    test('tạo ca: đúng cấu trúc, đang chờ chuyên gia, KHÔNG có kết quả AI', () async {
      created = await repo.create(photo: photo, note: '  TEST ghi chú  ');
      // ignore: avoid_print
      print('Ca ${created.caseNumber} → ${created.status}');

      expect(created.caseNumber, matches(RegExp(r'^DG-\d{8}-\d{4}$')));
      expect(created.note, 'TEST ghi chú');
      expect(created.isWaiting, isTrue,
          reason: 'mọi ca mới đều chờ chuyên gia (SUBMITTED/AI_COMPLETED/FAILED...)');
      expect(created.result, isNull);
      expect(created.inconclusive, isNull);
      expect(created.image, isNotNull);
      expect(created.image!.url, startsWith('http'));
      expect(created.image!.expiresAt, isNotNull);
    }, skip: skip);

    test('ảnh có chữ ký tải về được (URL còn hạn)', () async {
      final res = await rawLiveDio().get<List<int>>(created.image!.url,
          options: Options(responseType: ResponseType.bytes));
      expect(res.statusCode, 200);
      expect(res.data, isNotEmpty);
    }, skip: skip);

    test('chi tiết khớp với lúc tạo', () async {
      final d = await repo.get(created.id);
      expect(d.id, created.id);
      expect(d.caseNumber, created.caseNumber);
      expect(d.canCancel, isTrue);
    }, skip: skip);

    test('danh sách có ca vừa tạo; chưa có tên bệnh (chưa xác nhận)', () async {
      final r = await repo.list();
      final item = r.items.firstWhere((i) => i.id == created.id);
      expect(item.diseaseCode, isNull);
      expect(item.diseaseDisplay, isNull);
      expect(r.totalCount, 1);
    }, skip: skip);

    test('lọc trạng thái: mọi bộ lọc của app được backend chấp nhận', () async {
      for (final s in DiagnosisStatus.filters) {
        final r = await repo.list(status: s);
        expect(r.page, 1, reason: 'lọc ${s ?? 'tất cả'}');
      }
      final verified = await repo.list(status: DiagnosisStatus.verified);
      expect(verified.items, isEmpty);
    }, skip: skip);
  });

  group('Lỗi thật của backend', () {
    test('file không phải ảnh (đổi đuôi .png) → backend từ chối 400, app báo tiếng Việt', () async {
      final fake = File('${tmp.path}/fake.png')..writeAsStringSync('đây không phải ảnh');
      final e = await _failure(() => repo.create(
          photo: PickedPhoto(path: fake.path, name: 'fake.png', sizeBytes: fake.lengthSync())));
      expect(e.statusCode, 400);
      expect(e.message, contains('JPEG, PNG, WebP'));
    }, skip: skip);

    test('ghi chú quá 1000 ký tự → 400', () async {
      final e = await _failure(() => repo.create(photo: photo, note: 'x' * 1001));
      expect(e.statusCode, 400);
    }, skip: skip);

    test('chi tiết / huỷ ca không tồn tại → 404 tiếng Việt', () async {
      final g = await _failure(() => repo.get(_ghost));
      expect(g.statusCode, 404);
      expect(g.message, 'Không tìm thấy ca chẩn đoán.');
      final x = await _failure(() => repo.cancel(_ghost));
      expect(x.statusCode, 404);
    }, skip: skip);
  });

  group('Huỷ', () {
    test('huỷ ca đang chờ → CANCELLED; huỷ lần hai → 422 tiếng Việt', () async {
      final d = await repo.cancel(created.id, reason: 'TEST dọn');
      expect(d.status, 'CANCELLED');
      expect(d.canCancel, isFalse);

      final e = await _failure(() => repo.cancel(created.id));
      expect(e.statusCode, 422);
      expect(e.message, contains('không thể huỷ'));

      final cancelled = await repo.list(status: DiagnosisStatus.cancelled);
      expect(cancelled.items.map((i) => i.id), contains(created.id));
    }, skip: skip);
  });
}

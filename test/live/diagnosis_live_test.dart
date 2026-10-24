// Test tích hợp chẩn đoán AI với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/diagnosis_live_test.dart
//
// Tạo 1 tài khoản nông dân ("TEST Mobile Diagnosis <mã>") và 1 CA CHẨN ĐOÁN thật
// (ảnh PNG 1x1) trên DB dev dùng chung. Không còn chuyên gia duyệt (AI_DIAGNOSIS.md 2.0):
// AI-Service chạy thì ca có kết quả ngay (AI_COMPLETED, thường là "chưa chắc" với ảnh 1x1);
// AI-Service tắt thì ca là FAILED và thử lại được. Ca chưa có kết quả được huỷ ở cuối.
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
    test('tạo ca: đúng cấu trúc; có kết quả AI ngay, hoặc FAILED và thử lại được', () async {
      created = await repo.create(photo: photo, note: '  TEST ghi chú  ');
      // ignore: avoid_print
      print('Ca ${created.caseNumber} → ${created.status} ${created.result?.certainty ?? ''}');

      expect(created.caseNumber, matches(RegExp(r'^DG-\d{8}-\d{4}$')));
      expect(created.note, 'TEST ghi chú');
      expect(created.status, isIn([DiagnosisStatus.aiCompleted, DiagnosisStatus.failed]));
      if (created.status == DiagnosisStatus.aiCompleted) {
        expect(created.result, isNotNull);
        expect(created.result!.certainty,
            isIn([DiagnosisCertainty.confident, DiagnosisCertainty.uncertain]));
        if (created.result!.isUncertain) {
          expect(created.result!.hint, 'RETAKE_PHOTO_OR_ASK_STORE');
          expect(created.result!.products, isEmpty);
          expect(created.result!.treatments.map((t) => t.type), isNot(contains('CHEMICAL')));
        }
        expect(created.canRetry, isFalse);
      } else {
        expect(created.result, isNull);
        expect(created.canRetry, isTrue);
      }
      expect(created.isWaiting, isFalse);
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
      expect(d.canCancel, d.status == DiagnosisStatus.failed);
      expect(d.result?.disease.code, created.result?.disease.code);
    }, skip: skip);

    test('danh sách có ca vừa tạo; có tên bệnh và mức chắc chắn khi đã có kết quả', () async {
      final r = await repo.list();
      final item = r.items.firstWhere((i) => i.id == created.id);
      expect(item.diseaseCode, created.result?.disease.code);
      expect(item.certainty, created.result?.certainty);
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

    test('chi tiết / huỷ / thử lại ca không tồn tại → 404 tiếng Việt', () async {
      final g = await _failure(() => repo.get(_ghost));
      expect(g.statusCode, 404);
      expect(g.message, 'Không tìm thấy ca chẩn đoán.');
      final x = await _failure(() => repo.cancel(_ghost));
      expect(x.statusCode, 404);
      final r = await _failure(() => repo.retry(_ghost));
      expect(r.statusCode, 404);
    }, skip: skip);
  });

  group('Thử lại', () {
    test('ca đã có kết quả → 422; ca AI lỗi → có kết quả, hoặc 503 khi AI vẫn chưa chạy', () async {
      final d = await repo.get(created.id);
      if (d.canRetry) {
        try {
          final r = await repo.retry(d.id);
          expect(r.status, DiagnosisStatus.aiCompleted);
          expect(r.result, isNotNull);
          expect(r.canRetry, isFalse);
        } on ApiException catch (e) {
          expect(e.statusCode, 503);
          expect(e.message, contains('Dịch vụ AI đang bận'));
          expect((await repo.get(d.id)).status, DiagnosisStatus.failed, reason: '503 không ghi gì');
        }
      } else {
        final e = await _failure(() => repo.retry(d.id));
        expect(e.statusCode, 422);
        expect(e.message, contains('không cần phân tích lại'));
      }
    }, skip: skip);
  });

  group('Huỷ', () {
    test('ca chưa có kết quả → CANCELLED; ca đã có kết quả hoặc đã huỷ → 422 tiếng Việt', () async {
      final now = await repo.get(created.id);
      if (now.canCancel) {
        final d = await repo.cancel(created.id, reason: 'TEST dọn');
        expect(d.status, 'CANCELLED');
        expect(d.canCancel, isFalse);
        final cancelled = await repo.list(status: DiagnosisStatus.cancelled);
        expect(cancelled.items.map((i) => i.id), contains(created.id));
      }

      final e = await _failure(() => repo.cancel(created.id));
      expect(e.statusCode, 422);
      expect(e.message, contains('không thể huỷ'));
    }, skip: skip);
  });
}

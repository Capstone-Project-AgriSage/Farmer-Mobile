import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_models.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/diagnosis_fakes.dart';

void main() {
  late FakeAdapter adapter;
  late DiagnosisRepository repo;
  late Directory tmp;
  late File jpg;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('diag');
    jpg = File('${tmp.path}/leaf.JPG')..writeAsBytesSync(List.filled(64, 7));
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  void use(FakeHandler h) {
    adapter = FakeAdapter(h);
    repo = DiagnosisRepository(createApiDio(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      onSessionExpired: () async {},
      adapter: adapter,
    ));
  }

  Matcher failsWith(String part) => throwsA(
      isA<ApiException>().having((e) => e.message, 'message', contains(part)));

  PickedPhoto photo({String? name, int? size}) =>
      PickedPhoto(path: jpg.path, name: name ?? 'leaf.JPG', sizeBytes: size ?? 64);

  group('kiểm tra ảnh trước khi gửi', () {
    test('JPEG / PNG / WebP (không phân biệt hoa thường) hợp lệ', () {
      for (final n in ['a.jpg', 'a.JPEG', 'a.png', 'a.PNG', 'a.webp', 'IMG.1.Jpg']) {
        expect(DiagnosisRepository.validatePhoto(photo(name: n)), isNull, reason: n);
      }
    });

    test('định dạng khác (HEIC, GIF, PDF, không đuôi) bị từ chối', () {
      for (final n in ['a.heic', 'a.gif', 'a.pdf', 'a', 'a.jpg.txt']) {
        expect(DiagnosisRepository.validatePhoto(photo(name: n)), contains('JPEG, PNG hoặc WebP'),
            reason: n);
      }
    });

    test('đúng 5 MB hợp lệ; quá 5 MB và file rỗng bị từ chối', () {
      expect(DiagnosisRepository.validatePhoto(photo(size: 5 * 1024 * 1024)), isNull);
      expect(DiagnosisRepository.validatePhoto(photo(size: 5 * 1024 * 1024 + 1)),
          contains('quá lớn'));
      expect(DiagnosisRepository.validatePhoto(photo(size: 0)), contains('bị lỗi'));
    });
  });

  group('gửi ảnh', () {
    test('multipart: trường image đúng tên/kiểu, ghi chú đã trim, timeout dài', () async {
      use((o) => jsonBody(201, caseJson('c1', status: 'AI_COMPLETED', note: 'Lá vàng')));
      final c = await repo.create(photo: photo(), note: '  Lá vàng  ');

      final req = adapter.requests.single;
      expect(req.path, '/api/me/diagnosis-cases');
      expect(req.method, 'POST');
      final form = req.data as FormData;
      expect(form.fields.map((f) => (f.key, f.value)), [('note', 'Lá vàng')]);
      final file = form.files.single;
      expect(file.key, 'image');
      expect(file.value.filename, 'leaf.JPG');
      expect(file.value.contentType.toString(), 'image/jpeg');
      expect(file.value.length, 64);
      expect(req.sendTimeout, const Duration(seconds: 90));
      expect(req.receiveTimeout, const Duration(seconds: 90));
      expect(c.id, 'c1');
      expect(c.isWaiting, isTrue);
    });

    test('ghi chú trống thì không gửi trường note', () async {
      use((o) => jsonBody(201, caseJson('c1')));
      await repo.create(photo: photo(), note: '   ');
      expect((adapter.requests.single.data as FormData).fields, isEmpty);
    });

    test('PNG / WebP gửi đúng content type', () async {
      use((o) => jsonBody(201, caseJson('c1')));
      await repo.create(photo: photo(name: 'a.png'));
      await repo.create(photo: photo(name: 'a.webp'));
      final types = adapter.requests
          .map((r) => (r.data as FormData).files.single.value.contentType.toString());
      expect(types, ['image/png', 'image/webp']);
    });

    test('400 (backend từ chối ảnh/ghi chú) → thông báo tiếng Việt, nêu giới hạn', () async {
      use((o) => jsonBody(400, {'status': 400, 'errors': {'file': ['Only JPEG...']}}));
      expect(repo.create(photo: photo()), failsWith('tối đa 5 MB'));
    });

    test('429 (gửi quá nhanh) → thông báo chờ', () async {
      use((o) => jsonBody(429, {'status': 429}));
      expect(repo.create(photo: photo()), failsWith('quá nhanh'));
    });

    test('413 → ảnh quá lớn', () async {
      use((o) => jsonBody(413, {'status': 413}));
      expect(repo.create(photo: photo()), failsWith('quá lớn'));
    });
  });

  group('đọc ca chẩn đoán', () {
    test('mọi trạng thái chờ (kể cả AI lỗi) đều là "đang chờ", huỷ được', () {
      for (final s in ['SUBMITTED', 'PROCESSING', 'AI_COMPLETED', 'UNDER_REVIEW', 'FAILED']) {
        expect(DiagnosisStatus.isWaiting(s), isTrue, reason: s);
        expect(DiagnosisStatus.canCancel(s), isTrue, reason: s);
        expect(DiagnosisStatus.label(s), 'Chờ chuyên gia xem', reason: s);
      }
      for (final s in ['VERIFIED', 'INCONCLUSIVE', 'CANCELLED']) {
        expect(DiagnosisStatus.isWaiting(s), isFalse, reason: s);
        expect(DiagnosisStatus.canCancel(s), isFalse, reason: s);
      }
    });

    test('ca đã xác nhận: bệnh, điều trị và sản phẩm sắp theo rankOrder', () async {
      use((o) => jsonBody(200, caseJson('c1', status: 'VERIFIED', result: resultJson())));
      final c = await repo.get('c1');

      expect(adapter.requests.single.path, '/api/me/diagnosis-cases/c1');
      final r = c.result!;
      expect(r.disease.code, 'LEAF_BLAST');
      expect(r.disease.displayName, 'Đạo ôn lá');
      expect(r.reviewerComment, 'Vết bệnh hình thoi điển hình.');
      expect(r.treatments.map((t) => t.title), ['Phun thuốc đặc trị đạo ôn', 'Giữ ruộng thoáng']);
      expect(r.treatments.first.precautions, isNotNull);
      expect(r.products.map((p) => p.storeProductId), ['sp1', 'sp2']);
      expect(c.image!.url, startsWith('https://'));
      expect(c.isWaiting, isFalse);
    });

    test('ca chưa có kết quả: không có result/inconclusive (không có AI)', () async {
      use((o) => jsonBody(200, caseJson('c1', status: 'UNDER_REVIEW')));
      final c = await repo.get('c1');
      expect(c.result, isNull);
      expect(c.inconclusive, isNull);
    });

    test('ca chưa kết luận được: lời nhắn + gợi ý chụp lại', () async {
      use((o) => jsonBody(
          200,
          caseJson('c1',
              status: 'INCONCLUSIVE',
              inconclusive: {'comment': 'Ảnh bị mờ.', 'hint': 'RETAKE_PHOTO'})));
      final c = await repo.get('c1');
      expect(c.inconclusive!.comment, 'Ảnh bị mờ.');
      expect(c.inconclusive!.hint, 'RETAKE_PHOTO');
    });

    test('ảnh null / thiếu trường tuỳ chọn không làm vỡ', () async {
      use((o) => jsonBody(200, caseJson('c1', withImage: false)));
      expect((await repo.get('c1')).image, isNull);
    });

    test('tên bệnh: biết mã thì dùng tiếng Việt; mã lạ giữ tên backend', () {
      expect(diseaseDisplayName('HEALTHY', 'Healthy'), 'Lá khoẻ mạnh');
      expect(diseaseDisplayName('SHEATH_BLIGHT', 'Sheath Blight'), 'Khô vằn');
      expect(diseaseDisplayName('NEW_ONE', 'Bệnh mới'), 'Bệnh mới');
    });

    test('404 → thông báo tiếng Việt', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(repo.get('x'), failsWith('Không tìm thấy ca chẩn đoán'));
    });
  });

  group('danh sách', () {
    test('phân trang + lọc trạng thái; chỉ ca VERIFIED có tên bệnh', () async {
      use((o) => jsonBody(200, {
            'items': [
              {
                'id': 'a',
                'caseNumber': 'DG-1',
                'status': 'VERIFIED',
                'submittedAt': '2026-10-12T02:00:00Z',
                'completedAt': '2026-10-12T04:00:00Z',
                'diseaseCode': 'BROWN_SPOT',
                'diseaseName': 'Brown Spot',
              },
              {
                'id': 'b',
                'caseNumber': 'DG-2',
                'status': 'AI_COMPLETED',
                'submittedAt': '2026-10-12T03:00:00Z',
                'completedAt': null,
                'diseaseCode': null,
                'diseaseName': null,
              },
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 30,
            'totalPages': 2,
          }));
      final r = await repo.list(status: 'VERIFIED');

      expect(adapter.requests.single.queryParameters,
          {'page': 1, 'pageSize': 20, 'status': 'VERIFIED'});
      expect(r.items.first.diseaseDisplay, 'Đốm nâu');
      expect(r.items.last.diseaseDisplay, isNull);
      expect(r.hasMore, isTrue);
    });

    test('mọi bộ lọc của app là trạng thái hợp lệ của backend', () {
      const backend = {'SUBMITTED', 'PROCESSING', 'AI_COMPLETED', 'UNDER_REVIEW', 'VERIFIED',
        'INCONCLUSIVE', 'FAILED', 'CANCELLED'};
      for (final f in DiagnosisStatus.filters.whereType<String>()) {
        expect(backend, contains(f));
      }
    });
  });

  group('huỷ', () {
    test('POST đúng URL, lý do (nếu có) đã trim', () async {
      use((o) => jsonBody(200, caseJson('c1', status: 'CANCELLED')));
      final c = await repo.cancel('c1', reason: '  Chụp nhầm ');
      expect(adapter.requests.single.path, '/api/me/diagnosis-cases/c1/cancel');
      expect(adapter.requests.single.data, {'reason': 'Chụp nhầm'});
      expect(c.status, 'CANCELLED');
    });

    test('không có lý do thì gửi body rỗng', () async {
      use((o) => jsonBody(200, caseJson('c1', status: 'CANCELLED')));
      await repo.cancel('c1');
      expect(adapter.requests.single.data, <String, dynamic>{});
    });

    test('đã có kết luận / đã huỷ (422) → thông báo', () async {
      use((o) => jsonBody(422, {'status': 422, 'detail': "Diagnosis case 'DG-1' is Cancelled; this action is not allowed."}));
      expect(repo.cancel('c1'), failsWith('không thể huỷ'));
    });

    test('404', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(repo.cancel('c1'), failsWith('Không tìm thấy ca chẩn đoán'));
    });
  });
}

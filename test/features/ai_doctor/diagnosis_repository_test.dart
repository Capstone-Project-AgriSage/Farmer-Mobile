import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_models.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';
import 'package:farmer_mobile/features/ai_doctor/data/photo_type.dart';
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

    test('đã đọc byte đầu: loại THẬT quyết định, đuôi file sai vẫn nhận', () {
      // Tên .heic nhưng thực chất là JPEG (điện thoại đổi tên) → nhận.
      expect(
          DiagnosisRepository.validatePhoto(const PickedPhoto(
              path: 'p', name: 'a.heic', sizeBytes: 10, type: PhotoType.jpeg, typeChecked: true)),
          isNull);
      // Tên .jpg nhưng không phải ảnh → từ chối.
      expect(
          DiagnosisRepository.validatePhoto(
              const PickedPhoto(path: 'p', name: 'a.jpg', sizeBytes: 10, typeChecked: true)),
          contains('JPEG, PNG hoặc WebP'));
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
      use((o) => jsonBody(
          201, caseJson('c1', status: 'AI_COMPLETED', note: 'Lá vàng', result: aiResultJson())));
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
      expect(c.isWaiting, isFalse, reason: 'AI chạy xong trong yêu cầu gửi ảnh');
      expect(c.result!.certainty, DiagnosisCertainty.confident);
    });

    test('ghi chú trống thì không gửi trường note', () async {
      use((o) => jsonBody(201, caseJson('c1')));
      await repo.create(photo: photo(), note: '   ');
      expect((adapter.requests.single.data as FormData).fields, isEmpty);
    });

    test('gửi theo loại THẬT của ảnh, không theo đuôi file', () async {
      use((o) => jsonBody(201, caseJson('c1')));
      await repo.create(
          photo: PickedPhoto(
              path: jpg.path, name: 'a.heic', sizeBytes: 64, type: PhotoType.png, typeChecked: true));
      expect((adapter.requests.single.data as FormData).files.single.value.contentType.toString(),
          'image/png');
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
    test('chỉ SUBMITTED / PROCESSING là đang phân tích; huỷ được khi chưa có kết quả', () {
      for (final s in ['SUBMITTED', 'PROCESSING']) {
        expect(DiagnosisStatus.isWaiting(s), isTrue, reason: s);
        expect(DiagnosisStatus.canCancel(s), isTrue, reason: s);
        expect(DiagnosisStatus.label(s), 'Đang phân tích', reason: s);
      }
      expect(DiagnosisStatus.isWaiting('FAILED'), isFalse);
      expect(DiagnosisStatus.canCancel('FAILED'), isTrue);
      expect(DiagnosisStatus.label('FAILED'), 'Chưa phân tích được');
      for (final s in ['AI_COMPLETED', 'UNDER_REVIEW']) {
        expect(DiagnosisStatus.isWaiting(s), isFalse, reason: s);
        expect(DiagnosisStatus.canCancel(s), isFalse, reason: s);
        expect(DiagnosisStatus.label(s), 'Đã có kết quả', reason: s);
      }
      for (final s in ['VERIFIED', 'INCONCLUSIVE', 'CANCELLED']) {
        expect(DiagnosisStatus.isWaiting(s), isFalse, reason: s);
        expect(DiagnosisStatus.canCancel(s), isFalse, reason: s);
      }
      expect(DiagnosisStatus.label('VERIFIED'), 'Đã xác nhận');
      expect(DiagnosisStatus.label(null), 'Tất cả');
    });

    test('kết quả AI chắc chắn: mức chắc chắn, hoạt chất của cách xử lý, sản phẩm gợi ý', () async {
      use((o) => jsonBody(200, caseJson('c1', status: 'AI_COMPLETED', result: aiResultJson())));
      final c = await repo.get('c1');
      final r = c.result!;
      expect(r.certainty, DiagnosisCertainty.confident);
      expect(r.isFromAi, isTrue);
      expect(r.isUncertain, isFalse);
      expect(r.hint, isNull);
      expect(r.reviewerComment, isNull);
      expect(r.treatments.first.activeIngredientName, 'Tricyclazole');
      expect(r.treatments.last.activeIngredientName, isNull);
      expect(r.products.map((p) => p.storeProductId), ['sp1', 'sp2']);
      expect(c.canRetry, isFalse);
    });

    test('AI chưa chắc: gợi ý chụp lại hoặc hỏi cửa hàng, không có thuốc / sản phẩm', () async {
      use((o) => jsonBody(
          200, caseJson('c1', status: 'AI_COMPLETED', result: aiResultJson(uncertain: true))));
      final r = (await repo.get('c1')).result!;
      expect(r.certainty, DiagnosisCertainty.uncertain);
      expect(r.isUncertain, isTrue);
      expect(r.hint, 'RETAKE_PHOTO_OR_ASK_STORE');
      expect(r.treatments.map((t) => t.type), isNot(contains('CHEMICAL')));
      expect(r.products, isEmpty);
    });

    test('ca cũ không có trường certainty: coi như cửa hàng đã xác nhận', () async {
      use((o) => jsonBody(
          200, caseJson('c1', status: 'VERIFIED', result: resultJson()..remove('certainty'))));
      final r = (await repo.get('c1')).result!;
      expect(r.certainty, DiagnosisCertainty.verified);
      expect(r.isFromAi, isFalse);
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
      expect(r.certainty, DiagnosisCertainty.verified);
    });

    test('ca đang phân tích: chưa có result / inconclusive, chưa cần thử lại', () async {
      use((o) => jsonBody(200, caseJson('c1')));
      final c = await repo.get('c1');
      expect(c.result, isNull);
      expect(c.inconclusive, isNull);
      expect(c.canRetry, isFalse);
    });

    test('AI chưa phân tích được: canRetry; thiếu trường canRetry thì coi là không', () async {
      use((o) => jsonBody(200, caseJson('c1', status: 'FAILED')));
      expect((await repo.get('c1')).canRetry, isTrue);
      use((o) => jsonBody(200, caseJson('c1', status: 'FAILED')..remove('canRetry')));
      expect((await repo.get('c1')).canRetry, isFalse);
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
    test('phân trang + lọc trạng thái; ca có kết quả có tên bệnh và mức chắc chắn', () async {
      use((o) => jsonBody(200, {
            'items': [
              {
                'id': 'a',
                'caseNumber': 'DG-1',
                'status': 'AI_COMPLETED',
                'submittedAt': '2026-10-12T02:00:00Z',
                'completedAt': '2026-10-12T02:00:05Z',
                'diseaseCode': 'BROWN_SPOT',
                'diseaseName': 'Brown Spot',
                'certainty': 'CONFIDENT',
              },
              {
                'id': 'b',
                'caseNumber': 'DG-2',
                'status': 'AI_COMPLETED',
                'submittedAt': '2026-10-12T03:00:00Z',
                'completedAt': '2026-10-12T03:00:05Z',
                'diseaseCode': 'LEAF_BLAST',
                'diseaseName': 'Leaf Blast',
                'certainty': 'UNCERTAIN',
              },
              {
                'id': 'c',
                'caseNumber': 'DG-3',
                'status': 'PROCESSING',
                'submittedAt': '2026-10-12T04:00:00Z',
                'completedAt': null,
                'diseaseCode': null,
                'diseaseName': null,
                'certainty': null,
              },
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 30,
            'totalPages': 2,
          }));
      final r = await repo.list(status: 'AI_COMPLETED');

      expect(adapter.requests.single.queryParameters,
          {'page': 1, 'pageSize': 20, 'status': 'AI_COMPLETED'});
      expect(r.items[0].diseaseDisplay, 'Đốm nâu');
      expect(r.items[0].isUncertain, isFalse);
      expect(r.items[1].diseaseDisplay, 'Đạo ôn lá');
      expect(r.items[1].isUncertain, isTrue);
      expect(r.items[2].diseaseDisplay, isNull);
      expect(r.items[2].certainty, isNull);
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

  group('thử lại', () {
    test('POST đúng URL, timeout dài như lúc gửi ảnh, trả về ca đã có kết quả', () async {
      use((o) => jsonBody(200, caseJson('c1', status: 'AI_COMPLETED', result: aiResultJson())));
      final c = await repo.retry('c1');
      final req = adapter.requests.single;
      expect(req.path, '/api/me/diagnosis-cases/c1/retry');
      expect(req.method, 'POST');
      expect(req.sendTimeout, const Duration(seconds: 90));
      expect(req.receiveTimeout, const Duration(seconds: 90));
      expect(c.result!.certainty, DiagnosisCertainty.confident);
    });

    test('AI vẫn chưa sẵn sàng (503) → báo thử lại sau', () async {
      use((o) => jsonBody(503, {'status': 503}));
      expect(repo.retry('c1'), failsWith('Dịch vụ AI đang bận'));
    });

    test('ca đã có kết quả / đã huỷ (422) → báo không cần phân tích lại', () async {
      use((o) => jsonBody(422, {'status': 422}));
      expect(repo.retry('c1'), failsWith('không cần phân tích lại'));
    });

    test('429 → báo chờ; 404 → không tìm thấy', () async {
      use((o) => jsonBody(429, {'status': 429}));
      expect(repo.retry('c1'), failsWith('quá nhanh'));
      use((o) => jsonBody(404, {'status': 404}));
      expect(repo.retry('c1'), failsWith('Không tìm thấy ca chẩn đoán'));
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

    test('đã có kết quả / đã huỷ (422) → thông báo', () async {
      use((o) => jsonBody(422, {'status': 422, 'detail': "Diagnosis case 'DG-1' is Cancelled; this action is not allowed."}));
      expect(repo.cancel('c1'), failsWith('không thể huỷ'));
    });

    test('404', () async {
      use((o) => jsonBody(404, {'status': 404}));
      expect(repo.cancel('c1'), failsWith('Không tìm thấy ca chẩn đoán'));
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/labels/diagnosis_labels.dart';
import 'package:farmer_mobile/core/labels/status_label.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/features/diagnosis/data/diagnosis_models.dart';
import 'package:farmer_mobile/features/diagnosis/data/diagnosis_photo.dart';
import 'package:farmer_mobile/features/diagnosis/data/diagnosis_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../support/diagnosis_fixtures.dart';
import '../../support/order_fixtures.dart' show pageOf;

/// Records the request and answers with a fixed body, so the multipart form can be inspected.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), statusCode, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('models', () {
    test('a waiting case has no result and can be withdrawn', () {
      final item = DiagnosisCase.fromJson(waitingCaseJson());
      expect(item.caseNumber, 'DG-20261010-0001');
      expect(item.isWaiting, isTrue);
      expect(item.isVerified, isFalse);
      expect(item.canCancel, isTrue);
      expect(item.farmerNote, 'Lá vàng từ chóp');
      expect(item.photo?.imageUrl, startsWith('https://storage.test/'));
      expect(item.photo?.expiresAt, DateTime.utc(2026, 10, 10, 10));
      expect(item.submittedAt, DateTime.utc(2026, 10, 10, 9, 10));
    });

    test('every stage before the reviewer decides counts as waiting, including a failed AI run', () {
      for (final status in ['SUBMITTED', 'PROCESSING', 'AI_COMPLETED', 'UNDER_REVIEW', 'FAILED']) {
        expect(DiagnosisCase.fromJson(waitingCaseJson(status: status)).isWaiting, isTrue, reason: status);
      }
      for (final status in ['VERIFIED', 'INCONCLUSIVE', 'CANCELLED']) {
        expect(DiagnosisCase.fromJson(waitingCaseJson(status: status)).isWaiting, isFalse, reason: status);
        expect(DiagnosisCase.fromJson(waitingCaseJson(status: status)).canCancel, isFalse, reason: status);
      }
    });

    test('a verified case reads the disease, the guidance and the products', () {
      final item = DiagnosisCase.fromJson(verifiedCaseJson());
      expect(item.isVerified, isTrue);
      final result = item.result!;
      expect(result.disease.code, 'LEAF_BLAST');
      expect(result.disease.isHealthy, isFalse);
      expect(result.reviewerComment, 'Vết bệnh điển hình, nên xử lý sớm.');
      expect(result.treatments.map((t) => t.type), ['CHEMICAL', 'CULTURAL']);
      expect(result.treatments.first.precautions, 'Không phun lúc nắng gắt.');
      expect(result.treatments.last.precautions, isNull);
      expect(result.products.single.productId, 'p-1');
      expect(result.products.single.storeProductId, 'sp-1');
    });

    test('"verified" without a result is not treated as verified', () {
      final item = DiagnosisCase.fromJson({...waitingCaseJson(status: 'VERIFIED'), 'result': null});
      expect(item.isVerified, isFalse);
    });

    test('an inconclusive case keeps the reviewer comment', () {
      final item = DiagnosisCase.fromJson(inconclusiveCaseJson());
      expect(item.isInconclusive, isTrue);
      expect(item.inconclusive?.comment, 'Ảnh bị mờ, chưa thấy rõ vết bệnh.');
      expect(item.inconclusive?.hint, 'RETAKE_PHOTO');
    });

    test('missing optional parts do not break reading a case', () {
      final item = DiagnosisCase.fromJson({'id': 'x', 'caseNumber': 'DG-1', 'status': 'VERIFIED', 'result': <String, dynamic>{}});
      expect(item.photo, isNull);
      expect(item.submittedAt, isNull);
      expect(item.result?.treatments, isEmpty);
      expect(item.result?.products, isEmpty);
    });

    test('a list row carries the disease only once verified', () {
      final waiting = DiagnosisCaseListItem.fromJson(caseListRow());
      expect(waiting.diseaseCode, isNull);
      final done = DiagnosisCaseListItem.fromJson(caseListRow(status: 'VERIFIED', diseaseCode: 'BROWN_SPOT', diseaseName: 'Đốm nâu'));
      expect(done.diseaseCode, 'BROWN_SPOT');
      expect(done.status, DiagnosisStatus.verified);
    });
  });

  group('labels', () {
    test('all waiting stages show the same words, so the AI stage is never shown', () {
      final words = {
        for (final status in ['SUBMITTED', 'PROCESSING', 'AI_COMPLETED', 'UNDER_REVIEW', 'FAILED']) labelOf(diagnosisStatusLabels, status).label,
      };
      expect(words, {'Đang chờ chuyên viên xem'});
    });

    test('the decided stages and an unknown status', () {
      expect(labelOf(diagnosisStatusLabels, 'VERIFIED').label, 'Đã có kết quả');
      expect(labelOf(diagnosisStatusLabels, 'INCONCLUSIVE').label, 'Cần chụp lại ảnh');
      expect(labelOf(diagnosisStatusLabels, 'CANCELLED').label, 'Đã hủy');
      expect(labelOf(diagnosisStatusLabels, 'SOMETHING_NEW').label, 'SOMETHING_NEW');
    });

    test('the five classes have farmer wording; another disease uses the server name', () {
      expect(diseaseDisplayName('LEAF_BLAST'), 'Bệnh đạo ôn');
      expect(diseaseDisplayName('BACTERIAL_LEAF_BLIGHT'), 'Bệnh bạc lá (cháy bìa lá)');
      expect(diseaseDisplayName('BROWN_SPOT'), 'Bệnh đốm nâu');
      expect(diseaseDisplayName('SHEATH_BLIGHT'), 'Bệnh khô vằn');
      expect(diseaseDisplayName('HEALTHY'), 'Lá lúa khỏe mạnh');
      expect(diseaseDisplayName('RICE_HISPA', fallback: 'Sâu gai'), 'Sâu gai');
      expect(diseaseDisplayName(null), '—');
    });

    test('treatment types', () {
      expect(treatmentTypeLabel('CHEMICAL'), 'Thuốc / hóa chất');
      expect(treatmentTypeLabel('SOMETHING'), 'SOMETHING');
    });
  });

  group('photo type from the first bytes', () {
    test('JPEG, PNG and WebP are recognised', () {
      expect(detectDiagnosisImageType([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0]), DiagnosisImageType.jpeg);
      expect(detectDiagnosisImageType([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]), DiagnosisImageType.png);
      expect(detectDiagnosisImageType([0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50]), DiagnosisImageType.webp);
    });

    test('anything else is refused, whatever its name says', () {
      expect(detectDiagnosisImageType(utf8.encode('GIF89a......')), isNull);
      expect(detectDiagnosisImageType(utf8.encode('%PDF-1.7.....')), isNull);
      // RIFF container that is not WebP (a WAV file).
      expect(detectDiagnosisImageType([0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x41, 0x56, 0x45]), isNull);
      expect(detectDiagnosisImageType([0xFF, 0xD8]), isNull, reason: 'too short to be a JPEG header');
      expect(detectDiagnosisImageType([]), isNull);
    });
  });

  group('repository', () {
    late Dio dio;
    late DioAdapter adapter;
    late DiagnosisRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      adapter = DioAdapter(dio: dio);
      repo = DiagnosisRepository(dio);
    });

    test('the list sends the status and the page', () async {
      adapter.onGet(
        '/api/me/diagnosis-cases',
        (server) => server.reply(200, pageOf([caseListRow(status: 'VERIFIED', diseaseCode: 'LEAF_BLAST')], total: 21)),
        queryParameters: {'status': 'VERIFIED', 'page': 1, 'pageSize': 20},
      );

      final page = await repo.list(status: 'VERIFIED');
      expect(page.items.single.diseaseCode, 'LEAF_BLAST');
      expect(page.hasMore, isTrue);
    });

    test('the list for "all" sends no status', () async {
      adapter.onGet('/api/me/diagnosis-cases', (server) => server.reply(200, pageOf([])), queryParameters: {'page': 1, 'pageSize': 20});
      expect((await repo.list()).items, isEmpty);
    });

    test('one case', () async {
      adapter.onGet('/api/me/diagnosis-cases/dg-1', (server) => server.reply(200, verifiedCaseJson()));
      expect((await repo.get('dg-1')).isVerified, isTrue);
    });

    test('cancelling sends the reason, or null when there is none', () async {
      adapter.onPost('/api/me/diagnosis-cases/dg-1/cancel', (server) => server.reply(200, cancelledCaseJson()), data: {'reason': 'Gửi nhầm ảnh'});
      adapter.onPost('/api/me/diagnosis-cases/dg-2/cancel', (server) => server.reply(200, cancelledCaseJson(id: 'dg-2')), data: {'reason': null});

      expect((await repo.cancel('dg-1', reason: '  Gửi nhầm ảnh ')).isCancelled, isTrue);
      expect((await repo.cancel('dg-2', reason: '   ')).isCancelled, isTrue);
    });

    test('a failure comes back as a Vietnamese AppException', () async {
      adapter.onGet(
        '/api/me/diagnosis-cases/missing',
        (server) => server.reply(404, {'title': 'Not found', 'status': 404}),
      );
      await expectLater(repo.get('missing'), throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.notFound)));
    });

    group('sending a photo', () {
      late Directory temp;
      late File jpeg;

      setUp(() {
        temp = Directory.systemTemp.createTempSync('diagnosis_test');
        jpeg = File('${temp.path}/photo.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5, 6, 7, 8]);
      });

      tearDown(() {
        // Windows keeps the photo open until the upload stream is collected; the system cleans the temp folder anyway.
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // ignore
        }
      });

      test('posts a multipart form with the image and the trimmed note', () async {
        final recording = _RecordingAdapter(201, waitingCaseJson());
        dio.httpClientAdapter = recording;

        final created = await repo.create(
          DiagnosisPhotoFile(path: jpeg.path, sizeBytes: 12, type: DiagnosisImageType.jpeg),
          note: '  Lá vàng từ chóp  ',
        );

        expect(created.isWaiting, isTrue);
        final request = recording.last!;
        expect(request.method, 'POST');
        expect(request.path, '/api/me/diagnosis-cases');
        final form = request.data as FormData;
        expect(form.fields.map((e) => '${e.key}=${e.value}'), ['note=Lá vàng từ chóp']);
        final file = form.files.single;
        expect(file.key, 'image');
        expect(file.value.filename, 'leaf.jpg');
        expect(file.value.contentType.toString(), 'image/jpeg');
        expect(file.value.length, 12);
      });

      test('leaves the note out when it is blank', () async {
        final recording = _RecordingAdapter(201, waitingCaseJson(note: null));
        dio.httpClientAdapter = recording;

        await repo.create(DiagnosisPhotoFile(path: jpeg.path, sizeBytes: 12, type: DiagnosisImageType.jpeg), note: '   ');

        expect((recording.last!.data as FormData).fields, isEmpty);
      });

      test('allows the AI call time to answer', () async {
        final recording = _RecordingAdapter(201, waitingCaseJson());
        dio.httpClientAdapter = recording;

        await repo.create(DiagnosisPhotoFile(path: jpeg.path, sizeBytes: 12, type: DiagnosisImageType.jpeg));

        expect(recording.last!.receiveTimeout, const Duration(seconds: 60));
        expect(recording.last!.sendTimeout, const Duration(seconds: 60));
      });
    });
  });
}

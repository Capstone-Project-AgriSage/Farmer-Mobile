import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/network/paged.dart';
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/image_capture_screen.dart';
import 'package:farmer_mobile/features/diagnosis/data/diagnosis_models.dart';
import 'package:farmer_mobile/features/diagnosis/data/diagnosis_photo.dart';
import 'package:farmer_mobile/features/diagnosis/data/diagnosis_repository.dart';
import 'package:farmer_mobile/features/diagnosis/screens/diagnosis_case_screen.dart';
import 'package:farmer_mobile/features/diagnosis/screens/diagnosis_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/diagnosis_fixtures.dart';
import '../cart/cart_controller_test.dart' show TestUserId;

class MockDiagnosisRepository extends Mock implements DiagnosisRepository {}

/// A camera and gallery that answer with what the test says.
class FakePhotoService implements DiagnosisPhotoService {
  DiagnosisPhotoFile? next;
  DiagnosisPhotoFile? lost;
  Object? error;
  final picked = <ImageSource>[];

  @override
  Future<DiagnosisPhotoFile?> pick(ImageSource source) async {
    picked.add(source);
    if (error != null) throw error!;
    return next;
  }

  @override
  Future<DiagnosisPhotoFile?> recoverLostPhoto() async => lost;
}

// A 1x1 PNG, so Image.file has something real to decode.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

void main() {
  late MockDiagnosisRepository repo;
  late FakePhotoService photos;
  late SharedPreferences prefs;
  late Directory temp;
  late DiagnosisPhotoFile photo;

  setUpAll(() {
    registerFallbackValue(const DiagnosisPhotoFile(path: 'x', sizeBytes: 1, type: DiagnosisImageType.jpeg));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = MockDiagnosisRepository();
    photos = FakePhotoService();
    temp = Directory.systemTemp.createTempSync('diagnosis_widget_test');
    final file = File('${temp.path}/leaf.png')..writeAsBytesSync(_png);
    photo = DiagnosisPhotoFile(path: file.path, sizeBytes: _png.length, type: DiagnosisImageType.png);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Future<GoRouter> pump(WidgetTester tester, Widget home) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: '/ai-scan', builder: (_, __) => const Scaffold(body: Text('SCAN HOME'))),
        GoRoute(path: '/ai-scan/capture', builder: (_, __) => const ImageCaptureScreen()),
        GoRoute(path: '/ai-scan/history', builder: (_, __) => const DiagnosisHistoryScreen()),
        GoRoute(path: '/ai-scan/cases/:id', builder: (_, state) => DiagnosisCaseScreen(caseId: state.pathParameters['id']!)),
        GoRoute(path: '/products/:id', builder: (_, state) => Scaffold(body: Text('PRODUCT ${state.pathParameters['id']}'))),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosisRepositoryProvider.overrideWithValue(repo),
          diagnosisPhotoServiceProvider.overrideWithValue(photos),
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Paged<DiagnosisCaseListItem> rows(List<Map<String, dynamic>> items) =>
      Paged(items: items.map(DiagnosisCaseListItem.fromJson).toList(), page: 1, pageSize: 20, totalCount: items.length);

  void stubList(Paged<DiagnosisCaseListItem> Function(String? status) answer) {
    when(() => repo.list(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .thenAnswer((invocation) async => answer(invocation.namedArguments[#status] as String?));
  }

  void stubCase(Map<String, dynamic> json) {
    when(() => repo.get(any())).thenAnswer((_) async => DiagnosisCase.fromJson(json));
  }

  group('history', () {
    testWidgets('lists each case with its status, date and, once verified, the disease', (tester) async {
      stubList((_) => rows([
            caseListRow(id: 'dg-1', number: 'DG-1', status: 'AI_COMPLETED'),
            caseListRow(id: 'dg-2', number: 'DG-2', status: 'VERIFIED', diseaseCode: 'BROWN_SPOT', diseaseName: 'Đốm nâu'),
          ]));
      await pump(tester, const DiagnosisHistoryScreen());

      expect(find.text('#DG-1'), findsOneWidget);
      expect(find.text('Đang chờ chuyên viên xem'), findsOneWidget);
      expect(find.text('#DG-2'), findsOneWidget);
      expect(find.text('Bệnh đốm nâu'), findsOneWidget);
      expect(find.text('16:10 10/10/2026'), findsWidgets, reason: '09:10 UTC is 16:10 in Vietnam');
    });

    testWidgets('a waiting case never shows a disease, even if the server sent one', (tester) async {
      stubList((_) => rows([caseListRow(status: 'UNDER_REVIEW', diseaseCode: 'LEAF_BLAST', diseaseName: 'Đạo ôn')]));
      await pump(tester, const DiagnosisHistoryScreen());

      expect(find.text('Bệnh đạo ôn'), findsNothing);
      expect(find.text('Đạo ôn'), findsNothing);
    });

    testWidgets('a tab asks the server for that status', (tester) async {
      stubList((status) => status == 'VERIFIED'
          ? rows([caseListRow(number: 'DG-DONE', status: 'VERIFIED', diseaseCode: 'LEAF_BLAST')])
          : rows([caseListRow(number: 'DG-ALL')]));
      await pump(tester, const DiagnosisHistoryScreen());
      expect(find.text('#DG-ALL'), findsOneWidget);

      await tester.tap(find.text('Đã có kết quả').first);
      await tester.pumpAndSettle();

      expect(find.text('#DG-DONE'), findsOneWidget);
      expect(find.text('#DG-ALL'), findsNothing);
      verify(() => repo.list(status: 'VERIFIED', page: 1, pageSize: 20)).called(1);
    });

    testWidgets('no cases at all, and no cases in a status, say different things', (tester) async {
      stubList((_) => rows([]));
      await pump(tester, const DiagnosisHistoryScreen());
      expect(find.text('Bác chưa gửi ảnh nào để chẩn đoán'), findsOneWidget);

      await tester.tap(find.text('Đã hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Không có ca nào ở mục này'), findsOneWidget);
    });

    testWidgets('a failure shows the message and a retry that works', (tester) async {
      var fail = true;
      when(() => repo.list(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) async {
        if (fail) throw const AppException.offline();
        return rows([caseListRow(number: 'DG-BACK')]);
      });
      await pump(tester, const DiagnosisHistoryScreen());
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('#DG-BACK'), findsOneWidget);
    });

    testWidgets('tapping a case opens it', (tester) async {
      stubList((_) => rows([caseListRow(id: 'dg-9', number: 'DG-9')]));
      stubCase(waitingCaseJson(id: 'dg-9'));
      await pump(tester, const DiagnosisHistoryScreen());

      await tester.tap(find.text('#DG-9'));
      await tester.pumpAndSettle();

      expect(find.text('Kết quả chẩn đoán'), findsOneWidget);
      verify(() => repo.get('dg-9')).called(1);
    });
  });

  group('case', () {
    Future<void> open(WidgetTester tester) => pump(tester, const DiagnosisCaseScreen(caseId: 'dg-1'));

    testWidgets('waiting: says a specialist is looking, shows no AI answer, and can be withdrawn', (tester) async {
      stubCase(waitingCaseJson(status: 'AI_COMPLETED'));
      await open(tester);

      expect(find.text('#DG-20261010-0001'), findsOneWidget);
      expect(find.text('Đang chờ chuyên viên xem'), findsWidgets);
      expect(find.text('Ghi chú của Bác: Lá vàng từ chóp'), findsOneWidget);
      expect(find.text('Hủy yêu cầu'), findsOneWidget);
      expect(find.text('Cách xử lý'), findsNothing);
      expect(find.text('Chuyên viên xác nhận bệnh'), findsNothing);
    });

    testWidgets('waiting: withdrawing asks first, then cancels and shows the cancelled case', (tester) async {
      stubCase(waitingCaseJson());
      when(() => repo.cancel('dg-1', reason: any(named: 'reason'))).thenAnswer((_) async {
        stubCase(cancelledCaseJson());
        return DiagnosisCase.fromJson(cancelledCaseJson());
      });
      await open(tester);

      await tester.tap(find.text('Hủy yêu cầu'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy yêu cầu này?'), findsOneWidget);
      verifyNever(() => repo.cancel(any(), reason: any(named: 'reason')));

      await tester.tap(find.widgetWithText(TextButton, 'Hủy yêu cầu'));
      await tester.pumpAndSettle();

      verify(() => repo.cancel('dg-1', reason: any(named: 'reason'))).called(1);
      expect(find.text('Yêu cầu này đã hủy'), findsOneWidget);
    });

    testWidgets('waiting: "giữ lại" leaves the case alone', (tester) async {
      stubCase(waitingCaseJson());
      await open(tester);

      await tester.tap(find.text('Hủy yêu cầu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();

      verifyNever(() => repo.cancel(any(), reason: any(named: 'reason')));
      expect(find.text('Đang chờ chuyên viên xem'), findsWidgets);
    });

    testWidgets('verified: shows the disease, the guidance, the reviewer comment and the products', (tester) async {
      stubCase(verifiedCaseJson());
      await open(tester);

      expect(find.text('Đã có kết quả'), findsOneWidget);
      expect(find.text('Chuyên viên xác nhận bệnh'), findsOneWidget);
      expect(find.text('Bệnh đạo ôn'), findsOneWidget);
      expect(find.text('Vết bệnh hình thoi, tâm xám xanh, viền nâu.'), findsOneWidget);
      expect(find.text('Vết bệnh điển hình, nên xử lý sớm.'), findsOneWidget);
      expect(find.text('Hủy yêu cầu'), findsNothing, reason: 'a decided case cannot be withdrawn');

      await tester.scrollUntilVisible(find.text('Phun thuốc đặc trị đạo ôn'), 250, scrollable: find.byType(Scrollable).first);
      expect(find.text('Thuốc / hóa chất'), findsOneWidget);
      expect(find.text('Lưu ý: Không phun lúc nắng gắt.'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Thuốc trừ bệnh Fuji-One 40EC'), 250, scrollable: find.byType(Scrollable).first);
      expect(find.text('Đặc trị đạo ôn lá'), findsOneWidget);
    });

    testWidgets('verified: a recommended product opens its catalog page', (tester) async {
      stubCase(verifiedCaseJson());
      await open(tester);

      await tester.scrollUntilVisible(find.text('Thuốc trừ bệnh Fuji-One 40EC'), 250, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Thuốc trừ bệnh Fuji-One 40EC')); // built is not the same as on screen
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thuốc trừ bệnh Fuji-One 40EC'));
      await tester.pumpAndSettle();

      expect(find.text('PRODUCT p-1'), findsOneWidget);
    });

    testWidgets('verified healthy leaf has no treatments or products section', (tester) async {
      stubCase(verifiedCaseJson(result: {
        'disease': {'id': 'ds-5', 'code': 'HEALTHY', 'name': 'Khỏe mạnh', 'isHealthy': true},
        'reviewerComment': null,
        'treatments': [],
        'products': [],
      }));
      await open(tester);

      expect(find.text('Lá lúa khỏe mạnh'), findsOneWidget);
      expect(find.text('Kết luận'), findsOneWidget);
      expect(find.text('Cách xử lý'), findsNothing);
      expect(find.text('Sản phẩm gợi ý của đại lý'), findsNothing);
    });

    testWidgets('inconclusive: gives the reviewer comment and a way to retake the photo', (tester) async {
      stubCase(inconclusiveCaseJson());
      await open(tester);

      expect(find.text('Chưa thể kết luận từ ảnh này'), findsOneWidget);
      expect(find.text('Ảnh bị mờ, chưa thấy rõ vết bệnh.'), findsOneWidget);

      await tester.tap(find.text('Chụp lại ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Chụp ảnh lá lúa'), findsOneWidget);
    });

    testWidgets('inconclusive without a comment still explains what to do', (tester) async {
      stubCase(inconclusiveCaseJson(comment: null));
      await open(tester);

      expect(find.textContaining('chụp lại ảnh rõ hơn'), findsOneWidget);
    });

    testWidgets('cancelled: says so and offers no withdraw button', (tester) async {
      stubCase(cancelledCaseJson());
      await open(tester);

      expect(find.text('Yêu cầu này đã hủy'), findsOneWidget);
      expect(find.text('Hủy yêu cầu'), findsNothing);
    });

    testWidgets('a missing case shows the error with a retry', (tester) async {
      var fail = true;
      when(() => repo.get(any())).thenAnswer((_) async {
        if (fail) throw const AppException(kind: AppErrorKind.notFound, message: 'Không tìm thấy yêu cầu chẩn đoán.');
        return DiagnosisCase.fromJson(waitingCaseJson());
      });
      await open(tester);
      expect(find.text('Không tìm thấy yêu cầu chẩn đoán.'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('#DG-20261010-0001'), findsOneWidget);
    });
  });

  group('photo page', () {
    Future<void> open(WidgetTester tester) => pump(tester, const ImageCaptureScreen());

    testWidgets('nothing can be sent before a photo is chosen', (tester) async {
      await open(tester);

      expect(find.text('Chạm để chụp ảnh lá lúa'), findsOneWidget);
      expect(find.text('Gửi ảnh cho chuyên viên'), findsNothing);
      expect(find.textContaining('Sắp ra mắt'), findsNothing);
    });

    testWidgets('the camera and the gallery buttons ask the photo service', (tester) async {
      await open(tester);

      await tester.tap(find.text('Chụp ảnh mới'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      expect(photos.picked, [ImageSource.camera, ImageSource.gallery]);
    });

    testWidgets('a chosen photo can be sent with a note, and the case screen opens', (tester) async {
      photos.next = photo;
      stubCase(waitingCaseJson(id: 'dg-new'));
      when(() => repo.create(any(), note: any(named: 'note'))).thenAnswer((_) async => DiagnosisCase.fromJson(waitingCaseJson(id: 'dg-new')));
      await open(tester);

      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();
      expect(find.text('Ảnh sẵn sàng'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Lá vàng từ chóp');
      await tester.tap(find.text('Gửi ảnh cho chuyên viên'));
      await tester.pumpAndSettle();

      final sent = verify(() => repo.create(captureAny(), note: captureAny(named: 'note'))).captured;
      expect((sent[0] as DiagnosisPhotoFile).path, photo.path);
      expect(sent[1], 'Lá vàng từ chóp');
      expect(find.text('Kết quả chẩn đoán'), findsOneWidget);
      expect(find.text('Gửi ảnh cho chuyên viên'), findsNothing, reason: 'the photo page was replaced');
    });

    testWidgets('while sending the button is disabled, so the photo is not sent twice', (tester) async {
      photos.next = photo;
      final answer = Completer<DiagnosisCase>();
      when(() => repo.create(any(), note: any(named: 'note'))).thenAnswer((_) => answer.future);
      stubCase(waitingCaseJson(id: 'dg-new'));
      await open(tester);
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi ảnh cho chuyên viên'));
      await tester.pump();
      expect(find.text('Đang gửi ảnh...'), findsOneWidget);
      await tester.tap(find.text('Đang gửi ảnh...'));
      await tester.pump();

      verify(() => repo.create(any(), note: any(named: 'note'))).called(1);

      answer.complete(DiagnosisCase.fromJson(waitingCaseJson(id: 'dg-new')));
      await tester.pumpAndSettle();
      expect(find.text('Kết quả chẩn đoán'), findsOneWidget);
    });

    testWidgets('a failed send keeps the photo and says why', (tester) async {
      photos.next = photo;
      when(() => repo.create(any(), note: any(named: 'note')))
          .thenThrow(const AppException(kind: AppErrorKind.server, message: 'Hệ thống đang bận. Vui lòng thử lại sau.'));
      await open(tester);
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi ảnh cho chuyên viên'));
      await tester.pumpAndSettle();

      expect(find.text('Hệ thống đang bận. Vui lòng thử lại sau.'), findsOneWidget);
      expect(find.text('Ảnh sẵn sàng'), findsOneWidget);
      expect(find.text('Gửi ảnh cho chuyên viên'), findsOneWidget, reason: 'the farmer can try again');
    });

    testWidgets('a photo that cannot be used is explained, and nothing is chosen', (tester) async {
      photos.error = const DiagnosisPhotoException('Ảnh quá lớn (tối đa 5 MB). Bác vui lòng chụp lại.');
      await open(tester);

      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      expect(find.text('Ảnh quá lớn (tối đa 5 MB). Bác vui lòng chụp lại.'), findsOneWidget);
      expect(find.text('Gửi ảnh cho chuyên viên'), findsNothing);
    });

    testWidgets('backing out of the camera leaves things as they were', (tester) async {
      photos.next = null;
      await open(tester);

      await tester.tap(find.text('Chụp ảnh mới'));
      await tester.pumpAndSettle();

      expect(find.text('Chạm để chụp ảnh lá lúa'), findsOneWidget);
    });

    testWidgets('a photo lost when Android closed the app comes back', (tester) async {
      photos.lost = photo;
      await open(tester);

      expect(find.text('Ảnh sẵn sàng'), findsOneWidget);
      expect(find.text('Gửi ảnh cho chuyên viên'), findsOneWidget);
    });
  });
}

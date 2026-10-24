import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/diagnose_case_screen.dart';
import 'package:farmer_mobile/features/ai_doctor/screens/image_capture_screen.dart';
import 'package:farmer_mobile/features/products/screens/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/diagnosis_fakes.dart';
import '../../helpers/order_fakes.dart';

const _net = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');

Future<AppHarness> open(WidgetTester tester, String route,
    {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  setup?.call(h);
  await h.pump(tester, initial: route);
  await tester.pumpAndSettle();
  return h;
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('Chụp / chọn ảnh và gửi', () {
    testWidgets('lúc đầu chưa có ảnh: chưa có nút gửi', (tester) async {
      await open(tester, '/ai-scan/capture');
      expect(find.byKey(const Key('cap_send')), findsNothing);
      expect(find.textContaining('AI phân tích ảnh và cho kết quả ngay'), findsOneWidget);
      expect(find.textContaining('chuyên gia'), findsNothing);
    });

    testWidgets('hướng dẫn chụp nằm ngay dưới nút chụp, trước ô ghi chú, và nói không chụp cả cây',
        (tester) async {
      await open(tester, '/ai-scan/capture');
      final tips = find.byKey(const Key('cap_tips'));
      expect(tips, findsOneWidget);
      expect(find.descendant(of: tips, matching: find.textContaining('Chụp một lá bệnh')), findsOneWidget);
      expect(find.descendant(of: tips, matching: find.textContaining('Không chụp cả cây')), findsOneWidget);
      final tipsTop = tester.getTopLeft(tips).dy;
      expect(tipsTop, greaterThan(tester.getBottomLeft(find.byKey(const Key('cap_camera'))).dy));
      expect(tipsTop, lessThan(tester.getTopLeft(find.byKey(const Key('cap_note'))).dy));
    });

    testWidgets('chọn từ thư viện / camera: hiện ảnh sẵn sàng và nút gửi', (tester) async {
      final h = await open(tester, '/ai-scan/capture');
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      expect(h.photos.asked, [PhotoSource.gallery]);
      expect(find.text('Ảnh sẵn sàng'), findsOneWidget);
      expect(find.byKey(const Key('cap_send')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cap_camera')));
      await tester.pumpAndSettle();
      expect(h.photos.asked, [PhotoSource.gallery, PhotoSource.camera]);
    });

    testWidgets('Android đóng app lúc chụp: ảnh vừa chụp được lấy lại khi mở màn chụp', (tester) async {
      final h = await open(tester, '/ai-scan/capture', setup: (h) {
        h.photos.lost = const PickedPhoto(path: 'lost.jpg', name: 'lost.jpg', sizeBytes: 90000);
      });
      expect(find.text('Ảnh sẵn sàng'), findsOneWidget);
      expect(find.byKey(const Key('cap_send')), findsOneWidget);
      expect(h.photos.asked, isEmpty, reason: 'không cần chọn lại');
    });

    testWidgets('ảnh bị mất nhưng không phải ảnh JPEG/PNG/WebP: báo lỗi', (tester) async {
      await open(tester, '/ai-scan/capture', setup: (h) {
        h.photos.lost = const PickedPhoto(
            path: 'x.jpg', name: 'x.jpg', sizeBytes: 1000, typeChecked: true);
      });
      expect(find.textContaining('JPEG, PNG hoặc WebP'), findsOneWidget);
      expect(find.byKey(const Key('cap_send')), findsNothing);
    });

    testWidgets('người dùng bỏ qua (không chọn ảnh): không có gì thay đổi', (tester) async {
      await open(tester, '/ai-scan/capture', setup: (h) => h.photos.next = null);
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap_send')), findsNothing);
      expect(find.byKey(const Key('cap_error')), findsNothing);
    });

    testWidgets('không mở được camera: báo lỗi, không có nút gửi', (tester) async {
      await open(tester, '/ai-scan/capture', setup: (h) {
        h.photos.error = const PhotoPickerException(
            'Không mở được camera. Vui lòng thử lại.');
      });
      await tester.tap(find.byKey(const Key('cap_camera')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không mở được camera'), findsOneWidget);
      expect(find.byKey(const Key('cap_send')), findsNothing);
    });

    testWidgets('ảnh sai định dạng (HEIC): báo lỗi, không nhận ảnh', (tester) async {
      await open(tester, '/ai-scan/capture', setup: (h) {
        h.photos.next = const PickedPhoto(path: 'a.heic', name: 'a.heic', sizeBytes: 1000);
      });
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      expect(find.textContaining('JPEG, PNG hoặc WebP'), findsOneWidget);
      expect(find.byKey(const Key('cap_send')), findsNothing);
    });

    testWidgets('ảnh quá 5 MB: báo lỗi; chọn lại ảnh tốt thì lỗi biến mất', (tester) async {
      final h = await open(tester, '/ai-scan/capture', setup: (h) {
        h.photos.next = const PickedPhoto(path: 'big.jpg', name: 'big.jpg', sizeBytes: 6 * 1024 * 1024);
      });
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      expect(find.textContaining('quá lớn'), findsOneWidget);

      h.photos.next = const PickedPhoto(path: 'ok.jpg', name: 'ok.jpg', sizeBytes: 1000);
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap_error')), findsNothing);
      expect(find.byKey(const Key('cap_send')), findsOneWidget);
    });

    testWidgets('gửi thành công: gọi API với ảnh + ghi chú, mở ngay kết quả AI', (tester) async {
      final h = await open(tester, '/ai-scan/capture');
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cap_note')), 'Lá vàng từ chóp');
      await tester.ensureVisible(find.byKey(const Key('cap_send')));
      await tester.tap(find.byKey(const Key('cap_send')));
      await tester.pumpAndSettle();

      expect(h.diagnosis.lastCreate!.photo.name, 'leaf.jpg');
      expect(h.diagnosis.lastCreate!.note, 'Lá vàng từ chóp');
      expect(find.byType(DiagnoseCaseScreen), findsOneWidget);
      expect(find.byKey(const Key('case_result')), findsOneWidget);
      expect(textOf(tester, 'case_certainty'), 'Kết quả từ AI');
      expect(find.byKey(const Key('case_waiting')), findsNothing);
      await tester.scrollUntilVisible(find.text('Lá vàng từ chóp'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Lá vàng từ chóp'), findsOneWidget);
    });

    testWidgets('đang gửi: nút khoá, không gửi đúp', (tester) async {
      final gate = gate0();
      final h = await open(tester, '/ai-scan/capture',
          setup: (h) => h.diagnosis.createGate = gate.future);
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('cap_send')));
      await tester.tap(find.byKey(const Key('cap_send')));
      await tester.pump();

      expect(find.text('AI đang phân tích...'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('cap_send'))).onPressed, isNull);
      expect(h.diagnosis.calls.where((c) => c == 'create').length, 1);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('gửi lỗi (429): hiện lỗi, giữ ảnh, gửi lại được', (tester) async {
      final h = await open(tester, '/ai-scan/capture', setup: (h) {
        h.diagnosis.createError = const ApiException(
            kind: ApiErrorKind.rateLimited,
            statusCode: 429,
            message: 'Bạn gửi ảnh quá nhanh. Vui lòng đợi một chút rồi thử lại.');
      });
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('cap_send')));
      await tester.tap(find.byKey(const Key('cap_send')));
      await tester.pumpAndSettle();

      expect(find.textContaining('quá nhanh'), findsOneWidget);
      expect(find.text('Ảnh sẵn sàng'), findsOneWidget);
      h.diagnosis.createError = null;
      await tester.tap(find.byKey(const Key('cap_send')));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnoseCaseScreen), findsOneWidget);
    });

    testWidgets('lỗi ngoài dự kiến: không kẹt ở trạng thái đang gửi', (tester) async {
      await open(tester, '/ai-scan/capture', setup: (h) => h.diagnosis.createError = StateError('boom'));
      await tester.tap(find.byKey(const Key('cap_gallery')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('cap_send')));
      await tester.tap(find.byKey(const Key('cap_send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap_error')), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('cap_send'))).onPressed, isNotNull);
      expect(find.byType(ImageCaptureScreen), findsOneWidget);
    });
  });

  group('Chi tiết ca: AI đang phân tích', () {
    for (final s in ['SUBMITTED', 'PROCESSING']) {
      testWidgets('$s: đang phân tích, chưa có kết quả, huỷ được', (tester) async {
        await open(tester, '/ai-scan/case/c1', setup: (h) {
          h.diagnosis.cases['c1'] = caseOf('c1', status: s, withImage: false, note: 'Ghi chú');
        });
        expect(find.text('Đang phân tích'), findsOneWidget);
        expect(find.byKey(const Key('case_waiting')), findsOneWidget);
        expect(find.byKey(const Key('case_result')), findsNothing);
        expect(find.byKey(const Key('case_disease')), findsNothing);
        expect(find.byKey(const Key('case_retry')), findsNothing);
        expect(find.byKey(const Key('case_cancel')), findsOneWidget);
        expect(find.text('Ghi chú'), findsOneWidget);
        expect(find.textContaining('chuyên gia'), findsNothing);
      });
    }

    testWidgets('tự làm mới định kỳ: AI xong thì màn hình hiện kết quả', (tester) async {
      final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosisPollInterval = const Duration(seconds: 5);
        h.diagnosis.cases['c1'] = caseOf('c1', withImage: false);
      });
      expect(find.byKey(const Key('case_waiting')), findsOneWidget);

      h.diagnosis.cases['c1'] =
          caseOf('c1', status: 'AI_COMPLETED', withImage: false, result: aiResultJson());
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('case_result')), findsOneWidget);
      expect(find.text('Đã có kết quả'), findsOneWidget);
      expect(find.byKey(const Key('case_cancel')), findsNothing);
    });

    for (final s in ['AI_COMPLETED', 'VERIFIED', 'FAILED']) {
      testWidgets('ca $s thì KHÔNG hỏi lại định kỳ', (tester) async {
        final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
          h.diagnosisPollInterval = const Duration(seconds: 5);
          h.diagnosis.cases['c1'] = caseOf('c1',
              status: s,
              withImage: false,
              result: switch (s) {
                'AI_COMPLETED' => aiResultJson(),
                'VERIFIED' => resultJson(),
                _ => null,
              });
        });
        final before = h.diagnosis.calls.where((c) => c == 'get:c1').length;
        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
        expect(h.diagnosis.calls.where((c) => c == 'get:c1').length, before);
      });
    }

    testWidgets('huỷ: đóng hộp thoại thì không huỷ', (tester) async {
      final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', withImage: false);
      });
      await tester.tap(find.byKey(const Key('case_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('case_cancel_no')));
      await tester.pumpAndSettle();
      expect(h.diagnosis.lastCancel, isNull);
      expect(find.byKey(const Key('case_cancel')), findsOneWidget);
    });

    testWidgets('huỷ thành công: trạng thái Đã huỷ, hết nút huỷ', (tester) async {
      final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', withImage: false);
      });
      await tester.tap(find.byKey(const Key('case_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('case_cancel_yes')));
      await tester.pumpAndSettle();

      expect(h.diagnosis.lastCancel, 'c1');
      expect(find.byKey(const Key('case_cancelled')), findsOneWidget);
      expect(find.byKey(const Key('case_cancel')), findsNothing);
      expect(find.textContaining('Đã huỷ ca chẩn đoán'), findsOneWidget);
    });

    testWidgets('huỷ khi AI vừa có kết quả (422): báo lỗi và tải lại', (tester) async {
      final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', withImage: false);
        h.diagnosis.cancelError = const ApiException(
            kind: ApiErrorKind.businessRule,
            statusCode: 422,
            message: 'Ca đã có kết quả hoặc đã huỷ nên không thể huỷ nữa.');
      });
      await tester.tap(find.byKey(const Key('case_cancel')));
      await tester.pumpAndSettle();
      h.diagnosis.cases['c1'] =
          caseOf('c1', status: 'AI_COMPLETED', withImage: false, result: aiResultJson());
      await tester.tap(find.byKey(const Key('case_cancel_yes')));
      await tester.pumpAndSettle();

      expect(find.textContaining('không thể huỷ nữa'), findsOneWidget);
      expect(find.byKey(const Key('case_result')), findsOneWidget);
      expect(find.byKey(const Key('case_cancel')), findsNothing);
    });
  });

  group('Chi tiết ca: AI chưa phân tích được', () {
    testWidgets('FAILED: báo chưa phân tích được, có Thử lại, Gửi ảnh khác và Huỷ', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', status: 'FAILED', withImage: false);
      });
      expect(find.text('Chưa phân tích được'), findsOneWidget);
      expect(find.byKey(const Key('case_failed')), findsOneWidget);
      expect(find.byKey(const Key('case_retry')), findsOneWidget);
      expect(find.byKey(const Key('case_new_photo')), findsOneWidget);
      expect(find.byKey(const Key('case_cancel')), findsOneWidget);
      expect(find.byKey(const Key('case_waiting')), findsNothing);
      expect(find.byKey(const Key('case_result')), findsNothing);
    });

    testWidgets('ca kẹt ở SUBMITTED (server bảo thử lại được): hiện nút Thử lại', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', status: 'SUBMITTED', withImage: false, canRetry: true);
      });
      expect(find.byKey(const Key('case_failed')), findsOneWidget);
      expect(find.byKey(const Key('case_retry')), findsOneWidget);
      expect(find.byKey(const Key('case_waiting')), findsNothing);
    });

    testWidgets('Thử lại thành công: gọi API rồi hiện kết quả AI, hết nút huỷ', (tester) async {
      final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', status: 'FAILED', withImage: false);
      });
      await tester.tap(find.byKey(const Key('case_retry')));
      await tester.pumpAndSettle();

      expect(h.diagnosis.lastRetry, 'c1');
      expect(find.byKey(const Key('case_result')), findsOneWidget);
      expect(textOf(tester, 'case_disease'), 'Đạo ôn lá');
      expect(find.byKey(const Key('case_failed')), findsNothing);
      expect(find.byKey(const Key('case_cancel')), findsNothing);
    });

    testWidgets('Thử lại khi AI vẫn bận (503): báo lỗi, vẫn ở màn chưa phân tích được', (tester) async {
      final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', status: 'FAILED', withImage: false);
        h.diagnosis.retryError = const ApiException(
            kind: ApiErrorKind.unavailable,
            statusCode: 503,
            message: 'Dịch vụ AI đang bận. Bạn hãy thử lại sau ít phút.');
      });
      await tester.tap(find.byKey(const Key('case_retry')));
      await tester.pumpAndSettle();

      expect(h.diagnosis.lastRetry, 'c1');
      expect(find.textContaining('Dịch vụ AI đang bận. Bạn hãy thử lại'), findsOneWidget);
      expect(find.byKey(const Key('case_failed')), findsOneWidget);
      expect(
          tester.widget<ElevatedButton>(find.byKey(const Key('case_retry'))).onPressed, isNotNull,
          reason: 'bấm thử lại được lần nữa');
    });

    testWidgets('Gửi ảnh khác mở màn chụp', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', status: 'FAILED', withImage: false);
      });
      await tester.tap(find.byKey(const Key('case_new_photo')));
      await tester.pumpAndSettle();
      expect(find.byType(ImageCaptureScreen), findsOneWidget);
    });
  });

  group('Chi tiết ca: kết quả AI', () {
    testWidgets('AI chắc chắn: bệnh, cách xử lý kèm hoạt chất, sản phẩm gợi ý, lưu ý AI có thể sai',
        (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] =
            caseOf('c1', status: 'AI_COMPLETED', withImage: false, result: aiResultJson());
      });
      expect(find.text('Đã có kết quả'), findsOneWidget);
      expect(textOf(tester, 'case_certainty'), 'Kết quả từ AI');
      expect(textOf(tester, 'case_disease'), 'Đạo ôn lá');
      expect(find.textContaining('có thể chưa chính xác'), findsOneWidget);
      expect(find.byKey(const Key('case_uncertain')), findsNothing);
      expect(find.byKey(const Key('case_comment')), findsNothing);
      expect(find.byKey(const Key('case_cancel')), findsNothing);

      await tester.scrollUntilVisible(find.byKey(const Key('case_treatments')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Thuốc / hoá chất'), findsOneWidget);
      expect(find.text('Hoạt chất: Tricyclazole'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('case_disclaimer')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('case_products')), findsOneWidget);
      expect(find.text('Thuốc Beam 75WP'), findsOneWidget);
      expect(find.textContaining('Đọc kỹ nhãn thuốc'), findsOneWidget);
    });

    testWidgets('AI chưa chắc: "có thể là", không thuốc, không sản phẩm, nút Chụp lại', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'AI_COMPLETED', withImage: false, result: aiResultJson(uncertain: true));
      });
      expect(textOf(tester, 'case_certainty'), 'AI chưa chắc chắn, có thể là');
      expect(textOf(tester, 'case_disease'), 'Đạo ôn lá');
      expect(find.byKey(const Key('case_uncertain')), findsOneWidget);
      expect(find.text('Thuốc / hoá chất'), findsNothing);
      expect(find.byKey(const Key('case_products')), findsNothing);
      expect(find.byKey(const Key('case_no_products')), findsNothing);
      expect(find.text('Cây không có dấu hiệu bệnh.'), findsNothing);

      await tester.tap(find.byKey(const Key('case_retake')));
      await tester.pumpAndSettle();
      expect(find.byType(ImageCaptureScreen), findsOneWidget);
    });

    testWidgets('AI chưa chắc là lá khoẻ: KHÔNG báo "cây không có dấu hiệu bệnh"', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'AI_COMPLETED',
            withImage: false,
            result: aiResultJson(
                uncertain: true, code: 'HEALTHY', name: 'Healthy', healthy: true, treatments: []));
      });
      expect(textOf(tester, 'case_disease'), 'Lá khoẻ mạnh');
      expect(find.text('Cây không có dấu hiệu bệnh.'), findsNothing);
      expect(find.byKey(const Key('case_uncertain')), findsOneWidget);
    });

    testWidgets('AI chắc chắn nhưng cửa hàng chưa có sản phẩm khớp: mời hỏi cửa hàng', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'AI_COMPLETED', withImage: false, result: aiResultJson(products: []));
      });
      await tester.scrollUntilVisible(find.byKey(const Key('case_no_products')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('case_products')), findsNothing);
    });

    testWidgets('bệnh chưa có nội dung: mời hỏi cửa hàng thay vì để trống', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'AI_COMPLETED',
            withImage: false,
            result: aiResultJson(symptoms: null, prevention: null, treatments: [], products: []));
      });
      expect(find.byKey(const Key('case_no_content')), findsOneWidget);
      expect(find.byKey(const Key('case_treatments')), findsNothing);
    });

    testWidgets('AI chắc chắn lá khoẻ: thông báo tích cực, không có mục sản phẩm', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'AI_COMPLETED',
            withImage: false,
            result: aiResultJson(
                code: 'HEALTHY', name: 'Healthy', healthy: true, symptoms: null, prevention: null,
                treatments: []));
      });
      expect(find.text('Cây không có dấu hiệu bệnh.'), findsOneWidget);
      expect(find.byKey(const Key('case_products')), findsNothing);
      expect(find.byKey(const Key('case_no_products')), findsNothing);
      expect(find.byKey(const Key('case_no_content')), findsNothing);
    });

    testWidgets('ca cũ UNDER_REVIEW: hiện kết quả AI, không còn "chờ chuyên gia"', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] =
            caseOf('c1', status: 'UNDER_REVIEW', withImage: false, result: aiResultJson());
      });
      expect(find.byKey(const Key('case_result')), findsOneWidget);
      expect(find.byKey(const Key('case_waiting')), findsNothing);
      expect(find.byKey(const Key('case_cancel')), findsNothing);
    });
  });

  group('Chi tiết ca: ca cũ cửa hàng đã xác nhận', () {
    testWidgets('bệnh, nhận xét, triệu chứng, phòng ngừa, điều trị theo thứ tự, sản phẩm', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] =
            caseOf('c1', status: 'VERIFIED', withImage: false, result: resultJson());
      });

      expect(find.text('Đã xác nhận'), findsOneWidget);
      expect(textOf(tester, 'case_certainty'), 'Cửa hàng đã xác nhận');
      expect(textOf(tester, 'case_disease'), 'Đạo ôn lá');
      expect(find.text('Leaf Blast'), findsOneWidget);
      expect(find.text('Nhận xét của cửa hàng'), findsOneWidget);
      expect(find.text('Vết bệnh hình thoi điển hình.'), findsOneWidget);
      expect(find.textContaining('có thể chưa chính xác'), findsNothing);
      expect(find.text('Vết hình thoi màu nâu xám trên lá.'), findsOneWidget);
      expect(find.text('Bón phân cân đối, tránh thừa đạm.'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('case_treatments')), 300,
          scrollable: find.byType(Scrollable).first);
      final first = tester.getTopLeft(find.text('Phun thuốc đặc trị đạo ôn')).dy;
      final second = tester.getTopLeft(find.text('Giữ ruộng thoáng')).dy;
      expect(first, lessThan(second), reason: 'theo rankOrder');
      expect(find.text('Thuốc / hoá chất'), findsOneWidget);
      expect(find.text('Phòng ngừa'), findsWidgets);
      expect(find.textContaining('Lưu ý: Đeo khẩu trang'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('case_products')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Phân NPK'), findsOneWidget);
      expect(find.text('Thuốc Beam 75WP'), findsOneWidget);
      expect(find.text('Đặc trị đạo ôn'), findsOneWidget);
    });

    testWidgets('bấm sản phẩm gợi ý mở chi tiết sản phẩm theo storeProductId', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] =
            caseOf('c1', status: 'VERIFIED', withImage: false, result: resultJson());
      });
      await tester.scrollUntilVisible(find.byKey(const Key('case_product_sp1')), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('case_product_sp1')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(tester.widget<ProductDetailScreen>(find.byType(ProductDetailScreen)).productId, 'sp1');
    });

    testWidgets('lá khoẻ mạnh: thông báo tích cực, không có sản phẩm/điều trị', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'VERIFIED',
            withImage: false,
            result: resultJson(
                code: 'HEALTHY',
                name: 'Healthy',
                healthy: true,
                symptoms: null,
                prevention: null,
                treatments: [],
                products: []));
      });
      expect(textOf(tester, 'case_disease'), 'Lá khoẻ mạnh');
      expect(find.text('Cây không có dấu hiệu bệnh.'), findsOneWidget);
      expect(find.byKey(const Key('case_treatments')), findsNothing);
      expect(find.byKey(const Key('case_products')), findsNothing);
    });

    testWidgets('thiếu nhận xét / triệu chứng: ẩn mục tương ứng, không vỡ', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'VERIFIED',
            withImage: false,
            result: resultJson(comment: null, symptoms: '  ', prevention: null, products: []));
      });
      expect(find.byKey(const Key('case_comment')), findsNothing);
      expect(find.text('Triệu chứng'), findsNothing);
      expect(find.text('Cách phòng ngừa'), findsNothing);
    });
  });

  group('Chi tiết ca: chưa kết luận (ca cũ) / huỷ / lỗi mạng', () {
    testWidgets('ca cũ chưa kết luận: lời nhắn của cửa hàng + nút chụp lại mở màn chụp', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1',
            status: 'INCONCLUSIVE',
            withImage: false,
            inconclusive: {'comment': 'Ảnh bị mờ, vui lòng chụp lại.', 'hint': 'RETAKE_PHOTO'});
      });
      expect(find.byKey(const Key('case_inconclusive')), findsOneWidget);
      expect(find.textContaining('Ảnh bị mờ, vui lòng chụp lại.'), findsOneWidget);
      expect(find.byKey(const Key('case_cancel')), findsNothing);

      await tester.tap(find.byKey(const Key('case_retake')));
      await tester.pumpAndSettle();
      expect(find.byType(ImageCaptureScreen), findsOneWidget);
    });

    testWidgets('ca cũ chưa kết luận mà không có lời nhắn vẫn hiển thị được', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', status: 'INCONCLUSIVE', withImage: false);
      });
      expect(find.byKey(const Key('case_inconclusive')), findsOneWidget);
      expect(find.byKey(const Key('case_comment')), findsNothing);
    });

    testWidgets('đã huỷ: thông báo, không có nút huỷ', (tester) async {
      await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.cases['c1'] = caseOf('c1', status: 'CANCELLED', withImage: false);
      });
      expect(find.byKey(const Key('case_cancelled')), findsOneWidget);
      expect(find.byKey(const Key('case_cancel')), findsNothing);
    });

    testWidgets('không tìm thấy (404)', (tester) async {
      await open(tester, '/ai-scan/case/zzz');
      expect(find.text('Không tìm thấy ca chẩn đoán.'), findsOneWidget);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, '/ai-scan/case/c1', setup: (h) {
        h.diagnosis.getError = _net;
        h.diagnosis.cases['c1'] = caseOf('c1', withImage: false);
      });
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      h.diagnosis.getError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('case_waiting')), findsOneWidget);
    });

    testWidgets('có ảnh (URL ký): màn vẫn dựng đủ nội dung khi ảnh chưa/không tải được', (tester) async {
      // Ảnh mạng luôn quay vòng chờ nên không dùng pumpAndSettle.
      final h = AppHarness()..signIn();
      h.diagnosis.cases['c1'] = caseOf('c1');
      await h.pump(tester, initial: '/ai-scan/case/c1');
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('case_waiting')), findsOneWidget);
      expect(find.byKey(const Key('case_number')), findsOneWidget);
    });
  });

  group('Lịch sử', () {
    testWidgets('hiện các ca với trạng thái; ca có kết quả có tên bệnh tiếng Việt', (tester) async {
      await open(tester, '/ai-scan/history', setup: (h) {
        h.diagnosis.list0 = [
          diagSummaryOf('a',
              status: 'AI_COMPLETED', code: 'BROWN_SPOT', name: 'Brown Spot', certainty: 'CONFIDENT'),
          diagSummaryOf('u',
              status: 'AI_COMPLETED', code: 'LEAF_BLAST', name: 'Leaf Blast', certainty: 'UNCERTAIN'),
          diagSummaryOf('v',
              status: 'VERIFIED', code: 'SHEATH_BLIGHT', name: 'Sheath Blight', certainty: 'VERIFIED'),
          diagSummaryOf('b'),
          diagSummaryOf('f', status: 'FAILED'),
          diagSummaryOf('c', status: 'INCONCLUSIVE'),
          diagSummaryOf('d', status: 'CANCELLED'),
        ];
      });
      expect(find.text('Đốm nâu'), findsOneWidget);
      expect(find.text('Có thể là Đạo ôn lá (AI chưa chắc)'), findsOneWidget);
      expect(find.text('Khô vằn'), findsOneWidget);
      Finder inCard(String id, String text) =>
          find.descendant(of: find.byKey(Key('diag_$id')), matching: find.text(text));
      expect(inCard('a', 'Đã có kết quả'), findsOneWidget);
      expect(inCard('u', 'Đã có kết quả'), findsOneWidget);
      expect(inCard('v', 'Đã xác nhận'), findsOneWidget);
      expect(find.text('DG-b'), findsOneWidget, reason: 'ca chưa có kết quả hiện mã ca, không có tên bệnh');
      await tester.scrollUntilVisible(find.byKey(const Key('diag_d')), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Đang phân tích'), findsWidgets);
      expect(find.text('Chưa phân tích được'), findsWidgets);
      expect(find.text('Cần chụp lại'), findsOneWidget);
      expect(find.textContaining('chuyên gia'), findsNothing);
    });

    testWidgets('lọc theo trạng thái gọi API đúng', (tester) async {
      final h = await open(tester, '/ai-scan/history', setup: (h) {
        h.diagnosis.list0 = [
          diagSummaryOf('a',
              status: 'AI_COMPLETED', code: 'HEALTHY', name: 'Healthy', certainty: 'CONFIDENT'),
          diagSummaryOf('b'),
        ];
      });
      await tester.tap(find.byKey(const Key('diag_filter_AI_COMPLETED')));
      await tester.pumpAndSettle();
      expect(h.diagnosis.listCalls.last, (page: 1, status: 'AI_COMPLETED'));
      expect(find.byKey(const Key('diag_a')), findsOneWidget);
      expect(find.byKey(const Key('diag_b')), findsNothing);
    });

    testWidgets('trống: mời chụp ảnh; lọc mà trống: nêu tên bộ lọc', (tester) async {
      await open(tester, '/ai-scan/history');
      expect(find.textContaining('Chưa có lịch sử khám cây'), findsOneWidget);
      await tester.tap(find.byKey(const Key('diag_filter_CANCELLED')));
      await tester.pumpAndSettle();
      expect(find.text('Không có ca "Đã huỷ".'), findsOneWidget);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, '/ai-scan/history', setup: (h) => h.diagnosis.listError = _net);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      h.diagnosis.listError = null;
      h.diagnosis.list0 = [diagSummaryOf('a')];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diag_a')), findsOneWidget);
    });

    testWidgets('nhiều trang: Xem thêm', (tester) async {
      final h = await open(tester, '/ai-scan/history', setup: (h) {
        h.diagnosis.pageSize0 = 2;
        h.diagnosis.list0 = [for (var i = 1; i <= 3; i++) diagSummaryOf('r$i')];
      });
      expect(find.byKey(const Key('diag_r3')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('diag_load_more')));
      await tester.tap(find.byKey(const Key('diag_load_more')));
      await tester.pumpAndSettle();
      expect(h.diagnosis.listCalls.last.page, 2);
      expect(find.byKey(const Key('diag_r3')), findsOneWidget);
    });

    testWidgets('bấm một ca mở chi tiết', (tester) async {
      await open(tester, '/ai-scan/history', setup: (h) {
        h.diagnosis.list0 = [diagSummaryOf('a', status: 'AI_COMPLETED')];
        h.diagnosis.cases['a'] =
            caseOf('a', status: 'AI_COMPLETED', withImage: false, result: aiResultJson());
      });
      await tester.tap(find.byKey(const Key('diag_a')));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnoseCaseScreen), findsOneWidget);
    });
  });
}

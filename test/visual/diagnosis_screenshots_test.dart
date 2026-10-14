// Chụp ảnh các màn chẩn đoán AI bằng font thật (cần mạng để tải font Google).
//
//   SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/diagnosis_screenshots_test.dart
//
// Ảnh ra ở test/visual/shots/ (xem xong thì xoá thư mục). Test cũng thất bại nếu
// có lỗi tràn layout với font thật ở cả khung 390px và 320px.
import 'dart:io';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/diagnosis_fakes.dart';
import 'auth_screenshots_test.dart' show shoot, useRealFonts;

final _on = Platform.environment['SCREENSHOTS'] == '1';

void main() {
  for (final width in [390.0, 320.0]) {
    final tag = width.toInt();

    Future<AppHarness> open(WidgetTester tester, String route,
        {void Function(AppHarness)? setup}) async {
      await useRealFonts(tester);
      final h = AppHarness()..signIn();
      h.diagnosis.cases['w'] = caseOf('w',
          status: 'UNDER_REVIEW', withImage: false, note: 'Lá vàng từ chóp, sau đợt mưa');
      h.diagnosis.cases['v'] =
          caseOf('v', status: 'VERIFIED', withImage: false, result: resultJson());
      h.diagnosis.cases['h'] = caseOf('h',
          status: 'VERIFIED',
          withImage: false,
          result: resultJson(
              code: 'HEALTHY',
              name: 'Healthy',
              healthy: true,
              symptoms: null,
              prevention: 'Giữ chế độ nước và phân bón hiện tại.',
              treatments: [],
              products: []));
      h.diagnosis.cases['i'] = caseOf('i',
          status: 'INCONCLUSIVE',
          withImage: false,
          inconclusive: {'comment': 'Ảnh bị mờ và ngược sáng, vui lòng chụp lại gần hơn.', 'hint': 'RETAKE_PHOTO'});
      h.diagnosis.cases['x'] = caseOf('x', status: 'CANCELLED', withImage: false);
      h.diagnosis.list0 = [
        diagSummaryOf('v', status: 'VERIFIED', code: 'LEAF_BLAST', name: 'Leaf Blast'),
        diagSummaryOf('w', status: 'UNDER_REVIEW'),
        diagSummaryOf('i', status: 'INCONCLUSIVE'),
        diagSummaryOf('f', status: 'FAILED'),
        diagSummaryOf('x', status: 'CANCELLED'),
      ];
      setup?.call(h);
      await h.pump(tester, initial: route);
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpAndSettle();
      return h;
    }

    group('ảnh chẩn đoán $tag px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      testWidgets('chụp ảnh: trống → có ảnh → lỗi', (tester) async {
        final h = await open(tester, '/ai-scan/capture');
        await shoot(tester, '${tag}_diag_capture_empty');
        await tester.tap(find.byKey(const Key('cap_gallery')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('cap_note')), 'Lá vàng từ chóp');
        await tester.pump(const Duration(milliseconds: 300));
        await shoot(tester, '${tag}_diag_capture_ready');
        h.diagnosis.createError = const ApiException(
            kind: ApiErrorKind.rateLimited,
            statusCode: 429,
            message: 'Bạn gửi ảnh quá nhanh. Vui lòng đợi một chút rồi thử lại.');
        await tester.ensureVisible(find.byKey(const Key('cap_send')));
        await tester.tap(find.byKey(const Key('cap_send')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_diag_capture_error');
      });

      testWidgets('ảnh sai định dạng', (tester) async {
        await open(tester, '/ai-scan/capture', setup: (h) {
          h.photos.next = const PickedPhoto(path: 'a.heic', name: 'a.heic', sizeBytes: 1000);
        });
        await tester.tap(find.byKey(const Key('cap_gallery')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_diag_capture_badtype');
      });

      testWidgets('màn chính', (tester) async {
        await open(tester, '/ai-scan');
        await shoot(tester, '${tag}_diag_home');
      });

      testWidgets('lịch sử', (tester) async {
        await open(tester, '/ai-scan/history');
        await shoot(tester, '${tag}_diag_history');
      });

      testWidgets('lịch sử trống', (tester) async {
        await open(tester, '/ai-scan/history', setup: (h) => h.diagnosis.list0 = []);
        await shoot(tester, '${tag}_diag_history_empty');
      });

      testWidgets('chi tiết: đang chờ', (tester) async {
        await open(tester, '/ai-scan/case/w');
        await shoot(tester, '${tag}_diag_case_waiting');
      });

      testWidgets('chi tiết: có kết quả (3 đoạn cuộn)', (tester) async {
        await open(tester, '/ai-scan/case/v');
        await shoot(tester, '${tag}_diag_case_result_top');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_diag_case_result_mid');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_diag_case_result_bottom');
      });

      testWidgets('chi tiết: lá khoẻ mạnh', (tester) async {
        await open(tester, '/ai-scan/case/h');
        await shoot(tester, '${tag}_diag_case_healthy');
      });

      testWidgets('chi tiết: cần chụp lại', (tester) async {
        await open(tester, '/ai-scan/case/i');
        await shoot(tester, '${tag}_diag_case_inconclusive');
      });

      testWidgets('chi tiết: đã huỷ', (tester) async {
        await open(tester, '/ai-scan/case/x');
        await shoot(tester, '${tag}_diag_case_cancelled');
      });

      testWidgets('hộp thoại huỷ', (tester) async {
        await open(tester, '/ai-scan/case/w');
        await tester.tap(find.byKey(const Key('case_cancel')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_diag_cancel_dialog');
      });
    });
  }
}

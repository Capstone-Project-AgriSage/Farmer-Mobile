import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/advisory/data/advisory_models.dart';
import 'package:farmer_mobile/features/advisory/providers/advisory_providers.dart';
import 'package:farmer_mobile/features/advisory/screens/advisory_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/advisory_fakes.dart';
import '../../helpers/app_harness.dart';
import '../../helpers/diagnosis_fakes.dart';

const _net = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');

Future<AppHarness> open(WidgetTester tester, String route, {void Function(AppHarness)? setup}) async {
  final h = AppHarness()..signIn();
  setup?.call(h);
  await h.pump(tester, initial: route);
  await tester.pumpAndSettle();
  return h;
}

/// Một lần tư vấn trả về: chưa có diện tích thì chưa có số lượng, có diện tích thì có kế hoạch mua.
Map<String, dynamic> Function(AdvisoryQuery) answerWithPlan({
  String stock = 'ENOUGH',
  List<Map<String, dynamic>>? nutrition,
}) =>
    (q) => recommendationJson(
          areaSqm: q.areaSqm,
          growthStage: q.growthStage,
          protection: [advisoryProductJson('sp1', 'Tilt Super 300EC', stock: stock, withPlan: q.areaSqm != null)],
          nutrition: nutrition,
        );

void main() {
  group('Tìm vấn đề', () {
    testWidgets('liệt kê các vấn đề kèm loại, và có lối sang chụp ảnh', (tester) async {
      final h = await open(tester, '/advisory');
      expect(find.text('Tư vấn vật tư'), findsOneWidget);
      expect(find.byKey(const Key('advisory_problem_LEAF_BLAST')), findsOneWidget);
      expect(find.text('Đạo ôn lá'), findsOneWidget, reason: 'tên tiếng Việt theo mã bệnh');
      expect(find.text('Rầy nâu'), findsOneWidget);
      expect(find.text('Sâu rầy'), findsWidgets, reason: 'nhãn lọc và nhãn loại trên thẻ');
      expect(find.byKey(const Key('advisory_photo_shortcut')), findsOneWidget);
      expect(h.advisory.problemCalls.single, (search: null, type: null));
    });

    testWidgets('gõ không dấu: đợi gõ xong mới gọi, rồi chỉ còn vấn đề khớp', (tester) async {
      final h = await open(tester, '/advisory');
      await tester.enterText(find.byKey(const Key('advisory_search')), 'ray nau');
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.advisory.problemCalls.length, 1, reason: 'chưa đủ thời gian chờ');
      await tester.pump(AdvisorySearchScreen.searchDebounce + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(h.advisory.problemCalls.last, (search: 'ray nau', type: null));
      expect(find.byKey(const Key('advisory_problem_BROWN_PLANTHOPPER')), findsOneWidget);
      expect(find.byKey(const Key('advisory_problem_LEAF_BLAST')), findsNothing);
    });

    testWidgets('lọc theo loại gửi type lên server', (tester) async {
      final h = await open(tester, '/advisory');
      await tester.tap(find.byKey(const Key('advisory_type_PEST')));
      await tester.pumpAndSettle();
      expect(h.advisory.problemCalls.last, (search: null, type: 'PEST'));
      expect(find.byKey(const Key('advisory_problem_BROWN_PLANTHOPPER')), findsOneWidget);
      expect(find.byKey(const Key('advisory_problem_NITROGEN_DEFICIENCY')), findsNothing);
    });

    testWidgets('không có kết quả: nói rõ và gợi ý chụp ảnh', (tester) async {
      await open(tester, '/advisory');
      await tester.enterText(find.byKey(const Key('advisory_search')), 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advisory_empty')), findsOneWidget);
      expect(find.textContaining('Không tìm thấy vấn đề phù hợp'), findsOneWidget);
    });

    testWidgets('lỗi mạng hiện nút Thử lại và tải được khi thử lại', (tester) async {
      final h = await open(tester, '/advisory', setup: (h) => h.advisory.problemError = _net);
      expect(find.text('Thử lại'), findsOneWidget);
      h.advisory.problemError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advisory_problem_LEAF_BLAST')), findsOneWidget);
    });

    testWidgets('chọn một vấn đề mở màn tư vấn của vấn đề đó', (tester) async {
      final h = await open(tester, '/advisory');
      await tester.tap(find.byKey(const Key('advisory_problem_BROWN_PLANTHOPPER')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advisory_problem_header')), findsOneWidget, reason: 'đã sang màn tư vấn');
      expect(h.advisory.recommendCalls.single.diseaseId, 'd-BROWN_PLANTHOPPER');
    });
  });

  group('Tư vấn cho một vấn đề', () {
    testWidgets('chưa nhập diện tích: có sản phẩm, liều, nguồn đăng ký, cách ly, nhưng chưa có số lượng', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT',
          setup: (h) => h.advisory.answer = answerWithPlan());
      expect(h.advisory.recommendCalls.single.areaSqm, isNull);
      expect(find.byKey(const Key('advisory_problem_name')), findsOneWidget);
      expect(find.text('Khô vằn'), findsOneWidget, reason: 'tên tiếng Việt theo mã bệnh');
      expect(find.byKey(const Key('advisory_care')), findsOneWidget);
      expect(find.text('Tilt Super 300EC'), findsOneWidget);
      expect(find.textContaining('Đăng ký: TT 75/2025/TT-BNNMT'), findsOneWidget);
      expect(find.textContaining('0,25-0,3 lít/ha'), findsOneWidget);
      expect(find.text('Cách ly 14 ngày'), findsOneWidget);
      expect(find.text('Còn hàng'), findsOneWidget);
      expect(find.byKey(const Key('advisory_noplan_sp1')), findsOneWidget);
      expect(find.textContaining('Nhập diện tích ruộng'), findsOneWidget);
      expect(find.byKey(const Key('advisory_disclaimer')), findsOneWidget);
    });

    testWidgets('nhập 3 công: gửi 3.000 m², hiện số lượng và tiền, và nhớ diện tích cho lần sau', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT',
          setup: (h) => h.advisory.answer = answerWithPlan());
      await enter(tester, 'advisory_area', '3');
      await tester.tap(find.byKey(const Key('advisory_apply')));
      await tester.pumpAndSettle();
      expect(h.advisory.recommendCalls.last.areaSqm, 3000);
      expect(find.byKey(const Key('advisory_plan_sp1')), findsOneWidget);
      expect(find.textContaining('3 × Chai 100 ml'), findsOneWidget);
      expect(find.textContaining('Ước tính 255.000đ'), findsOneWidget);
      expect(find.text('Thêm vào giỏ · 255.000đ'), findsOneWidget);
      expect(h.areaStore.data[AdvisoryAreaController.key], '3.0|cong');
    });

    testWidgets('đổi đơn vị sang sào: 2 sào là 720 m²; dấu phẩy là số thập phân', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT',
          setup: (h) => h.advisory.answer = answerWithPlan());
      await tester.tap(find.byKey(const Key('advisory_unit_sao')));
      await tester.pump();
      await enter(tester, 'advisory_area', '2');
      await tester.tap(find.byKey(const Key('advisory_apply')));
      await tester.pumpAndSettle();
      expect(h.advisory.recommendCalls.last.areaSqm, 720);

      await tester.tap(find.byKey(const Key('advisory_unit_ha')));
      await tester.pump();
      await enter(tester, 'advisory_area', '0,5');
      await tester.tap(find.byKey(const Key('advisory_apply')));
      await tester.pumpAndSettle();
      expect(h.advisory.recommendCalls.last.areaSqm, 5000);
    });

    testWidgets('diện tích đã nhập lần trước nằm sẵn trong ô và được dùng ngay, chỉ gọi một lần', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.areaStore.data[AdvisoryAreaController.key] = '2.5|cong';
        h.advisory.answer = answerWithPlan();
      });
      expect(h.advisory.recommendCalls.length, 1);
      expect(h.advisory.recommendCalls.single.areaSqm, 2500);
      expect(tester.widget<TextField>(find.byKey(const Key('advisory_area'))).controller!.text, '2,5');
      expect(find.byKey(const Key('advisory_plan_sp1')), findsOneWidget);
    });

    testWidgets('diện tích không hợp lệ: báo lỗi và không gọi server', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT',
          setup: (h) => h.advisory.answer = answerWithPlan());
      for (final bad in ['0', '1,2,3', '5000']) {
        await enter(tester, 'advisory_area', bad);
        await tester.tap(find.byKey(const Key('advisory_apply')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Nhập diện tích là số lớn hơn 0'), findsOneWidget, reason: bad);
      }
      expect(h.advisory.recommendCalls.length, 1, reason: 'chỉ lần mở màn');
    });

    testWidgets('chọn giai đoạn gửi growthStage; không có sản phẩm hợp thì nói lý do', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.advisory.answer = (q) => q.growthStage == null
            ? recommendationJson(areaSqm: q.areaSqm)
            : recommendationJson(areaSqm: q.areaSqm, growthStage: q.growthStage, protection: [], emptyReason: 'NO_PRODUCT_FOR_STAGE');
      });
      await tester.tap(find.byKey(const Key('advisory_stage_HEADING')));
      await tester.pumpAndSettle();
      expect(h.advisory.recommendCalls.last.growthStage, 'HEADING');
      expect(find.byKey(const Key('advisory_empty_reason')), findsOneWidget);
      expect(find.textContaining('Chưa có sản phẩm hợp với giai đoạn'), findsOneWidget);

      await tester.tap(find.byKey(const Key('advisory_stage_any')));
      await tester.pumpAndSettle();
      expect(h.advisory.recommendCalls.last.growthStage, isNull);
      expect(find.byKey(const Key('advisory_empty_reason')), findsNothing);
    });

    testWidgets('thêm vào giỏ gửi từng dòng quy cách do server tính và có nút Xem giỏ', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.areaStore.data[AdvisoryAreaController.key] = '3.0|cong';
        h.advisory.answer = answerWithPlan();
      });
      await tester.ensureVisible(find.byKey(const Key('advisory_add_sp1')));
      await tester.tap(find.byKey(const Key('advisory_add_sp1')));
      await tester.pumpAndSettle();
      expect(h.cart.calls.where((c) => c.startsWith('add:')), ['add:sp1:pk1:3']);
      expect(find.textContaining('Đã thêm Tilt Super 300EC vào giỏ hàng'), findsOneWidget);
      expect(find.text('Xem giỏ'), findsOneWidget);
    });

    testWidgets('thêm vào giỏ thất bại thì báo lỗi, không báo đã thêm', (tester) async {
      await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.areaStore.data[AdvisoryAreaController.key] = '3.0|cong';
        h.advisory.answer = answerWithPlan();
        h.cart.writeError = _net;
      });
      await tester.ensureVisible(find.byKey(const Key('advisory_add_sp1')));
      await tester.tap(find.byKey(const Key('advisory_add_sp1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      expect(find.textContaining('Đã thêm'), findsNothing);
    });

    testWidgets('hết hàng: nút bị khoá, không thể thêm vào giỏ', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.areaStore.data[AdvisoryAreaController.key] = '3.0|cong';
        h.advisory.answer = answerWithPlan(stock: 'OUT_OF_STOCK');
      });
      expect(find.text('Hết hàng'), findsWidgets);
      expect(find.byKey(const Key('advisory_add_sp1')), findsNothing);
      final button = tester.widget<OutlinedButton>(find.byKey(const Key('advisory_soldout_sp1')));
      expect(button.onPressed, isNull);
      expect(h.cart.calls.where((c) => c.startsWith('add:')), isEmpty);
    });

    testWidgets('không đủ hàng: báo rõ nhưng vẫn cho thêm', (tester) async {
      await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.areaStore.data[AdvisoryAreaController.key] = '3.0|cong';
        h.advisory.answer = answerWithPlan(stock: 'NOT_ENOUGH');
      });
      expect(find.text('Không đủ số lượng'), findsOneWidget);
      expect(find.textContaining('chưa đủ số lượng này'), findsOneWidget);
      expect(find.byKey(const Key('advisory_add_sp1')), findsOneWidget);
    });

    testWidgets('sản phẩm chưa có liều theo ha: không có nút thêm, chỉ mở sản phẩm', (tester) async {
      await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.areaStore.data[AdvisoryAreaController.key] = '3.0|cong';
        h.advisory.answer = (q) => recommendationJson(
              areaSqm: q.areaSqm,
              protection: [advisoryProductJson('sp9', 'Camilo 150SC', withPlan: false, preHarvestDays: null)],
            );
      });
      expect(find.textContaining('Chưa tính được số lượng'), findsOneWidget);
      expect(find.byKey(const Key('advisory_add_sp9')), findsNothing);
      expect(find.byKey(const Key('advisory_open_sp9')), findsOneWidget);
      expect(find.textContaining('Cách ly'), findsNothing);
    });

    testWidgets('phân bón hiện ở nhóm riêng, không có nguồn đăng ký', (tester) async {
      await open(tester, '/advisory/problem/d-NITROGEN_DEFICIENCY', setup: (h) {
        h.advisory.answer = (q) => recommendationJson(
              code: 'NITROGEN_DEFICIENCY',
              name: 'Lúa vàng lá do thiếu đạm',
              type: 'NUTRITION',
              areaSqm: q.areaSqm,
              protection: [],
              nutrition: [
                advisoryProductJson('sp7', 'Đạm Phú Mỹ', group: 'NUTRITION', withPlan: false, preHarvestDays: null, doseText: 'Chia 2-3 lần bón thúc.'),
              ],
            );
      });
      expect(find.byKey(const Key('advisory_nutrition')), findsOneWidget);
      expect(find.byKey(const Key('advisory_protection')), findsNothing);
      expect(find.text('Đạm Phú Mỹ'), findsOneWidget);
      expect(find.byKey(const Key('advisory_source_sp7')), findsNothing);
    });

    testWidgets('chưa có sản phẩm nào được duyệt: nói để hỏi cửa hàng', (tester) async {
      await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.advisory.answer = (q) => recommendationJson(protection: [], emptyReason: 'NO_APPROVED_PRODUCT');
      });
      expect(find.byKey(const Key('advisory_empty_reason')), findsOneWidget);
      expect(find.textContaining('chưa có sản phẩm gợi ý cho vấn đề này'), findsOneWidget);
      expect(find.byKey(const Key('advisory_protection')), findsNothing);
    });

    testWidgets('đi từ ca chẩn đoán AI: gửi mã ca và ghi nguồn', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT?caseId=case-9',
          setup: (h) => h.advisory.answer = answerWithPlan());
      expect(h.advisory.recommendCalls.single.diagnosisCaseId, 'case-9');
      expect(find.text('Từ kết quả AI'), findsOneWidget);
    });

    testWidgets('lỗi mạng khi tư vấn: Thử lại gọi lại', (tester) async {
      final h = await open(tester, '/advisory/problem/d-SHEATH_BLIGHT', setup: (h) {
        h.advisory.answer = answerWithPlan();
        h.advisory.recommendError = _net;
      });
      expect(find.text('Thử lại'), findsOneWidget);
      h.advisory.recommendError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Tilt Super 300EC'), findsOneWidget);
    });
  });

  group('Từ kết quả chẩn đoán AI', () {
    Future<AppHarness> openCase(WidgetTester tester, Map<String, dynamic> result) => open(
          tester,
          '/ai-scan/case/c1',
          setup: (h) => h.diagnosis.cases['c1'] = caseOf('c1', status: 'AI_COMPLETED', withImage: false, result: result),
        );

    testWidgets('AI chắc chắn: có nút xem tư vấn chi tiết, mở đúng vấn đề kèm mã ca', (tester) async {
      final h = await openCase(tester, aiResultJson());
      await tester.ensureVisible(find.byKey(const Key('case_advisory')));
      await tester.tap(find.byKey(const Key('case_advisory')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advisory_problem_header')), findsOneWidget, reason: 'đã sang màn tư vấn');
      expect(h.advisory.recommendCalls.single.diseaseId, 'd1');
      expect(h.advisory.recommendCalls.single.diagnosisCaseId, 'c1');
    });

    testWidgets('AI chưa chắc hoặc lá khoẻ: không có nút tư vấn', (tester) async {
      await openCase(tester, aiResultJson(uncertain: true));
      expect(find.byKey(const Key('case_advisory')), findsNothing);
    });

    testWidgets('lá khoẻ: không có nút tư vấn', (tester) async {
      await openCase(tester, aiResultJson(code: 'HEALTHY', name: 'Healthy', healthy: true));
      expect(find.byKey(const Key('case_advisory')), findsNothing);
    });
  });

  group('Lối vào từ Trang chủ', () {
    testWidgets('Trang chủ có lối tắt Tư vấn mở màn tìm vấn đề', (tester) async {
      final h = AppHarness()..signIn();
      h.realHome = true;
      await h.pump(tester, initial: '/home');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_qa_advisory')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advisory_search')), findsOneWidget);
    });
  });

  group('Mô hình', () {
    test('đổi đơn vị diện tích sang mét vuông', () {
      expect(const AreaInput(3, AreaUnit.cong).sqm, 3000);
      expect(const AreaInput(2, AreaUnit.sao).sqm, 720);
      expect(const AreaInput(0.5, AreaUnit.ha).sqm, 5000);
      expect(const AreaInput(300, AreaUnit.m2).sqm, 300);
      expect(const AreaInput(2.5, AreaUnit.cong).valueText, '2,5');
      expect(const AreaInput(3, AreaUnit.cong).valueText, '3');
    });

    test('điều kiện tư vấn so sánh theo giá trị (khoá của provider)', () {
      const a = AdvisoryQuery(diseaseId: 'd', areaSqm: 1000, growthStage: 'HEADING');
      const b = AdvisoryQuery(diseaseId: 'd', areaSqm: 1000, growthStage: 'HEADING');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const AdvisoryQuery(diseaseId: 'd', areaSqm: 2000, growthStage: 'HEADING'), isFalse);
    });

    test('mã lý do rỗng và mã lạ', () {
      expect(emptyReasonText(null), isNull);
      expect(emptyReasonText('NOTHING_IN_STORE'), contains('chưa bán'));
      expect(emptyReasonText('SOMETHING_NEW'), contains('hỏi cửa hàng'));
    });
  });
}

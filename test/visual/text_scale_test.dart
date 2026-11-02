// Quét lỗi tràn layout (overflow) khi người dùng đặt CỠ CHỮ HỆ THỐNG LỚN (nông dân
// lớn tuổi hay dùng), bằng font thật, ở khung 360px. Cần mạng để tải font Google.
//
//   SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test test/visual/text_scale_test.dart
//
// Thất bại nếu có RenderFlex overflow. Ảnh (chỉ khi thêm --update-goldens) ra test/visual/shots/.
import 'dart:io';

import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/advisory_fakes.dart';
import '../helpers/app_harness.dart';
import '../helpers/debt_fakes.dart';
import '../helpers/diagnosis_fakes.dart';
import '../helpers/notification_fakes.dart';
import '../helpers/order_fakes.dart';
import '../helpers/return_fakes.dart';
import 'auth_screenshots_test.dart' show shoot, useRealFonts;

final _on = Platform.environment['SCREENSHOTS'] == '1';

void seed(AppHarness h) {
  final now = DateTime.now();
  h.realHome = true;
  h.orders.orders['o1'] = orderOf(id: 'o1', status: 'COMPLETED', total: 1560000);
  h.orders.list0 = [
    summaryOf('o1', status: 'COMPLETED', total: 1560000),
    summaryOf('o2', status: 'PENDING_CONFIRMATION'),
    summaryOf('o3', status: 'PREPARING', settlement: 'CREDIT', fulfillment: 'PICKUP'),
  ];
  h.returns.returnables['o1'] = returnableOf();
  h.returns.list0 = [returnSummaryOf('a', status: 'APPROVED')];
  h.returns.details['a'] = returnOf('a', status: 'APPROVED');
  h.debt.account0 = accountOf(balance: 4100000, overdue: 2350000, open: 3);
  h.credit.credit = creditOf(available: 5900000);
  final entries = [
    entryOf('a', original: 2350000, due: DateTime(2026, 10, 5), overdue: true, overdueDays: 7),
    entryOf('b', status: 'PARTIALLY_PAID', original: 1800000, paid: 600000),
  ];
  h.debt.entries0 = entries;
  for (final e in entries) {
    h.debt.details[e.id] = detailOf(e.id,
        status: e.status, original: e.originalAmount, paid: e.totalPaid, overdue: e.isOverdue, overdueDays: e.overdueDays);
  }
  h.debt.repayments0 = [repaymentOf('1', amount: 1500000)];
  h.diagnosis.list0 = [
    diagSummaryOf('v',
        status: 'AI_COMPLETED', code: 'LEAF_BLAST', name: 'Leaf Blast', certainty: 'CONFIDENT'),
    diagSummaryOf('w',
        status: 'AI_COMPLETED',
        code: 'BACTERIAL_LEAF_BLIGHT',
        name: 'Bacterial Leaf Blight',
        certainty: 'UNCERTAIN'),
    diagSummaryOf('f', status: 'FAILED'),
  ];
  h.diagnosis.cases['v'] =
      caseOf('v', status: 'AI_COMPLETED', withImage: false, result: aiResultJson());
  h.diagnosis.cases['w'] = caseOf('w',
      status: 'AI_COMPLETED',
      withImage: false,
      note: 'Lá vàng từ chóp',
      result: aiResultJson(
          uncertain: true, code: 'BACTERIAL_LEAF_BLIGHT', name: 'Bacterial Leaf Blight'));
  h.diagnosis.cases['f'] = caseOf('f', status: 'FAILED', withImage: false);
  // Tư vấn vật tư: một thuốc còn hàng có số lượng, một thuốc không đủ hàng, một thuốc chưa có liều, một phân bón.
  h.areaStore.data['agrisage.advisory_area'] = '3.0|cong';
  h.advisory.answer = (q) => recommendationJson(
        areaSqm: q.areaSqm,
        growthStage: q.growthStage,
        protection: [
          advisoryProductJson('sp1', 'Tilt Super 300EC - trị khô vằn, lem lép hạt', withPlan: q.areaSqm != null),
          advisoryProductJson('sp2', 'Amistar Top 325SC - trị khô vằn, lem lép hạt', stock: 'NOT_ENOUGH', withPlan: q.areaSqm != null),
          advisoryProductJson('sp3', 'Camilo 150SC - thuốc trừ đốm nâu, khô vằn', withPlan: false, preHarvestDays: null),
        ],
        nutrition: [
          advisoryProductJson('sp4', 'Đạm Phú Mỹ (Urê hạt đục 46,3% N)', group: 'NUTRITION', stock: 'OUT_OF_STOCK', doseText: 'Chia 2-3 lần bón thúc, tổng 150-200 kg/ha tùy giống và đất.'),
        ],
      );
  h.notifications.items = [
    notifOf('a', title: 'Đơn hàng đang được giao', type: 'ORDER_STATUS_CHANGED'),
    notifOf('b', title: 'Có khoản công nợ quá hạn', type: 'DEBT_OVERDUE', entityType: 'DEBT_ENTRY', read: true),
  ];
  h.repo.sessions0 = [
    AuthSession(id: 's1', createdAt: now.subtract(const Duration(days: 1)), lastUsedAt: now, expiresAt: now.add(const Duration(days: 29)), isCurrent: true),
    AuthSession(id: 's2', createdAt: now.subtract(const Duration(days: 8)), lastUsedAt: now.subtract(const Duration(days: 2)), expiresAt: now.add(const Duration(days: 22)), isCurrent: false),
  ];
}

const _routes = <String>[
  '/home',
  '/products',
  '/cart',
  '/orders',
  '/orders/o1',
  '/orders/o1/return',
  '/returns',
  '/returns/a',
  '/debt',
  '/debt/list',
  '/debt/a',
  '/debt/b',
  '/debt/repay?amount=2000000',
  '/debt/history',
  '/advisory',
  '/advisory/problem/d-SHEATH_BLIGHT',
  '/advisory/problem/d-SHEATH_BLIGHT?caseId=v',
  '/ai-scan',
  '/ai-scan/capture',
  '/ai-scan/history',
  '/ai-scan/case/v',
  '/ai-scan/case/w',
  '/ai-scan/case/f',
  '/home/notifications',
  '/profile',
  '/profile/edit',
  '/profile/addresses',
  '/profile/sessions',
  '/profile/help',
  '/profile/terms',
  '/profile/privacy',
  '/profile/notifications',
  '/login',
  '/register',
  '/welcome',
];

void main() {
  for (final scale in [1.3, 1.6]) {
    group('chữ hệ thống x$scale ở 360px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      for (final route in _routes) {
        testWidgets(route, (tester) async {
          await useRealFonts(tester);
          final signedIn = !['/login', '/register', '/welcome'].contains(route);
          final h = AppHarness();
          if (signedIn) h.signIn();
          seed(h);
          await h.pump(tester, initial: route);
          tester.view.physicalSize = const Size(360 * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          // Màn có đồng hồ/ảnh chạy mãi: không chờ yên lặng được.
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 600));
          // Cuộn hết màn để lộ các phần dưới (overflow nằm ở phần cuộn cũng bị bắt).
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            try {
              await tester.drag(scrollable.first, const Offset(0, -2000));
              await tester.pump(const Duration(milliseconds: 600));
            } catch (_) {}
          }
          if (Platform.environment['SHOTS'] == '1') {
            await shoot(tester, 'ts${(scale * 10).round()}_${route.replaceAll(RegExp(r'[/?=]'), '_')}');
          }
        });
      }
    });
  }
}

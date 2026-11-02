// Test tích hợp tư vấn vật tư với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/advisory_live_test.dart
//
// Tạo 1 tài khoản nông dân ("TEST Mobile Advisory <mã>") trên DB đang trỏ tới và đọc/ghi 2 ca tư vấn thật.
// Chỉ kiểm tra hình dạng dữ liệu và luật chung, không đòi sản phẩm cụ thể (cửa hàng có thể chưa duyệt liên kết nào).
@Timeout(Duration(minutes: 5))
library;

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/advisory/data/advisory_models.dart';
import 'package:farmer_mobile/features/advisory/data/advisory_repository.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

const _ghost = '0198a0f0-3333-7000-8000-000000000000';

void main() {
  late ProviderContainer c;
  late AdvisoryRepository repo;

  setUpAll(() async {
    if (!liveEnabled) return;
    final storage = MemoryTokenStorage();
    c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWith((ref) => createApiDio(
            baseUrl: liveBaseUrl,
            storage: storage,
            onSessionExpired: () async => ref.read(sessionProvider.notifier).markUnauthenticated(),
            adapter: liveAdapter,
          )),
    ]);
    addTearDown(c.dispose);
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    await c.read(authControllerProvider).register(
        fullName: 'TEST Mobile Advisory $code', phoneNumber: randomPhone(), password: 'Test@12345678');
    repo = c.read(advisoryRepositoryProvider);
  });

  final skip = liveEnabled ? null : 'Đặt LIVE_API=1 để chạy test với backend thật';

  test('liệt kê vấn đề, lọc theo loại và tìm không dấu', skip: skip, () async {
    final all = await repo.problems();
    expect(all.items, isNotEmpty);
    expect(all.items.every((p) => p.id.isNotEmpty && p.name.isNotEmpty), isTrue);
    expect(all.items.any((p) => p.code == 'HEALTHY'), isFalse, reason: 'lớp lá khoẻ không phải vấn đề để tư vấn');

    final diseases = await repo.problems(type: ProblemType.disease);
    expect(diseases.items.every((p) => p.problemType == ProblemType.disease), isTrue);

    final found = await repo.problems(search: 'dao on');
    expect(found.items.any((p) => p.code == 'LEAF_BLAST'), isTrue, reason: '"dao on" khớp đạo ôn');
  });

  test('tư vấn một vấn đề: đọc được mọi trường, kế hoạch mua nhất quán với giá', skip: skip, () async {
    final problems = await repo.problems(search: 'kho van');
    final id = problems.items.firstWhere((p) => p.code == 'SHEATH_BLIGHT').id;

    final withArea = await repo.recommend(AdvisoryQuery(diseaseId: id, areaSqm: 3000));
    expect(withArea.sessionId, isNotEmpty);
    expect(withArea.problem.id, id);
    expect(withArea.areaSqm, 3000);
    expect(withArea.safetyNote, isNotEmpty);
    for (final p in [...withArea.protection, ...withArea.nutrition]) {
      expect(p.storeProductId, isNotEmpty);
      expect(p.doseText, isNotEmpty);
      expect([AdvisoryStock.enough, AdvisoryStock.notEnough, AdvisoryStock.outOfStock], contains(p.stockStatus));
      final plan = p.plan;
      if (plan != null) {
        expect(plan.lines, isNotEmpty);
        final sum = plan.lines.fold<double>(0, (s, l) => s + l.lineAmount);
        expect(plan.totalAmount, closeTo(sum, 0.01), reason: 'tổng tiền = tổng các dòng');
        expect(plan.lines.every((l) => l.quantity > 0 && l.packagingId.isNotEmpty), isTrue);
      }
    }
    if (!withArea.hasProducts) {
      expect(emptyReasonText(withArea.emptyReason), isNotNull, reason: 'không có sản phẩm thì phải nói lý do');
    }

    final noArea = await repo.recommend(AdvisoryQuery(diseaseId: id));
    expect(noArea.areaSqm, isNull);
    expect([...noArea.protection, ...noArea.nutrition].every((p) => p.plan == null), isTrue,
        reason: 'chưa nhập diện tích thì chưa có số lượng');
  });

  test('điều kiện sai bị từ chối bằng thông báo tiếng Việt', skip: skip, () async {
    await expectLater(
      repo.recommend(const AdvisoryQuery(diseaseId: _ghost)),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.notFound)),
    );
    final id = (await repo.problems()).items.first.id;
    await expectLater(
      repo.recommend(AdvisoryQuery(diseaseId: id, areaSqm: -5)),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Diện tích'))),
    );
    await expectLater(
      repo.recommend(AdvisoryQuery(diseaseId: id, growthStage: 'FLOWERING')),
      throwsA(isA<ApiException>()),
    );
  });
}

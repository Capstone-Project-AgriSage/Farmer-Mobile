import 'dart:async';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/profile_fakes.dart';

String _name(WidgetTester tester) => tester
    .widget<EditableText>(find.descendant(
        of: field('profile_name'), matching: find.byType(EditableText)))
    .controller
    .text;

Future<AppHarness> open(WidgetTester tester,
    {void Function(FakeProfileRepository)? setup, String from = '/profile/edit'}) async {
  final h = AppHarness()..signIn();
  setup?.call(h.profile);
  await h.pump(tester, initial: from);
  await tester.pumpAndSettle();
  return h;
}

Future<void> save(WidgetTester tester) async {
  final b = find.widgetWithText(ElevatedButton, 'Lưu thay đổi');
  await tester.ensureVisible(b);
  await tester.tap(b);
  await tester.pump();
}

void main() {
  testWidgets('đang tải hồ sơ: hiện vòng tải, xong thì hiện form', (tester) async {
    final h = AppHarness()..signIn();
    final gate = Completer<void>();
    h.profile.profileGate = gate.future;
    await h.pump(tester, initial: '/profile/edit');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(field('profile_name'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(field('profile_name'), findsOneWidget);
  });

  testWidgets('hiện dữ liệu thật; SĐT/email chỉ đọc; có nhóm khách hàng', (tester) async {
    await open(tester, setup: (r) {
      r.profile = FarmerProfile.fromJson(profileJson(email: 'hai@example.com'));
    });

    expect(_name(tester), 'Trần Văn Hải');
    expect(find.text('0912345678'), findsOneWidget);
    expect(find.text('hai@example.com'), findsOneWidget);
    expect(find.text('01/05/1980'), findsOneWidget);
    expect(find.text('Nhóm khách hàng: Khách quen'), findsOneWidget);
    expect(find.text('TH'), findsOneWidget);
    // SĐT/email không phải ô nhập.
    expect(find.descendant(of: field('profile_phone'), matching: find.byType(EditableText)),
        findsNothing);
    expect(find.descendant(of: field('profile_email'), matching: find.byType(EditableText)),
        findsNothing);
    // Giới tính được chọn đúng.
    expect(tester.widget<ChoiceChip>(field('gender_MALE')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(field('gender_FEMALE')).selected, isFalse);
  });

  testWidgets('chưa có ngày sinh, giới tính, email: hiện "Chưa chọn"/"Chưa có"', (tester) async {
    await open(tester, setup: (r) {
      r.profile = FarmerProfile.fromJson(profileJson(dob: null, gender: null));
    });

    expect(find.text('Chưa chọn'), findsOneWidget);
    expect(find.text('Chưa có'), findsOneWidget); // email
    expect(tester.widget<ChoiceChip>(field('gender_MALE')).selected, isFalse);
  });

  testWidgets('lỗi tải: Thử lại tải được', (tester) async {
    final h = await open(tester, setup: (r) {
      r.profileError =
          const ApiException(kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ.');
    });
    expect(find.text('Không kết nối được máy chủ.'), findsOneWidget);

    h.profile.profileError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(_name(tester), 'Trần Văn Hải');
  });

  testWidgets('tên trống: báo lỗi, không gọi server', (tester) async {
    final h = await open(tester);

    await tester.enterText(field('profile_name'), '   ');
    await save(tester);

    expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
    expect(h.profile.calls, ['getProfile']);
  });

  testWidgets('chữ cái đầu ở avatar đổi theo tên đang gõ', (tester) async {
    await open(tester);
    await tester.enterText(field('profile_name'), 'Lê Thị Mai');
    await tester.pump();
    expect(find.text('LM'), findsOneWidget);
  });

  testWidgets('chọn/bỏ chọn giới tính (bấm lại để bỏ)', (tester) async {
    final h = await open(tester);

    await tester.tap(field('gender_FEMALE'));
    await tester.pump();
    expect(tester.widget<ChoiceChip>(field('gender_FEMALE')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(field('gender_MALE')).selected, isFalse);

    await tester.tap(field('gender_FEMALE'));
    await tester.pump();
    await save(tester);
    await tester.pumpAndSettle();

    expect(h.profile.lastGender, isNull);
  });

  testWidgets('chọn ngày sinh bằng lịch và xoá ngày sinh', (tester) async {
    final h = await open(tester, setup: (r) {
      r.profile = FarmerProfile.fromJson(profileJson(dob: null));
    });

    await tester.tap(field('profile_dob'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn ngày sinh'), findsOneWidget);
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa chọn'), findsNothing); // đã có ngày

    await tester.tap(find.byTooltip('Xoá ngày sinh'));
    await tester.pump();
    expect(find.text('Chưa chọn'), findsOneWidget);

    await save(tester);
    await tester.pumpAndSettle();
    expect(h.profile.lastDob, isNull);
  });

  testWidgets('lưu thành công: gửi đúng dữ liệu, cập nhật tên ở phiên, báo thành công',
      (tester) async {
    final h = AppHarness()..signIn();
    await h.pump(tester, initial: '/profile');
    await tester.pumpAndSettle();
    expect(find.text('Trần Văn Hải'), findsOneWidget);

    h.router.push('/profile/edit');
    await tester.pumpAndSettle();
    await tester.enterText(field('profile_name'), '  Nguyễn Văn Bình ');
    await tester.tap(field('gender_OTHER'));
    await tester.pump();
    await save(tester);
    await tester.pumpAndSettle();

    expect(h.profile.lastProfileName, '  Nguyễn Văn Bình ');
    expect(h.profile.lastGender, 'OTHER');
    expect(h.profile.lastDob, DateTime(1980, 5, 1));
    expect(find.text('Đã cập nhật thông tin cá nhân.'), findsOneWidget);
    // Về Hồ sơ và thấy tên mới (lấy từ phiên).
    expect(h.session.user?.fullName, 'Nguyễn Văn Bình');
    expect(find.text('Nguyễn Văn Bình'), findsOneWidget);
    expect(find.text('NB'), findsOneWidget);
  });

  testWidgets('lỗi 400 từ server: hiện banner, ở lại màn', (tester) async {
    final h = await open(tester);
    h.profile.writeError = const ApiException(
        kind: ApiErrorKind.validation, statusCode: 400, message: 'Dữ liệu không hợp lệ.');

    await save(tester);
    await tester.pumpAndSettle();

    expect(find.text('Dữ liệu không hợp lệ.'), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
  });

  testWidgets('lỗi: tên người dùng ở phiên KHÔNG bị đổi', (tester) async {
    final h = await open(tester);
    h.profile.writeError =
        const ApiException(kind: ApiErrorKind.network, message: 'mạng');
    await tester.enterText(field('profile_name'), 'Tên mới');

    await save(tester);
    await tester.pumpAndSettle();

    expect(h.session.user?.fullName, 'Trần Văn Hải');
  });

  testWidgets('mục "Thông tin cá nhân" và "Quản lý địa chỉ" ở Hồ sơ mở đúng màn',
      (tester) async {
    final h = AppHarness()..signIn();
    h.profile.addresses = [makeAddress('a', isDefault: true, name: 'Hải')];
    await h.pump(tester, initial: '/profile');
    await tester.pumpAndSettle();

    await tapText(tester, 'Quản lý địa chỉ');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('address_a')), findsOneWidget);
  });
}

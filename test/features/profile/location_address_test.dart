import 'package:farmer_mobile/data/models/address.dart';
import 'package:farmer_mobile/features/profile/data/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

String _text(WidgetTester tester, String key) => tester
    .widget<EditableText>(
        find.descendant(of: field(key), matching: find.byType(EditableText)))
    .controller
    .text;

Future<AppHarness> openForm(WidgetTester tester) async {
  final h = AppHarness()..signIn();
  await h.pump(tester, initial: '/profile/addresses/add');
  await tester.pumpAndSettle();
  return h;
}

Future<void> tapLocate(WidgetTester tester) async {
  await tester.ensureVisible(field('addr_use_location'));
  await tester.tap(field('addr_use_location'));
  await tester.pumpAndSettle();
}

void main() {
  group('addressFromPlace (geocoder -> ô địa chỉ)', () {
    test('tỉnh bỏ tiền tố; quận/huyện và phường/xã giữ nguyên', () {
      final a = addressFromPlace(
        10.0452,
        105.7469,
        const PlaceParts(
          administrativeArea: 'Thành phố Cần Thơ',
          subAdministrativeArea: 'Huyện Thới Lai',
          subLocality: 'Xã Thới Tân',
          thoroughfare: 'Đường Tỉnh 922',
          subThoroughfare: '12',
        ),
      );
      expect(a.province, 'Cần Thơ');
      expect(a.district, 'Huyện Thới Lai');
      expect(a.ward, 'Xã Thới Tân');
      expect(a.line, '12 Đường Tỉnh 922');
      expect(a.latitude, 10.0452);
      expect(a.hasText, isTrue);
    });

    test('"Quận 1" không bị mất chữ Quận; tỉnh "Tỉnh An Giang" thành "An Giang"', () {
      final a = addressFromPlace(
        10.77,
        106.69,
        const PlaceParts(
            administrativeArea: 'Tỉnh An Giang', subAdministrativeArea: 'Quận 1'),
      );
      expect(a.province, 'An Giang');
      expect(a.district, 'Quận 1');
    });

    test('locality trùng tên tỉnh không bị coi là quận/huyện', () {
      final a = addressFromPlace(
        10,
        105,
        const PlaceParts(administrativeArea: 'Cần Thơ', locality: 'Cần Thơ'),
      );
      expect(a.province, 'Cần Thơ');
      expect(a.district, isNull);
    });

    test('không có subAdministrativeArea thì lấy locality', () {
      final a = addressFromPlace(
        10,
        105,
        const PlaceParts(administrativeArea: 'Cần Thơ', locality: 'Huyện Cờ Đỏ'),
      );
      expect(a.district, 'Huyện Cờ Đỏ');
    });

    test('Plus Code và "đường không tên" không được điền vào ô địa chỉ', () {
      for (final road in ['7P2V+W8', 'Unnamed Road', 'Đường không tên']) {
        final a = addressFromPlace(
            10, 105, PlaceParts(administrativeArea: 'Cần Thơ', thoroughfare: road));
        expect(a.line, isNull, reason: road);
      }
    });

    test('chỉ có toạ độ: hasText false', () {
      final a = addressFromPlace(10, 105, const PlaceParts());
      expect(a.hasText, isFalse);
    });
  });

  test('AddressInput: chỉ gửi toạ độ khi có đủ cả hai', () {
    const base = AddressInput(
      recipientName: 'A',
      recipientPhone: '0912345678',
      addressLine: 'Số 1',
      province: 'Cần Thơ',
      addressType: AddressType.home,
    );
    expect(base.toJson().containsKey('latitude'), isFalse);
    expect(base.toJson().containsKey('longitude'), isFalse);

    const located = AddressInput(
      recipientName: 'A',
      recipientPhone: '0912345678',
      addressLine: 'Số 1',
      province: 'Cần Thơ',
      addressType: AddressType.home,
      latitude: 10.0452,
      longitude: 105.7469,
    );
    expect(located.toJson()['latitude'], 10.0452);
    expect(located.toJson()['longitude'], 105.7469);
  });

  group('Form địa chỉ: nút "Dùng vị trí hiện tại"', () {
    testWidgets('điền tỉnh/huyện/xã và số nhà, lưu kèm toạ độ', (tester) async {
      final h = await openForm(tester);
      expect(find.text('Dùng vị trí hiện tại'), findsOneWidget);
      // Chưa bấm thì chưa hỏi vị trí.
      expect(h.geo.calls, 0);

      await tapLocate(tester);
      expect(h.geo.calls, 1);
      expect(_text(tester, 'addr_province'), 'Cần Thơ');
      expect(_text(tester, 'addr_district'), 'Huyện Thới Lai');
      expect(_text(tester, 'addr_ward'), 'Xã Thới Tân');
      expect(_text(tester, 'addr_line'), '12 Đường Tỉnh 922');
      expect(find.textContaining('Đã điền theo vị trí hiện tại'), findsOneWidget);

      await enter(tester, 'addr_name', 'Nguyễn A');
      await enter(tester, 'addr_phone', '0912345678');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu địa chỉ'));
      await tester.pumpAndSettle();

      final input = h.profile.lastInput!;
      expect(input.latitude, 10.0452);
      expect(input.longitude, 105.7469);
      expect(input.province, 'Cần Thơ');
    });

    testWidgets('không đè lên số nhà người dùng đã gõ', (tester) async {
      final h = await openForm(tester);
      await enter(tester, 'addr_line', 'Ấp 3, nhà bà Tư');

      await tapLocate(tester);

      expect(h.geo.calls, 1);
      expect(_text(tester, 'addr_line'), 'Ấp 3, nhà bà Tư');
      expect(_text(tester, 'addr_province'), 'Cần Thơ');
    });

    testWidgets('từ chối quyền: hiện lý do, ô vẫn nhập tay và lưu được không toạ độ', (tester) async {
      final h = await openForm(tester);
      h.geo.error = const LocationException(LocationProblem.denied);

      await tapLocate(tester);

      expect(find.textContaining('chưa cho phép'), findsOneWidget);
      await enter(tester, 'addr_name', 'Nguyễn A');
      await enter(tester, 'addr_phone', '0912345678');
      await enter(tester, 'addr_province', 'Cần Thơ');
      await enter(tester, 'addr_line', 'Số 1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu địa chỉ'));
      await tester.pumpAndSettle();

      expect(h.profile.lastInput!.latitude, isNull);
      expect(h.profile.lastInput!.longitude, isNull);
    });

    testWidgets('GPS tắt: báo cách bật, không điền gì', (tester) async {
      final h = await openForm(tester);
      h.geo.error = const LocationException(LocationProblem.serviceDisabled);

      await tapLocate(tester);

      expect(find.textContaining('GPS'), findsOneWidget);
      expect(_text(tester, 'addr_province'), isEmpty);
    });

    testWidgets('chỉ có toạ độ (geocoder không trả địa chỉ): báo nhập tay, vẫn lưu toạ độ', (tester) async {
      final h = await openForm(tester);
      h.geo.result = const DetectedAddress(latitude: 9.99, longitude: 105.5);

      await tapLocate(tester);

      expect(find.textContaining('chưa xác định được địa chỉ'), findsOneWidget);
      expect(_text(tester, 'addr_province'), isEmpty);

      await enter(tester, 'addr_name', 'Nguyễn A');
      await enter(tester, 'addr_phone', '0912345678');
      await enter(tester, 'addr_province', 'Cần Thơ');
      await enter(tester, 'addr_line', 'Số 1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu địa chỉ'));
      await tester.pumpAndSettle();

      expect(h.profile.lastInput!.latitude, 9.99);
    });
  });
}

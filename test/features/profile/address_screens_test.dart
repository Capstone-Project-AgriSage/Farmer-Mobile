import 'dart:async';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/shared/widgets/shimmer_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/profile_fakes.dart';

const _list = '/profile/addresses';

Future<AppHarness> openList(WidgetTester tester,
    {void Function(FakeProfileRepository)? setup}) async {
  final h = AppHarness()..signIn();
  setup?.call(h.profile);
  await h.pump(tester, initial: _list);
  await tester.pumpAndSettle();
  return h;
}

String _text(WidgetTester tester, String key) => tester
    .widget<EditableText>(find.descendant(
        of: field(key), matching: find.byType(EditableText)))
    .controller
    .text;

void main() {
  group('Danh sách địa chỉ', () {
    testWidgets('đang tải: hiện khung xương, rồi hiện danh sách', (tester) async {
      final h = AppHarness()..signIn();
      final gate = Completer<void>();
      h.profile.addresses = [makeAddress('a', isDefault: true)];
      h.profile.listGate = gate.future;
      await h.pump(tester, initial: _list);
      await tester.pump();

      expect(find.byType(ShimmerListWidget), findsOneWidget);
      expect(find.byKey(const Key('address_a')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('address_a')), findsOneWidget);
    });

    testWidgets('hiện thẻ: tên, SĐT, địa chỉ đầy đủ, nhãn Mặc định và loại',
        (tester) async {
      await openList(tester, setup: (r) {
        r.addresses = [
          makeAddress('a', isDefault: true, name: 'Trần Văn Hải', line: 'Ấp 3'),
          makeAddress('b', name: 'Lê Thị Mai', type: 'FARM'),
        ];
      });

      expect(find.text('Trần Văn Hải'), findsOneWidget);
      expect(find.text('Lê Thị Mai'), findsOneWidget);
      expect(find.text('Mặc định'), findsOneWidget);
      expect(find.text('Nhà riêng'), findsOneWidget);
      expect(find.text('Vườn / Ruộng'), findsOneWidget);
      expect(find.textContaining('Ấp 3, Cần Thơ'), findsOneWidget);
      // Địa chỉ mặc định không có nút "Đặt mặc định", địa chỉ khác có.
      expect(find.byKey(const Key('address_default_a')), findsNothing);
      expect(find.byKey(const Key('address_default_b')), findsOneWidget);
    });

    testWidgets('rỗng: thông báo + nút Thêm địa chỉ mở form', (tester) async {
      final h = await openList(tester);

      expect(find.textContaining('Bạn chưa có địa chỉ nào'), findsOneWidget);
      expect(field('address_add'), findsNothing); // nút dưới ẩn khi rỗng

      await tester.tap(find.text('Thêm địa chỉ'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm địa chỉ mới'), findsWidgets);
      expect(h.profile.calls, ['listAddresses']);
    });

    testWidgets('lỗi mạng: thông báo + Thử lại tải lại được', (tester) async {
      final h = await openList(tester, setup: (r) {
        r.listError =
            const ApiException(kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ.');
      });
      expect(find.text('Không kết nối được máy chủ.'), findsOneWidget);

      h.profile.listError = null;
      h.profile.addresses = [makeAddress('a', isDefault: true)];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('address_a')), findsOneWidget);
    });

    testWidgets('đặt mặc định: nhãn chuyển sang địa chỉ kia, thông báo thành công',
        (tester) async {
      final h = await openList(tester, setup: (r) {
        r.addresses = [
          makeAddress('a', isDefault: true, name: 'Một'),
          makeAddress('b', name: 'Hai'),
        ];
      });

      await tester.tap(field('address_default_b'));
      await tester.pumpAndSettle();

      expect(h.profile.calls, contains('setDefault:b'));
      expect(find.text('Đã đặt làm địa chỉ mặc định.'), findsOneWidget);
      expect(find.text('Mặc định'), findsOneWidget);
      // Địa chỉ mặc định mới nhảy lên đầu.
      final firstTop = tester.getTopLeft(find.byKey(const Key('address_b'))).dy;
      final secondTop = tester.getTopLeft(find.byKey(const Key('address_a'))).dy;
      expect(firstTop, lessThan(secondTop));
      expect(field('address_default_b'), findsNothing);
      expect(field('address_default_a'), findsOneWidget);
    });

    testWidgets('đang xử lý: nút bị khoá, bấm đúp chỉ gửi một lần', (tester) async {
      final gate = Completer<void>();
      final h = await openList(tester, setup: (r) {
        r.addresses = [
          makeAddress('a', isDefault: true),
          makeAddress('b'),
        ];
        r.gate = gate.future;
      });

      await tester.tap(field('address_default_b'));
      await tester.pump();

      expect(tester.widget<TextButton>(field('address_default_b')).onPressed, isNull);
      expect(tester.widget<TextButton>(field('address_delete_b')).onPressed, isNull);
      await tester.tap(field('address_default_b'), warnIfMissed: false);
      await tester.pump();
      expect(h.profile.calls.where((c) => c.startsWith('setDefault')).length, 1);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('xoá: hỏi xác nhận; Huỷ thì không xoá', (tester) async {
      final h = await openList(tester, setup: (r) {
        r.addresses = [makeAddress('a', isDefault: true), makeAddress('b')];
      });

      await tester.tap(field('address_delete_b'));
      await tester.pumpAndSettle();
      expect(find.text('Xoá địa chỉ'), findsOneWidget);

      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      expect(h.profile.calls.where((c) => c.startsWith('delete')), isEmpty);
      expect(find.byKey(const Key('address_b')), findsOneWidget);
    });

    testWidgets('xoá xác nhận: địa chỉ biến mất, có thông báo', (tester) async {
      final h = await openList(tester, setup: (r) {
        r.addresses = [makeAddress('a', isDefault: true), makeAddress('b')];
      });

      await tester.tap(field('address_delete_b'));
      await tester.pumpAndSettle();
      await tester.tap(field('address_delete_confirm'));
      await tester.pumpAndSettle();

      expect(h.profile.calls, contains('deleteAddress:b'));
      expect(find.byKey(const Key('address_b')), findsNothing);
      expect(find.text('Đã xoá địa chỉ.'), findsOneWidget);
    });

    testWidgets('xoá địa chỉ mặc định: cảnh báo sẽ không còn mặc định', (tester) async {
      await openList(tester, setup: (r) {
        r.addresses = [makeAddress('a', isDefault: true)];
      });

      await tester.tap(field('address_delete_a'));
      await tester.pumpAndSettle();

      expect(find.textContaining('không còn địa chỉ mặc định'), findsOneWidget);
    });

    testWidgets('xoá địa chỉ đã bị xoá nơi khác (404): báo lỗi và đồng bộ lại',
        (tester) async {
      final h = await openList(tester, setup: (r) {
        r.addresses = [makeAddress('a', isDefault: true), makeAddress('b')];
      });
      // Địa chỉ b biến mất ở thiết bị khác.
      h.profile.addresses = [makeAddress('a', isDefault: true)];

      await tester.tap(field('address_delete_b'));
      await tester.pumpAndSettle();
      await tester.tap(field('address_delete_confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Địa chỉ này không còn tồn tại.'), findsOneWidget);
      expect(find.byKey(const Key('address_b')), findsNothing);
    });

    testWidgets('đủ 10 địa chỉ: nút Thêm bị khoá kèm lời nhắc', (tester) async {
      await openList(tester, setup: (r) {
        r.addresses = [
          for (var i = 0; i < 10; i++) makeAddress('a$i', isDefault: i == 0)
        ];
      });

      expect(tester.widget<ElevatedButton>(field('address_add')).onPressed, isNull);
      expect(find.textContaining('Đã đủ 10 địa chỉ'), findsOneWidget);
    });

    testWidgets('9 địa chỉ: vẫn thêm được', (tester) async {
      await openList(tester, setup: (r) {
        r.addresses = [
          for (var i = 0; i < 9; i++) makeAddress('a$i', isDefault: i == 0)
        ];
      });

      expect(tester.widget<ElevatedButton>(field('address_add')).onPressed, isNotNull);
      expect(find.textContaining('Đã đủ'), findsNothing);
    });

    testWidgets('kéo để làm mới', (tester) async {
      final h = await openList(tester, setup: (r) {
        r.addresses = [makeAddress('a', isDefault: true)];
      });
      h.profile.addresses = [
        makeAddress('a', isDefault: true),
        makeAddress('moi', name: 'Mới thêm'),
      ];

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Mới thêm'), findsOneWidget);
    });

    testWidgets('mở màn Sửa từ thẻ', (tester) async {
      await openList(tester, setup: (r) {
        r.addresses = [makeAddress('a', isDefault: true, name: 'Hải')];
      });

      await tester.tap(field('address_edit_a'));
      await tester.pumpAndSettle();

      expect(find.text('Sửa địa chỉ'), findsOneWidget);
      expect(_text(tester, 'addr_name'), 'Hải');
    });
  });

  group('Form địa chỉ', () {
    Future<AppHarness> openAdd(WidgetTester tester,
        {void Function(FakeProfileRepository)? setup}) async {
      final h = AppHarness()..signIn();
      setup?.call(h.profile);
      await h.pump(tester, initial: '/profile/addresses/add');
      await tester.pumpAndSettle();
      return h;
    }

    Future<void> fillAll(WidgetTester tester) async {
      await enter(tester, 'addr_name', '  Nguyễn Văn A ');
      await enter(tester, 'addr_phone', '+84 912 345 678');
      await enter(tester, 'addr_province', 'Cần Thơ');
      await enter(tester, 'addr_district', 'Thới Lai');
      await enter(tester, 'addr_ward', 'Thới Tân');
      await enter(tester, 'addr_line', '123 Ấp Thới Phước');
    }

    Future<void> save(WidgetTester tester) async {
      final b = find.widgetWithText(ElevatedButton, 'Lưu địa chỉ');
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.pump();
    }

    testWidgets('trống: báo lỗi trường bắt buộc, không gọi server', (tester) async {
      final h = await openAdd(tester);

      await save(tester);

      expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
      expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
      expect(find.text('Vui lòng nhập tỉnh/thành phố'), findsOneWidget);
      expect(find.text('Vui lòng nhập địa chỉ'), findsOneWidget);
      // Quận/huyện, phường/xã là tuỳ chọn.
      expect(find.text('Vui lòng nhập quận/huyện'), findsNothing);
      expect(h.profile.calls.where((c) => c == 'createAddress'), isEmpty);
    });

    testWidgets('SĐT người nhận sai định dạng', (tester) async {
      await openAdd(tester);
      await fillAll(tester);
      await enter(tester, 'addr_phone', '12345');

      await save(tester);

      expect(find.text('Số điện thoại di động Việt Nam không hợp lệ'), findsOneWidget);
    });

    testWidgets('chỉ cần tên, SĐT, tỉnh, địa chỉ (huyện/xã bỏ trống vẫn lưu)',
        (tester) async {
      final h = await openAdd(tester);
      await enter(tester, 'addr_name', 'A');
      await enter(tester, 'addr_phone', '0912345678');
      await enter(tester, 'addr_province', 'Cần Thơ');
      await enter(tester, 'addr_line', 'Số 1');

      await save(tester);
      await tester.pumpAndSettle();

      expect(h.profile.lastInput?.toJson()['ward'], isNull);
      expect(h.profile.lastInput?.toJson()['district'], isNull);
    });

    testWidgets('lưu thành công: gửi dữ liệu chuẩn hoá, quay về danh sách có địa chỉ mới',
        (tester) async {
      final h = await openAdd(tester);
      h.router.go('/profile/addresses');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm địa chỉ'));
      await tester.pumpAndSettle();

      await fillAll(tester);
      await tester.tap(field('addr_type_FARM'));
      await tester.pump();
      await save(tester);
      await tester.pumpAndSettle();

      final sent = h.profile.lastInput!.toJson();
      expect(sent['recipientName'], 'Nguyễn Văn A');
      expect(sent['recipientPhone'], '0912345678'); // đã chuẩn hoá
      expect(sent['addressType'], 'FARM');
      expect(sent['province'], 'Cần Thơ');
      expect(find.text('Đã lưu địa chỉ.'), findsOneWidget);
      // Quay lại danh sách và thấy địa chỉ mới (mặc định vì là địa chỉ đầu tiên).
      expect(find.text('Quản lý địa chỉ'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Mặc định'), findsOneWidget);
    });

    testWidgets('chọn loại địa chỉ và bật mặc định được gửi đúng', (tester) async {
      final h = await openAdd(tester, setup: (r) {
        r.addresses = [makeAddress('a', isDefault: true)];
      });
      await fillAll(tester);
      await tester.tap(field('addr_type_OTHER'));
      await tester.ensureVisible(field('addr_default'));
      await tester.tap(field('addr_default'));
      await tester.pump();

      await save(tester);
      await tester.pumpAndSettle();

      final sent = h.profile.lastInput!.toJson();
      expect(sent['addressType'], 'OTHER');
      expect(sent['isDefault'], isTrue);
    });

    testWidgets('quá 10 địa chỉ (422): hiện lỗi, giữ nguyên dữ liệu đã nhập',
        (tester) async {
      final h = await openAdd(tester);
      h.profile.writeError = const ApiException(
          kind: ApiErrorKind.businessRule,
          statusCode: 422,
          message: 'Bạn chỉ lưu được tối đa 10 địa chỉ. Hãy xoá bớt địa chỉ cũ.');
      await fillAll(tester);

      await save(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('tối đa 10 địa chỉ'), findsOneWidget);
      expect(_text(tester, 'addr_line'), '123 Ấp Thới Phước');
    });

    testWidgets('đang lưu: nút khoá, chỉ một request', (tester) async {
      final gate = Completer<void>();
      final h = await openAdd(tester, setup: (r) => r.gate = gate.future);
      await fillAll(tester);

      await save(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(h.profile.calls.where((c) => c == 'createAddress').length, 1);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('Sửa: điền sẵn dữ liệu, lưu gọi PUT đúng id', (tester) async {
      final h = AppHarness()..signIn();
      h.profile.addresses = [
        makeAddress('a', isDefault: true, name: 'Hải', line: 'Ấp 3', type: 'FARM'),
        makeAddress('b', name: 'Mai'),
      ];
      await h.pump(tester, initial: '/profile/addresses/edit/b');
      await tester.pumpAndSettle();

      expect(find.text('Sửa địa chỉ'), findsOneWidget);
      expect(_text(tester, 'addr_name'), 'Mai');
      expect(_text(tester, 'addr_phone'), '0912345678');
      expect(_text(tester, 'addr_province'), 'Cần Thơ');

      await enter(tester, 'addr_line', 'Số 99 mới');
      await save(tester);
      await tester.pumpAndSettle();

      expect(h.profile.calls, contains('updateAddress:b'));
      expect(h.profile.lastInput?.addressLine, 'Số 99 mới');
    });

    testWidgets('Sửa địa chỉ đang mặc định: công tắc bị khoá kèm giải thích',
        (tester) async {
      final h = AppHarness()..signIn();
      h.profile.addresses = [makeAddress('a', isDefault: true)];
      await h.pump(tester, initial: '/profile/addresses/edit/a');
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('addr_default'));

      final sw = tester.widget<Switch>(field('addr_default'));
      expect(sw.value, isTrue);
      expect(sw.onChanged, isNull);
      expect(find.textContaining('Muốn đổi, hãy đặt địa chỉ khác'), findsOneWidget);
    });

    testWidgets('Sửa địa chỉ không còn tồn tại: báo lỗi thay vì form rỗng',
        (tester) async {
      final h = AppHarness()..signIn();
      h.profile.addresses = [makeAddress('a', isDefault: true)];
      await h.pump(tester, initial: '/profile/addresses/edit/khong-co');
      await tester.pumpAndSettle();

      expect(find.text('Địa chỉ này không còn tồn tại.'), findsOneWidget);
      expect(field('addr_name'), findsNothing);
    });
  });
}

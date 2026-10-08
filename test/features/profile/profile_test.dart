import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:farmer_mobile/features/profile/data/address_models.dart';
import 'package:farmer_mobile/features/profile/data/address_repository.dart';
import 'package:farmer_mobile/features/profile/data/profile_models.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:farmer_mobile/features/profile/screens/address_form_screen.dart';
import 'package:farmer_mobile/features/profile/screens/address_list_screen.dart';
import 'package:farmer_mobile/features/profile/screens/change_password_screen.dart';
import 'package:farmer_mobile/features/profile/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/checkout_fixtures.dart';
import '../../support/fakes.dart';
import '../auth/auth_providers_test.dart' show MockAuthRepository;
import '../cart/cart_controller_test.dart' show TestUserId;
import '../checkout/checkout_screen_test.dart' show MockAddressRepository;

class MockProfileRepository extends Mock implements ProfileRepository {}

const profileJson = {
  'farmerProfileId': 'f-1',
  'fullName': 'Nông dân E2E 170679',
  'phoneNumber': '0917067932',
  'email': null,
  'dateOfBirth': '1985-03-09T00:00:00Z',
  'gender': 'MALE',
  'customerGroup': {'id': 'g-1', 'name': 'Nông dân thân thiết'},
};

void main() {
  setUpAll(() {
    registerFallbackValue(const ProfileUpdate(fullName: 'x'));
    registerFallbackValue(const AddressInput(recipientName: 'x', recipientPhone: '0', addressLine: 'x', province: 'x'));
  });

  group('profile data', () {
    test('FarmerProfile reads the account, the date of birth and the customer group', () {
      final profile = FarmerProfile.fromJson(profileJson);

      expect(profile.fullName, 'Nông dân E2E 170679');
      expect(profile.phoneNumber, '0917067932');
      expect(profile.email, isNull);
      expect(profile.dateOfBirth, DateTime.utc(1985, 3, 9));
      expect(profile.gender, 'MALE');
      expect(profile.customerGroupName, 'Nông dân thân thiết');
    });

    test('a profile without a group, birthday or gender still reads', () {
      final profile = FarmerProfile.fromJson({'farmerProfileId': 'f-2', 'fullName': 'Bác Tư'});

      expect(profile.dateOfBirth, isNull);
      expect(profile.gender, isNull);
      expect(profile.customerGroupName, isNull);
      expect(Gender.label(profile.gender), 'Chưa cập nhật');
    });

    test('ProfileUpdate sends a trimmed name and a date-only birthday', () {
      final json = ProfileUpdate(fullName: '  Bác Tư  ', dateOfBirth: DateTime.utc(1985, 3, 9), gender: Gender.female).toJson();

      expect(json, {'fullName': 'Bác Tư', 'dateOfBirth': '1985-03-09', 'gender': 'FEMALE'});
    });

    test('ProfileUpdate sends null for a birthday and gender that were never set', () {
      expect(const ProfileUpdate(fullName: 'A').toJson(), {'fullName': 'A', 'dateOfBirth': null, 'gender': null});
    });

    test('ProfileRepository reads and saves through /api/me/profile', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;
      adapter.onGet('/api/me/profile', (server) => server.reply(200, profileJson));
      adapter.onPut(
        '/api/me/profile',
        (server) => server.reply(200, {...profileJson, 'fullName': 'Bác Tư'}),
        data: {'fullName': 'Bác Tư', 'dateOfBirth': null, 'gender': null},
      );
      final repo = ProfileRepository(dio);

      expect((await repo.profile()).fullName, 'Nông dân E2E 170679');
      expect((await repo.update(const ProfileUpdate(fullName: 'Bác Tư'))).fullName, 'Bác Tư');
    });
  });

  group('edit profile screen', () {
    late MockProfileRepository profiles;
    late SessionManager session;

    setUp(() async {
      profiles = MockProfileRepository();
      session = SessionManager(store: InMemoryTokenStore());
      await session.signIn(
        accessToken: 't',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        user: const SessionUser(id: 'u1', fullName: 'Nông dân E2E 170679', role: 'FARMER', phoneNumber: '0917067932'),
      );
      when(() => profiles.profile()).thenAnswer((_) async => FarmerProfile.fromJson(profileJson));
    });

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('ACCOUNT'))),
          GoRoute(path: '/edit', builder: (_, __) => const EditProfileScreen()),
        ],
        initialLocation: '/',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(profiles),
            sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
            sessionManagerProvider.overrideWithValue(session),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      router.push('/edit');
      await tester.pumpAndSettle();
    }

    testWidgets('shows what the server has, with phone and group read-only', (tester) async {
      await pump(tester);

      expect(find.widgetWithText(TextFormField, 'Nông dân E2E 170679'), findsOneWidget);
      expect(find.text('09/03/1985'), findsOneWidget);
      expect(find.text('0917067932'), findsOneWidget);
      expect(find.text('Nông dân thân thiết'), findsOneWidget);
      expect(find.text('Nam'), findsOneWidget);
    });

    testWidgets('saving sends the change, updates the name the app shows and goes back', (tester) async {
      when(() => profiles.update(any())).thenAnswer((_) async => FarmerProfile.fromJson({...profileJson, 'fullName': 'Bác Tư'}));
      await pump(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Bác Tư');
      await tester.tap(find.text('Nữ'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Lưu thay đổi'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      final sent = verify(() => profiles.update(captureAny())).captured.single as ProfileUpdate;
      expect(sent.fullName, 'Bác Tư');
      expect(sent.gender, Gender.female);
      expect(sent.dateOfBirth, DateTime.utc(1985, 3, 9), reason: 'the birthday is sent back unchanged');
      expect(session.user?.fullName, 'Bác Tư', reason: 'the home and account headers read the session');
      expect(find.text('ACCOUNT'), findsOneWidget);
    });

    testWidgets('an empty name is refused before anything is sent', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.scrollUntilVisible(find.text('Lưu thay đổi'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      verifyNever(() => profiles.update(any()));
      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('a server refusal stays on the form and says why', (tester) async {
      when(() => profiles.update(any())).thenThrow(const AppException(kind: AppErrorKind.validation, message: 'Thông tin chưa hợp lệ.', statusCode: 400));
      await pump(tester);

      await tester.scrollUntilVisible(find.text('Lưu thay đổi'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(find.text('Thông tin chưa hợp lệ.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
    });
  });

  group('change password screen', () {
    late MockAuthRepository auth;
    late SessionManager session;

    setUp(() async {
      auth = MockAuthRepository();
      session = SessionManager(store: InMemoryTokenStore());
      await session.signIn(
        accessToken: 't',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        user: const SessionUser(id: 'u1', fullName: 'A', role: 'FARMER'),
      );
    });

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('ACCOUNT'))),
          GoRoute(path: '/password', builder: (_, __) => const ChangePasswordScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            sessionManagerProvider.overrideWithValue(session),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      router.push('/password');
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, {String current = 'matkhau-cu', String next = 'matkhau-moi-1', String? confirm}) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), current);
      await tester.enterText(fields.at(1), next);
      await tester.enterText(fields.at(2), confirm ?? next);
      await tester.scrollUntilVisible(find.widgetWithText(ElevatedButton, 'Đổi mật khẩu'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đổi mật khẩu'));
      await tester.pumpAndSettle();
    }

    testWidgets('a good change is sent and the screen closes', (tester) async {
      when(() => auth.changePassword(currentPassword: any(named: 'currentPassword'), newPassword: any(named: 'newPassword')))
          .thenAnswer((_) async {});
      await pump(tester);

      await fill(tester);

      verify(() => auth.changePassword(currentPassword: 'matkhau-cu', newPassword: 'matkhau-moi-1')).called(1);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(session.isSignedIn, isTrue);
    });

    testWidgets('a wrong current password is shown on that field and the farmer stays signed in', (tester) async {
      when(() => auth.changePassword(currentPassword: any(named: 'currentPassword'), newPassword: any(named: 'newPassword')))
          .thenThrow(const AppException(kind: AppErrorKind.unauthorized, message: 'Mật khẩu hiện tại chưa đúng.', statusCode: 401));
      await pump(tester);

      await fill(tester);

      expect(find.text('Mật khẩu hiện tại chưa đúng.'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(session.isSignedIn, isTrue, reason: 'a 401 here means the typed password is wrong, not that the session ended');
    });

    testWidgets('two different new passwords are caught before anything is sent', (tester) async {
      await pump(tester);

      await fill(tester, confirm: 'khac-hoan-toan');

      verifyNever(() => auth.changePassword(currentPassword: any(named: 'currentPassword'), newPassword: any(named: 'newPassword')));
      expect(find.text('Hai mật khẩu chưa khớp'), findsOneWidget);
    });

    testWidgets('a new password equal to the current one is refused', (tester) async {
      await pump(tester);

      await fill(tester, current: 'giong-nhau-1', next: 'giong-nhau-1');

      verifyNever(() => auth.changePassword(currentPassword: any(named: 'currentPassword'), newPassword: any(named: 'newPassword')));
      expect(find.text('Mật khẩu mới phải khác mật khẩu hiện tại'), findsOneWidget);
    });

    testWidgets('a new password under 8 characters is refused', (tester) async {
      await pump(tester);

      await fill(tester, next: 'ngan');

      verifyNever(() => auth.changePassword(currentPassword: any(named: 'currentPassword'), newPassword: any(named: 'newPassword')));
      expect(find.text('Mật khẩu tối thiểu 8 ký tự'), findsOneWidget);
    });
  });

  group('address book screens', () {
    late MockAddressRepository addresses;
    late List<Address> book;

    setUp(() {
      addresses = MockAddressRepository();
      book = [homeAddress, farmAddress];
      when(() => addresses.list()).thenAnswer((_) async => book);
    });

    Future<GoRouter> pump(WidgetTester tester, {String start = '/profile/addresses'}) async {
      final router = GoRouter(
        initialLocation: start,
        routes: [
          GoRoute(path: '/profile/addresses', builder: (_, __) => const AddressListScreen()),
          GoRoute(path: '/profile/addresses/add', builder: (_, __) => const AddressFormScreen()),
          GoRoute(path: '/profile/addresses/edit/:id', builder: (_, state) => AddressFormScreen(addressId: state.pathParameters['id'])),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addressRepositoryProvider.overrideWithValue(addresses),
            sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
            sessionManagerProvider.overrideWithValue(
              SessionManager(store: InMemoryTokenStore())
                ..signIn(
                  accessToken: 't',
                  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
                  user: const SessionUser(id: 'u1', fullName: 'Nông dân E2E 170679', role: 'FARMER', phoneNumber: '0917067932'),
                ),
            ),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('lists the addresses, the default one marked', (tester) async {
      await pump(tester);

      expect(find.text('Nông dân E2E 170679'), findsOneWidget);
      expect(find.text('Anh Ba'), findsOneWidget);
      expect(find.text('Mặc định'), findsOneWidget);
      expect(find.text('Đặt mặc định'), findsOneWidget, reason: 'only the address that is not the default offers it');
      expect(find.text('Thêm địa chỉ mới'), findsOneWidget);
    });

    testWidgets('an empty book says so', (tester) async {
      book = [];
      await pump(tester);

      expect(find.text('Bác chưa có địa chỉ giao hàng nào.'), findsOneWidget);
    });

    testWidgets('at ten addresses the add button is disabled', (tester) async {
      book = [for (var i = 0; i < Address.maxPerFarmer; i++) i == 0 ? homeAddress : _copy(farmAddress, 'a-$i')];
      await pump(tester);

      await tester.scrollUntilVisible(find.text('Đã đủ 10 địa chỉ'), 300, scrollable: find.byType(Scrollable).first);
      final button = tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('Đã đủ 10 địa chỉ'), matching: find.bySubtype<ButtonStyleButton>()));
      expect(button.onPressed, isNull);
    });

    testWidgets('"Đặt mặc định" asks the server and reloads the list', (tester) async {
      when(() => addresses.setDefault('a-farm')).thenAnswer((_) async {
        book = [homeAddress.copyWithDefault(false), farmAddress.copyWithDefault(true)];
        return book.last;
      });
      await pump(tester);

      await tester.tap(find.text('Đặt mặc định'));
      await tester.pumpAndSettle();

      verify(() => addresses.setDefault('a-farm')).called(1);
      expect(find.text('Đã đặt làm địa chỉ mặc định.'), findsOneWidget);
      // The server's list wins: the farm address is now first and carries the badge.
      expect(tester.getTopLeft(find.text('Anh Ba')).dy, lessThan(tester.getTopLeft(find.text('Nông dân E2E 170679')).dy));
    });

    testWidgets('deleting asks first, then removes the address', (tester) async {
      when(() => addresses.delete('a-farm')).thenAnswer((_) async => book = [homeAddress]);
      await pump(tester);

      await tester.tap(find.text('Xóa').last);
      await tester.pumpAndSettle();
      expect(find.text('Xóa địa chỉ?'), findsOneWidget);
      verifyNever(() => addresses.delete(any()));

      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Xóa')));
      await tester.pumpAndSettle();

      verify(() => addresses.delete('a-farm')).called(1);
      expect(find.text('Anh Ba'), findsNothing);
      expect(find.text('Đã xóa địa chỉ.'), findsOneWidget);
    });

    testWidgets('keeping the address in the dialog deletes nothing', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Xóa').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();

      verifyNever(() => addresses.delete(any()));
      expect(find.text('Anh Ba'), findsOneWidget);
    });

    testWidgets('a server refusal is shown and the list stays', (tester) async {
      when(() => addresses.delete(any())).thenThrow(const AppException(kind: AppErrorKind.conflict, message: 'Không xóa được địa chỉ này.', statusCode: 409));
      await pump(tester);

      await tester.tap(find.text('Xóa').last);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Xóa')));
      await tester.pumpAndSettle();

      expect(find.text('Không xóa được địa chỉ này.'), findsOneWidget);
      expect(find.text('Anh Ba'), findsOneWidget);
    });

    testWidgets('editing opens the form filled with that address and saves it', (tester) async {
      when(() => addresses.update('a-farm', any())).thenAnswer((_) async => farmAddress);
      await pump(tester);

      await tester.tap(find.text('Sửa').last);
      await tester.pumpAndSettle();
      expect(find.text('Sửa địa chỉ'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Anh Ba'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Ruộng số 7'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Lưu thay đổi'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      final sent = verify(() => addresses.update('a-farm', captureAny())).captured.single as AddressInput;
      expect(sent.recipientName, 'Anh Ba');
      expect(sent.addressType, AddressType.farm);
      expect(find.text('Địa chỉ giao hàng'), findsOneWidget, reason: 'back on the list');
    });

    testWidgets('an address that is no longer there says so instead of showing a blank form', (tester) async {
      await pump(tester, start: '/profile/addresses/edit/a-gone');

      expect(find.text('Không tìm thấy địa chỉ này.'), findsOneWidget);
    });

    testWidgets('the first address a farmer adds starts as the default', (tester) async {
      book = [];
      when(() => addresses.create(any())).thenAnswer((_) async => homeAddress);
      await pump(tester, start: '/profile/addresses/add');

      final fields = find.byType(TextFormField);
      expect(tester.widget<TextFormField>(fields.at(0)).controller?.text, 'Nông dân E2E 170679', reason: 'the name comes from the account');
      await tester.enterText(find.widgetWithText(TextFormField, 'Số nhà, ấp / thôn, đường'), 'Ấp 2');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tỉnh / Thành phố'), 'Cần Thơ');
      await tester.scrollUntilVisible(find.text('Lưu địa chỉ'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Lưu địa chỉ'));
      await tester.pumpAndSettle();

      final sent = verify(() => addresses.create(captureAny())).captured.single as AddressInput;
      expect(sent.isDefault, isTrue);
      expect(sent.addressLine, 'Ấp 2');
      expect(sent.province, 'Cần Thơ');
    });
  });
}

Address _copy(Address a, String id) => Address(
      id: id,
      recipientName: a.recipientName,
      recipientPhone: a.recipientPhone,
      addressLine: a.addressLine,
      province: a.province,
      addressType: a.addressType,
      isDefault: false,
    );

extension on Address {
  Address copyWithDefault(bool value) => Address(
        id: id,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
        addressLine: addressLine,
        ward: ward,
        district: district,
        province: province,
        addressType: addressType,
        isDefault: value,
      );
}

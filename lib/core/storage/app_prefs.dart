import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kho cài đặt thường (không bí mật). `main()` mở sẵn rồi ghi đè provider này.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'sharedPreferencesProvider phải được ghi đè trong ProviderScope (main.dart / test).'),
);

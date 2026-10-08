import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` once the preferences have been read (and in tests).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Plain, non-secret conveniences. Never put a token or a password here.
class AppPrefs {
  AppPrefs(this._prefs);

  static const _onboardingSeenKey = 'onboarding_seen';

  final SharedPreferences _prefs;

  bool get onboardingSeen => _prefs.getBool(_onboardingSeenKey) ?? false;

  Future<void> markOnboardingSeen() => _prefs.setBool(_onboardingSeenKey, true);
}

final appPrefsProvider = Provider<AppPrefs>((ref) => AppPrefs(ref.watch(sharedPreferencesProvider)));

import 'package:farmer_mobile/core/storage/token_store.dart';

/// A token store that lives in memory, so tests never touch the Android Keystore.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this.stored]);

  StoredSession? stored;
  int writes = 0;

  @override
  Future<StoredSession?> read() async => stored;

  @override
  Future<void> write(StoredSession session) async {
    writes++;
    stored = session;
  }

  @override
  Future<void> clear() async => stored = null;
}

/// A fixed clock for tests that depend on "now".
class FakeClock {
  FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
}

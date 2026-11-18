/// Where this device keeps the unwrapped data key while sync is on.
///
/// - Android and iOS: `flutter_secure_storage` (Android Keystore, iOS
///   Keychain, this device only, never in iCloud).
/// - Web: a non-extractable WebCrypto AES-GCM key in IndexedDB wraps the data
///   key. Script on the page can use the AES key but can't read it out.
///
/// Signing out of sync clears it.
library;

import 'dart:typed_data';

import 'key_store_io.dart' if (dart.library.js_interop) 'key_store_web.dart' as platform;

/// The data key and the account it belongs to.
class StoredKey {
  const StoredKey(this.userId, this.dataKey);
  final String userId;
  final Uint8List dataKey;
}

abstract interface class KeyStore {
  Future<StoredKey?> read();
  Future<void> write(StoredKey key);
  Future<void> clear();
}

/// The key store for the platform the app runs on.
KeyStore platformKeyStore() => platform.createKeyStore();

/// Keeps the key in memory only. For tests.
class MemoryKeyStore implements KeyStore {
  StoredKey? key;

  @override
  Future<StoredKey?> read() async => key;

  @override
  Future<void> write(StoredKey k) async => key = k;

  @override
  Future<void> clear() async => key = null;
}

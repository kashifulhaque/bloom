import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_store.dart';

KeyStore createKeyStore() => SecureKeyStore();

/// Android Keystore or iOS Keychain through `flutter_secure_storage`.
class SecureKeyStore implements KeyStore {
  SecureKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // This device only, and never copied to iCloud Keychain.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const _name = 'bloom_sync_data_key_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredKey?> read() async {
    final raw = await _storage.read(key: _name);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return StoredKey(j['user'] as String, base64.decode(j['key'] as String));
  }

  @override
  Future<void> write(StoredKey k) =>
      _storage.write(key: _name, value: jsonEncode({'user': k.userId, 'key': base64.encode(k.dataKey)}));

  @override
  Future<void> clear() => _storage.delete(key: _name);
}

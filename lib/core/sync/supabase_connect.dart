/// Starts the Supabase client the first time sync needs it. The rest of the
/// app never touches it, so a build without sync, or a user who never turns
/// it on, makes no network requests to Supabase.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_sync_service.dart';
import 'sync_config.dart';
import 'sync_service.dart';

Future<SyncService>? _connecting;

/// Returns a [SyncService] for [config], initializing Supabase once.
Future<SyncService> connectSupabase(SyncConfig config) => _connecting ??= () async {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
        authOptions: FlutterAuthClientOptions(
          // Sign-in is by typed code; there are no auth links to catch.
          detectSessionInUri: false,
          // The web keeps the session in localStorage (the default). Phones
          // keep it in the Keystore or Keychain instead of plain preferences.
          localStorage: kIsWeb ? null : const _SecureSessionStorage(),
        ),
        debug: false,
      );
      return SupabaseSyncService(Supabase.instance.client);
    }()
        .catchError((Object e) {
      _connecting = null;
      throw e;
    });

class _SecureSessionStorage extends LocalStorage {
  const _SecureSessionStorage();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _key = 'bloom_sync_session_v1';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) => _storage.write(key: _key, value: persistSessionString);
}

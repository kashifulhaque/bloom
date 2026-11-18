// Sync against the local Supabase stack: real Auth email codes (read from
// Mailpit), real row-level security, the version trigger, and the
// delete-account Edge Function.
//
// It's skipped unless SUPABASE_LOCAL_URL and SUPABASE_LOCAL_PUBLISHABLE_KEY
// are set. Run it with tool/sync_integration_test.sh, which starts nothing
// remote and reads the local keys from `npx supabase status`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/core/sync/crypto/sync_crypto.dart';
import 'package:bloom/core/sync/key_store.dart';
import 'package:bloom/core/sync/supabase_sync_service.dart';
import 'package:bloom/core/sync/sync_controller.dart';
import 'package:bloom/core/sync/sync_models.dart';
import 'package:bloom/core/sync/sync_service.dart';
import 'package:bloom/core/sync/sync_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _url = Platform.environment['SUPABASE_LOCAL_URL'] ?? '';
final _key = Platform.environment['SUPABASE_LOCAL_PUBLISHABLE_KEY'] ?? '';
final _mailpit = Platform.environment['SUPABASE_LOCAL_MAILPIT_URL'] ?? 'http://127.0.0.1:54324';

/// Refuses anything but a local stack, so this test can't touch a real project.
bool get _isLocal {
  final host = Uri.tryParse(_url)?.host;
  return host == '127.0.0.1' || host == 'localhost';
}

SupabaseClient _client() => SupabaseClient(
      _url,
      _key,
      // Pure Dart clients have no storage for the PKCE verifier.
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit, autoRefreshToken: false),
    );

final _http = HttpClient();

Future<Object?> _getJson(String url) async {
  final req = await _http.getUrl(Uri.parse(url));
  final res = await req.close();
  return jsonDecode(await res.transform(utf8.decoder).join());
}

/// Signs [client] in as [email] with the 6-digit code from Mailpit.
Future<void> _signIn(SupabaseClient client, String email) async {
  final service = SupabaseSyncService(client);
  final before = DateTime.now().toUtc();
  await service.sendCode(email);
  String? code;
  for (var i = 0; i < 50 && code == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final search = await _getJson('$_mailpit/api/v1/search?query=${Uri.encodeQueryComponent('to:"$email"')}') as Map;
    for (final m in (search['messages'] as List? ?? const [])) {
      if (DateTime.parse(m['Created'] as String).isBefore(before.subtract(const Duration(seconds: 2)))) continue;
      final msg = await _getJson('$_mailpit/api/v1/message/${m['ID']}') as Map;
      code = RegExp(r'\b(\d{6})\b').firstMatch(msg['Text'] as String)?.group(1);
      break;
    }
  }
  expect(code, isNotNull, reason: 'no code email for $email in Mailpit');
  await service.verifyCode(email, code!);
  expect(client.auth.currentUser?.email, email);
}

/// A device: an in-memory store and a controller on its own client.
class _Device {
  _Device(this.client) : store = AppStore.memory(profile: Profile(onboarded: true)) {
    sync = SyncController(
      store: store,
      connect: () async => SupabaseSyncService(client),
      keyStore: MemoryKeyStore(),
      stateStorage: MemorySyncStateStorage(),
    );
  }

  final SupabaseClient client;
  final AppStore store;
  late final SyncController sync;

  Future<void> syncNow() async {
    await sync.syncNow();
    expect(sync.syncError, isNull);
  }
}

void main() {
  final run = _url.isNotEmpty && _key.isNotEmpty && _isLocal;
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final emailA = 'ada-$stamp@example.test';
  final emailB = 'bea-$stamp@example.test';

  group('local stack', () {
    late _Device a1, a2, b;
    late RecoveryPhrase phrase;

    setUpAll(() async {
      a1 = _Device(_client());
      a2 = _Device(_client());
      b = _Device(_client());
      await _signIn(a1.client, emailA);
      await Future<void>.delayed(const Duration(milliseconds: 1100)); // auth.email.max_frequency
      await _signIn(a2.client, emailA);
      await _signIn(b.client, emailB);
    });

    tearDownAll(() async {
      // Clean up user A through the Edge Function too.
      if (a1.client.auth.currentUser != null) await SupabaseSyncService(a1.client).deleteAccount();
      _http.close(force: true);
    });

    test('device one sets up sync and uploads ciphertext only', () async {
      a1.store.updateProfile((p) => p.name = 'Ada Lovelace');
      a1.store.startPeriod(parseDayKey('2026-10-29'), length: 5);
      a1.store.setNote(parseDayKey('2026-11-10'), 'secret note');
      a1.store.setFeature('journal', [{'text': 'dear diary'}]);

      await a1.sync.open();
      expect(a1.sync.phase, SyncPhase.needsSetup);
      phrase = a1.sync.beginSetup();
      final sw = Stopwatch()..start();
      await a1.sync.finishSetup();
      // ignore: avoid_print
      print('setup with Argon2id ${KdfParams.current.memKiB} KiB x ${KdfParams.current.iterations}: ${sw.elapsedMilliseconds} ms');
      expect(a1.sync.actionError, isNull);
      expect(a1.sync.phase, SyncPhase.active);
      expect(a1.sync.syncError, isNull);
      expect(a1.sync.pendingCount, 0);

      final rows = await a1.client.from('sync_records').select('kind,record_id,ciphertext');
      expect(rows, hasLength(5)); // profile, 2 months, 1 day, 1 feature
      for (final r in rows) {
        final bytes = byteaFromJson(r['ciphertext']);
        final text = latin1.decode(bytes);
        expect(text, isNot(contains('secret note')));
        expect(text, isNot(contains('Ada')));
        expect(r['record_id'] as String, isNot(contains('2026')));
      }
      final key = await a1.client.from('sync_keys').select('kdf_mem_kib,kdf_iterations').single();
      expect(key['kdf_mem_kib'], KdfParams.current.memKiB);
    });

    test('device two unlocks with the phrase and gets everything', () async {
      await a2.sync.open();
      expect(a2.sync.phase, SyncPhase.needsUnlock);
      await a2.sync.unlock(RecoveryPhrase.generate().toString());
      expect(a2.sync.actionError, contains('doesn\'t match'));
      await a2.sync.unlock(phrase.toString());
      expect(a2.sync.actionError, isNull);
      await a2.sync.syncNow();
      expect(a2.store.profile.name, 'Ada Lovelace');
      expect(a2.store.periodDays, a1.store.periodDays);
      expect(a2.store.logs['2026-11-10']!.note, 'secret note');
      expect(a2.store.feature<List>('journal'), [{'text': 'dear diary'}]);
    });

    test('edits from both devices merge, and deletes travel', () async {
      a1.store.setNote(parseDayKey('2026-11-11'), 'from one');
      a2.store.setNote(parseDayKey('2026-11-12'), 'from two');
      a2.store.setNote(parseDayKey('2026-11-10'), ''); // Deletes the log.
      await a1.syncNow();
      await a2.syncNow();
      await a1.syncNow();
      for (final d in [a1, a2]) {
        expect(d.store.logs.keys.toSet(), {'2026-11-11', '2026-11-12'});
      }
      final tomb = await a1.client.from('sync_records').select('deleted').eq('deleted', true);
      expect(tomb, hasLength(1));
    });

    test('the same day edited on both devices: the later edit wins', () async {
      a1.store.setNote(parseDayKey('2026-11-13'), 'older');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      a2.store.setNote(parseDayKey('2026-11-13'), 'newer');
      await a2.syncNow();
      await a1.syncNow(); // A1's older version is skipped by the trigger.
      expect(a1.sync.lastReport!.stale + a1.sync.lastReport!.applied, greaterThan(0));
      expect(a1.store.logs['2026-11-13']!.note, 'newer');
      await a2.syncNow();
      expect(a2.store.logs['2026-11-13']!.note, 'newer');
    });

    test('the trigger skips stale and equal versions through the Data API', () async {
      final service = SupabaseSyncService(a1.client);
      final rows = await service.pull(limit: 1000);
      final row = rows.firstWhere((r) => r.kind == 'day');
      final older = RemoteRow(
          kind: row.kind, recordId: row.recordId, version: row.version - 1, deleted: false, ciphertext: row.ciphertext);
      final same = RemoteRow(
          kind: row.kind, recordId: row.recordId, version: row.version, deleted: false, ciphertext: row.ciphertext);
      expect(await service.upsert([older, same]), isEmpty);
      final after = await service.fetch([row]);
      expect(after.single.version, row.version);
      expect(after.single.updatedAt, row.updatedAt);
    });

    test('keyset pages use the server\'s own timestamps', () async {
      final service = SupabaseSyncService(a1.client);
      final all = await service.pull(limit: 1000);
      expect(all.length, greaterThan(3));
      final pages = <String>[];
      PullCursor? after;
      while (true) {
        final page = await service.pull(after: after, limit: 2);
        if (page.isEmpty) break;
        pages.addAll(page.map((r) => r.id));
        after = PullCursor(page.last.updatedAt!, page.last.recordId);
      }
      expect(pages, [for (final r in all) r.id]);
      expect(all.first.updatedAt, contains('+00:00'), reason: 'the raw string goes back in the filter');
    });

    test('user B sees none of A\'s rows and can\'t write them', () async {
      final service = SupabaseSyncService(b.client);
      expect(await service.pull(limit: 1000), isEmpty);
      expect(await service.fetchKey(), isNull);
      final aId = a1.client.auth.currentUser!.id;
      final aRows = await SupabaseSyncService(a1.client).pull(limit: 1);
      await expectLater(
        b.client.from('sync_records').insert({
          'user_id': aId,
          'kind': 'day',
          'record_id': aRows.single.recordId,
          'version': 9007199254740000,
          'ciphertext': byteaToHex(aRows.single.ciphertext),
        }),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
      );
      final updated = await b.client.from('sync_records').update({'version': 9007199254740000}).eq('user_id', aId).select();
      expect(updated, isEmpty);
      final deleted = await b.client.from('sync_records').delete().eq('user_id', aId).select();
      expect(deleted, isEmpty);
      expect(await SupabaseSyncService(a1.client).pull(limit: 1000), isNotEmpty);

      // B's own sync works next to A's.
      b.store.setNote(parseDayKey('2026-11-01'), 'B only');
      await b.sync.open();
      b.sync.beginSetup();
      await b.sync.finishSetup();
      expect(b.sync.syncError, isNull);
      final bRows = await b.client.from('sync_records').select('user_id');
      expect(bRows.every((r) => r['user_id'] == b.client.auth.currentUser!.id), isTrue);
      expect(a1.store.logs.containsKey('2026-11-01'), isFalse);
    });

    test('the anon role has no access', () async {
      final anon = _client();
      await expectLater(
        anon.from('sync_records').select(),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
      );
      await expectLater(
        anon.from('sync_keys').select(),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
      );
    });

    test('delete-account removes the user\'s rows and the user', () async {
      final bId = b.client.auth.currentUser!.id;
      final refresh = b.client.auth.currentSession!.refreshToken!;
      await b.sync.deleteSyncedData();
      expect(b.sync.actionError, isNull);
      expect(b.sync.phase, SyncPhase.signedOut);
      // The refresh token no longer works, and signing in again makes a new user.
      final probe = _client();
      await expectLater(probe.auth.setSession(refresh), throwsA(isA<AuthException>()));
      await _signIn(probe, emailB);
      expect(probe.auth.currentUser!.id, isNot(bId));
      expect(await SupabaseSyncService(probe).pull(limit: 10), isEmpty);
      expect(await SupabaseSyncService(probe).fetchKey(), isNull);
      await SupabaseSyncService(probe).deleteAccount();
    });

    test('a service error is reported, not thrown, by the controller', () async {
      await a2.client.auth.signOut(scope: SignOutScope.local);
      a2.store.setNote(parseDayKey('2026-11-20'), 'while signed out');
      await a2.sync.syncNow();
      expect(a2.sync.syncError, isNotNull);
      expect(a2.sync.pendingCount, greaterThan(0));
    });

    test('SyncServiceException wording for a bad code', () async {
      final c = _client();
      await expectLater(
        SupabaseSyncService(c).verifyCode(emailA, '000000'),
        throwsA(isA<SyncServiceException>()),
      );
    });
  }, skip: run ? false : 'Set SUPABASE_LOCAL_URL and SUPABASE_LOCAL_PUBLISHABLE_KEY (see tool/sync_integration_test.sh).');
}

/// [SyncService] on Supabase: Auth email codes, the `sync_records` and
/// `sync_keys` tables (protected by row-level security), and the
/// `delete-account` Edge Function.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'crypto/kdf.dart';
import 'sync_models.dart';
import 'sync_service.dart';

class SupabaseSyncService implements SyncService {
  SupabaseSyncService(this.client);

  final SupabaseClient client;

  static const _records = 'sync_records';
  static const _keys = 'sync_keys';
  static const _rowColumns = 'kind,record_id,version,deleted,ciphertext,updated_at';

  GoTrueClient get _auth => client.auth;

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  String? get email => _auth.currentUser?.email;

  String get _uid {
    final id = userId;
    if (id == null) throw const SyncServiceException('You\'re signed out. Sign in again to sync.', code: 'signed_out');
    return id;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException catch (e) {
      throw SyncServiceException(_authMessage(e), code: e.code ?? e.statusCode);
    } on PostgrestException catch (e) {
      throw SyncServiceException('The server refused the request (${e.code ?? 'error'}).', code: e.code);
    } on FunctionException catch (e) {
      throw SyncServiceException('The server couldn\'t complete the request (${e.status}).', code: '${e.status}');
    }
  }

  static String _authMessage(AuthException e) => switch (e.code) {
        'otp_expired' => 'That code has expired or isn\'t right. Ask for a new one.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' => 'Too many attempts. Wait a minute, then try again.',
        'email_address_invalid' || 'validation_failed' => 'Check the email address.',
        'session_not_found' || 'refresh_token_not_found' => 'Your session ended. Sign in again.',
        _ => e.message,
      };

  // ---------------------------------------------------------------- auth

  @override
  Future<void> sendCode(String email) => _guard(() => _auth.signInWithOtp(email: email.trim(), shouldCreateUser: true));

  @override
  Future<void> verifyCode(String email, String code) =>
      _guard(() => _auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.email));

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Offline, or already signed out on the server. The local session is
      // removed before the request, so this device is signed out anyway.
    }
  }

  // ---------------------------------------------------------------- key

  @override
  Future<WrappedKey?> fetchKey() => _guard(() async {
        final row = await client
            .from(_keys)
            .select('wrapped_key,kdf_alg,kdf_salt,kdf_mem_kib,kdf_iterations,kdf_parallelism')
            .eq('user_id', _uid)
            .maybeSingle();
        if (row == null) return null;
        return WrappedKey(
          wrappedKey: byteaFromJson(row['wrapped_key']),
          salt: byteaFromJson(row['kdf_salt']),
          params: KdfParams(
            alg: row['kdf_alg'] as String,
            memKiB: row['kdf_mem_kib'] as int,
            iterations: row['kdf_iterations'] as int,
            parallelism: row['kdf_parallelism'] as int,
          ),
        );
      });

  @override
  Future<bool> insertKey(WrappedKey key) => _guard(() async {
        try {
          await client.from(_keys).insert({
            'user_id': _uid,
            'wrapped_key': byteaToHex(key.wrappedKey),
            'kdf_alg': key.params.alg,
            'kdf_salt': byteaToHex(key.salt),
            'kdf_mem_kib': key.params.memKiB,
            'kdf_iterations': key.params.iterations,
            'kdf_parallelism': key.params.parallelism,
          });
          return true;
        } on PostgrestException catch (e) {
          if (e.code == '23505') return false; // Another device set up sync first.
          rethrow;
        }
      });

  // ---------------------------------------------------------------- rows

  @override
  Future<List<RowVersion>> upsert(List<RemoteRow> rows) => _guard(() async {
        if (rows.isEmpty) return const [];
        final uid = _uid;
        // The before-update trigger skips stale versions, so they're missing
        // from the returned rows.
        final out = await client
            .from(_records)
            .upsert([
              for (final r in rows)
                {
                  'user_id': uid,
                  'kind': r.kind,
                  'record_id': r.recordId,
                  'version': r.version,
                  'deleted': r.deleted,
                  'ciphertext': byteaToHex(r.ciphertext),
                },
            ], onConflict: 'user_id,kind,record_id')
            .select('kind,record_id,version');
        return [for (final r in out) RowVersion(r['kind'] as String, r['record_id'] as String, r['version'] as int)];
      });

  @override
  Future<List<RemoteRow>> pull({PullCursor? after, required int limit}) => _guard(() async {
        var q = client.from(_records).select(_rowColumns).eq('user_id', _uid);
        if (after != null) {
          final at = '"${after.updatedAt}"';
          q = q.or('updated_at.gt.$at,and(updated_at.eq.$at,record_id.gt.${after.recordId})');
        }
        final out = await q.order('updated_at', ascending: true).order('record_id', ascending: true).limit(limit);
        return out.map(_row).toList();
      });

  @override
  Future<List<RemoteRow>> fetch(List<RemoteRow> rows) => _guard(() async {
        if (rows.isEmpty) return const [];
        final wanted = {for (final r in rows) r.id};
        final out = await client
            .from(_records)
            .select(_rowColumns)
            .eq('user_id', _uid)
            .inFilter('record_id', [for (final r in rows) r.recordId]);
        return [for (final r in out.map(_row)) if (wanted.contains(r.id)) r];
      });

  static RemoteRow _row(Map<String, dynamic> j) => RemoteRow(
        kind: j['kind'] as String,
        recordId: j['record_id'] as String,
        version: j['version'] as int,
        deleted: j['deleted'] as bool,
        ciphertext: byteaFromJson(j['ciphertext']),
        updatedAt: j['updated_at'] as String,
      );

  // ---------------------------------------------------------------- account

  @override
  Future<void> deleteAccount() => _guard(() async {
        _uid;
        await client.functions.invoke('delete-account', method: HttpMethod.post);
        await signOut();
      });
}

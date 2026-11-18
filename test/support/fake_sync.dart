/// An in-memory sync server for tests. It follows the same rules as the
/// Supabase migration: rows are private to their user, updates with a version
/// that isn't greater are skipped, and `updated_at` is set by the server.
library;

import 'dart:typed_data';

import 'package:bloom/core/sync/sync_models.dart';
import 'package:bloom/core/sync/sync_service.dart';

class FakeServer {
  final Map<String, Map<String, RemoteRow>> rows = {};
  final Map<String, WrappedKey> keys = {};
  final Map<String, String> users = {}; // email -> id
  final Map<String, String> codes = {}; // email -> code
  int _tick = 0;

  /// When set, every timestamp is this value, to test equal `updated_at`s.
  String? frozenTime;

  String now() {
    if (frozenTime != null) return frozenTime!;
    _tick++;
    final t = DateTime.utc(2026, 11, 18).add(Duration(microseconds: _tick * 1000 + 1));
    final s = t.toIso8601String(); // 2026-11-18T00:00:00.001001Z
    return '${s.substring(0, s.length - 1)}+00:00';
  }

  List<RemoteRow> rowsOf(String user) => rows[user]?.values.toList() ?? const [];

  /// Replaces a row's ciphertext, as a malicious or broken server might.
  void corrupt(String user, String id) {
    final r = rows[user]![id]!;
    final c = Uint8List.fromList(r.ciphertext)..[r.ciphertext.length - 1] ^= 1;
    rows[user]![id] = RemoteRow(
        kind: r.kind, recordId: r.recordId, version: r.version, deleted: r.deleted, ciphertext: c, updatedAt: now());
  }
}

class FakeSyncService implements SyncService {
  FakeSyncService(this.server);

  final FakeServer server;
  String? _user;
  String? _email;

  /// Fails every data call while true, like a device without a connection.
  bool offline = false;

  int upserts = 0;

  /// Makes pulls return nothing, to force a push to meet a newer row.
  bool hidePulls = false;

  @override
  String? get userId => _user;

  @override
  String? get email => _email;

  void _check() {
    if (offline) throw const SyncServiceException('offline');
    if (_user == null) throw const SyncServiceException('signed out', code: 'signed_out');
  }

  /// Signs in directly, skipping the code step.
  void signInAs(String email) {
    _email = email;
    _user = server.users.putIfAbsent(email, () => 'user-${server.users.length + 1}');
  }

  @override
  Future<void> sendCode(String email) async {
    if (offline) throw const SyncServiceException('offline');
    if (!email.contains('@')) throw const SyncServiceException('Check the email address.');
    server.codes[email.trim()] = '123456';
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    if (server.codes[email] != code.trim()) {
      throw const SyncServiceException('That code has expired or isn\'t right. Ask for a new one.');
    }
    signInAs(email);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _email = null;
  }

  @override
  Future<WrappedKey?> fetchKey() async {
    _check();
    return server.keys[_user];
  }

  @override
  Future<bool> insertKey(WrappedKey key) async {
    _check();
    if (server.keys.containsKey(_user)) return false;
    server.keys[_user!] = key;
    return true;
  }

  @override
  Future<List<RowVersion>> upsert(List<RemoteRow> rows) async {
    _check();
    upserts++;
    final mine = server.rows.putIfAbsent(_user!, () => {});
    final out = <RowVersion>[];
    for (final r in rows) {
      final old = mine[r.id];
      if (old != null && r.version <= old.version) continue; // The trigger skips it.
      mine[r.id] = RemoteRow(
        kind: r.kind,
        recordId: r.recordId,
        version: r.version,
        deleted: r.deleted,
        ciphertext: r.ciphertext,
        updatedAt: server.now(),
      );
      out.add(RowVersion(r.kind, r.recordId, r.version));
    }
    return out;
  }

  @override
  Future<List<RemoteRow>> pull({PullCursor? after, required int limit}) async {
    _check();
    if (hidePulls) return const [];
    final all = [...server.rowsOf(_user!)]..sort(_order);
    final from = after == null
        ? all
        : all.where((r) {
            final c = _cmpTime(r.updatedAt!, after.updatedAt);
            return c > 0 || (c == 0 && r.recordId.compareTo(after.recordId) > 0);
          });
    return from.take(limit).toList();
  }

  @override
  Future<List<RemoteRow>> fetch(List<RemoteRow> rows) async {
    _check();
    final mine = server.rows[_user] ?? const {};
    return [for (final r in rows) if (mine[r.id] != null) mine[r.id]!];
  }

  @override
  Future<void> deleteAccount() async {
    _check();
    server.rows.remove(_user);
    server.keys.remove(_user);
    server.users.removeWhere((_, id) => id == _user);
    await signOut();
  }

  static int _order(RemoteRow a, RemoteRow b) {
    final c = _cmpTime(a.updatedAt!, b.updatedAt!);
    return c != 0 ? c : a.recordId.compareTo(b.recordId);
  }

  static int _cmpTime(String a, String b) {
    final c = DateTime.parse(a).compareTo(DateTime.parse(b));
    return c != 0 ? c : a.compareTo(b);
  }
}

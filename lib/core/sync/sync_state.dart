/// What a device remembers about sync between launches: the account, the
/// clock, the pull cursor, and per-record versions. It's kept apart from the
/// app data, so backups and exports don't include it.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hlc.dart';
import 'sync_models.dart';

class SyncState {
  SyncState({this.userId, Hlc? clock, this.joined = false, this.cursor, this.lastSyncAt, Map<String, RecordMeta>? records})
      : clock = clock ?? Hlc.random(),
        records = records ?? {};

  /// The account these records belong to.
  String? userId;

  final Hlc clock;

  /// True once this device has finished its first full download. Until then,
  /// downloaded records replace local ones, so a new device adopts the
  /// account's data instead of overwriting it.
  bool joined;

  PullCursor? cursor;
  DateTime? lastSyncAt;

  /// Per-record state, keyed by `SyncRef.id`.
  final Map<String, RecordMeta> records;

  int get pending => records.values.where((m) => m.dirty).length;
  int get live => records.values.where((m) => !m.deleted).length;

  String encode() => jsonEncode({
        'v': 1,
        'user': userId,
        'clock': clock.toJson(),
        'joined': joined,
        'cursor': cursor?.toJson(),
        'last': lastSyncAt?.toUtc().toIso8601String(),
        'records': {for (final e in records.entries) e.key: e.value.toJson()},
      });

  factory SyncState.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return SyncState(
      userId: j['user'] as String?,
      clock: Hlc.fromJson(Map<String, dynamic>.from(j['clock'] as Map)),
      joined: j['joined'] as bool? ?? false,
      cursor: PullCursor.fromJson(j['cursor']),
      lastSyncAt: j['last'] == null ? null : DateTime.parse(j['last'] as String),
      records: {
        for (final e in (j['records'] as Map? ?? const {}).entries)
          e.key as String: RecordMeta.fromJson(e.value as List),
      },
    );
  }
}

/// Where [SyncState] is saved.
abstract interface class SyncStateStorage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

class PrefsSyncStateStorage implements SyncStateStorage {
  static const _key = 'bloom_sync_state_v1';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String data) async => (await SharedPreferences.getInstance()).setString(_key, data);

  @override
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

class MemorySyncStateStorage implements SyncStateStorage {
  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String d) async => data = d;

  @override
  Future<void> clear() async => data = null;
}

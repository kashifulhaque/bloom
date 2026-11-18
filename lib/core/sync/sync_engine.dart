/// The sync algorithm: version local changes, pull, merge, and push.
///
/// It has no UI and no timers, so tests drive it with a fake [SyncService].
/// [SyncController] decides when it runs.
///
/// Rules:
///
/// - Each local change gets a new hybrid-logical-clock version and is marked
///   dirty (see [localChanged]).
/// - **Pull** reads rows changed since the last pull, in `(updated_at,
///   record_id)` order. Each pull starts [overlap] before the saved cursor,
///   because a write that commits late can carry an earlier timestamp.
///   Applying a row twice changes nothing.
/// - **Merge**, per record: the higher version wins. A downloaded row with a
///   higher version replaces the local record, even an unsent local edit.
///   A lower one means the server is behind, so the local record is sent
///   again. Deletes are rows with `deleted = true` (tombstones).
/// - **Push** upserts dirty records. The server skips stale versions, so a
///   row missing from the reply is fetched and merged instead.
/// - A device that hasn't finished its first download adopts the server's
///   copy of every record, then uploads only what the server lacks.
library;

import 'dart:async';

import '../store.dart';
import 'crypto/sync_crypto.dart';
import 'record_codec.dart';
import 'sync_models.dart';
import 'sync_service.dart';
import 'sync_state.dart';

/// The outcome of one [SyncEngine.sync] run.
class SyncReport {
  int pulled = 0;
  int applied = 0;
  int pushed = 0;
  int stale = 0;

  /// Ids of rows that couldn't be decrypted or parsed. They're skipped.
  final Set<String> unreadableIds = {};

  int get unreadable => unreadableIds.length;

  @override
  String toString() => 'pulled $pulled, applied $applied, pushed $pushed, stale $stale, unreadable $unreadable';
}

class SyncEngine implements SyncHooks {
  SyncEngine({
    required this.store,
    required this.service,
    required SyncCrypto crypto,
    required this.state,
    this.onLocalChange,
    this.onLocalReset,
    this.pageSize = 500,
    this.pushBatch = 200,
  }) : codec = RecordCodec(crypto);

  final AppStore store;
  final SyncService service;
  final RecordCodec codec;
  final SyncState state;

  /// Called after a local change is versioned, so the caller can schedule a
  /// sync.
  final void Function()? onLocalChange;

  /// Called when the user erases all data on this device.
  final FutureOr<void> Function()? onLocalReset;

  final int pageSize;
  final int pushBatch;

  static const overlap = Duration(minutes: 2);

  /// True when a change could have touched any record, so the next sync
  /// checks them all.
  bool _scanAll = true;

  Future<SyncReport>? _running;

  // ---------------------------------------------------------------- hooks

  void attach() => store.syncHooks = this;

  void detach() {
    if (identical(store.syncHooks, this)) store.syncHooks = null;
  }

  @override
  void localChanged(Iterable<SyncRef>? refs) {
    if (refs == null || !state.joined) {
      _scanAll = true;
    } else {
      for (final ref in refs) {
        _version(ref);
      }
    }
    onLocalChange?.call();
  }

  @override
  FutureOr<void> localReset() => onLocalReset?.call();

  /// Gives [ref] a new version when its content changed since it was last
  /// versioned.
  void _version(SyncRef ref) {
    final value = store.syncValue(ref);
    final fp = RecordCodec.fingerprint(ref.kind, value);
    final meta = state.records[ref.id];
    if (meta == null) {
      if (value == null) return; // Never synced and doesn't exist.
      state.records[ref.id] = RecordMeta(version: state.clock.next(), dirty: true, fingerprint: fp);
    } else if (meta.fingerprint != fp || meta.deleted != (value == null)) {
      meta
        ..version = state.clock.next()
        ..dirty = true
        ..deleted = value == null
        ..fingerprint = fp;
    }
  }

  /// Versions changed records. Profile and feature records are always
  /// checked, because some features write to the store directly; day logs
  /// and period months only on a full scan.
  Future<void> _scan({required bool all}) async {
    final refs = <SyncRef>{SyncRef.profile};
    for (final k in store.features.keys) {
      if (SyncRef.syncsFeature(k)) refs.add(SyncRef.feature(k));
    }
    for (final id in state.records.keys) {
      final ref = SyncRef.parse(id);
      if (all || ref.kind == SyncKind.feature) refs.add(ref);
    }
    if (all) refs.addAll(store.syncRefs());
    var n = 0;
    for (final ref in refs) {
      _version(ref);
      // Yield now and then, so a long history doesn't block a frame.
      if (++n % 200 == 0) await Future<void>.delayed(Duration.zero);
    }
  }

  // ---------------------------------------------------------------- sync

  /// Runs one sync. Concurrent calls share the run in progress.
  Future<SyncReport> sync() => _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncReport> _sync() async {
    final report = SyncReport();
    if (!state.joined) {
      // First run on this device: take the server's records first.
      await _pull(report);
      state.joined = true;
      _scanAll = true;
    }
    final all = _scanAll;
    _scanAll = false;
    try {
      await _scan(all: all);
      await _pull(report);
      await _push(report);
    } catch (_) {
      if (all) _scanAll = true;
      rethrow;
    }
    state.lastSyncAt = DateTime.now();
    return report;
  }

  Future<void> _pull(SyncReport report) async {
    final saved = state.cursor;
    var after = saved == null ? null : PullCursor(_minus(saved.updatedAt, overlap), '');
    while (true) {
      final rows = await service.pull(after: after, limit: pageSize);
      if (rows.isEmpty) break;
      report.pulled += rows.length;
      await _merge(rows, report);
      final last = rows.last;
      after = PullCursor(last.updatedAt!, last.recordId);
      if (state.cursor == null || _later(last.updatedAt!, state.cursor!.updatedAt)) state.cursor = after;
      if (rows.length < pageSize) break;
    }
  }

  Future<void> _merge(List<RemoteRow> rows, SyncReport report) async {
    final changes = <RemoteChange>[];
    final metas = <RecordMeta, DecodedRecord>{};
    for (final row in rows) {
      final DecodedRecord rec;
      try {
        rec = await codec.decode(row);
      } on Exception {
        report.unreadableIds.add(row.id);
        continue;
      }
      state.clock.observe(row.version);
      final meta = state.records[rec.ref.id];
      if (meta == null || row.version > meta.version) {
        final m = RecordMeta(version: row.version, deleted: row.deleted, recordId: row.recordId);
        state.records[rec.ref.id] = m;
        metas[m] = rec;
        changes.add(RemoteChange(rec.ref, rec.value));
      } else if (row.version < meta.version) {
        meta.dirty = true; // The server is behind this device.
      } else {
        meta
          ..dirty = false
          ..recordId ??= row.recordId;
      }
    }
    if (changes.isEmpty) return;
    store.applyRemote(changes);
    report.applied += changes.length;
    // Fingerprint what the store now holds, so the next scan sees no change.
    for (final e in metas.entries) {
      e.key.fingerprint = RecordCodec.fingerprint(e.value.ref.kind, store.syncValue(e.value.ref));
    }
  }

  Future<void> _push(SyncReport report) async {
    final dirty = [for (final e in state.records.entries) if (e.value.dirty) e];
    for (var i = 0; i < dirty.length; i += pushBatch) {
      final batch = dirty.sublist(i, i + pushBatch > dirty.length ? dirty.length : i + pushBatch);
      final rows = <RemoteRow>[];
      final sent = <String, (RecordMeta, int)>{};
      for (final e in batch) {
        final ref = SyncRef.parse(e.key);
        final meta = e.value;
        final row = await codec.encode(ref, store.syncValue(ref), version: meta.version, recordId: meta.recordId);
        meta.recordId = row.recordId;
        rows.add(row);
        sent[row.id] = (meta, meta.version);
      }
      final accepted = await service.upsert(rows);
      for (final a in accepted) {
        final s = sent.remove(a.id);
        // Clear the flag only if nothing changed while the request was out.
        if (s != null && s.$1.version == a.version) s.$1.dirty = false;
      }
      report.pushed += accepted.length;
      if (sent.isNotEmpty) {
        // Skipped as stale: the server has the same or a newer version.
        report.stale += sent.length;
        final stale = [for (final r in rows) if (sent.containsKey(r.id)) r];
        await _merge(await service.fetch(stale), report);
      }
    }
  }

  // ---------------------------------------------------------------- time

  static String _minus(String ts, Duration d) =>
      DateTime.parse(ts).toUtc().subtract(d).toIso8601String();

  /// Whether server timestamp [a] is later than [b]. The web's DateTime keeps
  /// only milliseconds, so equal parses fall back to comparing the strings,
  /// which the server always formats the same way.
  static bool _later(String a, String b) {
    final da = DateTime.parse(a), db = DateTime.parse(b);
    return da.isAfter(db) || (da == db && a.compareTo(b) > 0);
  }
}

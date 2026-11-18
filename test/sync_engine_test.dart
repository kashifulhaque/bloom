// The sync engine against an in-memory server: clock ordering, the record
// codec, AppStore change tracking, merge rules, tombstones, and period months.
import 'dart:typed_data';

import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/core/sync/crypto/sync_crypto.dart';
import 'package:bloom/core/sync/hlc.dart';
import 'package:bloom/core/sync/record_codec.dart';
import 'package:bloom/core/sync/sync_engine.dart';
import 'package:bloom/core/sync/sync_models.dart';
import 'package:bloom/core/sync/sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_sync.dart';

final _dataKey = Uint8List.fromList(List.generate(32, (i) => 200 - i));

/// One device: a store, its engine, and its connection.
class Device {
  Device._(this.store, this.service, this.engine);

  final AppStore store;
  final FakeSyncService service;
  final SyncEngine engine;
  int localChanges = 0;

  SyncState get state => engine.state;

  static Future<Device> create(FakeServer server, {String email = 'a@example.test', AppStore? store, int? node, int Function()? now}) async {
    final s = store ?? AppStore.memory(profile: Profile(onboarded: true));
    final service = FakeSyncService(server)..signInAs(email);
    late Device d;
    final engine = SyncEngine(
      store: s,
      service: service,
      crypto: await SyncCrypto.fromDataKey(_dataKey),
      state: SyncState(userId: service.userId, clock: node == null ? Hlc.random(now: now) : Hlc(node: node, now: now)),
      onLocalChange: () => d.localChanges++,
      pageSize: 3, // Small pages exercise pagination.
      pushBatch: 4,
    )..attach();
    return d = Device._(s, service, engine);
  }

  Future<SyncReport> sync() => engine.sync();
}

DateTime d(String key) => parseDayKey(key);

void main() {
  group('Hybrid logical clock', () {
    test('versions increase, even when the wall clock stands still or goes back', () {
      var wall = 1000;
      final c = Hlc(node: 5, now: () => wall);
      final a = c.next();
      final b = c.next();
      wall = 900; // The clock jumped back.
      final e = c.next();
      expect(a < b && b < e, isTrue);
      expect(Hlc.nodeOf(a), 5);
      expect(Hlc.millisOf(e), 1000);
      expect(Hlc.counterOf(e), 2);
    });

    test('more than 64 events in a millisecond borrow the next millisecond', () {
      final c = Hlc(node: 1, now: () => 50);
      final versions = [for (var i = 0; i < 70; i++) c.next()];
      expect(versions, orderedEquals([...versions]..sort()));
      expect(versions.toSet(), hasLength(70));
      expect(Hlc.millisOf(versions.last), 51);
    });

    test('observing a remote version moves the clock past it', () {
      final slow = Hlc(node: 1, now: () => 100);
      final remote = Hlc.compose(5000, 3, 9);
      slow.observe(remote);
      expect(slow.next(), greaterThan(remote));
    });

    test('ties between devices break by node, and versions stay JavaScript-safe', () {
      final a = Hlc(node: 1, now: () => 10).next();
      final b = Hlc(node: 2, now: () => 10).next();
      expect(a, isNot(b));
      final late2090 = DateTime.utc(2090).millisecondsSinceEpoch - Hlc.epochMillis;
      expect(Hlc(node: 63, now: () => late2090).next(), lessThanOrEqualTo(Hlc.maxVersion));
      expect(Hlc.timeOf(Hlc.compose(0, 0, 1)), DateTime.utc(2025));
    });

    test('state survives a save and load', () {
      final c = Hlc(node: 7, now: () => 10)..next();
      final back = Hlc.fromJson(c.toJson(), now: () => 10);
      expect(back.next(), greaterThan(c.toJson()['millis'] as int));
      expect(back.node, 7);
    });
  });

  group('Record codec', () {
    test('canonical JSON sorts keys and day options, so equal logs hash equally', () {
      final a = {'date': '2026-11-18', 'selections': {'mood': ['calm', 'happy'], 'flow': ['light']}, 'metrics': {'b': 1, 'a': 2}};
      final b = {'metrics': {'a': 2, 'b': 1}, 'selections': {'flow': ['light'], 'mood': ['happy', 'calm']}, 'date': '2026-11-18'};
      expect(RecordCodec.canonical(SyncKind.day, a), RecordCodec.canonical(SyncKind.day, b));
      expect(RecordCodec.fingerprint(SyncKind.day, a), RecordCodec.fingerprint(SyncKind.day, b));
      // Feature lists keep their order.
      expect(RecordCodec.fingerprint(SyncKind.feature, [1, 2]), isNot(RecordCodec.fingerprint(SyncKind.feature, [2, 1])));
      expect(RecordCodec.fingerprint(SyncKind.feature, null), isNull);
    });

    test('encodes and decodes records and tombstones', () async {
      final codec = RecordCodec(await SyncCrypto.fromDataKey(_dataKey));
      final row = await codec.encode(const SyncRef(SyncKind.periods, '2026-11'), ['2026-11-01', '2026-11-02'], version: 9);
      expect(row.recordId, hasLength(43));
      expect(row.recordId, isNot(contains('2026')));
      final back = await codec.decode(row);
      expect(back.ref, const SyncRef(SyncKind.periods, '2026-11'));
      expect(back.value, ['2026-11-01', '2026-11-02']);

      final tomb = await codec.encode(SyncRef.day('2026-11-18'), null, version: 10);
      expect(tomb.deleted, isTrue);
      expect((await codec.decode(tomb)).value, isNull);
    });

    test('rejects a row whose id was swapped for another record\'s', () async {
      final codec = RecordCodec(await SyncCrypto.fromDataKey(_dataKey));
      final a = await codec.encode(SyncRef.day('2026-11-18'), {'date': '2026-11-18'}, version: 1);
      final b = await codec.encode(SyncRef.day('2026-11-19'), {'date': '2026-11-19'}, version: 1);
      final swapped = RemoteRow(kind: 'day', recordId: b.recordId, version: 1, deleted: false, ciphertext: a.ciphertext);
      await expectLater(codec.decode(swapped), throwsA(isA<Exception>()));
    });
  });

  group('AppStore change tracking', () {
    late AppStore store;
    late List<Iterable<SyncRef>?> seen;
    setUp(() {
      store = AppStore.memory(profile: Profile(onboarded: true));
      seen = [];
      store.syncHooks = _Recorder(seen);
    });

    test('each method reports the records it changed', () {
      store.setNote(d('2026-11-18'), 'hello');
      expect(seen.last, [SyncRef.day('2026-11-18')]);

      store.toggleOption(d('2026-11-03'), 'flow', 'medium', single: true);
      expect(seen.last, [SyncRef.day('2026-11-03'), const SyncRef(SyncKind.periods, '2026-11')]);

      store.startPeriod(d('2026-10-30'), length: 4);
      expect(seen.last!.toSet(), {const SyncRef(SyncKind.periods, '2026-10'), const SyncRef(SyncKind.periods, '2026-11')});

      store.updateProfile((p) => p.name = 'Ada');
      expect(seen.last, [SyncRef.profile]);

      store.setFeature('journal', ['x']);
      expect(seen.last, [SyncRef.feature('journal')]);

      store.commit(); // A direct edit somewhere.
      expect(seen.last, isNull);
    });

    test('with sync off, nothing is reported and behavior is unchanged', () {
      store.syncHooks = null;
      store.setPeriodDay(d('2026-11-01'), true);
      store.saveLog(DayLog(d('2026-11-02'), selections: {'flow': {'light'}}));
      expect(store.periodDays, {'2026-11-01', '2026-11-02'});
      expect(seen, isEmpty);
    });

    test('syncValue keeps device-only data out', () {
      store.updateProfile((p) => p.pin = 'fnv1a:secret');
      store.setFeature('assistant_ai', {'key': 'sk-or-secret'});
      store.setFeature('journal', ['entry']);
      final profile = store.syncValue(SyncRef.profile) as Map;
      expect(profile.containsKey('pin'), isFalse);
      expect(store.syncValue(SyncRef.feature('assistant_ai')), isNull);
      expect(store.syncRefs(), isNot(contains(SyncRef.feature('assistant_ai'))));
      expect(store.syncRefs(), contains(SyncRef.feature('journal')));
    });

    test('applyRemote applies each kind without reporting back', () {
      store.updateProfile((p) => p.pin = 'fnv1a:local');
      seen.clear();
      var notified = 0;
      store.addListener(() => notified++);
      store.applyRemote([
        RemoteChange(SyncRef.profile, {...Profile(name: 'Remote', onboarded: true).toJson(), 'pin': 'fnv1a:remote'}),
        RemoteChange(SyncRef.day('2026-11-05'), DayLog(d('2026-11-05'), note: 'from phone').toJson()),
        const RemoteChange(SyncRef(SyncKind.periods, '2026-11'), ['2026-11-01', '2026-11-02']),
        RemoteChange(SyncRef.feature('kicks'), {'n': 3}),
        RemoteChange(SyncRef.feature('assistant_ai'), {'key': 'nope'}),
      ]);
      expect(seen, isEmpty);
      expect(notified, 1);
      expect(store.profile.name, 'Remote');
      expect(store.profile.pin, 'fnv1a:local', reason: 'the PIN stays on this device');
      expect(store.logs['2026-11-05']!.note, 'from phone');
      expect(store.periodDays, {'2026-11-01', '2026-11-02'});
      expect(store.feature<Map>('kicks'), {'n': 3});
      expect(store.feature<Object>('assistant_ai'), isNull);

      store.applyRemote([
        RemoteChange(SyncRef.day('2026-11-05'), null),
        const RemoteChange(SyncRef(SyncKind.periods, '2026-11'), null),
        RemoteChange(SyncRef.feature('kicks'), null),
      ]);
      expect(store.logs, isEmpty);
      expect(store.periodDays, isEmpty);
      expect(store.features.containsKey('kicks'), isFalse);
    });

    test('applyRemote skips records that don\'t fit their key', () {
      store.applyRemote([
        RemoteChange(SyncRef.day('2026-11-05'), DayLog(d('2026-11-06')).toJson()),
        const RemoteChange(SyncRef(SyncKind.periods, '2026-11'), ['2026-12-01']),
      ]);
      expect(store.logs, isEmpty);
      expect(store.periodDays, isEmpty);
    });
  });

  group('Sync engine', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('a new device receives everything, and the server sees only ciphertext', () async {
      final a = await Device.create(server);
      a.store.updateProfile((p) => p.name = 'Ada');
      a.store.startPeriod(d('2026-10-28'), length: 6); // Spans two months.
      a.store.setNote(d('2026-11-10'), 'cramps, slept badly');
      a.store.setFeature('journal', [{'text': 'private thought'}]);
      final r = await a.sync();
      expect(r.pushed, 5); // profile, 2 period months, 1 day, 1 feature

      for (final row in server.rowsOf(a.service.userId!)) {
        final text = String.fromCharCodes(row.ciphertext);
        expect(text, isNot(contains('cramps')));
        expect(text, isNot(contains('Ada')));
        expect(row.recordId, isNot(contains('2026')));
      }

      final b = await Device.create(server);
      await b.sync();
      expect(b.store.profile.name, 'Ada');
      expect(b.store.periodDays, a.store.periodDays);
      expect(b.store.logs['2026-11-10']!.note, 'cramps, slept badly');
      expect(b.store.feature<List>('journal'), [{'text': 'private thought'}]);
      expect(b.state.pending, 0);
    });

    test('edits on two devices to different days both survive', () async {
      final a = await Device.create(server);
      final b = await Device.create(server);
      a.store.setNote(d('2026-11-01'), 'from A');
      b.store.setNote(d('2026-11-02'), 'from B');
      await a.sync();
      await b.sync();
      await a.sync();
      for (final dev in [a, b]) {
        expect(dev.store.logs.keys.toSet(), {'2026-11-01', '2026-11-02'});
      }
    });

    test('the same day edited on two devices: the later edit wins everywhere', () async {
      var wall = 1000;
      final a = await Device.create(server, node: 1, now: () => wall);
      final b = await Device.create(server, node: 2, now: () => wall);
      a.store.setNote(d('2026-11-01'), 'first');
      wall = 2000;
      b.store.setNote(d('2026-11-01'), 'second');
      await b.sync(); // The later edit reaches the server first.
      await a.sync(); // A's older edit is skipped as stale, and A takes B's.
      expect(a.store.logs['2026-11-01']!.note, 'second');
      expect(a.state.pending, 0);
      await b.sync();
      expect(b.store.logs['2026-11-01']!.note, 'second');
      final days = server.rowsOf(a.service.userId!).where((r) => r.kind == 'day');
      expect(days, hasLength(1));
    });

    test('a stale push is answered by merging the server\'s newer copy', () async {
      var wall = 5000;
      final a = await Device.create(server, node: 1, now: () => wall);
      final b = await Device.create(server, node: 2, now: () => wall);
      await a.sync();
      b.store.setFeature('kicks', {'n': 9});
      await b.sync();
      wall = 1000; // A's clock is behind, and A hasn't seen B's row.
      a.store.setFeature('kicks', {'n': 1});
      a.service.hidePulls = true;
      final r = await a.sync();
      expect(r.stale, 1);
      expect(r.pushed, 0);
      expect(a.store.feature<Map>('kicks'), {'n': 9});
      expect(a.state.pending, 0);
      // The server kept B's version.
      a.service.hidePulls = false;
      final c = await Device.create(server);
      await c.sync();
      expect(c.store.feature<Map>('kicks'), {'n': 9});
    });

    test('deletes travel as tombstones', () async {
      final a = await Device.create(server);
      final b = await Device.create(server);
      a.store.setNote(d('2026-11-01'), 'gone soon');
      a.store.setFeature('kicks', {'n': 1});
      await a.sync();
      await b.sync();
      expect(b.store.logs, contains('2026-11-01'));

      a.store.setNote(d('2026-11-01'), ''); // An empty log is removed.
      a.store.setFeature('kicks', null);
      await a.sync();
      final tombs = server.rowsOf(a.service.userId!).where((r) => r.deleted);
      expect(tombs, hasLength(2));
      await b.sync();
      expect(b.store.logs, isNot(contains('2026-11-01')));
      expect(b.store.features.containsKey('kicks'), isFalse);

      // A tombstone loses to a later re-creation.
      b.store.setNote(d('2026-11-01'), 'back again');
      await b.sync();
      await a.sync();
      expect(a.store.logs['2026-11-01']!.note, 'back again');
    });

    test('period days sync as one record per month', () async {
      final a = await Device.create(server);
      final b = await Device.create(server);
      a.store.startPeriod(d('2026-09-28'), length: 5);
      await a.sync();
      expect(server.rowsOf(a.service.userId!).where((r) => r.kind == 'periods'), hasLength(2));
      await b.sync();
      // A changes October only; B changes November. Both survive.
      a.store.setPeriodDay(d('2026-10-03'), true);
      b.store.startPeriod(d('2026-11-01'), length: 2);
      final before = a.service.upserts;
      await a.sync();
      expect(a.service.upserts - before, 1);
      await b.sync();
      await a.sync();
      final expected = {'2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-11-01', '2026-11-02'};
      expect(a.store.periodDays, expected);
      expect(b.store.periodDays, expected);
    });

    test('a joining device adopts the account\'s records instead of overwriting them', () async {
      final a = await Device.create(server);
      a.store.updateProfile((p) {
        p.name = 'Ada';
        p.cycleLength = 31;
      });
      a.store.setNote(d('2026-11-01'), 'synced');
      await a.sync();

      // B went through onboarding just now, so its profile is newer locally.
      final fresh = AppStore.memory(profile: Profile(onboarded: true, cycleLength: 28));
      fresh.setNote(d('2026-11-02'), 'only on B');
      final b = await Device.create(server, store: fresh);
      await b.sync();
      expect(b.store.profile.name, 'Ada');
      expect(b.store.profile.cycleLength, 31);
      expect(b.store.logs.keys.toSet(), {'2026-11-01', '2026-11-02'});
      await a.sync();
      expect(a.store.logs['2026-11-02']!.note, 'only on B');
    });

    test('direct edits are found by a full scan', () async {
      final a = await Device.create(server);
      await a.sync();
      a.store.logs['2026-11-07'] = DayLog(d('2026-11-07'), note: 'direct');
      a.store.periodDays.add('2026-11-07');
      a.store.features['pregnancy_history'] = ['x'];
      a.store.commit();
      final r = await a.sync();
      expect(r.pushed, 3);
    });

    test('feature writes that skip setFeature are still picked up', () async {
      final a = await Device.create(server);
      await a.sync();
      a.store.features['pregnancy_history'] = ['archived'];
      a.store.setFeature('pregnancy', null); // Reports only "pregnancy".
      final r = await a.sync();
      expect(r.pushed, 1);
    });

    test('an unchanged record isn\'t uploaded again', () async {
      final a = await Device.create(server);
      a.store.setNote(d('2026-11-01'), 'x');
      await a.sync();
      final v = a.state.records[SyncRef.day('2026-11-01').id]!.version;
      a.store.setNote(d('2026-11-01'), 'x');
      final r = await a.sync();
      expect(r.pushed, 0);
      expect(a.state.records[SyncRef.day('2026-11-01').id]!.version, v);
    });

    test('rows with equal timestamps across pages are all pulled', () async {
      server.frozenTime = '2026-11-18T00:00:00.000001+00:00';
      final a = await Device.create(server);
      for (var i = 1; i <= 10; i++) {
        a.store.setNote(d('2026-11-${i.toString().padLeft(2, '0')}'), 'n$i');
      }
      await a.sync();
      final b = await Device.create(server);
      await b.sync();
      expect(b.store.logs, hasLength(10));
      // A second pull with the overlap window changes nothing.
      final r = await b.sync();
      expect(r.applied, 0);
    });

    test('a row that doesn\'t decrypt is skipped and reported', () async {
      final a = await Device.create(server);
      a.store.setNote(d('2026-11-01'), 'ok');
      a.store.setNote(d('2026-11-02'), 'tampered');
      await a.sync();
      final uid = a.service.userId!;
      final victim = server.rowsOf(uid).firstWhere((r) => r.kind == 'day');
      server.corrupt(uid, victim.id);
      final b = await Device.create(server);
      final r = await b.sync();
      expect(r.unreadable, 1);
      expect(b.store.logs, hasLength(1));
    });

    test('another account\'s rows are invisible', () async {
      final a = await Device.create(server, email: 'a@example.test');
      a.store.setNote(d('2026-11-01'), 'A only');
      await a.sync();
      final other = await Device.create(server, email: 'b@example.test');
      final r = await other.sync();
      expect(r.pulled, 0);
      expect(other.store.logs, isEmpty);
    });

    test('offline edits are kept and sent later', () async {
      final a = await Device.create(server);
      await a.sync();
      a.service.offline = true;
      a.store.setNote(d('2026-11-01'), 'offline');
      await expectLater(a.sync(), throwsA(anything));
      expect(a.state.pending, 1);
      a.service.offline = false;
      await a.sync();
      expect(a.state.pending, 0);
      expect(server.rowsOf(a.service.userId!), hasLength(2)); // day + profile
    });

    test('local changes are reported so the caller can debounce a sync', () async {
      final a = await Device.create(server);
      await a.sync();
      a.store.setNote(d('2026-11-01'), 'x');
      a.store.setNote(d('2026-11-01'), 'xy');
      expect(a.localChanges, 2);
      expect(a.state.pending, 1);
    });

    test('sync state survives a save and load', () async {
      final a = await Device.create(server);
      a.store.setNote(d('2026-11-01'), 'x');
      await a.sync();
      await a.sync(); // Pulls its own rows, so the cursor is set.
      final back = SyncState.decode(a.state.encode());
      expect(back.userId, a.state.userId);
      expect(back.joined, isTrue);
      expect(back.cursor!.updatedAt, a.state.cursor!.updatedAt);
      expect(back.records.keys, a.state.records.keys);
      expect(back.records.values.first.version, a.state.records.values.first.version);
    });
  });
}

class _Recorder implements SyncHooks {
  _Recorder(this.seen);
  final List<Iterable<SyncRef>?> seen;
  @override
  void localChanged(Iterable<SyncRef>? refs) => seen.add(refs?.toList());
  @override
  void localReset() {}
}

// Merge rules and the store write, including what sync hears.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/import/apple_health_parser.dart';
import 'package:bloom/features/import/import_data.dart';
import 'package:bloom/features/import/merge.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingHooks implements SyncHooks {
  final List<Iterable<SyncRef>?> calls = [];

  @override
  void localChanged(Iterable<SyncRef>? refs) => calls.add(refs?.toList());

  @override
  FutureOr<void> localReset() {}
}

ImportedData apple() {
  final p = AppleHealthParser(today: DateTime(2025, 1, 1))
    ..add(File('test/import/fixtures/apple_health_export.xml').readAsStringSync());
  return p.finish();
}

AppStore existingStore() {
  final store = AppStore.memory(profile: Profile(name: 'Ada', onboarded: true));
  store.setPeriodDay(parseDayKey('2024-03-02'), true);
  store.saveLog(DayLog(parseDayKey('2024-03-16'), selections: {
    'mood': {'happy'},
  }));
  store.saveLog(DayLog(parseDayKey('2023-01-10'), note: 'Old note'));
  store.setFeature('journal', {'entries': 1});
  return store;
}

void main() {
  test('add: days already in Bloom keep Bloom\'s entry', () {
    final store = existingStore();
    final data = apple();
    final plan = planMerge(
      existingPeriodDays: store.periodDays,
      existingLogs: store.logs,
      data: data,
      mode: MergeMode.add,
    );
    expect(plan.keptDays, 2, reason: '2024-03-02 is a period day, 2024-03-16 has a log');
    expect(plan.logs.containsKey('2024-03-02'), isFalse);
    expect(plan.logs.containsKey('2024-03-16'), isFalse);
    expect(plan.periodDays.contains('2024-03-02'), isFalse);
    expect(plan.importedDays, data.days.length - 2);

    store.applyImport(logs: plan.logs, periodDays: plan.periodDays);
    expect(store.logs['2024-03-16']!.get('mood'), {'happy'});
    expect(store.logs['2024-03-16']!.metrics, isEmpty, reason: 'the imported temperature is left out');
    expect(store.logs['2024-03-02'], isNull, reason: 'the existing period day had no log, and stays that way');
    expect(store.logs['2024-03-03']!.get('flow'), {'heavy'});
    expect(store.periodDays, containsAll(['2024-03-02', '2024-03-03', '2024-03-31']));
    expect(store.logs['2023-01-10']!.note, 'Old note');
  });

  test('add: an empty log in Bloom doesn\'t count as an entry', () {
    final data = ImportedData(
      format: ImportFormat.genericCsv,
      logs: const {},
      periodDays: {'2024-01-01'},
    );
    final plan = planMerge(
      existingPeriodDays: const {},
      existingLogs: {'2024-01-01': DayLog(DateTime(2024))},
      data: data,
      mode: MergeMode.add,
    );
    expect(plan.keptDays, 0);
    expect(plan.periodDays, {'2024-01-01'});
  });

  test('replace: everything goes except the profile and features', () {
    final store = existingStore();
    final data = apple();
    final plan = planMerge(
      existingPeriodDays: store.periodDays,
      existingLogs: store.logs,
      data: data,
      mode: MergeMode.replace,
    );
    expect(plan.keptDays, 0);
    expect(plan.removedDays, 1, reason: 'only 2023-01-10 isn\'t in the import');
    expect(plan.importedDays, data.days.length);

    store.applyImport(logs: plan.logs, periodDays: plan.periodDays, replace: true);
    expect(store.logs['2023-01-10'], isNull);
    expect(store.logs['2024-03-16']!.get('mood'), isEmpty);
    expect(store.logs['2024-03-16']!.metrics['bbt'], 36.42);
    expect(store.periodDays, data.periodDays);
    expect(store.profile.name, 'Ada');
    expect(store.feature<Map>('journal'), {'entries': 1});
  });

  test('the import goes through sync like a normal edit', () {
    final store = existingStore();
    final hooks = RecordingHooks();
    store.syncHooks = hooks;
    final data = apple();
    final plan = planMerge(
      existingPeriodDays: store.periodDays,
      existingLogs: store.logs,
      data: data,
      mode: MergeMode.add,
    );
    store.applyImport(logs: plan.logs, periodDays: plan.periodDays);
    expect(hooks.calls, hasLength(1));
    final refs = hooks.calls.single!.toSet();
    expect(refs, contains(SyncRef.day('2024-03-03')));
    expect(refs, contains(const SyncRef(SyncKind.periods, '2024-03')));
    expect(refs, contains(const SyncRef(SyncKind.periods, '2024-04')));
    expect(refs, isNot(contains(SyncRef.day('2024-03-16'))), reason: 'kept days don\'t change');
    // Every reported record has the value sync would upload.
    for (final r in refs) {
      expect(store.syncValue(r), isNotNull, reason: r.id);
    }
    expect(jsonEncode(store.syncValue(SyncRef.day('2024-03-03'))), contains('heavy'));
  });

  test('replace tells sync about removed records, which then read as deleted', () {
    final store = existingStore();
    final hooks = RecordingHooks();
    store.syncHooks = hooks;
    final data = apple();
    final plan = planMerge(
      existingPeriodDays: store.periodDays,
      existingLogs: store.logs,
      data: data,
      mode: MergeMode.replace,
    );
    store.applyImport(logs: plan.logs, periodDays: plan.periodDays, replace: true);
    final refs = hooks.calls.single!.toSet();
    expect(refs, contains(SyncRef.day('2023-01-10')));
    expect(store.syncValue(SyncRef.day('2023-01-10')), isNull);
  });

  test('countPeriods counts runs of consecutive days', () {
    expect(countPeriods(const []), 0);
    expect(countPeriods(['2024-01-01', '2024-01-02', '2024-01-04', '2024-02-01']), 3);
    expect(countPeriods(['2024-02-29', '2024-03-01']), 1);
  });
}

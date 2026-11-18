/// Single source of truth for app state, persisted locally as JSON.
///
/// Widgets read it with `context.watch<AppStore>()` and change it through
/// its methods. Every change saves to `SharedPreferences` (IndexedDB-backed
/// local storage on the web) and rebuilds the cycle engine.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'engine.dart';
import 'models.dart';
import 'sync_records.dart';

export 'sync_records.dart';

class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  static const _storageKey = 'bloom_state_v1';
  static const schemaVersion = 1;

  final SharedPreferences? _prefs;

  Profile profile = Profile();

  /// Day keys (`yyyy-MM-dd`) marked as period days.
  final Set<String> periodDays = {};

  /// Day logs keyed by day key.
  final Map<String, DayLog> logs = {};

  /// Namespaced storage for feature modules (reminders, kicks, contractions,
  /// pregnancy settings, journal, quiz results, etc.). Values must be
  /// JSON-encodable. Use [feature] and [setFeature]; pick a unique key
  /// per feature, for example `pregnancy`, `kicks`, `reminders`.
  final Map<String, dynamic> features = {};

  /// True while the app lock is engaged for this session.
  bool locked = false;

  late CycleEngine engine;

  /// Set by the sync engine while sync is on. When it's null (the default),
  /// the store behaves exactly as it does without sync.
  SyncHooks? syncHooks;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore._(prefs);
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        store._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not read saved state: $e');
      }
    }
    store.locked = store.profile.pin != null;
    store._rebuild();
    return store;
  }

  /// In-memory store for tests. Nothing is persisted.
  factory AppStore.memory({Profile? profile}) {
    final s = AppStore._(null);
    if (profile != null) s.profile = profile;
    s._rebuild();
    return s;
  }

  void _rebuild() {
    engine = CycleEngine(periodDays: periodDays, logs: logs, profile: profile);
  }

  Timer? _saveTimer;

  /// Rebuilds derived state, notifies listeners, and schedules a save.
  ///
  /// Call it after changing [profile], [periodDays], [logs], or [features]
  /// directly. Sync then rescans every record for changes. The store's own
  /// methods report exactly which records changed instead.
  void commit() => _commit(null);

  /// Like [commit], but tells sync which records changed. Null means "could
  /// be anything".
  void _commit(Iterable<SyncRef>? changed) {
    syncHooks?.localChanged(changed);
    _apply();
  }

  void _apply() {
    _rebuild();
    notifyListeners();
    if (_prefs == null) return; // In-memory store: nothing to persist.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), save);
  }

  Future<void> save() async {
    await _prefs?.setString(_storageKey, jsonEncode(toJson()));
  }

  // ---------------------------------------------------------------- profile

  void updateProfile(void Function(Profile p) change) {
    change(profile);
    _commit(const [SyncRef.profile]);
  }

  void setGoal(Goal g) => updateProfile((p) => p.goal = g);

  // ---------------------------------------------------------------- periods

  bool isPeriodDay(DateTime d) => periodDays.contains(dayKey(d));

  void setPeriodDay(DateTime d, bool on) {
    on ? periodDays.add(dayKey(d)) : periodDays.remove(dayKey(d));
    _commit([SyncRef.periodsOf(d)]);
  }

  /// Replaces period days in [from]..[to] with exactly [days].
  void setPeriodDaysInRange(DateTime from, DateTime to, Set<DateTime> days) {
    final touched = <SyncRef>{};
    periodDays.removeWhere((k) {
      final d = parseDayKey(k);
      final hit = !d.isBefore(from) && !d.isAfter(to);
      if (hit) touched.add(SyncRef.periodsOf(d));
      return hit;
    });
    periodDays.addAll(days.map(dayKey));
    touched.addAll(days.map(SyncRef.periodsOf));
    _commit(touched);
  }

  /// Logs a period starting on [start] for [length] days (default: average).
  void startPeriod(DateTime start, {int? length}) {
    final len = length ?? engine.avgPeriodLength;
    final touched = <SyncRef>{};
    for (var i = 0; i < len; i++) {
      final d = addDays(start, i);
      periodDays.add(dayKey(d));
      touched.add(SyncRef.periodsOf(d));
    }
    _commit(touched);
  }

  /// Ends the period that contains [day]: removes later days of that run.
  void endPeriod(DateTime day) {
    var d = addDays(day, 1);
    final touched = <SyncRef>{};
    while (periodDays.remove(dayKey(d))) {
      touched.add(SyncRef.periodsOf(d));
      d = addDays(d, 1);
    }
    _commit(touched);
  }

  // ---------------------------------------------------------------- logs

  DayLog logFor(DateTime d) => logs[dayKey(d)] ?? DayLog(dayOf(d));

  /// Saves [log]; removes it when empty. Logging a flow (not spotting)
  /// marks the day as a period day.
  void saveLog(DayLog log) {
    if (log.isEmpty) {
      logs.remove(log.key);
    } else {
      logs[log.key] = log;
    }
    final flow = log.get('flow');
    final touched = [SyncRef.day(log.key)];
    if (flow.isNotEmpty && !flow.contains('spotting') && periodDays.add(log.key)) {
      touched.add(SyncRef.periodsOf(log.date));
    }
    _commit(touched);
  }

  void toggleOption(DateTime d, String categoryId, String optionId, {bool single = false}) {
    final log = logFor(d).copy();
    final set = log.selections.putIfAbsent(categoryId, () => {});
    if (set.contains(optionId)) {
      set.remove(optionId);
    } else {
      if (single) set.clear();
      set.add(optionId);
    }
    saveLog(log);
  }

  void setMetric(DateTime d, String metricId, double? value) {
    final log = logFor(d).copy();
    value == null ? log.metrics.remove(metricId) : log.metrics[metricId] = value;
    saveLog(log);
  }

  void setNote(DateTime d, String note) {
    final log = logFor(d).copy()..note = note;
    saveLog(log);
  }

  /// Logs between [from] and [to] inclusive, oldest first.
  List<DayLog> logsBetween(DateTime from, DateTime to) {
    final out = logs.values.where((l) => !l.date.isBefore(from) && !l.date.isAfter(to)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  // ---------------------------------------------------------------- features

  T? feature<T>(String key) => features[key] as T?;

  void setFeature(String key, Object? value) {
    value == null ? features.remove(key) : features[key] = value;
    _commit([SyncRef.feature(key)]);
  }

  // ---------------------------------------------------------------- lock

  /// Engages the app lock when a PIN is set.
  void lock() {
    if (profile.pin == null) return;
    locked = true;
    notifyListeners();
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- import/export

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'app': 'bloom',
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': profile.toJson(),
        'periodDays': (periodDays.toList()..sort()),
        'logs': [for (final l in logs.values) l.toJson()],
        'features': features,
      };

  void _fromJson(Map<String, dynamic> j) {
    profile = Profile.fromJson(Map<String, dynamic>.from(j['profile'] ?? {}));
    periodDays
      ..clear()
      ..addAll(List<String>.from(j['periodDays'] ?? const []));
    logs.clear();
    for (final l in (j['logs'] as List? ?? const [])) {
      final log = DayLog.fromJson(Map<String, dynamic>.from(l));
      logs[log.key] = log;
    }
    features
      ..clear()
      ..addAll(Map<String, dynamic>.from(j['features'] ?? {}));
  }

  /// Replaces all data with an exported backup. Throws on invalid input.
  void importJson(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['app'] != 'bloom') throw const FormatException('Not a Bloom backup file');
    _fromJson(j);
    locked = false;
    _commit(null);
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Deletes every piece of data and returns to onboarding.
  ///
  /// This erases only this device. When sync is on, it also turns sync off
  /// here (see [SyncHooks.localReset]), so the synced copy isn't erased too.
  Future<void> deleteAll() async {
    await syncHooks?.localReset();
    profile = Profile();
    periodDays.clear();
    logs.clear();
    features.clear();
    locked = false;
    await _prefs?.remove(_storageKey);
    _apply();
  }

  // ---------------------------------------------------------------- sync

  /// Every record that sync would upload now. Device-only data, such as the
  /// app-lock PIN or the AI key, isn't included (see [SyncRef.syncsFeature]).
  Iterable<SyncRef> syncRefs() sync* {
    yield SyncRef.profile;
    for (final k in logs.keys) {
      yield SyncRef.day(k);
    }
    final months = <String>{for (final k in periodDays) k.substring(0, 7)};
    for (final m in months) {
      yield SyncRef(SyncKind.periods, m);
    }
    for (final k in features.keys) {
      if (SyncRef.syncsFeature(k)) yield SyncRef.feature(k);
    }
  }

  /// The JSON value of one record, or null when it doesn't exist (deleted).
  Object? syncValue(SyncRef ref) {
    switch (ref.kind) {
      case SyncKind.profile:
        return profile.toJson()..removeWhere((k, _) => SyncRef.localProfileFields.contains(k));
      case SyncKind.day:
        return logs[ref.key]?.toJson();
      case SyncKind.periods:
        final days = [for (final k in periodDays) if (k.startsWith('${ref.key}-')) k]..sort();
        return days.isEmpty ? null : days;
      case SyncKind.feature:
        return SyncRef.syncsFeature(ref.key) ? features[ref.key] : null;
    }
  }

  /// Applies records that sync downloaded. A null value deletes the record.
  ///
  /// It doesn't report the changes back to sync, then saves and notifies
  /// listeners like any other change. Records that don't parse are skipped.
  void applyRemote(Iterable<RemoteChange> changes) {
    var any = false;
    for (final c in changes) {
      try {
        _applyOne(c);
        any = true;
      } catch (e) {
        debugPrint('Skipped a synced ${c.ref.kind.name} record: $e');
      }
    }
    if (any) _apply();
  }

  void _applyOne(RemoteChange c) {
    final v = c.value;
    switch (c.ref.kind) {
      case SyncKind.profile:
        if (v == null) return; // The profile is never deleted.
        final local = SyncRef.localProfileFields.map((f) => MapEntry(f, profile.toJson()[f]));
        profile = Profile.fromJson({...Map<String, dynamic>.from(v as Map), ...Map.fromEntries(local)});
      case SyncKind.day:
        if (v == null) {
          logs.remove(c.ref.key);
        } else {
          final log = DayLog.fromJson(Map<String, dynamic>.from(v as Map));
          if (log.key != c.ref.key) throw FormatException('Day ${log.key} sent as ${c.ref.key}');
          logs[log.key] = log;
        }
      case SyncKind.periods:
        final month = c.ref.key;
        final days = v == null ? const <String>[] : List<String>.from(v as List);
        if (days.any((d) => !d.startsWith('$month-'))) throw FormatException('Period days outside $month');
        periodDays
          ..removeWhere((k) => k.startsWith('$month-'))
          ..addAll(days);
      case SyncKind.feature:
        if (!SyncRef.syncsFeature(c.ref.key)) return;
        v == null ? features.remove(c.ref.key) : features[c.ref.key] = v;
    }
  }
}

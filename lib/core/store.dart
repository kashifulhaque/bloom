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
  void commit() {
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
    commit();
  }

  void setGoal(Goal g) => updateProfile((p) => p.goal = g);

  // ---------------------------------------------------------------- periods

  bool isPeriodDay(DateTime d) => periodDays.contains(dayKey(d));

  void setPeriodDay(DateTime d, bool on) {
    on ? periodDays.add(dayKey(d)) : periodDays.remove(dayKey(d));
    commit();
  }

  /// Replaces period days in [from]..[to] with exactly [days].
  void setPeriodDaysInRange(DateTime from, DateTime to, Set<DateTime> days) {
    periodDays.removeWhere((k) {
      final d = parseDayKey(k);
      return !d.isBefore(from) && !d.isAfter(to);
    });
    periodDays.addAll(days.map(dayKey));
    commit();
  }

  /// Logs a period starting on [start] for [length] days (default: average).
  void startPeriod(DateTime start, {int? length}) {
    final len = length ?? engine.avgPeriodLength;
    for (var i = 0; i < len; i++) {
      periodDays.add(dayKey(addDays(start, i)));
    }
    commit();
  }

  /// Ends the period that contains [day]: removes later days of that run.
  void endPeriod(DateTime day) {
    var d = addDays(day, 1);
    while (periodDays.remove(dayKey(d))) {
      d = addDays(d, 1);
    }
    commit();
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
    if (flow.isNotEmpty && !flow.contains('spotting')) periodDays.add(log.key);
    commit();
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
    commit();
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
    commit();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Deletes every piece of data and returns to onboarding.
  Future<void> deleteAll() async {
    profile = Profile();
    periodDays.clear();
    logs.clear();
    features.clear();
    locked = false;
    await _prefs?.remove(_storageKey);
    commit();
  }
}

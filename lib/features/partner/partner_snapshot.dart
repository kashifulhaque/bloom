/// Read-only partner snapshot: what's shared, how it's built from the
/// store, and how it's encoded as a compact text code.
///
/// Sharing is offline: the code holds the data itself (base64url JSON with a
/// `BLOOM1.` prefix). There's no server, so "stop sharing" can only stop
/// showing the old code; anyone who already has it keeps that snapshot.
library;

import 'dart:convert';
import 'dart:math';

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/store.dart';
import '../reports/pregnancy_info.dart';

const kSnapshotPrefix = 'BLOOM1.';

/// What the user chose to include in the snapshot.
class ShareOptions {
  ShareOptions({
    this.name = true,
    this.predictions = true,
    this.fertility = true,
    this.phase = true,
    this.pregnancy = true,
    this.moods = false,
    this.symptoms = false,
  });

  bool name;
  bool predictions;
  bool fertility;
  bool phase;
  bool pregnancy;
  bool moods;
  bool symptoms;

  Map<String, dynamic> toJson() => {
        'name': name,
        'predictions': predictions,
        'fertility': fertility,
        'phase': phase,
        'pregnancy': pregnancy,
        'moods': moods,
        'symptoms': symptoms,
      };

  factory ShareOptions.fromJson(Map<String, dynamic>? j) => ShareOptions(
        name: j?['name'] as bool? ?? true,
        predictions: j?['predictions'] as bool? ?? true,
        fertility: j?['fertility'] as bool? ?? true,
        phase: j?['phase'] as bool? ?? true,
        pregnancy: j?['pregnancy'] as bool? ?? true,
        moods: j?['moods'] as bool? ?? false,
        symptoms: j?['symptoms'] as bool? ?? false,
      );
}

class PartnerSnapshot {
  PartnerSnapshot({
    required this.id,
    required this.generated,
    this.name,
    this.pregnant = false,
    this.periodStarts = const [],
    this.periodLength,
    this.ovulations = const [],
    this.phase,
    this.cycleDay,
    this.dueDate,
    this.moods = const [],
    this.symptoms = const [],
  });

  final String id;
  final DateTime generated;
  final String? name;
  final bool pregnant;

  /// Recent and predicted period starts, oldest first.
  final List<DateTime> periodStarts;
  final int? periodLength;

  /// Estimated ovulation days, oldest first. Empty when fertility isn't shared.
  final List<DateTime> ovulations;

  /// Phase and cycle day on [generated], when shared.
  final Phase? phase;
  final int? cycleDay;
  final DateTime? dueDate;

  /// Mood and symptom labels logged in the 3 days before [generated].
  final List<String> moods;
  final List<String> symptoms;

  DateTime? nextPeriodAfter(DateTime day) {
    for (final s in periodStarts) {
      if (!s.isBefore(day)) return s;
    }
    return null;
  }

  bool isPeriodDay(DateTime d) =>
      periodLength != null &&
      periodStarts.any((s) => !d.isBefore(s) && d.isBefore(addDays(s, periodLength!)));

  bool isFertile(DateTime d) =>
      ovulations.any((o) => !d.isBefore(addDays(o, -5)) && !d.isAfter(addDays(o, 1)));

  bool isOvulation(DateTime d) => ovulations.any((o) => sameDay(o, d));

  /// Phase on [d], estimated from the shared dates. Falls back to the
  /// phase at generation time when no dates were shared.
  Phase? phaseOn(DateTime d) {
    if (periodStarts.isEmpty) return sameDay(d, generated) ? phase : null;
    if (isPeriodDay(d)) return Phase.menstrual;
    if (isFertile(d)) return Phase.ovulation;
    DateTime? lastStart;
    for (final s in periodStarts) {
      if (!s.isAfter(d)) lastStart = s;
    }
    if (lastStart == null) return null;
    final ov = ovulations.where((o) => o.isAfter(lastStart!) && o.isBefore(d)).isNotEmpty;
    return ov ? Phase.luteal : Phase.follicular;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'id': id,
        'g': dayKey(generated),
        if (name != null) 'n': name,
        if (pregnant) 'pg': 1,
        if (periodStarts.isNotEmpty) 'ps': [for (final d in periodStarts) dayKey(d)],
        if (periodLength != null) 'pl': periodLength,
        if (ovulations.isNotEmpty) 'ov': [for (final d in ovulations) dayKey(d)],
        if (phase != null) 'ph': phase!.name,
        if (cycleDay != null) 'cd': cycleDay,
        if (dueDate != null) 'dd': dayKey(dueDate!),
        if (moods.isNotEmpty) 'm': moods,
        if (symptoms.isNotEmpty) 's': symptoms,
      };

  factory PartnerSnapshot.fromJson(Map<String, dynamic> j) {
    List<DateTime> days(Object? v) => [for (final k in (v as List? ?? const [])) parseDayKey(k as String)];
    return PartnerSnapshot(
      id: j['id'] as String? ?? '',
      generated: parseDayKey(j['g'] as String),
      name: j['n'] as String?,
      pregnant: j['pg'] == 1,
      periodStarts: days(j['ps']),
      periodLength: (j['pl'] as num?)?.toInt(),
      ovulations: days(j['ov']),
      phase: Phase.values.asNameMap()[j['ph']],
      cycleDay: (j['cd'] as num?)?.toInt(),
      dueDate: j['dd'] == null ? null : parseDayKey(j['dd'] as String),
      moods: List<String>.from(j['m'] as List? ?? const []),
      symptoms: List<String>.from(j['s'] as List? ?? const []),
    );
  }

  String encode() => kSnapshotPrefix + base64Url.encode(utf8.encode(jsonEncode(toJson()))).replaceAll('=', '');

  /// Decodes a code made by [encode]. Throws [FormatException] when invalid.
  static PartnerSnapshot decode(String code) {
    var c = code.trim().replaceAll(RegExp(r'\s'), '');
    if (!c.startsWith(kSnapshotPrefix)) throw const FormatException('This isn\'t a Bloom partner code.');
    c = c.substring(kSnapshotPrefix.length);
    c = c.padRight((c.length + 3) ~/ 4 * 4, '=');
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(base64Url.decode(c))) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('The code is incomplete or damaged. Copy it again.');
    }
    if (j['v'] != 1) throw const FormatException('This code is from a different version of Bloom.');
    try {
      return PartnerSnapshot.fromJson(j);
    } catch (_) {
      throw const FormatException('The code is incomplete or damaged. Copy it again.');
    }
  }
}

String newSnapshotId() {
  final r = Random.secure();
  return List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
}

/// Builds a snapshot from the store using only what [o] allows.
PartnerSnapshot buildSnapshot(AppStore store, ShareOptions o, {required String id, DateTime? now}) {
  final n = dayOf(now ?? DateTime.now());
  final e = store.engine;
  final preg = pregnancyInfo(store, now: n);
  final pregnant = preg != null;
  final info = e.info(n);

  final starts = <DateTime>[];
  final ovs = <DateTime>[];
  if (!pregnant && e.hasData) {
    final current = e.currentCycle!;
    if (o.predictions) {
      starts.add(current.start);
      starts.addAll(e.futureCycles(3).map((f) => f.start));
    }
    if (o.fertility) {
      ovs.add(current.ovulation);
      ovs.addAll(e.futureCycles(3).map((f) => f.ovulation));
    }
  }

  List<String> recent(String category) {
    final out = <String>{};
    for (final l in store.logsBetween(addDays(n, -2), n)) {
      out.addAll(l.get(category).map((id) => optionLabel(category, id)));
    }
    return out.toList();
  }

  final name = store.profile.name.trim();
  return PartnerSnapshot(
    id: id,
    generated: n,
    name: o.name && name.isNotEmpty ? name : null,
    pregnant: pregnant && o.pregnancy,
    periodStarts: starts,
    periodLength: starts.isEmpty ? null : e.avgPeriodLength,
    ovulations: ovs,
    phase: !pregnant && o.phase ? info.phase : null,
    cycleDay: !pregnant && o.phase ? info.cycleDay : null,
    dueDate: pregnant && o.pregnancy ? preg.dueDate : null,
    // Personal logs stay private in pregnancy mode.
    moods: !pregnant && o.moods ? recent('mood') : const [],
    symptoms: !pregnant && o.symptoms ? recent('symptoms') : const [],
  );
}

/// Feature data saved under `partner`.
class PartnerState {
  PartnerState({ShareOptions? options, this.code, this.viewed}) : options = options ?? ShareOptions();

  static const storageKey = 'partner';

  ShareOptions options;

  /// The code currently shared, or null when not sharing.
  String? code;

  /// The last code imported in partner view.
  String? viewed;

  Map<String, dynamic> toJson() => {'options': options.toJson(), 'code': code, 'viewed': viewed};

  static PartnerState of(AppStore store) {
    final raw = store.feature<Object>(storageKey);
    if (raw is! Map) return PartnerState();
    final j = Map<String, dynamic>.from(raw);
    return PartnerState(
      options: ShareOptions.fromJson(j['options'] is Map ? Map<String, dynamic>.from(j['options'] as Map) : null),
      code: j['code'] as String?,
      viewed: j['viewed'] as String?,
    );
  }

  void save(AppStore store) => store.setFeature(storageKey, toJson());
}

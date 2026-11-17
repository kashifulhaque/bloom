/// Collects the numbers for the doctor report from the store.
library;

import 'dart:math' as math;

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/units.dart';
import '../reminders/contraception_model.dart';

class ReportCycle {
  ReportCycle({
    required this.start,
    required this.length,
    required this.periodLength,
    required this.ovulationDay,
    required this.currentDay,
  });
  final DateTime start;

  /// Null for the current cycle.
  final int? length;
  final int periodLength;

  /// 1-based cycle day of the estimated ovulation.
  final int ovulationDay;

  /// Day of the current cycle; null for completed cycles.
  final int? currentDay;
}

class CountItem {
  CountItem(this.label, this.count);
  final String label;
  final int count;
}

class ReportData {
  ReportData({
    required this.name,
    required this.age,
    required this.goal,
    required this.cycles,
    required this.avgCycle,
    required this.avgPeriod,
    required this.health,
    required this.topSymptoms,
    required this.topMoods,
    required this.bbtSummary,
    required this.weightSummary,
    required this.notes,
    required this.contraception,
    required this.generated,
    required this.from,
    required this.conditions,
  });

  final String name;
  final int? age;
  final String goal;

  /// Up to six cycles, oldest first, including the current one.
  final List<ReportCycle> cycles;
  final int avgCycle;
  final int avgPeriod;
  final CycleHealth health;
  final List<CountItem> topSymptoms;
  final List<CountItem> topMoods;
  final String? bbtSummary;
  final String? weightSummary;
  final List<(DateTime, String)> notes;
  final String? contraception;
  final DateTime generated;

  /// Start of the reporting window.
  final DateTime from;
  final List<String> conditions;

  int get shortestCycle => cycles.where((c) => c.length != null).map((c) => c.length!).fold(9999, math.min);
  int get longestCycle => cycles.where((c) => c.length != null).map((c) => c.length!).fold(0, math.max);

  String get regularityText {
    if (!health.enoughData) return 'Not enough completed cycles to assess regularity.';
    final parts = [
      health.cycleNormal ? 'cycle lengths within 21-35 days' : 'some cycle lengths outside 21-35 days',
      health.periodNormal ? 'period lengths within 2-7 days' : 'some period lengths outside 2-7 days',
      health.regular
          ? 'regular (variation ${health.variation} days, 7 or less)'
          : 'irregular (variation ${health.variation} days, more than 7)',
    ];
    return '${parts.join('; ')}. Ranges from ACOG guidance.';
  }
}

ReportData buildReportData(AppStore store, {DateTime? now}) {
  final n = dayOf(now ?? DateTime.now());
  final e = store.engine;
  final p = store.profile;

  final recent = e.cycles.length > 6 ? e.cycles.sublist(e.cycles.length - 6) : e.cycles;
  final cycles = [
    for (final c in recent)
      ReportCycle(
        start: c.start,
        length: c.length,
        periodLength: c.period.length,
        ovulationDay: daysBetween(c.start, c.ovulation) + 1,
        currentDay: c.isCurrent ? daysBetween(c.start, n) + 1 : null,
      ),
  ];
  final from = recent.isEmpty ? addDays(n, -180) : recent.first.start;
  final logs = store.logsBetween(from, n);

  List<CountItem> top(String category) {
    final counts = <String, int>{};
    for (final l in logs) {
      for (final o in l.get(category)) {
        counts[o] = (counts[o] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final s in sorted.take(5)) CountItem(optionLabel(category, s.key), s.value)];
  }

  String? bbt;
  final temps = [for (final l in logs) if (l.metrics['bbt'] != null) l.metrics['bbt']!];
  if (temps.isNotEmpty) {
    final avg = temps.reduce((a, b) => a + b) / temps.length;
    bbt = '${temps.length} readings; range ${fmtTemp(temps.reduce(math.min), p.tempUnit)} to '
        '${fmtTemp(temps.reduce(math.max), p.tempUnit)}; average ${fmtTemp(avg, p.tempUnit)}';
  }

  String? weight;
  final weights = [for (final l in logs) if (l.metrics['weight'] != null) (l.date, l.metrics['weight']!)];
  if (weights.isNotEmpty) {
    final first = weights.first, last = weights.last;
    final change = last.$2 - first.$2;
    final changeText = fmtWeight(change.abs(), p.weightUnit);
    weight = weights.length == 1
        ? '${fmtWeight(last.$2, p.weightUnit)} on ${fmtFull(last.$1)}'
        : 'Latest ${fmtWeight(last.$2, p.weightUnit)} (${fmtFull(last.$1)}); '
            '${change >= 0 ? 'up' : 'down'} $changeText since ${fmtFull(first.$1)}';
  }

  final notes = [
    for (final l in logs.reversed)
      if (l.note.trim().isNotEmpty) (l.date, l.note.trim()),
  ].take(10).toList();

  final c = Contraception.of(store);

  return ReportData(
    name: p.name.trim(),
    age: p.birthYear == null ? null : n.year - p.birthYear!,
    goal: p.goal.label,
    cycles: cycles,
    avgCycle: e.avgCycleLength,
    avgPeriod: e.avgPeriodLength,
    health: e.health(),
    topSymptoms: top('symptoms'),
    topMoods: top('mood'),
    bbtSummary: bbt,
    weightSummary: weight,
    notes: notes,
    contraception: c.method == BirthControlMethod.none ? null : '${c.method.label}: ${c.status(n)}',
    generated: n,
    from: from,
    conditions: p.conditions,
  );
}

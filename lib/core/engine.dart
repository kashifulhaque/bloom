/// Cycle math: periods, cycles, averages, predictions, fertile windows.
///
/// The engine is a pure function of the logged period days, the day logs,
/// and the profile. `AppStore` rebuilds it after every change, so widgets
/// read it through `store.engine`.
library;

import 'dart:math' as math;

import 'dates.dart';
import 'models.dart';

/// A run of consecutive period days (gaps of one day are bridged).
class Period {
  Period(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int get length => daysBetween(start, end) + 1;
  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
}

/// One menstrual cycle: from a period start to the day before the next one.
class Cycle {
  Cycle({required this.period, required this.start, this.nextStart, required this.ovulation, this.ovulationDetected = false});
  final Period period;
  final DateTime start;

  /// Start of the following period. Null for the current cycle.
  final DateTime? nextStart;

  /// Estimated or detected ovulation day.
  final DateTime ovulation;

  /// True when [ovulation] comes from an LH test or a BBT shift.
  final bool ovulationDetected;

  bool get isCurrent => nextStart == null;

  /// Length in days. Null for the current cycle.
  int? get length => nextStart == null ? null : daysBetween(start, nextStart!);
  DateTime get fertileStart => addDays(ovulation, -5);
  DateTime get fertileEnd => addDays(ovulation, 1);
}

enum Phase { menstrual, follicular, ovulation, luteal }

extension PhaseLabel on Phase {
  String get label => switch (this) {
        Phase.menstrual => 'Menstrual phase',
        Phase.follicular => 'Follicular phase',
        Phase.ovulation => 'Ovulation phase',
        Phase.luteal => 'Luteal phase',
      };
}

enum Chance { low, medium, high }

extension ChanceLabel on Chance {
  String get label => switch (this) {
        Chance.low => 'Low',
        Chance.medium => 'Medium',
        Chance.high => 'High',
      };
}

/// How a calendar day should be drawn and described.
class DayInfo {
  DayInfo({
    required this.date,
    this.isPeriod = false,
    this.isPredictedPeriod = false,
    this.isFertile = false,
    this.isOvulation = false,
    this.isPredicted = false,
    this.cycleDay,
    this.phase,
    this.chance = Chance.low,
  });
  final DateTime date;

  /// Logged period day.
  final bool isPeriod;
  final bool isPredictedPeriod;
  final bool isFertile;
  final bool isOvulation;

  /// True when fertile/ovulation flags come from a future prediction.
  final bool isPredicted;

  /// 1-based day of the cycle, or null before the first logged period.
  final int? cycleDay;
  final Phase? phase;
  final Chance chance;
}

/// Regularity assessment using ACOG ranges.
class CycleHealth {
  CycleHealth({
    required this.cycleNormal,
    required this.periodNormal,
    required this.regular,
    required this.variation,
    required this.enoughData,
  });
  final bool cycleNormal;
  final bool periodNormal;
  final bool regular;

  /// Longest minus shortest cycle length, in days.
  final int variation;
  final bool enoughData;
}

class CycleEngine {
  CycleEngine({
    required Set<String> periodDays,
    required Map<String, DayLog> logs,
    required this.profile,
    DateTime? now,
  }) : today = dayOf(now ?? DateTime.now()) {
    _logs = logs;
    _periodKeys = periodDays;
    _build(periodDays);
  }

  final Profile profile;
  final DateTime today;
  late final Map<String, DayLog> _logs;
  late final Set<String> _periodKeys;

  /// All logged periods, oldest first.
  final List<Period> periods = [];

  /// All cycles, oldest first. The last one is the current cycle.
  final List<Cycle> cycles = [];

  late int avgCycleLength;
  late int avgPeriodLength;

  /// Lengths of completed cycles used for statistics, oldest first.
  final List<int> cycleLengths = [];

  /// Lengths of completed, non-excluded cycles without the plausibility
  /// filter. Used for the health assessment.
  final List<int> rawCycleLengths = [];

  void _build(Set<String> keys) {
    final days = keys.map(parseDayKey).toList()..sort();
    for (final d in days) {
      if (periods.isNotEmpty && daysBetween(periods.last.end, d) <= 2) {
        periods[periods.length - 1] = Period(periods.last.start, d);
      } else {
        periods.add(Period(d, d));
      }
    }

    // Completed cycle lengths, skipping excluded starts and implausible gaps.
    for (var i = 0; i + 1 < periods.length; i++) {
      final len = daysBetween(periods[i].start, periods[i + 1].start);
      if (profile.excludedCycleStarts.contains(dayKey(periods[i].start))) continue;
      rawCycleLengths.add(len);
      if (len < 15 || len > 90) continue;
      cycleLengths.add(len);
    }
    avgCycleLength = _weightedAverage(cycleLengths, profile.cycleLength);
    final finishedPeriods = periods.where((p) => p.end.isBefore(addDays(today, -1))).map((p) => p.length).toList();
    avgPeriodLength = finishedPeriods.isEmpty
        ? profile.periodLength
        : (finishedPeriods.reversed.take(6).reduce((a, b) => a + b) / math.min(6, finishedPeriods.length)).round();

    for (var i = 0; i < periods.length; i++) {
      final next = i + 1 < periods.length ? periods[i + 1].start : null;
      final expectedNext = next ?? addDays(periods[i].start, avgCycleLength);
      var ov = addDays(expectedNext, -profile.lutealLength);
      final detected = _detectOvulation(periods[i].start, expectedNext);
      if (detected != null) ov = detected;
      if (!ov.isAfter(periods[i].end)) ov = addDays(periods[i].end, 1);
      cycles.add(Cycle(
          period: periods[i], start: periods[i].start, nextStart: next, ovulation: ov, ovulationDetected: detected != null));
    }
  }

  /// Weighted average of the last six values; recent cycles weigh more.
  static int _weightedAverage(List<int> values, int fallback) {
    if (values.isEmpty) return fallback;
    final recent = values.reversed.take(6).toList();
    var sum = 0.0, weights = 0.0;
    for (var i = 0; i < recent.length; i++) {
      final w = (recent.length - i).toDouble();
      sum += recent[i] * w;
      weights += w;
    }
    // Blend with the profile setting while data is scarce.
    if (recent.length < 3) {
      sum += fallback * (3 - recent.length);
      weights += (3 - recent.length);
    }
    return (sum / weights).round();
  }

  /// Ovulation from a positive LH test (ovulation ≈ next day) or a sustained
  /// BBT rise (three temps above the previous six; ovulation = day before).
  DateTime? _detectOvulation(DateTime start, DateTime end) {
    for (var d = start; d.isBefore(end); d = addDays(d, 1)) {
      final log = _logs[dayKey(d)];
      if (log == null) continue;
      if (log.has('ovulation_test', 'positive')) return addDays(d, 1);
      if (log.has('ovulation_test', 'my_method')) return d;
    }
    final temps = <DateTime, double>{};
    for (var d = start; d.isBefore(end); d = addDays(d, 1)) {
      final t = _logs[dayKey(d)]?.metrics['bbt'];
      if (t != null) temps[d] = t;
    }
    final entries = temps.entries.toList();
    for (var i = 6; i + 2 < entries.length; i++) {
      final prev = entries.sublist(i - 6, i).map((e) => e.value).reduce(math.max);
      if (entries[i].value > prev && entries[i + 1].value > prev && entries[i + 2].value > prev + 0.1) {
        return addDays(entries[i].key, -1);
      }
    }
    return null;
  }

  bool get hasData => periods.isNotEmpty;
  Cycle? get currentCycle => cycles.isEmpty ? null : cycles.last;

  /// Predicted start of the next period.
  DateTime? get nextPeriodStart {
    final c = currentCycle;
    if (c == null) return null;
    final byAverage = addDays(c.start, avgCycleLength);
    if (!c.ovulationDetected) return byAverage;
    final byOvulation = addDays(c.ovulation, profile.lutealLength);
    return byOvulation.isAfter(byAverage) ? byOvulation : byAverage;
  }

  /// Days until the next period; negative when the period is late.
  int? get daysUntilNextPeriod => nextPeriodStart == null ? null : daysBetween(today, nextPeriodStart!);

  bool get isLate => (daysUntilNextPeriod ?? 0) < 0 && !isOnPeriod(today);

  int get daysLate => isLate ? -daysUntilNextPeriod! : 0;

  bool isOnPeriod(DateTime d) => _periodKeys.contains(dayKey(d));

  /// Predicted future cycles (starting with the next period).
  List<({DateTime start, DateTime ovulation})> futureCycles(int count) {
    final start = nextPeriodStart;
    if (start == null) return [];
    // When late, roll predictions forward from today.
    final base = start.isBefore(today) ? today : start;
    return [
      for (var i = 0; i < count; i++)
        (
          start: addDays(base, avgCycleLength * i),
          ovulation: addDays(base, avgCycleLength * (i + 1) - profile.lutealLength),
        ),
    ];
  }

  Cycle? cycleFor(DateTime d) {
    for (final c in cycles.reversed) {
      if (!d.isBefore(c.start)) return c;
    }
    return null;
  }

  DayInfo info(DateTime date) {
    final d = dayOf(date);
    final isPeriod = isOnPeriod(d);
    final cycle = cycleFor(d);

    // Days inside a known cycle (past or current, up to its predicted end).
    if (cycle != null) {
      final end = cycle.nextStart ?? nextPeriodStart!;
      if (d.isBefore(end) || (cycle.isCurrent && !d.isAfter(today))) {
        final cd = daysBetween(cycle.start, d) + 1;
        final fertile = !d.isBefore(cycle.fertileStart) && !d.isAfter(cycle.fertileEnd);
        final isOv = sameDay(d, cycle.ovulation);
        return DayInfo(
          date: d,
          isPeriod: isPeriod,
          isFertile: fertile && !isPeriod,
          isOvulation: isOv,
          isPredicted: d.isAfter(today),
          cycleDay: cd,
          phase: _phase(isPeriod || cycle.period.contains(d), fertile, isOv, d.isAfter(cycle.ovulation)),
          chance: _chance(d, cycle.ovulation, isPeriod),
        );
      }
    }

    // Future, predicted cycles.
    if (d.isAfter(today) && hasData) {
      for (final f in futureCycles(14)) {
        final end = addDays(f.start, avgCycleLength);
        if (!d.isBefore(f.start) && d.isBefore(end)) {
          final cd = daysBetween(f.start, d) + 1;
          final predictedPeriod = cd <= avgPeriodLength;
          final fertile = !d.isBefore(addDays(f.ovulation, -5)) && !d.isAfter(addDays(f.ovulation, 1));
          final isOv = sameDay(d, f.ovulation);
          return DayInfo(
            date: d,
            isPredictedPeriod: predictedPeriod,
            isFertile: fertile,
            isOvulation: isOv,
            isPredicted: true,
            cycleDay: cd,
            phase: _phase(predictedPeriod, fertile, isOv, d.isAfter(f.ovulation)),
            chance: _chance(d, f.ovulation, predictedPeriod),
          );
        }
      }
    }
    return DayInfo(date: d, isPeriod: isPeriod);
  }

  Phase _phase(bool period, bool fertile, bool ovulation, bool afterOvulation) {
    if (period) return Phase.menstrual;
    if (ovulation || fertile) return Phase.ovulation;
    if (afterOvulation) return Phase.luteal;
    return Phase.follicular;
  }

  Chance _chance(DateTime d, DateTime ovulation, bool period) {
    if (period) return Chance.low;
    final diff = daysBetween(d, ovulation);
    if (diff >= 0 && diff <= 2) return Chance.high;
    if (diff >= -1 && diff <= 5) return Chance.medium;
    return Chance.low;
  }

  CycleHealth health() {
    final recent = rawCycleLengths.reversed.take(6).toList();
    final periodLens = periods
        .where((p) => p.end.isBefore(addDays(today, -1)))
        .toList()
        .reversed
        .take(6)
        .map((p) => p.length)
        .toList();
    final variation = recent.isEmpty ? 0 : recent.reduce(math.max) - recent.reduce(math.min);
    return CycleHealth(
      cycleNormal: recent.every((l) => l >= 21 && l <= 35),
      periodNormal: periodLens.every((l) => l >= 2 && l <= 7),
      regular: variation <= 7,
      variation: variation,
      enoughData: recent.length >= 2,
    );
  }
}

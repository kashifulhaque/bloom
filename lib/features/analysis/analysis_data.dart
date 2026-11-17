/// Pure statistics for the analysis screen: symptom counts, phase frequency,
/// BBT cover lines, and rule-based pattern detection.
library;

import 'dart:math' as math;

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/models.dart';

/// A logged option, such as `('symptoms', 'headache')`.
typedef OptionRef = ({String category, String option});

String optionRefLabel(OptionRef r) {
  final cat = categoryById(r.category);
  final emoji = cat?.option(r.option)?.emoji;
  return '${emoji == null ? '' : '$emoji '}${optionLabel(r.category, r.option)}';
}

/// Categories counted in symptom and mood statistics.
const statCategories = ['symptoms', 'mood', 'digestion', 'discharge', 'other'];

/// Options that mean "nothing to report" and are left out of statistics.
const _neutralOptions = {'fine'};

/// Start of the window covering the last [n] cycles (including the current one).
DateTime? windowStart(CycleEngine engine, int n) {
  if (engine.cycles.isEmpty) return null;
  final i = math.max(0, engine.cycles.length - n);
  return engine.cycles[i].start;
}

/// Counts how many days each option was logged in [logs], most frequent first.
List<MapEntry<OptionRef, int>> optionCounts(Iterable<DayLog> logs, {Iterable<String> categories = statCategories}) {
  final counts = <OptionRef, int>{};
  for (final log in logs) {
    for (final c in categories) {
      for (final o in log.get(c)) {
        if (_neutralOptions.contains(o)) continue;
        final key = (category: c, option: o);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
  }
  final out = counts.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.option.compareTo(b.key.option));
  return out;
}

/// Phase columns used by the frequency table.
const tablePhases = [Phase.menstrual, Phase.follicular, Phase.ovulation, Phase.luteal];

String phaseShort(Phase p) => switch (p) {
      Phase.menstrual => 'Period',
      Phase.follicular => 'Follicular',
      Phase.ovulation => 'Fertile',
      Phase.luteal => 'Luteal',
    };

/// Option → phase → number of days logged in that phase.
Map<OptionRef, Map<Phase, int>> phaseFrequency(CycleEngine engine, Iterable<DayLog> logs,
    {Iterable<String> categories = statCategories}) {
  final out = <OptionRef, Map<Phase, int>>{};
  for (final log in logs) {
    final phase = engine.info(log.date).phase;
    if (phase == null) continue;
    for (final c in categories) {
      for (final o in log.get(c)) {
        if (_neutralOptions.contains(o)) continue;
        final row = out.putIfAbsent((category: c, option: o), () => {});
        row[phase] = (row[phase] ?? 0) + 1;
      }
    }
  }
  return out;
}

/// The BBT cover line for a cycle: the highest of the six temperatures
/// logged on or before [ovulation]. Null with fewer than three readings.
double? coverLine(Map<DateTime, double> temps, DateTime ovulation) {
  final before = temps.entries.where((e) => !e.key.isAfter(ovulation)).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (before.length < 3) return null;
  return before.reversed.take(6).map((e) => e.value).reduce(math.max);
}

/// BBT readings for [cycle], keyed by day.
Map<DateTime, double> cycleTemps(Cycle cycle, Map<String, DayLog> logs, DateTime end) {
  final out = <DateTime, double>{};
  for (var d = cycle.start; !d.isAfter(end); d = addDays(d, 1)) {
    final t = logs[dayKey(d)]?.metrics['bbt'];
    if (t != null) out[d] = t;
  }
  return out;
}

/// Last day of [cycle]: the day before the next period, or the predicted end.
DateTime cycleEnd(CycleEngine engine, Cycle cycle) {
  if (cycle.nextStart != null) return addDays(cycle.nextStart!, -1);
  final predicted = addDays(cycle.start, engine.avgCycleLength - 1);
  return predicted.isBefore(engine.today) ? engine.today : predicted;
}

enum PatternTone { info, attention }

class PatternInsight {
  const PatternInsight(this.title, this.body, {this.tone = PatternTone.info, this.icon = '🔎'});
  final String title;
  final String body;
  final PatternTone tone;
  final String icon;
}

/// Rule-based observations from the user's own history.
List<PatternInsight> detectPatterns(CycleEngine engine, Map<String, DayLog> logs) {
  final out = <PatternInsight>[];
  final completed = engine.cycles.where((c) => !c.isCurrent).toList();

  // Options logged in the five days before a period, in most of the last cycles.
  final recent = completed.reversed.take(4).toList();
  if (recent.length >= 3) {
    final hits = <OptionRef, int>{};
    for (final c in recent) {
      final seen = <OptionRef>{};
      for (var i = 1; i <= 5; i++) {
        final log = logs[dayKey(addDays(c.nextStart!, -i))];
        if (log == null) continue;
        for (final cat in const ['symptoms', 'mood', 'digestion']) {
          for (final o in log.get(cat)) {
            if (!_neutralOptions.contains(o)) seen.add((category: cat, option: o));
          }
        }
      }
      for (final s in seen) {
        hits[s] = (hits[s] ?? 0) + 1;
      }
    }
    final strong = hits.entries.where((e) => e.value >= 3 || e.value == recent.length).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in strong.take(3)) {
      out.add(PatternInsight(
        '${optionLabel(e.key.category, e.key.option)} before your period',
        '${optionLabel(e.key.category, e.key.option)} was logged in the 5 days before your period '
            'in ${e.value} of the last ${recent.length} cycles. Knowing this can help you plan ahead.',
        icon: categoryById(e.key.category)?.option(e.key.option)?.emoji ?? '🔁',
      ));
    }
  }

  // Trend in cycle length.
  final lens = engine.cycleLengths;
  if (lens.length >= 6) {
    final last = lens.sublist(lens.length - 3);
    final prev = lens.sublist(lens.length - 6, lens.length - 3);
    final a = prev.reduce((x, y) => x + y) / 3, b = last.reduce((x, y) => x + y) / 3;
    if (b - a >= 3) {
      out.add(PatternInsight('Your cycles have become longer',
          'Your last 3 cycles averaged ${b.round()} days, up from ${a.round()} days before.',
          icon: '📈'));
    } else if (a - b >= 3) {
      out.add(PatternInsight('Your cycles have become shorter',
          'Your last 3 cycles averaged ${b.round()} days, down from ${a.round()} days before.',
          icon: '📉'));
    }
  }

  // Cycle length outside the typical range.
  final outOfRange = lens.reversed.take(6).where((l) => l < 21 || l > 35).toList();
  if (outOfRange.isNotEmpty) {
    out.add(PatternInsight(
      'Cycle length outside the typical range',
      '${outOfRange.length} of your recent cycles lasted fewer than 21 or more than 35 days '
          '(${outOfRange.join(', ')} days). If this keeps happening, consider talking to a clinician.',
      tone: PatternTone.attention,
      icon: '⚠️',
    ));
  }

  // Long periods.
  final longPeriods = engine.periods.reversed.take(6).where((p) => p.length > 7).toList();
  if (longPeriods.isNotEmpty) {
    final p = longPeriods.first;
    out.add(PatternInsight(
      'Period longer than 7 days',
      'Your period starting ${fmtShort(p.start)} lasted ${p.length} days. Periods that often last '
          'more than 7 days are worth mentioning to a clinician.',
      tone: PatternTone.attention,
      icon: '🩸',
    ));
  }

  // Irregular cycles.
  final health = engine.health();
  if (health.enoughData && !health.regular) {
    out.add(PatternInsight(
      'Cycle lengths vary a lot',
      'Your recent cycle lengths differ by ${health.variation} days. A difference of more than '
          '7 days is often described as irregular.',
      tone: PatternTone.attention,
      icon: '〰️',
    ));
  }

  // Spotting outside of a period.
  final spotting = logs.values
      .where((l) => l.has('flow', 'spotting') && !engine.isOnPeriod(l.date))
      .where((l) => daysBetween(l.date, engine.today) <= 180)
      .length;
  if (spotting >= 2) {
    out.add(PatternInsight(
      'Spotting between periods',
      'You logged spotting outside your period on $spotting days in the last 6 months.',
      tone: PatternTone.attention,
      icon: '💧',
    ));
  }

  if (engine.isLate) {
    out.add(PatternInsight(
      'Your period is ${engine.daysLate} ${engine.daysLate == 1 ? 'day' : 'days'} late',
      'Stress, travel, illness, and changes in routine can all delay a period. '
          'If you might be pregnant, a pregnancy test can help.',
      tone: PatternTone.attention,
      icon: '⏰',
    ));
  }
  return out;
}

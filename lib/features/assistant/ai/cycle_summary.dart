/// The short, de-identified cycle summary that AI answers can include.
///
/// It holds only coarse facts: the goal, the cycle day and phase, averages,
/// regularity, days late, the pregnancy week, the most-logged symptoms and
/// moods of the last 30 days, and a five-year age bracket. It never holds
/// the name, notes, journal entries, the exact birth year, or any dates.
library;

import '../../../core/catalog.dart';
import '../../../core/dates.dart';
import '../../../core/engine.dart';
import '../../../core/models.dart';
import '../../../core/store.dart';
import '../../modes/pregnancy_math.dart';
import '../scripts.dart' show topOptions;

/// A five-year age bracket, such as `30-34`, or `under 15`.
String ageBracket(int age) {
  if (age < 15) return 'under 15';
  final lo = age ~/ 5 * 5;
  return '$lo-${lo + 4}';
}

String _days(int n) => '$n day${n == 1 ? '' : 's'}';

/// Builds the summary text for [store], one fact per line.
String buildCycleSummary(AppStore store) {
  final e = store.engine;
  final p = store.profile;
  final lines = <String>['Goal: ${p.goal.label}'];

  final pregnancy = p.goal == Goal.trackPregnancy ? readPregnancy(store) : null;
  if (pregnancy != null) {
    final ga = gestationalAge(pregnancy.lmp, e.today);
    lines.add('Pregnancy: week ${ga.weeks} (${trimesterLabel(ga.trimester).toLowerCase()})');
  } else if (e.hasData) {
    final info = e.info(e.today);
    if (info.cycleDay != null) {
      lines.add('Cycle day: ${info.cycleDay}${info.phase == null ? '' : ' (${info.phase!.label.toLowerCase()})'}');
    }
    if (e.isLate) lines.add('Period late by: ${_days(e.daysLate)}');
  } else {
    lines.add('Cycle: no periods logged yet');
  }

  if (e.hasData) {
    lines.add('Average cycle: ${_days(e.avgCycleLength)}');
    lines.add('Average period: ${_days(e.avgPeriodLength)}');
    final h = e.health();
    if (!h.enoughData) {
      lines.add('Regularity: not enough cycles logged to tell');
    } else {
      final notes = [
        h.regular ? 'regular' : 'irregular',
        'lengths vary by ${_days(h.variation)}',
        if (!h.cycleNormal) 'some cycles outside 21-35 days',
        if (!h.periodNormal) 'some periods outside 2-7 days',
      ];
      lines.add('Regularity: ${notes.join(', ')}');
    }
  }

  final top = topOptions(
    store.logsBetween(addDays(e.today, -29), e.today),
    const ['symptoms', 'mood', 'digestion'],
  );
  if (top.isNotEmpty) {
    lines.add('Most logged in the last 30 days: '
        '${[for (final t in top) '${optionLabel(t.$1, t.$2).toLowerCase()} (${_days(t.$3)})'].join(', ')}');
  }

  if (p.birthYear != null) lines.add('Age: ${ageBracket(e.today.year - p.birthYear!)}');
  return lines.join('\n');
}

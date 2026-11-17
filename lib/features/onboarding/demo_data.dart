/// Generates about eight months of realistic sample data for testing.
library;

import 'dart:math' as math;

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';

/// Replaces all cycle data in [store] with about eight months of sample
/// cycles and daily logs, and marks onboarding as done.
///
/// Cycles vary from 26 to 31 days and periods from 4 to 6 days. Logs include
/// flow, symptoms, moods, discharge, a biphasic basal temperature, weight,
/// sleep, water, steps, energy, and a positive ovulation test in some cycles.
/// Pass [seed] for repeatable output.
void loadDemoData(AppStore store, {int? seed}) {
  final rnd = math.Random(seed);
  final now = today();
  final first = addDays(now, -240);

  store.periodDays.clear();
  store.logs.clear();

  // Cycle starts from about eight months ago up to today.
  final starts = <DateTime>[];
  for (var d = first; !d.isAfter(now); d = addDays(d, 26 + rnd.nextInt(6))) {
    starts.add(d);
  }

  final logs = <String, DayLog>{};
  DayLog logAt(DateTime d) => logs.putIfAbsent(dayKey(d), () => DayLog(d));
  void pick(DateTime d, String cat, String opt) =>
      logAt(d).selections.putIfAbsent(cat, () => {}).add(opt);
  T any<T>(List<T> xs) => xs[rnd.nextInt(xs.length)];

  var weight = 61.0 + rnd.nextDouble() * 3;

  for (var c = 0; c < starts.length; c++) {
    final start = starts[c];
    final isLast = c == starts.length - 1;
    final nextStart = isLast ? addDays(start, 28) : starts[c + 1];
    final cycleLen = daysBetween(start, nextStart);
    final ovulation = addDays(nextStart, -14 + rnd.nextInt(3) - 1);
    final periodLen = 4 + rnd.nextInt(3);
    final usesLhTests = rnd.nextDouble() < 0.5;
    final baseTemp = 36.25 + rnd.nextDouble() * 0.1;

    for (var i = 0; i < cycleLen; i++) {
      final d = addDays(start, i);
      if (d.isAfter(now)) break;
      final toOv = daysBetween(d, ovulation);
      final toNext = daysBetween(d, nextStart);

      // Period and flow.
      if (i < periodLen) {
        store.periodDays.add(dayKey(d));
        final flow = switch (i) {
          0 => rnd.nextBool() ? 'medium' : 'heavy',
          1 => 'heavy',
          2 => 'medium',
          _ => i == periodLen - 1 ? 'spotting' : 'light',
        };
        pick(d, 'flow', flow);
        pick(d, 'products', i < 3 ? any(['pad', 'tampon', 'cup']) : 'liner');
        if (i < 2) pick(d, 'symptoms', 'cramps');
        if (i < 2 && rnd.nextDouble() < 0.4) pick(d, 'symptoms', any(['backache', 'fatigue', 'headache']));
        if (i == 1 && rnd.nextDouble() < 0.3) pick(d, 'clots', 'clots');
        if (rnd.nextDouble() < 0.4) pick(d, 'mood', any(['low_energy', 'sad', 'calm', 'irritated']));
      } else if (toOv >= -1 && toOv <= 2) {
        // Around ovulation.
        if (rnd.nextDouble() < 0.7) pick(d, 'discharge', 'egg_white');
        if (rnd.nextDouble() < 0.5) pick(d, 'mood', any(['energetic', 'frisky', 'happy']));
        if (rnd.nextDouble() < 0.4) pick(d, 'sex', 'high_drive');
      } else if (toNext <= 4 && toNext > 0) {
        // Premenstrual days.
        if (rnd.nextDouble() < 0.6) {
          final s = any(['bloating', 'tender_breasts', 'acne', 'cravings', 'headache']);
          pick(d, s == 'bloating' ? 'digestion' : 'symptoms', s);
        }
        if (rnd.nextDouble() < 0.5) pick(d, 'mood', any(['irritated', 'swings', 'anxious', 'sad']));
        if (rnd.nextDouble() < 0.4) pick(d, 'discharge', 'creamy');
      } else {
        if (rnd.nextDouble() < 0.3) pick(d, 'mood', any(['calm', 'happy', 'energetic']));
        if (rnd.nextDouble() < 0.2) pick(d, 'symptoms', 'fine');
        if (rnd.nextDouble() < 0.25) pick(d, 'discharge', toOv > 0 ? 'sticky' : 'creamy');
        if (rnd.nextDouble() < 0.08) pick(d, 'digestion', any(['bloating', 'constipation', 'gas']));
      }

      // Ovulation tests in some cycles: negatives, then a positive the day
      // before ovulation.
      if (usesLhTests && toOv >= 1 && toOv <= 4) {
        pick(d, 'ovulation_test', toOv == 1 ? 'positive' : 'negative');
      }

      // Sex and activity.
      if (i >= periodLen && rnd.nextDouble() < 0.12) pick(d, 'sex', any(['protected', 'unprotected']));
      if (rnd.nextDouble() < 0.35) pick(d, 'activity', any(['walking', 'yoga', 'gym', 'running', 'cycling']));

      // Basal body temperature with a biphasic shift after ovulation.
      if (rnd.nextDouble() < 0.85) {
        final shift = toOv < 0 ? 0.35 : 0.0;
        final t = baseTemp + shift + (rnd.nextDouble() - 0.5) * 0.14;
        logAt(d).metrics['bbt'] = double.parse(t.toStringAsFixed(2));
      }

      // Weight every few days, slightly higher before the period.
      weight += (rnd.nextDouble() - 0.5) * 0.08;
      if (rnd.nextDouble() < 0.35) {
        final w = weight + (toNext <= 5 ? 0.6 : 0);
        logAt(d).metrics['weight'] = double.parse(w.toStringAsFixed(1));
      }

      if (rnd.nextDouble() < 0.75) logAt(d).metrics['sleep'] = 5.5 + rnd.nextInt(7) * 0.5;
      if (rnd.nextDouble() < 0.7) logAt(d).metrics['water'] = 1000.0 + rnd.nextInt(7) * 250;
      if (rnd.nextDouble() < 0.4) logAt(d).metrics['steps'] = 3000.0 + rnd.nextInt(19) * 500;
      if (rnd.nextDouble() < 0.4) {
        logAt(d).metrics['energy'] = (i < periodLen || toNext <= 2 ? 1 + rnd.nextInt(3) : 3 + rnd.nextInt(3)).toDouble();
      }
      if (rnd.nextDouble() < 0.04) {
        logAt(d).note = any([
          'Long day at work.',
          'Felt great after a walk.',
          'Slept badly.',
          'Busy weekend.',
          'Started a new book.',
        ]);
      }
    }
  }

  store.logs.addAll(logs);
  store.profile
    ..goal = Goal.trackCycle
    ..name = store.profile.name.isEmpty ? 'Alex' : store.profile.name
    ..birthYear = store.profile.birthYear ?? now.year - 29
    ..cycleLength = 28
    ..periodLength = 5
    ..irregular = false
    ..onboarded = true;
  store.features['onboarding'] = {'birthControl': 'none', 'demo': true};
  store.commit();
}

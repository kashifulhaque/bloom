import 'package:bloom/core/dates.dart';
import 'package:bloom/core/engine.dart';
import 'package:bloom/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Period days for runs of [len] days starting on each of [starts].
Set<String> periodsAt(List<DateTime> starts, {int len = 5}) => {
      for (final s in starts)
        for (var i = 0; i < len; i++) dayKey(addDays(s, i)),
    };

CycleEngine engineFor(
  Set<String> days, {
  required DateTime now,
  Map<String, DayLog>? logs,
  Profile? profile,
}) =>
    CycleEngine(periodDays: days, logs: logs ?? {}, profile: profile ?? Profile(), now: now);

/// Starts [count] periods every [gap] days from [first].
List<DateTime> regular(DateTime first, int count, int gap) => [for (var i = 0; i < count; i++) addDays(first, gap * i)];

void main() {
  final jan1 = DateTime(2026, 1, 1);

  group('period grouping', () {
    test('consecutive days form one period', () {
      final e = engineFor(periodsAt([jan1]), now: DateTime(2026, 1, 20));
      expect(e.periods, hasLength(1));
      expect(e.periods.single.length, 5);
    });

    test('a one-day gap is bridged', () {
      final days = {...periodsAt([jan1], len: 3), dayKey(DateTime(2026, 1, 5))};
      final e = engineFor(days, now: DateTime(2026, 1, 20));
      expect(e.periods, hasLength(1));
      expect(e.periods.single.end, DateTime(2026, 1, 5));
      expect(e.periods.single.length, 5);
    });

    test('a two-day gap starts a new period', () {
      final days = {...periodsAt([jan1], len: 3), dayKey(DateTime(2026, 1, 6))};
      final e = engineFor(days, now: DateTime(2026, 1, 20));
      expect(e.periods, hasLength(2));
    });

    test('no data', () {
      final e = engineFor({}, now: jan1);
      expect(e.hasData, isFalse);
      expect(e.nextPeriodStart, isNull);
      expect(e.daysUntilNextPeriod, isNull);
      expect(e.isLate, isFalse);
      expect(e.futureCycles(3), isEmpty);
      expect(e.avgCycleLength, 28);
      expect(e.avgPeriodLength, 5);
      final info = e.info(jan1);
      expect(info.cycleDay, isNull);
      expect(info.isPeriod, isFalse);
    });
  });

  group('averages', () {
    test('regular 28-day cycles average 28', () {
      final starts = regular(jan1, 4, 28);
      final e = engineFor(periodsAt(starts), now: addDays(starts.last, 3));
      expect(e.cycleLengths, [28, 28, 28]);
      expect(e.avgCycleLength, 28);
      expect(e.avgPeriodLength, 5);
      expect(e.cycles, hasLength(4));
      expect(e.cycles.last.isCurrent, isTrue);
      expect(e.cycles.first.length, 28);
    });

    test('recent cycles weigh more', () {
      // Lengths 26, 30, 30 → weights 1, 2, 3 → (26 + 60 + 90) / 6 = 29.33.
      final starts = [jan1, addDays(jan1, 26), addDays(jan1, 56), addDays(jan1, 86)];
      final e = engineFor(periodsAt(starts), now: addDays(starts.last, 2));
      expect(e.cycleLengths, [26, 30, 30]);
      expect(e.avgCycleLength, 29);
    });

    test('blends with the profile while data is scarce', () {
      // One 26-day cycle and a 30-day setting: (26 + 30 * 2) / 3 = 28.67.
      final starts = [jan1, addDays(jan1, 26)];
      final e = engineFor(periodsAt(starts), now: addDays(starts.last, 2), profile: Profile(cycleLength: 30));
      expect(e.avgCycleLength, 29);
    });

    test('uses the profile length without completed cycles', () {
      final e = engineFor(periodsAt([jan1]), now: addDays(jan1, 2), profile: Profile(cycleLength: 31));
      expect(e.avgCycleLength, 31);
      expect(e.nextPeriodStart, addDays(jan1, 31));
    });

    test('average period length uses finished periods only', () {
      final starts = regular(jan1, 3, 28);
      final days = {...periodsAt(starts.take(2).toList(), len: 4), ...periodsAt([starts.last], len: 2)};
      // The last period is still in progress (today is its 2nd day).
      final e = engineFor(days, now: addDays(starts.last, 1));
      expect(e.avgPeriodLength, 4);
    });

    test('excluded cycles and implausible gaps are left out', () {
      final starts = [jan1, addDays(jan1, 28), addDays(jan1, 28 + 60), addDays(jan1, 28 + 60 + 28)];
      final e = engineFor(
        periodsAt(starts),
        now: addDays(starts.last, 2),
        profile: Profile(excludedCycleStarts: [dayKey(starts[1])]),
      );
      expect(e.cycleLengths, [28, 28]);

      final tooLong = [jan1, addDays(jan1, 120), addDays(jan1, 148)];
      final e2 = engineFor(periodsAt(tooLong), now: addDays(tooLong.last, 2));
      expect(e2.cycleLengths, [28]);
    });
  });

  group('predictions', () {
    final starts = regular(jan1, 4, 28);
    final last = starts.last;

    test('next period is the last start plus the average', () {
      final e = engineFor(periodsAt(starts), now: addDays(last, 10));
      expect(e.nextPeriodStart, addDays(last, 28));
      expect(e.daysUntilNextPeriod, 18);
      expect(e.isLate, isFalse);
      expect(e.daysLate, 0);
    });

    test('late detection', () {
      final e = engineFor(periodsAt(starts), now: addDays(last, 31));
      expect(e.daysUntilNextPeriod, -3);
      expect(e.isLate, isTrue);
      expect(e.daysLate, 3);
      // Predictions roll forward from today while late.
      expect(e.futureCycles(1).single.start, addDays(last, 31));
    });

    test('not late while on a period', () {
      final days = {...periodsAt(starts), dayKey(addDays(last, 31))};
      final e = engineFor(days, now: addDays(last, 31));
      expect(e.isLate, isFalse);
    });

    test('future cycles repeat the average', () {
      final e = engineFor(periodsAt(starts), now: addDays(last, 3));
      final f = e.futureCycles(3);
      expect(f.map((c) => c.start), [addDays(last, 28), addDays(last, 56), addDays(last, 84)]);
      expect(f.first.ovulation, addDays(last, 28 + 28 - 14));
    });

    test('estimated ovulation and fertile window', () {
      final e = engineFor(periodsAt(starts), now: addDays(last, 3));
      final c = e.currentCycle!;
      expect(c.ovulation, addDays(last, 14));
      expect(c.fertileStart, addDays(last, 9));
      expect(c.fertileEnd, addDays(last, 15));
      // Past cycle: ovulation 14 days before the next period.
      expect(e.cycles.first.ovulation, addDays(starts[1], -14));
    });

    test('positive LH test sets ovulation to the next day', () {
      final lh = addDays(last, 11);
      final logs = {
        dayKey(lh): DayLog(lh, selections: {
          'ovulation_test': {'positive'},
        }),
      };
      final e = engineFor(periodsAt(starts), now: addDays(last, 13), logs: logs);
      expect(e.currentCycle!.ovulation, addDays(last, 12));
      expect(e.info(addDays(last, 12)).isOvulation, isTrue);
      expect(e.info(addDays(last, 7)).isFertile, isTrue);
      expect(e.info(addDays(last, 6)).isFertile, isFalse);
    });

    test('a sustained BBT rise sets ovulation to the day before it', () {
      final logs = <String, DayLog>{};
      for (var i = 5; i < 22; i++) {
        final d = addDays(last, i);
        // Low phase 36.40, shift to 36.80 on cycle day 17 (index 16).
        logs[dayKey(d)] = DayLog(d, metrics: {'bbt': i < 16 ? 36.4 : 36.8});
      }
      final e = engineFor(periodsAt(starts), now: addDays(last, 22), logs: logs);
      expect(e.currentCycle!.ovulation, addDays(last, 15));
    });
  });

  group('info', () {
    final starts = regular(jan1, 4, 28);
    final last = starts.last;
    final e = engineFor(periodsAt(starts), now: addDays(last, 3));

    test('logged period day', () {
      final i = e.info(addDays(last, 1));
      expect(i.isPeriod, isTrue);
      expect(i.cycleDay, 2);
      expect(i.phase, Phase.menstrual);
      expect(i.chance, Chance.low);
      expect(i.isPredicted, isFalse);
    });

    test('ovulation day in the current cycle', () {
      final i = e.info(addDays(last, 14));
      expect(i.isOvulation, isTrue);
      expect(i.isFertile, isTrue);
      expect(i.isPredicted, isTrue);
      expect(i.phase, Phase.ovulation);
      expect(i.chance, Chance.high);
    });

    test('follicular and luteal days', () {
      expect(e.info(addDays(last, 6)).phase, Phase.follicular);
      expect(e.info(addDays(last, 20)).phase, Phase.luteal);
      expect(e.info(addDays(last, 20)).chance, Chance.low);
    });

    test('predicted next period', () {
      final next = addDays(last, 28);
      final i = e.info(next);
      expect(i.isPredictedPeriod, isTrue);
      expect(i.isPeriod, isFalse);
      expect(i.cycleDay, 1);
      expect(e.info(addDays(next, 4)).isPredictedPeriod, isTrue);
      expect(e.info(addDays(next, 5)).isPredictedPeriod, isFalse);
      expect(e.info(addDays(next, 14)).isOvulation, isTrue);
    });

    test('days before the first period have no cycle day', () {
      final i = e.info(addDays(jan1, -3));
      expect(i.cycleDay, isNull);
      expect(i.phase, isNull);
    });
  });

  group('health', () {
    test('regular normal cycles', () {
      final starts = regular(jan1, 4, 28);
      final h = engineFor(periodsAt(starts), now: addDays(starts.last, 10)).health();
      expect(h.enoughData, isTrue);
      expect(h.cycleNormal, isTrue);
      expect(h.periodNormal, isTrue);
      expect(h.regular, isTrue);
      expect(h.variation, 0);
    });

    test('long cycle and high variation', () {
      final starts = [jan1, addDays(jan1, 26), addDays(jan1, 26 + 40), addDays(jan1, 26 + 40 + 28)];
      final h = engineFor(periodsAt(starts), now: addDays(starts.last, 10)).health();
      expect(h.cycleNormal, isFalse);
      expect(h.variation, 14);
      expect(h.regular, isFalse);
    });

    test('long period', () {
      final starts = regular(jan1, 3, 28);
      final h = engineFor(periodsAt(starts, len: 9), now: addDays(starts.last, 15)).health();
      expect(h.periodNormal, isFalse);
    });

    test('not enough data', () {
      final h = engineFor(periodsAt([jan1]), now: addDays(jan1, 10)).health();
      expect(h.enoughData, isFalse);
    });
  });
}

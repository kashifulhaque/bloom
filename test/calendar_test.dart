import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/analysis/analysis_screen.dart';
import 'package:bloom/features/calendar/calendar_screen.dart';
import 'package:bloom/features/calendar/edit_period_screen.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Six regular-ish cycles ending with a period that started 10 days ago,
/// plus symptoms before each period, BBT, weight, sleep, and a note.
AppStore demoStore({Goal goal = Goal.trackCycle}) {
  final store = AppStore.memory(profile: Profile(onboarded: true, goal: goal));
  final now = today();
  final lengths = [29, 27, 30, 28, 31, 28];
  var start = addDays(now, -10);
  final starts = <DateTime>[start];
  for (final l in lengths) {
    start = addDays(start, -l);
    starts.insert(0, start);
  }
  for (final s in starts) {
    for (var i = 0; i < 5; i++) {
      store.setPeriodDay(addDays(s, i), true);
    }
    for (var i = 1; i <= 3; i++) {
      final d = addDays(s, -i);
      store.saveLog(DayLog(d, selections: {
        'symptoms': {'headache', 'cramps'},
        'mood': {'irritated'},
      }));
    }
  }
  for (var i = 0; i < 40; i++) {
    final d = addDays(now, -i);
    final log = store.logFor(d).copy();
    log.metrics['bbt'] = i > 25 ? 36.4 : 36.7;
    log.metrics['weight'] = 60 + (i % 5) * 0.2;
    log.metrics['sleep'] = 7 + (i % 3) * 0.5;
    if (i == 2) log.note = 'Felt great today';
    store.saveLog(log);
  }
  return store;
}

Widget wrap(AppStore store, Widget child) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
    );

void main() {
  testWidgets('CalendarScreen renders month view, day details, and year view', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = demoStore();
    await tester.pumpWidget(wrap(store, const CalendarScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Predicted period'), findsWidgets);
    // Day details for today are shown by default.
    expect(find.text(fmtLong(today())), findsOneWidget);
    expect(find.textContaining('Cycle day 11'), findsOneWidget);

    // Select the first of the month and check the panel follows.
    final first = DateTime(today().year, today().month, 1);
    await tester.tap(find.byKey(ValueKey('day-${dayKey(first)}')));
    await tester.pumpAndSettle();
    expect(find.text(fmtLong(first)), findsOneWidget);

    // Swipe to the previous month.
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    // Year view and back.
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('January'), findsOneWidget);
    await tester.tap(find.text('March'));
    await tester.pumpAndSettle();
    expect(find.textContaining('March'), findsWidgets);

    await tester.tap(find.text('Today').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mark period day from the day panel', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = AppStore.memory(profile: Profile(onboarded: true));
    await tester.pumpWidget(wrap(store, const CalendarScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Log a period to see predictions'), findsOneWidget);
    await tester.tap(find.text('Mark period day'));
    await tester.pumpAndSettle();
    expect(store.isPeriodDay(today()), isTrue);
    expect(find.text('Unmark period day'), findsOneWidget);
  });

  testWidgets('Pregnancy mode tints days after the LMP', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = demoStore(goal: Goal.trackPregnancy);
    store.setFeature('pregnancy', {'lmp': dayKey(addDays(today(), -10))});
    await tester.pumpWidget(wrap(store, const CalendarScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Pregnancy'), findsWidgets);
    expect(find.textContaining('Pregnancy week 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('EditPeriodScreen toggles and saves days', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = AppStore.memory(profile: Profile(onboarded: true));
    await tester.pumpWidget(wrap(
      store,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditPeriodScreen())),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final day = today();
    await tester.tap(find.byKey(ValueKey('edit-${dayKey(day)}')));
    await tester.pump();
    // Days far in the future can't be selected.
    expect(store.periodDays, isEmpty);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.isPeriodDay(day), isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  for (final width in [360.0, 1200.0]) {
    testWidgets('AnalysisScreen renders every tab at ${width.toInt()} px', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = demoStore();
      await tester.pumpWidget(wrap(store, const AnalysisScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Regularity'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cycle history'), 300, scrollable: find.byType(Scrollable).at(1));
      expect(find.text('Cycle history'), findsOneWidget);

      await tester.tap(find.text('Charts'));
      await tester.pumpAndSettle();
      expect(find.text('Cycle length'), findsWidgets);
      expect(find.text('Basal body temperature'), findsOneWidget);

      await tester.tap(find.text('Symptoms'));
      await tester.pumpAndSettle();
      expect(find.text('Top symptoms'), findsOneWidget);
      expect(find.textContaining('Headache'), findsWidgets);

      await tester.tap(find.text('Patterns'));
      await tester.pumpAndSettle();
      expect(find.text('Headache before your period'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AnalysisScreen excludes a cycle from averages', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = demoStore();
    await tester.pumpWidget(wrap(store, const AnalysisScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cycle options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exclude from averages'));
    await tester.pumpAndSettle();
    expect(store.profile.excludedCycleStarts, hasLength(1));
  });

  testWidgets('AnalysisScreen shows empty states without data', (tester) async {
    final store = AppStore.memory(profile: Profile(onboarded: true));
    await tester.pumpWidget(wrap(store, const AnalysisScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Log your period'), findsOneWidget);
    for (final tab in ['Charts', 'Symptoms', 'Patterns']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('No patterns yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

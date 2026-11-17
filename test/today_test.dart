import 'package:bloom/core/catalog.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/log/log_sheet.dart';
import 'package:bloom/features/onboarding/demo_data.dart';
import 'package:bloom/features/onboarding/onboarding_screen.dart';
import 'package:bloom/features/today/today_screen.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Widget _wrap(AppStore store, Widget child) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
    );

void main() {
  test('loadDemoData produces more than five periods', () {
    final store = AppStore.memory();
    loadDemoData(store, seed: 1);
    expect(store.engine.periods.length, greaterThan(5));
    expect(store.profile.onboarded, isTrue);
    expect(store.logs.length, greaterThan(100));
    expect(store.feature<Map>('onboarding')?['birthControl'], 'none');
    final h = store.engine.health();
    expect(h.enoughData, isTrue);
  });

  test('loadDemoData only logs options that exist in the catalog', () {
    final store = AppStore.memory();
    loadDemoData(store, seed: 1);
    for (final log in store.logs.values) {
      for (final e in log.selections.entries) {
        final cat = categoryById(e.key);
        expect(cat, isNotNull, reason: 'unknown category ${e.key}');
        for (final o in e.value) {
          expect(cat!.option(o), isNotNull, reason: 'unknown option ${e.key}/$o');
        }
      }
    }
  });

  testWidgets('Log summary shows catalog labels and emoji', (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore.memory();
    final now = DateTime.now();
    store.toggleOption(now, 'symptoms', 'fine');
    store.toggleOption(now, 'mood', 'happy');
    await tester.pumpWidget(_wrap(store, const TodayScreen()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Everything is fine'), findsOneWidget);
    expect(find.text('👍'), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('fine'), findsNothing);
    expect(find.text('•'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('TodayScreen has no floating action button', (tester) async {
    final store = AppStore.memory();
    loadDemoData(store, seed: 1);
    await tester.pumpWidget(_wrap(store, const TodayScreen()));
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  for (final goal in Goal.values) {
    testWidgets('TodayScreen renders with demo data for ${goal.name}', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = AppStore.memory();
      loadDemoData(store, seed: 2);
      store.profile.goal = goal;
      store.commit();
      await tester.pumpWidget(_wrap(store, const TodayScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TodayScreen), findsOneWidget);
      // Flush the store's save timer.
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('TodayScreen renders at 360 px with no data and when late', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore.memory();
    await tester.pumpWidget(_wrap(store, const TodayScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Log your period'), findsOneWidget);

    // A period 40 days ago makes the next period late.
    store.startPeriod(DateTime.now().subtract(const Duration(days: 40)), length: 5);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(store.engine.isLate, isTrue);
    expect(find.textContaining('late'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Log sheet opens and toggles an option', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore.memory();
    final day = DateTime(2026, 1, 10);
    await tester.pumpWidget(_wrap(
      store,
      Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () => showLogSheet(c, day), child: const Text('open')))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Period day'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'cramps');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cramps'));
    await tester.pumpAndSettle();
    expect(store.logFor(day).has('symptoms', 'cramps'), isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Onboarding demo button marks onboarded', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = AppStore.memory();
    await tester.pumpWidget(_wrap(store, const OnboardingScreen()));
    await tester.ensureVisible(find.text('Load demo data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load demo data'));
    await tester.pump();
    expect(store.profile.onboarded, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });
}

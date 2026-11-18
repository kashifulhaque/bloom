// Widget tests of the import flow: source, guide, file, preview, merge, and
// summary, with the file picker replaced by a fixture.
import 'dart:io';
import 'dart:typed_data';

import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/import/import_file.dart';
import 'package:bloom/features/import/import_platform.dart';
import 'package:bloom/features/import/import_screen.dart';
import 'package:bloom/features/onboarding/onboarding_screen.dart';
import 'package:bloom/features/settings/my_data_screen.dart';
import 'package:bloom/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Widget wrap(AppStore store, Widget child) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
    );

ImportPicker pickerFor(String fixture) => () async => PickedImportFile(
      BytesImportFile(fixture, File('test/import/fixtures/$fixture').readAsBytesSync()),
    );

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
  await settle(tester);
}

void main() {
  testWidgets('imports a Clue export into an empty Bloom', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    final store = AppStore.memory(profile: Profile(onboarded: true));
    await tester.pumpWidget(wrap(store, ImportScreen(picker: pickerFor('clue_measurements.json'))));

    expect(find.text('Coming from another app?'), findsOneWidget);
    await tapText(tester, 'Clue');
    expect(find.text('From Clue'), findsOneWidget);
    expect(find.textContaining('Download my data'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Choose file'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    expect(find.text('What Bloom found'), findsOneWidget);
    expect(find.text('CLUE EXPORT'), findsOneWidget);
    expect(find.text('Pain: ovulation'), findsOneWidget);
    // Nothing in Bloom yet, so there's no merge choice.
    expect(find.text('Replace everything'), findsNothing);
    expect(store.periodDays, isEmpty, reason: 'nothing changes before the user confirms');

    await tester.ensureVisible(find.byKey(const ValueKey('import-apply')));
    await tester.tap(find.byKey(const ValueKey('import-apply')));
    await settle(tester);

    expect(find.text('Your history is here'), findsOneWidget);
    expect(store.periodDays, containsAll(['2024-02-01', '2024-02-02', '2024-02-03', '2024-03-01']));
    expect(store.logs['2024-02-14']!.metrics['bbt'], 36.55);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('replace needs a typed confirmation', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    final store = AppStore.memory(profile: Profile(onboarded: true));
    store.saveLog(DayLog(parseDayKey('2023-05-05'), note: 'Keep me?'));
    await tester.pumpWidget(wrap(store, ImportScreen(picker: pickerFor('drip_export.csv'))));

    await tapText(tester, 'drip');
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose file'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    expect(find.text('Add to my data'), findsOneWidget);
    await tapText(tester, 'Replace everything');
    final apply = find.byKey(const ValueKey('import-apply'));
    InkButton button() => tester.widget<InkButton>(apply);
    expect(button().onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('import-confirm')), 'replace');
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'the word must match');
    await tester.enterText(find.byKey(const ValueKey('import-confirm')), 'REPLACE');
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await settle(tester);
    expect(store.logs['2023-05-05'], isNull);
    expect(store.periodDays, {'2024-04-01', '2024-04-02'});
    expect(find.textContaining('earlier days were replaced'), findsOneWidget);
  });

  testWidgets('a generic CSV asks which column is which', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    final store = AppStore.memory(profile: Profile(onboarded: true));
    await tester.pumpWidget(wrap(store, ImportScreen(picker: pickerFor('generic_days.csv'))));

    await tapText(tester, 'Another app (CSV)');
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose file'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    expect(find.text('Which column is which?'), findsOneWidget);
    expect(find.textContaining('The first row reads as'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('What Bloom found'), findsOneWidget);
    expect(find.textContaining('purple'), findsOneWidget);
  });

  testWidgets('an unsupported file explains itself and stays on the guide', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    final store = AppStore.memory(profile: Profile(onboarded: true));
    await tester.pumpWidget(wrap(
      store,
      ImportScreen(picker: () async => PickedImportFile(BytesImportFile('report.pdf', Uint8List.fromList('%PDF-1.4'.codeUnits)))),
    ));
    await tapText(tester, 'Flo');
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose file'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    expect(find.textContaining('This is a PDF'), findsOneWidget);
    expect(find.text('From Flo'), findsOneWidget);
  });

  testWidgets('Health Connect explains why it isn\'t supported', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(wrap(AppStore.memory(), const ImportScreen()));
    await tapText(tester, 'Health Connect');
    expect(find.textContaining('Bloom can\'t read it reliably yet'), findsOneWidget);
    expect(find.text('Choose file'), findsNothing);
  });

  testWidgets('My data links to the import', (tester) async {
    tester.view.physicalSize = const Size(1080, 7200);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(wrap(AppStore.memory(profile: Profile(onboarded: true)), const MyDataScreen()));
    expect(find.text('Import from another app'), findsOneWidget);
    await tapText(tester, 'Import from another app');
    expect(find.text('Coming from another app?'), findsOneWidget);
  });

  testWidgets('the welcome page links to the import', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(wrap(AppStore.memory(), const OnboardingScreen()));
    await settle(tester);
    expect(find.byKey(const ValueKey('onboarding-import')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-import')));
    await tester.tap(find.byKey(const ValueKey('onboarding-import')));
    await settle(tester);
    expect(find.text('Clue'), findsOneWidget, reason: 'the source list is open');
  });
}

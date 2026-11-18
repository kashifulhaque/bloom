import 'dart:convert';
import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/partner/partner_snapshot.dart';
import 'package:bloom/features/profile/profile_screen.dart';
import 'package:bloom/features/reminders/contraception_model.dart';
import 'package:bloom/features/reminders/reminder_model.dart';
import 'package:bloom/features/reminders/scheduler.dart';
import 'package:bloom/features/partner/partner_screen.dart';
import 'package:bloom/features/reminders/contraception_screen.dart';
import 'package:bloom/features/reminders/reminders_screen.dart';
import 'package:bloom/features/reports/doctor_report_screen.dart';
import 'package:bloom/features/reports/report_data.dart';
import 'package:bloom/features/reports/report_pdf.dart';
import 'package:bloom/features/settings/app_lock_screen.dart';
import 'package:bloom/features/settings/appearance_screen.dart';
import 'package:bloom/features/settings/cycle_settings_screen.dart';
import 'package:bloom/features/settings/data_export.dart';
import 'package:bloom/features/settings/my_data_screen.dart';
import 'package:bloom/features/settings/lock_screen.dart';
import 'package:bloom/features/settings/pin_hash.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

AppStore _storeWithPeriod({Goal goal = Goal.trackCycle, int startDaysAgo = 10}) {
  final store = AppStore.memory(
    profile: Profile(name: 'Ada', onboarded: true, goal: goal),
  );
  store.startPeriod(addDays(today(), -startDaysAgo), length: 5);
  return store;
}

List<ReminderOccurrence> _occ(AppStore store, ReminderSettings s, {Contraception? c, int horizon = 30}) =>
    computeOccurrences(
      settings: s,
      contraception: c ?? Contraception(),
      engine: store.engine,
      goal: store.profile.goal,
      now: DateTime.now(),
      horizonDays: horizon,
    );

void main() {
  group('PIN hash', () {
    test('FNV-1a 64 matches reference vectors', () {
      expect(fnv1a64([]), 'cbf29ce484222325');
      expect(fnv1a64('a'.codeUnits), 'af63dc4c8601ec8c');
      expect(fnv1a64('foobar'.codeUnits), '85944171f73967e8');
    });

    test('hash verifies the right PIN only', () {
      final h = hashPin('1234');
      expect(h, startsWith('fnv1a:'));
      expect(h, isNot(contains('1234:')));
      expect(verifyPin('1234', h), isTrue);
      expect(verifyPin('1235', h), isFalse);
      expect(verifyPin('1234', null), isFalse);
    });

    test('salts differ, and a fixed salt is deterministic', () {
      expect(hashPin('0000'), isNot(hashPin('0000')));
      expect(hashPin('0000', salt: 'ab'), hashPin('0000', salt: 'ab'));
    });

    test('accepts a legacy plain-text PIN', () {
      expect(verifyPin('4321', '4321'), isTrue);
      expect(verifyPin('4321', '1111'), isFalse);
    });
  });

  group('Reminder scheduler', () {
    test('period coming fires N days before the predicted start', () {
      final store = _storeWithPeriod();
      final s = ReminderSettings.fromJson(null);
      s[ReminderType.periodComing]
        ..enabled = true
        ..days = 2
        ..hour = 9;
      final next = store.engine.nextPeriodStart!;
      final occ = _occ(store, s);
      expect(occ, isNotEmpty);
      expect(occ.first.type, ReminderType.periodComing);
      expect(dayOf(occ.first.when), addDays(next, -2));
      expect(occ.first.when.hour, 9);
    });

    test('ovulation and fertile reminders follow engine predictions', () {
      final store = _storeWithPeriod(startDaysAgo: 2);
      final s = ReminderSettings.fromJson(null);
      s[ReminderType.ovulation].enabled = true;
      s[ReminderType.fertileStart].enabled = true;
      final ov = store.engine.currentCycle!.ovulation;
      final occ = _occ(store, s);
      expect(occ.where((o) => o.type == ReminderType.ovulation).first.day, ov);
      expect(occ.where((o) => o.type == ReminderType.fertileStart).first.day, addDays(ov, -5));
    });

    test('cycle reminders are skipped in pregnancy mode', () {
      final store = _storeWithPeriod(goal: Goal.trackPregnancy);
      final s = ReminderSettings.fromJson(null);
      s[ReminderType.periodStart].enabled = true;
      expect(_occ(store, s), isEmpty);
    });

    test('daily and interval reminders repeat every day', () {
      final store = AppStore.memory();
      final s = ReminderSettings.fromJson(null);
      s[ReminderType.dailyLog].enabled = true;
      s[ReminderType.water]
        ..enabled = true
        ..intervalHours = 2
        ..startHour = 9
        ..endHour = 21;
      final occ = _occ(store, s, horizon: 14);
      expect(occ.where((o) => o.type == ReminderType.dailyLog).length, 14);
      expect(occ.where((o) => o.type == ReminderType.water).length, 14 * 7);
      expect(occ, orderedEquals([...occ]..sort((a, b) => a.when.compareTo(b.when))));
    });

    test('pill pack: break days, new pack, and refill', () {
      final store = AppStore.memory();
      final s = ReminderSettings.fromJson(null);
      s[ReminderType.contraception].enabled = true;
      // Pack started 22 days ago: today is break day 2 of a 21+7 pack.
      final c = Contraception(
        method: BirthControlMethod.pill,
        pack: PillPack.combo21,
        startDate: addDays(today(), -22),
        refillDaysBefore: 5,
      );
      final p = c.packDay(today())!;
      expect(p.dayInPack, 23);
      expect(p.isBreak, isTrue);
      final occ = _occ(store, s, c: c, horizon: 10);
      final nextPack = addDays(today(), 6);
      expect(occ.any((o) => o.title == 'New pack tomorrow' && o.day == addDays(nextPack, -1)), isTrue);
      expect(occ.any((o) => o.title == 'Refill your pills' && o.day == addDays(nextPack, -5)), isTrue);
      final pills = occ.where((o) => o.title == 'Time for your pill').toList();
      expect(pills.first.day, nextPack);
      expect(pills.first.body, contains('pill 1 '));
    });

    test('notification text respects privacy', () {
      final o = ReminderOccurrence(
        type: ReminderType.periodComing,
        when: DateTime(2026, 1, 1, 9),
        title: 'Period coming soon',
        body: 'Your period is expected in 2 days.',
      );
      expect(notificationText(o, NotificationPrivacy.detailed).$1, 'Period coming soon');
      expect(notificationText(o, NotificationPrivacy.minimal).$2, isNot(contains('period')));
      expect(notificationText(o, NotificationPrivacy.private).$2, 'You have a reminder from Bloom');
    });

    test('settings round-trip through JSON', () {
      final s = ReminderSettings.fromJson(null);
      s[ReminderType.weight]
        ..enabled = true
        ..weekday = DateTime.friday;
      final back = ReminderSettings.fromJson(s.toJson());
      expect(back[ReminderType.weight].enabled, isTrue);
      expect(back[ReminderType.weight].weekday, DateTime.friday);
    });
  });

  group('Partner snapshot', () {
    test('encode/decode round-trip', () {
      final store = _storeWithPeriod();
      store.toggleOption(today(), 'mood', 'happy');
      final snap = buildSnapshot(store, ShareOptions(moods: true), id: 'abc123');
      final code = snap.encode();
      expect(code, startsWith(kSnapshotPrefix));
      final back = PartnerSnapshot.decode(code);
      expect(back.id, 'abc123');
      expect(back.name, 'Ada');
      expect(back.generated, today());
      expect(back.periodStarts, snap.periodStarts);
      expect(back.ovulations, snap.ovulations);
      expect(back.periodLength, snap.periodLength);
      expect(back.phase, snap.phase);
      expect(back.moods, isNotEmpty);
      expect(back.nextPeriodAfter(today()), store.engine.nextPeriodStart);
    });

    test('respects share options', () {
      final store = _storeWithPeriod();
      store.toggleOption(today(), 'symptoms', 'cramps');
      final snap = PartnerSnapshot.decode(
        buildSnapshot(store, ShareOptions(name: false, fertility: false), id: 'x').encode(),
      );
      expect(snap.name, isNull);
      expect(snap.ovulations, isEmpty);
      expect(snap.symptoms, isEmpty);
      expect(snap.moods, isEmpty);
    });

    test('rejects invalid codes', () {
      expect(() => PartnerSnapshot.decode('hello'), throwsFormatException);
      expect(() => PartnerSnapshot.decode('${kSnapshotPrefix}not-base64!!'), throwsFormatException);
    });
  });

  test('CSV export escapes notes', () {
    final store = _storeWithPeriod();
    store.setNote(today(), 'Felt "ok", tired');
    final csv = buildLogsCsv(store);
    expect(csv.split('\r\n').first, startsWith('date,period,'));
    expect(csv, contains('"Felt ""ok"", tired"'));
  });

  test('doctor report PDF builds, including non-Latin text', () async {
    final store = _storeWithPeriod(startDaysAgo: 40);
    store.startPeriod(addDays(today(), -12), length: 5);
    store.updateProfile((p) => p.name = 'Ада 🌸');
    store.toggleOption(addDays(today(), -11), 'symptoms', 'cramps');
    store.setNote(addDays(today(), -11), 'Héllo 😀');
    final d = buildReportData(store);
    expect(d.cycles.length, 2);
    expect(d.cycles.first.length, 28);
    expect(d.topSymptoms.single.count, 1);
    final bytes = await buildReportPdf(d);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  testWidgets('doctor report PDF embeds the bundled fonts when they load', (tester) async {
    final store = _storeWithPeriod(startDaysAgo: 40);
    store.setNote(addDays(today(), -11), 'Felt “fine” — mostly 😀');
    final bytes = (await tester.runAsync(() => buildReportPdf(buildReportData(store))))!;
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(lastReportUsedBundledFonts, isTrue);
    // The serif is the static Fraunces cut, not built-in Times.
    final pdf = latin1.decode(bytes, allowInvalid: true);
    expect(pdf, contains('Fraunces'));
    expect(pdf, isNot(contains('/Times-Roman')));
  });

  group('Widgets', () {
    Widget wrap(AppStore store, Widget child) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
    );

    testWidgets('ProfileScreen renders the menu', (tester) async {
      // Tall enough that the lazily built menu is fully laid out.
      tester.view.physicalSize = const Size(1170, 9000);
      addTearDown(tester.view.resetPhysicalSize);
      final store = AppStore.memory(profile: Profile(name: 'Ada', onboarded: true));
      await tester.pumpWidget(wrap(store, const ProfileScreen()));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      for (final t in ['My goal', 'Reminders', 'Birth control', 'Partner sharing', 'App lock', 'My data']) {
        expect(find.text(t), findsOneWidget);
      }
    });

    testWidgets('feature screens render', (tester) async {
      // 360 x 2400 logical pixels: the narrowest phone width Bloom supports.
      tester.view.physicalSize = const Size(1080, 7200);
      addTearDown(tester.view.resetPhysicalSize);
      final store = _storeWithPeriod();
      Contraception(method: BirthControlMethod.pill, startDate: addDays(today(), -3)).save(store);
      for (final screen in const <Widget>[
        RemindersScreen(),
        ContraceptionScreen(),
        DoctorReportScreen(),
        PartnerScreen(),
        MyDataScreen(),
        CycleSettingsScreen(),
        AppearanceScreen(),
        AppLockSettingsScreen(),
      ]) {
        await tester.pumpWidget(wrap(store, screen));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: screen.runtimeType.toString());
      }
      // Pill grid: tapping today's pill logs it as taken.
      await tester.pumpWidget(wrap(store, const ContraceptionScreen()));
      final pill4 = find.descendant(of: find.byType(GridView), matching: find.text('4'));
      await tester.ensureVisible(pill4);
      await tester.pump();
      await tester.tap(pill4);
      await tester.pump();
      expect(store.logFor(today()).has('pill', 'taken'), isTrue);
    });

    testWidgets('tapping a reminder opens its editor', (tester) async {
      tester.view.physicalSize = const Size(1080, 7200);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(wrap(AppStore.memory(), const RemindersScreen()));
      await tester.tap(find.text('Bedtime'));
      await tester.pumpAndSettle();
      expect(find.text('WELLNESS REMINDER'), findsOneWidget);
      expect(find.text('Remind me'), findsOneWidget);
    });

    testWidgets('LockScreen rejects a wrong PIN and unlocks with the right one', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      final store = AppStore.memory(profile: Profile(onboarded: true, pin: hashPin('2468')));
      store.locked = true;
      await tester.pumpWidget(wrap(store, const LockScreen()));
      Future<void> enter(String pin) async {
        for (final d in pin.split('')) {
          await tester.tap(find.text(d));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      }

      await enter('1111');
      expect(find.text('Wrong PIN. Try again.'), findsOneWidget);
      expect(store.locked, isTrue);
      await enter('2468');
      expect(store.locked, isFalse);
    });
  });
}

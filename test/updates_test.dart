import 'package:bloom/core/store.dart';
import 'package:bloom/features/downloads/download_manifest.dart';
import 'package:bloom/features/settings/about_screen.dart';
import 'package:bloom/features/today/today_screen.dart';
import 'package:bloom/features/updates/app_version.dart';
import 'package:bloom/features/updates/update_controller.dart';
import 'package:bloom/features/updates/update_widgets.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _manifest({String version = '1.0.0+9', String? notes}) => {
      'version': version,
      'builtAt': '2026-11-18T10:00:00Z',
      'apk': {'file': 'bloom.apk', 'bytes': 21456789, 'sha256': 'a' * 64},
      'ipa': {'file': 'bloom-unsigned.ipa', 'bytes': 19876543, 'sha256': 'b' * 64},
      'notes': ?notes,
    };

/// A controller with a fake clock, loader, browser, and reload.
class _Rig {
  _Rig({
    this.platform = UpdatePlatform.android,
    AppVersion? running = const AppVersion('1.0.0', 7),
    Map<String, dynamic>? manifest,
  }) : manifest = manifest ?? _manifest() {
    controller = UpdateController(
      store: store,
      platform: platform,
      running: running,
      site: Uri.parse('https://bloom.ifkash.dev/'),
      load: () async {
        loads++;
        if (offline) throw Exception('offline');
        return DownloadManifest.tryParse(this.manifest);
      },
      clock: () => now,
      openUrl: (u) async {
        opened.add(u);
        return true;
      },
      reload: () => reloads++,
    );
  }

  final UpdatePlatform platform;
  final store = AppStore.memory();
  late final UpdateController controller;
  Object? manifest;
  DateTime now = DateTime(2026, 11, 18, 9);
  bool offline = false;
  int loads = 0;
  int reloads = 0;
  final opened = <Uri>[];

  void advance(Duration d) => now = now.add(d);
}

void main() {
  group('AppVersion', () {
    test('parses versions and rejects malformed ones', () {
      expect(AppVersion.tryParse('1.0.0+7'), const AppVersion('1.0.0', 7));
      expect(AppVersion.tryParse(' 2.1 '), const AppVersion('2.1'));
      expect(AppVersion.tryParse('1.0.0+7')!.label, '1.0.0 (build 7)');
      for (final bad in [null, '', 'latest', '1.0.0+', '1.0.0+x', 'v1.0.0', '1..0', '1.0.0+7+8', '-1.0.0']) {
        expect(AppVersion.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('compares by build number, then by name', () {
      final v7 = AppVersion.tryParse('1.0.0+7')!;
      expect(AppVersion.tryParse('1.0.0+9')!.isNewerThan(v7), isTrue);
      expect(v7.isNewerThan(v7), isFalse);
      expect(AppVersion.tryParse('1.0.0+6')!.isNewerThan(v7), isFalse);
      // CI run numbers only grow, so the build decides even if the name is
      // older.
      expect(AppVersion.tryParse('0.9.0+8')!.isNewerThan(v7), isTrue);
      // Without a build number on either side, the names decide.
      expect(AppVersion.tryParse('1.0.1')!.isNewerThan(v7), isTrue);
      expect(AppVersion.tryParse('1.0')!.isNewerThan(AppVersion.tryParse('1.0.0')!), isFalse);
      expect(AppVersion.tryParse('1.10.0')!.isNewerThan(AppVersion.tryParse('1.9.9')!), isTrue);
    });

    test('reads the build-time name and number', () {
      expect(AppVersion.fromBuild('1.0.0', '42'), const AppVersion('1.0.0', 42));
      expect(AppVersion.fromBuild('1.0.0', null), const AppVersion('1.0.0'));
      expect(AppVersion.fromBuild(null, '42'), const AppVersion('0', 42));
      expect(AppVersion.fromBuild(null, null), isNull);
      expect(AppVersion.fromBuild('dev', 'abc'), isNull);
      // `flutter test` compiles in the pubspec version.
      expect(AppVersion.running, isNotNull);
    });
  });

  group('manifest notes', () {
    test('optional, one line, and capped', () {
      expect(DownloadManifest.tryParse(_manifest())!.notes, isNull);
      expect(DownloadManifest.tryParse(_manifest(notes: '  Add an\n update\tnudge '))!.notes, 'Add an update nudge');
      expect(DownloadManifest.tryParse(_manifest(notes: '   '))!.notes, isNull);
      expect(DownloadManifest.tryParse(_manifest()..['notes'] = 42)!.notes, isNull);
      final long = DownloadManifest.tryParse(_manifest(notes: 'x' * 500))!.notes!;
      expect(long.length, DownloadManifest.maxNotesLength);
      expect(long.endsWith('…'), isTrue);
    });
  });

  group('UpdateController', () {
    test('finds a newer build and keeps it for the next launch', () async {
      final r = _Rig();
      expect(r.controller.pending, isNull);
      expect(await r.controller.check(), UpdateCheckResult.available);
      expect(r.controller.pending, const AppVersion('1.0.0', 9));
      expect(r.controller.checkedAt!.isAtSameMomentAs(r.now), isTrue);

      // A new controller on the same store remembers it without a request.
      final again = UpdateController(
        store: r.store,
        platform: UpdatePlatform.android,
        running: const AppVersion('1.0.0', 7),
        site: Uri.parse('https://bloom.ifkash.dev/'),
        load: () async => null,
        clock: () => r.now,
      );
      expect(again.pending, const AppVersion('1.0.0', 9));
      expect(again.apkUrl, Uri.parse('https://bloom.ifkash.dev/downloads/bloom.apk'));
    });

    test('same or older builds are up to date', () async {
      for (final v in ['1.0.0+7', '1.0.0+3']) {
        final r = _Rig(manifest: _manifest(version: v));
        expect(await r.controller.check(), UpdateCheckResult.upToDate, reason: v);
        expect(r.controller.pending, isNull);
      }
    });

    test('missing, malformed, and unreachable manifests fail quietly', () async {
      for (final m in <Object?>[null, 'not json', <String, dynamic>{}, _manifest(version: 'latest'), _manifest()..remove('apk')..remove('ipa')]) {
        final r = _Rig()..manifest = m;
        expect(await r.controller.check(), UpdateCheckResult.failed, reason: '$m');
        expect(r.controller.pending, isNull);
        expect(r.controller.checkedAt, isNull);
      }
      final r = _Rig()..offline = true;
      await r.controller.maybeCheck(); // Never throws.
      expect(r.controller.lastResult, UpdateCheckResult.failed);
    });

    test('a failure keeps the last known version', () async {
      final r = _Rig();
      await r.controller.check();
      r.offline = true;
      expect(await r.controller.check(), UpdateCheckResult.failed);
      expect(r.controller.pending, const AppVersion('1.0.0', 9));
    });

    test('checks at most once a day on Android', () async {
      final r = _Rig();
      await r.controller.maybeCheck();
      expect(r.loads, 1);
      r.advance(const Duration(hours: 23));
      await r.controller.maybeCheck();
      expect(r.loads, 1);
      r.advance(const Duration(hours: 1));
      await r.controller.maybeCheck();
      expect(r.loads, 2);
      // A clock set back past the last check doesn't stop checks forever.
      r.now = r.now.subtract(const Duration(days: 3));
      await r.controller.maybeCheck();
      expect(r.loads, 3);
    });

    test('retries an hour after a failure, not sooner', () async {
      final r = _Rig()..offline = true;
      await r.controller.maybeCheck();
      r.advance(const Duration(minutes: 59));
      await r.controller.maybeCheck();
      expect(r.loads, 1);
      r.offline = false;
      r.advance(const Duration(minutes: 1));
      await r.controller.maybeCheck();
      expect(r.loads, 2);
      expect(r.controller.pending, isNotNull);
    });

    test('iOS checks weekly; web every six hours', () async {
      final ios = _Rig(platform: UpdatePlatform.ios);
      await ios.controller.maybeCheck();
      ios.advance(const Duration(days: 6));
      await ios.controller.maybeCheck();
      expect(ios.loads, 1);
      ios.advance(const Duration(days: 1));
      await ios.controller.maybeCheck();
      expect(ios.loads, 2);

      final web = _Rig(platform: UpdatePlatform.web);
      await web.controller.maybeCheck();
      web.advance(const Duration(hours: 6));
      await web.controller.maybeCheck();
      expect(web.loads, 2);
    });

    test('concurrent checks share one request', () async {
      final r = _Rig();
      await Future.wait([r.controller.check(), r.controller.check(), r.controller.maybeCheck()]);
      expect(r.loads, 1);
    });

    test('Not now hides that version for 7 days on Android', () async {
      final r = _Rig();
      await r.controller.check();
      r.controller.snooze();
      expect(r.controller.pending, isNull);
      r.advance(const Duration(days: 6, hours: 23));
      expect(r.controller.pending, isNull);
      r.advance(const Duration(hours: 1));
      expect(r.controller.pending, const AppVersion('1.0.0', 9));
    });

    test('a newer version shows despite a snooze', () async {
      final r = _Rig();
      await r.controller.check();
      r.controller.snooze();
      r.manifest = _manifest(version: '1.0.0+10');
      r.advance(const Duration(days: 1));
      await r.controller.maybeCheck();
      expect(r.controller.pending, const AppVersion('1.0.0', 10));
    });

    test('iOS snoozes for 30 days', () async {
      final r = _Rig(platform: UpdatePlatform.ios);
      await r.controller.check();
      r.controller.snooze();
      r.advance(const Duration(days: 29));
      expect(r.controller.pending, isNull);
      r.advance(const Duration(days: 1));
      expect(r.controller.pending, isNotNull);
    });

    test('turning checks off stops requests and the note', () async {
      final r = _Rig();
      await r.controller.check();
      r.controller.enabled = false;
      expect(r.controller.pending, isNull);
      r.advance(const Duration(days: 2));
      await r.controller.maybeCheck();
      expect(r.loads, 1);
      // A manual check still works.
      expect(await r.controller.check(), UpdateCheckResult.available);
      r.controller.enabled = true;
      expect(r.controller.pending, isNotNull);
    });

    test('desktop and unknown builds never check', () async {
      for (final r in [_Rig(platform: UpdatePlatform.other), _Rig(running: null)]) {
        expect(r.controller.supported, isFalse);
        await r.controller.maybeCheck();
        expect(await r.controller.check(), UpdateCheckResult.skipped);
        expect(r.loads, 0);
        expect(r.controller.pending, isNull);
      }
    });

    test('Download update opens the APK and rests the note', () async {
      final r = _Rig();
      await r.controller.check();
      expect(await r.controller.downloadUpdate(), isTrue);
      expect(r.opened.single, Uri.parse('https://bloom.ifkash.dev/downloads/bloom.apk'));
      expect(r.controller.pending, isNull);
      r.advance(UpdatePolicy.afterAction);
      expect(r.controller.pending, isNotNull);
    });

    test('Reload reloads once and does not loop', () async {
      final r = _Rig(platform: UpdatePlatform.web);
      await r.controller.check();
      r.controller.reloadNow();
      expect(r.reloads, 1);
      expect(r.controller.pending, isNull);
    });

    test('update state stays on this device', () {
      expect(SyncRef.syncsFeature(kUpdatesFeature), isFalse);
      expect(_Rig().controller.getAppUrl.toString(), 'https://bloom.ifkash.dev/#/get-app');
    });
  });

  group('widgets', () {
    Widget wrap(_Rig r, Widget child) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: r.store),
            ChangeNotifierProvider.value(value: r.controller),
          ],
          child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
        );

    Future<void> pumpToday(WidgetTester tester, _Rig r) async {
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(r, const TodayScreen()));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('Android: download or not now', (tester) async {
      final r = _Rig(manifest: _manifest(notes: 'Add an update nudge'));
      await r.controller.check();
      await pumpToday(tester, r);
      expect(find.text('A new version of Bloom is ready.'), findsOneWidget);
      expect(find.text('UPDATE · 1.0.0 (BUILD 9)'), findsOneWidget);
      expect(find.textContaining('Add an update nudge'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-reload')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('update-not-now')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('update-note')), findsNothing);
      expect(r.opened, isEmpty);
    });

    testWidgets('Android: Download update opens the APK in the browser', (tester) async {
      final r = _Rig();
      await r.controller.check();
      await pumpToday(tester, r);
      await tester.tap(find.byKey(const ValueKey('update-download')));
      await tester.pump(const Duration(seconds: 1));
      expect(r.opened.single, Uri.parse('https://bloom.ifkash.dev/downloads/bloom.apk'));
      expect(find.byKey(const ValueKey('update-note')), findsNothing);
    });

    testWidgets('Android: no notes line without notes', (tester) async {
      final r = _Rig();
      await r.controller.check();
      await pumpToday(tester, r);
      expect(find.byKey(const ValueKey('update-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('update-notes')), findsNothing);
    });

    testWidgets('iOS: quiet links to the web app', (tester) async {
      final r = _Rig(platform: UpdatePlatform.ios);
      await r.controller.check();
      await pumpToday(tester, r);
      expect(find.text('A new version of Bloom is available.'), findsOneWidget);
      expect(find.textContaining("can't update itself"), findsOneWidget);
      expect(find.byKey(const ValueKey('update-download')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('update-web-app')));
      await tester.tap(find.byKey(const ValueKey('update-get-app')));
      await tester.pump();
      expect(r.opened.map((u) => u.toString()), ['https://bloom.ifkash.dev/', 'https://bloom.ifkash.dev/#/get-app']);
    });

    testWidgets('web: Reload', (tester) async {
      final r = _Rig(platform: UpdatePlatform.web);
      await r.controller.check();
      await pumpToday(tester, r);
      expect(find.textContaining('Reload to use it'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update-reload')));
      await tester.pump(const Duration(seconds: 1));
      expect(r.reloads, 1);
      expect(find.byKey(const ValueKey('update-note')), findsNothing);
    });

    testWidgets('no note when up to date, off, or without a controller', (tester) async {
      final current = _Rig(manifest: _manifest(version: '1.0.0+7'));
      await current.controller.check();
      await pumpToday(tester, current);
      expect(find.byKey(const ValueKey('update-note')), findsNothing);

      final off = _Rig();
      await off.controller.check();
      off.controller.enabled = false;
      await pumpToday(tester, off);
      expect(find.byKey(const ValueKey('update-note')), findsNothing);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: AppStore.memory(),
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const TodayScreen()),
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('update-note')), findsNothing);
    });

    testWidgets('About: version, Check for updates, and the switch', (tester) async {
      tester.view.physicalSize = const Size(1080, 9000);
      addTearDown(tester.view.reset);
      final r = _Rig();
      await tester.pumpWidget(wrap(r, const AboutPrivacyScreen()));
      expect(find.text('1.0.0 (build 7)'), findsOneWidget);
      expect(find.text('Not checked yet.'), findsOneWidget);
      expect(find.textContaining('sends no account, device ID, or notebook data'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(r.loads, 1);
      expect(find.text('1.0.0 (build 9) is available.'), findsOneWidget);

      r.offline = true;
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't check. Try again when you're online."), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('update-auto')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('update-auto')));
      await tester.pump();
      expect(r.controller.enabled, isFalse);
    });

    testWidgets('lifecycle checks after launch and on resume', (tester) async {
      final r = _Rig();
      await tester.pumpWidget(UpdateLifecycle(
        controller: r.controller,
        startDelay: const Duration(seconds: 5),
        child: const SizedBox(),
      ));
      expect(r.loads, 0); // Startup never waits for a check.
      await tester.pump(const Duration(seconds: 5));
      expect(r.loads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(r.loads, 1); // Resumed within a day: no request.
      r.advance(const Duration(hours: 24));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(r.loads, 2);
    });
  });
}

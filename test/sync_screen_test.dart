// Widget tests for You > Sync, against the in-memory server.
import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/core/sync/crypto/sync_crypto.dart';
import 'package:bloom/core/sync/key_store.dart';
import 'package:bloom/core/sync/sync_controller.dart';
import 'package:bloom/core/sync/sync_state.dart';
import 'package:bloom/features/profile/profile_screen.dart';
import 'package:bloom/features/settings/about_screen.dart';
import 'package:bloom/features/sync/sync_screen.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:bloom/widgets/ink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fake_sync.dart';

/// Small Argon2id parameters keep the tests fast.
const _fastKdf = KdfParams(memKiB: 8192, iterations: 1);

SyncController controllerFor(AppStore store, FakeServer? server, {KeyStore? keys}) => SyncController(
      store: store,
      connect: server == null ? null : () async => FakeSyncService(server),
      keyStore: keys ?? MemoryKeyStore(),
      stateStorage: MemorySyncStateStorage(),
      kdfParams: _fastKdf,
    );

Widget wrap(AppStore store, SyncController sync, Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
    );

/// Lets real async work (Argon2id, timers in the controller) finish.
Future<void> settle(WidgetTester t, SyncController sync, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
  }
  await t.pumpAndSettle();
  expect(done(), isTrue, reason: 'phase ${sync.phase}, error ${sync.actionError}');
}

/// A 390 x 844 phone screen.
void phone(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<void> scrollTap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pump();
}

/// Signs in through the email and code steps.
Future<void> signIn(WidgetTester t, SyncController sync, String email) async {
  await settle(t, sync, () => sync.phase == SyncPhase.signedOut);
  expect(find.text('No phrase, no recovery'), findsOneWidget);
  await t.enterText(find.byKey(const ValueKey('sync-email')), email);
  await t.pump();
  final send = find.widgetWithText(InkButton, 'Email me a code');
  expect(t.widget<InkButton>(send).onPressed, isNull, reason: 'needs the acknowledgment first');
  await scrollTap(t, find.byKey(const ValueKey('sync-understood')));
  await scrollTap(t, send);
  await settle(t, sync, () => sync.phase == SyncPhase.codeSent);

  await t.enterText(find.byKey(const ValueKey('sync-code')), '000000');
  await scrollTap(t, find.widgetWithText(InkButton, 'Sign in'));
  await settle(t, sync, () => sync.actionError != null);
  expect(find.textContaining('code has expired or isn\'t right'), findsOneWidget);

  await t.enterText(find.byKey(const ValueKey('sync-code')), '123456');
  await scrollTap(t, find.widgetWithText(InkButton, 'Sign in'));
  await settle(t, sync, () => sync.phase == SyncPhase.needsSetup || sync.phase == SyncPhase.needsUnlock);
}

void main() {
  testWidgets('a build without sync settings explains that sync isn\'t available', (t) async {
    final store = AppStore.memory(profile: Profile(onboarded: true));
    final sync = controllerFor(store, null);
    await t.pumpWidget(wrap(store, sync, const SyncScreen()));
    await t.pumpAndSettle();
    expect(find.text('This copy of Bloom has no sync'), findsOneWidget);
    expect(sync.statusLabel, 'Not set up');
  });

  testWidgets('first device: sign in, save the phrase, confirm 3 words, and sync', (t) async {
    phone(t);
    final server = FakeServer();
    final store = AppStore.memory(profile: Profile(onboarded: true, name: 'Ada'));
    store.setNote(parseDayKey('2026-11-01'), 'synced note');
    final sync = controllerFor(store, server);
    await t.pumpWidget(wrap(store, sync, const SyncScreen()));
    await signIn(t, sync, 'ada@example.test');
    expect(sync.phase, SyncPhase.needsSetup);

    final words = sync.newPhrase!.words;
    for (var i = 0; i < 12; i++) {
      expect(find.bySemanticsLabel(RegExp('${i + 1}, ${words[i]}')), findsOneWidget);
    }
    await scrollTap(t, find.widgetWithText(InkButton, 'I\'ve written it down'));
    await t.pumpAndSettle();

    // Wrong words keep the button off.
    final turnOn = find.widgetWithText(InkButton, 'Turn on sync');
    for (var i = 0; i < 3; i++) {
      await t.enterText(find.byKey(ValueKey('sync-confirm-$i')), 'wrong');
    }
    await t.pump();
    expect(t.widget<InkButton>(turnOn).onPressed, isNull);

    for (var i = 0; i < 3; i++) {
      final label = t.widget<TextField>(find.byKey(ValueKey('sync-confirm-$i'))).decoration!.labelText!;
      final n = int.parse(label.split(' ').last);
      await t.enterText(find.byKey(ValueKey('sync-confirm-$i')), words[n - 1].toUpperCase());
    }
    await t.pump();
    await scrollTap(t, turnOn);
    await settle(t, sync, () => sync.phase == SyncPhase.active && !sync.syncing && sync.lastSyncAt != null);

    expect(find.text('Just now'), findsOneWidget);
    expect(sync.recordCount, 2); // The profile and one day.
    expect(server.keys, hasLength(1));
    expect(server.rows.values.single, hasLength(2));
    expect(sync.newPhrase, isNull, reason: 'the phrase is forgotten once saved');

    // Sync now pushes a new edit.
    store.setNote(parseDayKey('2026-11-02'), 'another');
    await scrollTap(t, find.widgetWithText(InkButton, 'Sync now'));
    await settle(t, sync, () => !sync.syncing && sync.pendingCount == 0);
    expect(server.rows.values.single, hasLength(3));
  });

  testWidgets('new device: a wrong phrase fails, the right one unlocks and pulls', (t) async {
    phone(t);
    final server = FakeServer();

    // Device one sets up sync without the UI.
    final first = AppStore.memory(profile: Profile(onboarded: true, name: 'Ada'));
    first.setNote(parseDayKey('2026-11-01'), 'from the first device');
    final svc = FakeSyncService(server);
    final oneController = SyncController(
      store: first,
      connect: () async => svc..signInAs('ada@example.test'),
      keyStore: MemoryKeyStore(),
      stateStorage: MemorySyncStateStorage(),
      kdfParams: _fastKdf,
    );
    late RecoveryPhrase phrase;
    await t.runAsync(() async {
      await oneController.open();
      phrase = oneController.beginSetup();
      await oneController.finishSetup();
      await oneController.syncNow();
    });
    expect(oneController.phase, SyncPhase.active);

    // Device two, through the UI.
    final store = AppStore.memory(profile: Profile(onboarded: true));
    final sync = controllerFor(store, server);
    await t.pumpWidget(wrap(store, sync, const SyncScreen()));
    await signIn(t, sync, 'ada@example.test');
    expect(sync.phase, SyncPhase.needsUnlock);

    final unlock = find.widgetWithText(InkButton, 'Unlock');
    await t.enterText(find.byKey(const ValueKey('sync-phrase')), 'abandon abandon abandon');
    await t.pump();
    expect(t.widget<InkButton>(unlock).onPressed, isNull);
    expect(find.text('3 of 12 words'), findsOneWidget);

    final wrong = RecoveryPhrase.generate().toString();
    await t.enterText(find.byKey(const ValueKey('sync-phrase')), wrong);
    await scrollTap(t, unlock);
    await settle(t, sync, () => sync.actionError != null);
    expect(find.text('That recovery phrase doesn\'t match this account.'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('sync-phrase')), phrase.toString());
    await scrollTap(t, unlock);
    await settle(t, sync, () => sync.phase == SyncPhase.active && !sync.syncing && sync.lastSyncAt != null);
    expect(store.profile.name, 'Ada');
    expect(store.logs['2026-11-01']!.note, 'from the first device');
  });

  testWidgets('delete synced data needs the typed confirmation, then signs out', (t) async {
    phone(t);
    final server = FakeServer();
    final store = AppStore.memory(profile: Profile(onboarded: true));
    final keys = MemoryKeyStore();
    final svc = FakeSyncService(server)..signInAs('ada@example.test');
    final sync = SyncController(
      store: store,
      connect: () async => svc,
      keyStore: keys,
      stateStorage: MemorySyncStateStorage(),
      kdfParams: _fastKdf,
    );
    await t.runAsync(() async {
      await sync.open();
      sync.beginSetup();
      await sync.finishSetup();
      await sync.syncNow();
    });
    expect(server.rows, isNotEmpty);

    await t.pumpWidget(wrap(store, sync, const SyncScreen()));
    await t.pumpAndSettle();
    expect(find.text('ada@example.test'), findsOneWidget);

    await scrollTap(t, find.widgetWithText(InkButton, 'Delete synced data'));
    await t.pumpAndSettle();
    final confirm = find.widgetWithText(InkButton, 'Delete');
    expect(t.widget<InkButton>(confirm).onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('sync-delete-confirm')), 'DELETE');
    await t.pump();
    await t.tap(confirm);
    await settle(t, sync, () => sync.phase == SyncPhase.signedOut);
    expect(server.rows, isEmpty);
    expect(server.keys, isEmpty);
    expect(await t.runAsync(keys.read), isNull);
    expect(find.text('Synced data deleted'), findsOneWidget);
  });

  testWidgets('erasing all data on the device turns sync off without touching the account', (t) async {
    final server = FakeServer();
    final store = AppStore.memory(profile: Profile(onboarded: true));
    final svc = FakeSyncService(server)..signInAs('ada@example.test');
    final sync = SyncController(
      store: store,
      connect: () async => svc,
      keyStore: MemoryKeyStore(),
      stateStorage: MemorySyncStateStorage(),
      kdfParams: _fastKdf,
    );
    await t.runAsync(() async {
      await sync.open();
      sync.beginSetup();
      await sync.finishSetup();
      await sync.syncNow();
      await store.deleteAll();
    });
    expect(sync.phase, SyncPhase.signedOut);
    expect(store.syncHooks, isNull);
    expect(server.rows.values.single, isNotEmpty, reason: 'the synced copy stays');
  });

  testWidgets('You lists Sync with its status, and About mentions encryption', (t) async {
    final store = AppStore.memory(profile: Profile(onboarded: true));
    phone(t);
    final sync = controllerFor(store, FakeServer());
    await t.pumpWidget(wrap(store, sync, const ProfileScreen()));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Sync'), 200);
    expect(find.text('Optional · end-to-end encrypted'), findsOneWidget);

    await t.pumpWidget(wrap(store, sync, const AboutPrivacyScreen()));
    await t.pumpAndSettle();
    expect(find.text('Sync is end-to-end encrypted'), findsOneWidget);
  });

  testWidgets('without a SyncController, You still renders (sync off)', (t) async {
    final store = AppStore.memory(profile: Profile(onboarded: true));
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const ProfileScreen()),
    ));
    await t.pumpAndSettle();
    expect(find.text('Optional · end-to-end encrypted'), findsNothing);
  });
}

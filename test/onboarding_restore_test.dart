// Widget tests for "Already have an account?" on the onboarding welcome page,
// against the in-memory sync server.
import 'package:bloom/app.dart';
import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/core/sync/crypto/sync_crypto.dart';
import 'package:bloom/core/sync/key_store.dart';
import 'package:bloom/core/sync/sync_controller.dart';
import 'package:bloom/core/sync/sync_models.dart';
import 'package:bloom/core/sync/sync_service.dart';
import 'package:bloom/core/sync/sync_state.dart';
import 'package:bloom/features/onboarding/onboarding_screen.dart';
import 'package:bloom/features/settings/lock_screen.dart';
import 'package:bloom/features/sync/sync_screen.dart';
import 'package:bloom/widgets/ink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fake_sync.dart';

/// Small Argon2id parameters keep the tests fast.
const _fastKdf = KdfParams(memKiB: 8192, iterations: 1);

const _email = 'ada@example.test';

/// A fake server connection that can fail its next pulls, like a connection
/// that drops part way through a download.
class _FlakyService extends FakeSyncService {
  _FlakyService(super.server);

  int failPulls = 0;

  @override
  Future<List<RemoteRow>> pull({PullCursor? after, required int limit}) async {
    if (failPulls > 0) {
      failPulls--;
      throw const SyncServiceException('The connection dropped.');
    }
    return super.pull(after: after, limit: limit);
  }
}

/// The device under test: an app on the welcome page, with its own sync
/// controller, key store, and state storage.
class _Device {
  _Device(this.server, {Profile? profile, bool configured = true})
      : store = AppStore.memory(profile: profile),
        service = _FlakyService(server) {
    sync = SyncController(
      store: store,
      connect: configured ? () async => service : null,
      keyStore: keys,
      stateStorage: states,
      kdfParams: _fastKdf,
    );
  }

  final FakeServer server;
  final AppStore store;
  final _FlakyService service;
  final keys = MemoryKeyStore();
  final states = MemorySyncStateStorage();
  late final SyncController sync;

  Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: sync),
        ],
        child: const BloomApp(),
      );
}

/// Sets up sync for [_email] on another device, with a profile and one note,
/// and returns the recovery phrase.
Future<RecoveryPhrase> _seedAccount(WidgetTester t, FakeServer server) async {
  final first = AppStore.memory(profile: Profile(onboarded: true, name: 'Ada', cycleLength: 31));
  first.setNote(parseDayKey('2026-11-01'), 'from the first device');
  final svc = FakeSyncService(server);
  final controller = SyncController(
    store: first,
    connect: () async => svc..signInAs(_email),
    keyStore: MemoryKeyStore(),
    stateStorage: MemorySyncStateStorage(),
    kdfParams: _fastKdf,
  );
  late RecoveryPhrase phrase;
  await t.runAsync(() async {
    await controller.open();
    phrase = controller.beginSetup();
    await controller.finishSetup();
    await controller.syncNow();
  });
  expect(server.rows.values.single, hasLength(2));
  return phrase;
}

/// A 390 x 844 phone screen, or a wider one.
void _phone(WidgetTester t, {double width = 390}) {
  t.view
    ..physicalSize = Size(width * 3, 2532)
    ..devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// Lets real async work (Argon2id, the controller's futures) finish.
Future<void> _settle(WidgetTester t, SyncController sync, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
  }
  await t.pumpAndSettle();
  expect(done(), isTrue, reason: 'phase ${sync.phase}, error ${sync.actionError}');
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pump();
}

final _restoreLink = find.byKey(const ValueKey('onboarding-restore'));
final _back = find.byKey(const ValueKey('restore-back'));

/// Opens the restore flow and signs in with the emailed code.
Future<void> _signIn(WidgetTester t, _Device d, {String email = _email}) async {
  await t.pumpWidget(d.app());
  await t.pumpAndSettle();
  await _tap(t, _restoreLink);
  await _settle(t, d.sync, () => d.sync.phase == SyncPhase.signedOut);
  expect(find.text('Sign in to restore your data.'), findsOneWidget);
  expect(find.byKey(const ValueKey('sync-understood')), findsNothing, reason: 'no acknowledgment to restore');

  await t.enterText(find.byKey(const ValueKey('sync-email')), email);
  await _tap(t, find.widgetWithText(InkButton, 'Email me a code'));
  await _settle(t, d.sync, () => d.sync.phase == SyncPhase.codeSent);
  expect(find.text('Check your email.'), findsOneWidget);

  await t.enterText(find.byKey(const ValueKey('sync-code')), '123456');
  await _tap(t, find.widgetWithText(InkButton, 'Sign in'));
  await _settle(t, d.sync, () => d.sync.phase == SyncPhase.needsUnlock || d.sync.phase == SyncPhase.needsSetup);
}

Future<void> _enterPhrase(WidgetTester t, _Device d, String phrase) async {
  await t.enterText(find.byKey(const ValueKey('sync-phrase')), phrase);
  await _tap(t, find.widgetWithText(InkButton, 'Restore'));
  await _settle(t, d.sync, () => !d.sync.busy);
}

/// Checks that the device is exactly as it was on the welcome page.
Future<void> _expectUntouched(WidgetTester t, _Device d) async {
  expect(find.text('Get started'), findsOneWidget);
  expect(_restoreLink, findsOneWidget);
  expect(d.store.profile.onboarded, isFalse);
  expect(d.store.logs, isEmpty);
  expect(d.store.syncHooks, isNull);
  expect(d.sync.phase, SyncPhase.signedOut);
  expect(d.sync.email, isNull);
  expect(d.service.userId, isNull, reason: 'signed out');
  expect(await t.runAsync(d.keys.read), isNull);
  expect(await t.runAsync(d.states.read), isNull);
}

void main() {
  testWidgets('the welcome page hides the action when the build has no sync', (t) async {
    _phone(t);
    final d = _Device(FakeServer(), configured: false);
    await t.pumpWidget(d.app());
    await t.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Already have an account?'), findsNothing);

    // And without any SyncController, as in other screens' tests.
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: AppStore.memory(),
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await t.pumpAndSettle();
    expect(find.text('Already have an account?'), findsNothing);
  });

  testWidgets('restores an account and lands on Today, the same as You > Sync', (t) async {
    _phone(t);
    final server = FakeServer();
    final phrase = await _seedAccount(t, server);
    final d = _Device(server);
    await _signIn(t, d);
    expect(d.sync.phase, SyncPhase.needsUnlock);
    expect(find.text('Enter your 12 words.'), findsOneWidget);

    await _enterPhrase(t, d, phrase.toString());
    expect(d.sync.actionError, isNull);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);

    // The account's data, including its profile, replaced the blank one.
    expect(d.store.profile.onboarded, isTrue);
    expect(d.store.profile.name, 'Ada');
    expect(d.store.profile.cycleLength, 31);
    expect(d.store.logs['2026-11-01']!.note, 'from the first device');

    // Sync is on, exactly as after unlocking in You > Sync.
    expect(d.sync.phase, SyncPhase.active);
    expect(d.sync.statusLabel, 'On');
    expect(d.sync.email, _email);
    expect(d.sync.lastSyncAt, isNotNull);
    expect(d.sync.recordCount, 2);
    expect(d.sync.pendingCount, 0);
    expect((await t.runAsync(d.keys.read))!.userId, d.service.userId);
    expect(SyncState.decode((await t.runAsync<String?>(d.states.read))!).joined, isTrue);
    expect(server.rows.values.single, hasLength(2), reason: 'the blank profile wasn\'t uploaded');

    // You > Sync shows the account's status.
    await t.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: d.store),
        ChangeNotifierProvider.value(value: d.sync),
      ],
      child: const MaterialApp(home: SyncScreen()),
    ));
    await t.pumpAndSettle();
    expect(find.text('End-to-end encrypted.'), findsOneWidget);
    expect(find.text(_email), findsOneWidget);

    // Edits sync like on any other device.
    d.store.setNote(parseDayKey('2026-11-02'), 'from the restored device');
    await t.runAsync(d.sync.syncNow);
    expect(server.rows.values.single, hasLength(3));
  });

  testWidgets('a device with an app-lock PIN is locked after the restore', (t) async {
    _phone(t);
    final server = FakeServer();
    final phrase = await _seedAccount(t, server);
    final d = _Device(server, profile: Profile(pin: '1234'));
    await _signIn(t, d);
    await _enterPhrase(t, d, phrase.toString());
    expect(d.store.profile.onboarded, isTrue);
    expect(d.store.profile.pin, '1234', reason: 'the PIN stays on this device');
    expect(d.store.locked, isTrue);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('an account without synced data explains it and creates no key', (t) async {
    // Tablet width: in the test font, the birth-year menu is wider than a phone.
    _phone(t, width: 800);
    final server = FakeServer();
    final d = _Device(server);
    await _signIn(t, d, email: 'new@example.test');
    expect(d.sync.phase, SyncPhase.needsSetup);
    expect(find.text('This account has no synced data.'), findsOneWidget);
    expect(server.keys, isEmpty);

    // Go back: signed out, and nothing changed.
    await _tap(t, find.widgetWithText(InkButton, 'Go back'));
    await _settle(t, d.sync, () => find.text('Get started').evaluate().isNotEmpty);
    await _expectUntouched(t, d);

    // Set up a new account: onboarding continues, still with no key.
    await _signIn(t, d, email: 'new@example.test');
    await _tap(t, find.widgetWithText(InkButton, 'Set up a new account'));
    await t.pumpAndSettle();
    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(server.keys, isEmpty);

    // Answer the questions; finishing opens sync setup with a new phrase.
    await _tap(t, find.widgetWithText(InkButton, 'Continue')); // Goal
    await _tap(t, find.widgetWithText(InkButton, 'Continue')); // Name
    await _tap(t, find.widgetWithText(InkButton, 'Continue')); // Birth year
    await t.pumpAndSettle();
    await _tap(t, find.text("I don't remember"));
    for (var i = 0; i < 6; i++) {
      await _tap(t, find.widgetWithText(InkButton, 'Continue'));
      await t.pumpAndSettle();
    }
    await _tap(t, find.widgetWithText(InkButton, 'Finish'));
    await _settle(t, d.sync, () => find.byType(SyncScreen).evaluate().isNotEmpty);
    expect(d.store.profile.onboarded, isTrue);
    expect(d.sync.phase, SyncPhase.needsSetup);
    expect(find.text('I\'ve written it down'), findsOneWidget);
    expect(d.sync.newPhrase, isNotNull);
    expect(server.keys, isEmpty, reason: 'the key is made only after the phrase is confirmed');
  });

  testWidgets('back from the questions after choosing a new account signs out', (t) async {
    _phone(t);
    final d = _Device(FakeServer());
    await _signIn(t, d, email: 'new@example.test');
    await _tap(t, find.widgetWithText(InkButton, 'Set up a new account'));
    await t.pumpAndSettle();
    await _tap(t, find.byTooltip('Back'));
    await _settle(t, d.sync, () => d.service.userId == null);
    await _expectUntouched(t, d);
  });

  testWidgets('a wrong phrase can be retried, and a lost phrase offers a fresh start', (t) async {
    _phone(t);
    final server = FakeServer();
    final phrase = await _seedAccount(t, server);
    final d = _Device(server);
    await _signIn(t, d);

    await _enterPhrase(t, d, RecoveryPhrase.generate().toString());
    expect(find.text('That recovery phrase doesn\'t match this account.'), findsOneWidget);
    expect(d.sync.phase, SyncPhase.needsUnlock);
    expect(d.store.profile.onboarded, isFalse);
    expect(await t.runAsync(d.keys.read), isNull);

    // "I lost my phrase" explains, and "I found my phrase" comes back.
    await _tap(t, find.text('I lost my phrase'));
    await t.pumpAndSettle();
    expect(find.text('Encrypted data can\'t be recovered'), findsOneWidget);
    await _tap(t, find.text('I found my phrase'));
    await t.pumpAndSettle();
    expect(find.text('Enter your 12 words.'), findsOneWidget);

    // Start fresh: signed out, on to the questions, the account untouched.
    await _tap(t, find.text('I lost my phrase'));
    await t.pumpAndSettle();
    await _tap(t, find.widgetWithText(InkButton, 'Start fresh'));
    await _settle(t, d.sync, () => find.text('What would you like to do?').evaluate().isNotEmpty);
    expect(d.service.userId, isNull);
    expect(d.sync.phase, SyncPhase.signedOut);
    expect(d.store.profile.onboarded, isFalse);
    expect(server.keys, hasLength(1));
    expect(server.rows.values.single, hasLength(2));

    // The right phrase still works after a retry (from a new attempt).
    await _tap(t, find.byTooltip('Back'));
    await t.pumpAndSettle();
    await _expectUntouched(t, d);
    await _tap(t, _restoreLink);
    await _settle(t, d.sync, () => d.sync.phase == SyncPhase.signedOut);
    await t.enterText(find.byKey(const ValueKey('sync-email')), _email);
    await _tap(t, find.widgetWithText(InkButton, 'Email me a code'));
    await _settle(t, d.sync, () => d.sync.phase == SyncPhase.codeSent);
    await t.enterText(find.byKey(const ValueKey('sync-code')), '123456');
    await _tap(t, find.widgetWithText(InkButton, 'Sign in'));
    await _settle(t, d.sync, () => d.sync.phase == SyncPhase.needsUnlock);
    await _enterPhrase(t, d, phrase.toString());
    expect(d.store.profile.name, 'Ada');
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('back at each step returns to the welcome page with nothing changed', (t) async {
    _phone(t);
    final server = FakeServer();
    await _seedAccount(t, server);
    final d = _Device(server);

    // From the email step.
    await t.pumpWidget(d.app());
    await t.pumpAndSettle();
    await _tap(t, _restoreLink);
    await _settle(t, d.sync, () => d.sync.phase == SyncPhase.signedOut);
    await _tap(t, _back);
    await t.pumpAndSettle();
    await _expectUntouched(t, d);

    // From the code step.
    await _tap(t, _restoreLink);
    await _settle(t, d.sync, () => d.sync.phase == SyncPhase.signedOut);
    await t.enterText(find.byKey(const ValueKey('sync-email')), _email);
    await _tap(t, find.widgetWithText(InkButton, 'Email me a code'));
    await _settle(t, d.sync, () => d.sync.phase == SyncPhase.codeSent);
    await _tap(t, _back);
    await t.pumpAndSettle();
    await _expectUntouched(t, d);

    // From the phrase step, signed in.
    await _signIn(t, d);
    expect(d.service.userId, isNotNull);
    await _tap(t, _back);
    await _settle(t, d.sync, () => d.service.userId == null);
    await _expectUntouched(t, d);

    // The system back gesture does the same.
    await _signIn(t, d);
    final popped = await t.binding.handlePopRoute();
    expect(popped, isTrue, reason: 'the restore flow handles back instead of closing the app');
    await _settle(t, d.sync, () => d.service.userId == null);
    await _expectUntouched(t, d);
  });

  testWidgets('a network failure mid-restore changes nothing and can be retried', (t) async {
    _phone(t);
    final server = FakeServer();
    final phrase = await _seedAccount(t, server);
    final d = _Device(server);
    await _signIn(t, d);

    d.service.failPulls = 1;
    await _enterPhrase(t, d, phrase.toString());
    expect(find.text('The connection dropped.'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(d.sync.phase, SyncPhase.needsUnlock);
    expect(d.store.profile.onboarded, isFalse);
    expect(d.store.logs, isEmpty);
    expect(d.store.syncHooks, isNull);
    expect(await t.runAsync(d.keys.read), isNull);
    expect(await t.runAsync(d.states.read), isNull);

    // The phrase is still in the field: try again.
    await _tap(t, find.widgetWithText(InkButton, 'Restore'));
    await _settle(t, d.sync, () => d.sync.phase == SyncPhase.active);
    expect(d.store.profile.name, 'Ada');
    expect(d.store.logs['2026-11-01']!.note, 'from the first device');
    expect(find.byType(HomeShell), findsOneWidget);
  });
}

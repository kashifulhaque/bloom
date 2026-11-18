/// Turns sync on and off and decides when it runs: on launch, when the app
/// resumes, 5 seconds after the last edit, and on **Sync now**.
///
/// Everything runs in the background. Errors are kept in [syncError] for the
/// Sync screen and never interrupt the app. With sync off, the controller
/// does nothing, and the store behaves as it always has.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../store.dart';
import 'crypto/recovery_phrase.dart';
import 'crypto/sync_crypto.dart';
import 'key_store.dart';
import 'sync_engine.dart';
import 'sync_models.dart';
import 'sync_service.dart';
import 'sync_state.dart';

export 'crypto/recovery_phrase.dart' show RecoveryPhrase, InvalidPhraseException;

enum SyncPhase {
  /// This build has no Supabase settings.
  unconfigured,

  /// Checking the saved session and key.
  starting,

  /// No account on this device.
  signedOut,

  /// A code was emailed; waiting for the user to type it.
  codeSent,

  /// Signed in, and the account has no key yet: this is the first device.
  needsSetup,

  /// Signed in, and the account has a key: enter the recovery phrase.
  needsUnlock,

  /// Syncing.
  active,
}

class SyncController extends ChangeNotifier {
  SyncController({
    required this.store,
    this.connect,
    KeyStore? keyStore,
    SyncStateStorage? stateStorage,
    this.kdfParams = KdfParams.current,
    this.debounce = const Duration(seconds: 5),
  })  : keyStore = keyStore ?? MemoryKeyStore(),
        stateStorage = stateStorage ?? MemorySyncStateStorage(),
        phase = connect == null ? SyncPhase.unconfigured : SyncPhase.starting;

  final AppStore store;

  /// Connects to the server. Null when this build has no sync settings.
  final Future<SyncService> Function()? connect;
  final KeyStore keyStore;
  final SyncStateStorage stateStorage;

  /// Argon2id parameters for new keys.
  final KdfParams kdfParams;

  /// How long after the last edit sync waits before it runs.
  final Duration debounce;

  SyncPhase phase;
  SyncService? _service;
  SyncEngine? _engine;
  SyncState? _state;

  /// The address a code was sent to, or the signed-in address.
  String? email;

  /// True while a user action (sending a code, deriving a key) runs.
  bool busy = false;

  /// True while a sync runs.
  bool syncing = false;

  /// The last user action's error, worded for the user.
  String? actionError;

  /// The last background sync error. Cleared by the next successful sync.
  String? syncError;

  SyncReport? lastReport;

  /// The phrase made for this device's setup. It's shown once and kept only
  /// until setup finishes.
  RecoveryPhrase? newPhrase;

  Timer? _timer;
  bool _started = false;

  bool get configured => connect != null;
  DateTime? get lastSyncAt => _state?.lastSyncAt;
  int get recordCount => _state?.live ?? 0;
  int get pendingCount => _state?.pending ?? 0;

  /// A short status for the You tab.
  String get statusLabel => switch (phase) {
        SyncPhase.unconfigured => 'Not set up',
        SyncPhase.active => syncError == null ? 'On' : 'Error',
        SyncPhase.starting => '…',
        _ => 'Off',
      };

  // ---------------------------------------------------------------- launch

  /// Called once at launch, after the first frame. Connects only when this
  /// device already has a sync key, so the offline app is unchanged.
  Future<void> start() async {
    if (_started || !configured) return;
    _started = true;
    try {
      final key = await keyStore.read();
      if (key == null) {
        _set(SyncPhase.signedOut);
        return;
      }
      final service = await _connectService();
      if (service.userId != key.userId) {
        // The session ended or belongs to someone else: forget the key.
        await keyStore.clear();
        _set(service.userId == null ? SyncPhase.signedOut : await _phaseAfterSignIn());
        return;
      }
      email = service.email;
      await _activate(key);
      unawaited(syncNow());
    } catch (e) {
      syncError = _describe(e);
      if (phase == SyncPhase.starting) _set(SyncPhase.signedOut);
    }
  }

  /// Called when the Sync screen opens: connects if needed and works out
  /// which step to show.
  Future<void> open() async {
    if (!configured || phase == SyncPhase.active) return;
    await _action(() async {
      if (!_started) {
        await start();
        if (phase == SyncPhase.active) return;
      }
      final service = await _connectService();
      if (service.userId == null) {
        if (phase != SyncPhase.codeSent) _set(SyncPhase.signedOut);
      } else {
        email = service.email;
        _set(await _phaseAfterSignIn());
      }
    });
  }

  Future<SyncService> _connectService() async => _service ??= await connect!();

  Future<SyncPhase> _phaseAfterSignIn() async =>
      await _service!.fetchKey() == null ? SyncPhase.needsSetup : SyncPhase.needsUnlock;

  // ---------------------------------------------------------------- sign-in

  Future<void> sendCode(String address) => _action(() async {
        final service = await _connectService();
        await service.sendCode(address);
        email = address.trim();
        _set(SyncPhase.codeSent);
      });

  Future<void> verifyCode(String code) => _action(() async {
        await _service!.verifyCode(email!, code);
        email = _service!.email ?? email;
        _set(await _phaseAfterSignIn());
      });

  /// Goes back from the code step to the email step.
  void changeEmail() {
    actionError = null;
    _set(SyncPhase.signedOut);
  }

  // ---------------------------------------------------------------- keys

  /// Makes the recovery phrase for a first device. Call [finishSetup] after
  /// the user has written it down and confirmed it.
  RecoveryPhrase beginSetup() => newPhrase ??= RecoveryPhrase.generate();

  /// Creates the data key, wraps it with the phrase, uploads it, and starts
  /// syncing.
  Future<void> finishSetup() => _action(() async {
        final phrase = newPhrase!;
        final service = _service!;
        final dataKey = SyncCrypto.newDataKey();
        final salt = SyncCrypto.newSalt();
        final kek = await SyncCrypto.deriveKek(phrase.entropy, salt, kdfParams);
        final wrapped = await SyncCrypto.wrapDataKey(dataKey, kek);
        final stored = await service.insertKey(WrappedKey(wrappedKey: wrapped, salt: salt, params: kdfParams));
        if (!stored) {
          newPhrase = null;
          _set(SyncPhase.needsUnlock);
          throw const SyncServiceException(
              'Sync was set up from another device in the meantime. Enter that device\'s recovery phrase.');
        }
        newPhrase = null;
        final key = StoredKey(service.userId!, dataKey);
        await keyStore.write(key);
        await _activate(key);
      }).then((_) => phase == SyncPhase.active ? syncNow() : null);

  /// Unlocks sync on a new device with the account's recovery phrase.
  Future<void> unlock(String phraseText) => _action(() async {
        final phrase = RecoveryPhrase.parse(phraseText);
        final service = _service!;
        final wrapped = await service.fetchKey();
        if (wrapped == null) {
          _set(SyncPhase.needsSetup);
          throw const SyncServiceException('This account has no synced data yet. Set up sync instead.');
        }
        if (!wrapped.params.supported) {
          throw const SyncServiceException('This account\'s key needs a newer version of Bloom.');
        }
        final kek = await SyncCrypto.deriveKek(phrase.entropy, wrapped.salt, wrapped.params);
        final dataKey = await SyncCrypto.unwrapDataKey(wrapped.wrappedKey, kek);
        final key = StoredKey(service.userId!, dataKey);
        await keyStore.write(key);
        await _activate(key);
      }).then((_) => phase == SyncPhase.active ? syncNow() : null);

  Future<void> _activate(StoredKey key) async {
    final crypto = await SyncCrypto.fromDataKey(key.dataKey);
    var state = await _loadState();
    if (state == null || state.userId != key.userId) {
      // A different account than last time: start over.
      state = SyncState(userId: key.userId);
    }
    _state = state;
    _engine?.detach();
    _engine = SyncEngine(
      store: store,
      service: _service!,
      crypto: crypto,
      state: state,
      onLocalChange: _scheduleSync,
      onLocalReset: _onLocalReset,
    )..attach();
    _set(SyncPhase.active);
  }

  Future<SyncState?> _loadState() async {
    final raw = await stateStorage.read();
    if (raw == null) return null;
    try {
      return SyncState.decode(raw);
    } catch (e) {
      debugPrint('Starting sync state over: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------- running

  void _scheduleSync() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(syncNow()));
  }

  /// When the app comes back to the foreground.
  void onResume() {
    if (phase == SyncPhase.active) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), () => unawaited(syncNow()));
    }
  }

  /// Runs a sync now. Never throws; errors go to [syncError].
  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null || phase != SyncPhase.active) return;
    _timer?.cancel();
    syncing = true;
    notifyListeners();
    try {
      lastReport = await engine.sync();
      syncError = lastReport!.unreadable > 0
          ? '${lastReport!.unreadable} synced ${lastReport!.unreadable == 1 ? 'record' : 'records'} couldn\'t be read.'
          : null;
    } catch (e) {
      syncError = _describe(e);
      debugPrint('Sync failed: $e');
    } finally {
      syncing = false;
      await _saveState();
      notifyListeners();
    }
  }

  Future<void> _saveState() async {
    final s = _state;
    if (s != null) await stateStorage.write(s.encode());
  }

  // ---------------------------------------------------------------- off

  /// Turns sync off on this device: forgets the key and signs out. Data on
  /// this device and in the account stays. Signing back in to the same
  /// account later picks up where it left off.
  Future<void> signOut() => _action(() async {
        await _saveState();
        await _stop();
        await _service?.signOut();
        email = null;
        _set(SyncPhase.signedOut);
      });

  /// Deletes the account and everything synced to it. This device keeps its
  /// data.
  Future<void> deleteSyncedData() => _action(() async {
        await _service!.deleteAccount();
        await _stop();
        await stateStorage.clear();
        email = null;
        _set(SyncPhase.signedOut);
      });

  /// The user erased all data on this device: turn sync off here first, so
  /// the erase stays on this device.
  Future<void> _onLocalReset() async {
    await _stop();
    await stateStorage.clear();
    try {
      await _service?.signOut();
    } catch (e) {
      debugPrint('Sign-out after erase failed: $e');
    }
    email = null;
    _set(SyncPhase.signedOut);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _engine?.detach();
    _engine = null;
    _state = null;
    newPhrase = null;
    await keyStore.clear();
  }

  // ---------------------------------------------------------------- helpers

  Future<void> _action(Future<void> Function() run) async {
    busy = true;
    actionError = null;
    notifyListeners();
    try {
      await run();
    } catch (e) {
      actionError = _describe(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _set(SyncPhase p) {
    phase = p;
    notifyListeners();
  }

  static String _describe(Object e) => switch (e) {
        SyncServiceException() || InvalidPhraseException() || WrongPhraseException() => e.toString(),
        TimeoutException() => 'The server didn\'t answer. Check your connection.',
        _ when '$e'.contains('SocketException') || '$e'.contains('ClientException') =>
          'Bloom couldn\'t reach the sync server. Check your connection.',
        _ => 'Something went wrong: $e',
      };

  @override
  void dispose() {
    _timer?.cancel();
    _engine?.detach();
    super.dispose();
  }
}

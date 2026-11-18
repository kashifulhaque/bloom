/// Wires sync into the app: the controller for this platform, resume
/// handling, and the licenses of the bundled crypto pieces.
library;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/store.dart';
import '../../core/sync/crypto/bip39_english.dart';
import '../../core/sync/key_store.dart';
import '../../core/sync/supabase_connect.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/sync/sync_state.dart';

/// The app's sync controller. Without SUPABASE_URL and
/// SUPABASE_PUBLISHABLE_KEY in this build, it stays [SyncPhase.unconfigured].
SyncController createAppSyncController(AppStore store, {SyncConfig config = SyncConfig.fromEnvironment}) {
  _registerLicenses();
  return SyncController(
    store: store,
    connect: config.isConfigured ? () => connectSupabase(config) : null,
    keyStore: platformKeyStore(),
    stateStorage: PrefsSyncStateStorage(),
  );
}

bool _licensed = false;

void _registerLicenses() {
  if (_licensed) return;
  _licensed = true;
  LicenseRegistry.addLicense(() => Stream.value(const LicenseEntryWithLineBreaks(['BIP-39 wordlist'], bip39License)));
  if (kIsWeb) {
    LicenseRegistry.addLicense(() => Stream.value(const LicenseEntryWithLineBreaks(['libsodium.js', 'libsodium'], _isc)));
  }
}

const _isc = '''libsodium.js (web/sodium.js), which includes libsodium compiled to WebAssembly.
Copyright (c) 2015-2026 Ahmad Ben Mrad, Frank Denis, Ryan Lester. libsodium: Copyright (c) 2013-2026 Frank Denis.

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.''';

/// Starts sync after the first frame and syncs again when the app returns
/// to the foreground.
class SyncLifecycle extends StatefulWidget {
  const SyncLifecycle({super.key, required this.controller, required this.child});

  final SyncController controller;
  final Widget child;

  @override
  State<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends State<SyncLifecycle> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame, so launching the app never waits for sync.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.controller.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.onResume();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

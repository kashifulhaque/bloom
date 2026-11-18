import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'kdf.dart';

/// libsodium.js, once it has loaded.
JSObject? _sodium;
Future<JSObject?>? _loading;

/// How long to wait for `sodium.js` before falling back to Dart.
const _loadTimeout = Duration(seconds: 20);

Future<Uint8List> argon2id(Uint8List password, Uint8List salt, KdfParams params) async {
  final sodium = await (_loading ??= _load());
  if (sodium == null) return argon2idDart(password, salt, params);
  final alg = sodium.getProperty<JSNumber>('crypto_pwhash_ALG_ARGON2ID13'.toJS);
  final out = sodium.callMethodVarArgs<JSUint8Array>('crypto_pwhash'.toJS, [
    32.toJS,
    password.toJS,
    salt.toJS,
    params.iterations.toJS,
    (params.memKiB * 1024).toJS,
    alg,
  ]);
  return out.toDart;
}

/// Loads the self-hosted `sodium.js` (the libsodium.js "sumo" browser build)
/// the first time a key is derived. The rest of the app never loads it.
Future<JSObject?> _load() async {
  final existing = web.window.getProperty<JSAny?>('sodium'.toJS);
  if (existing != null && existing.isA<JSObject>() && (existing as JSObject).has('crypto_pwhash')) {
    return _sodium = existing;
  }
  final done = Completer<JSObject?>();
  // libsodium.js reads `window.sodium.onload` and calls it once it's ready.
  final config = JSObject()
    ..setProperty('onload'.toJS, ((JSObject s) {
      if (!done.isCompleted) done.complete(s);
    }).toJS);
  web.window.setProperty('sodium'.toJS, config);
  final script = web.HTMLScriptElement()
    ..src = 'sodium.js'
    ..async = true;
  script.onerror = ((web.Event _) {
    if (!done.isCompleted) done.complete(null);
  }).toJS;
  web.document.head!.append(script);
  try {
    return _sodium = await done.future.timeout(_loadTimeout, onTimeout: () => null);
  } finally {
    if (_sodium == null) {
      debugPrint('sodium.js didn\'t load; deriving the key in Dart, which is slower.');
      _loading = null; // Try again next time.
    }
  }
}

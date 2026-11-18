import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'key_store.dart';

KeyStore createKeyStore() => WebKeyStore();

/// IndexedDB plus WebCrypto.
///
/// IndexedDB holds a non-extractable AES-GCM `CryptoKey` and the data key
/// encrypted with it. WebCrypto can't hold an XChaCha20 key directly, so the
/// AES key wraps the data key instead. The browser can use the AES key but
/// never reveals its bytes, so a copy of the IndexedDB files alone doesn't
/// expose the data key.
class WebKeyStore implements KeyStore {
  WebKeyStore({this.dbName = 'bloom-sync'});

  final String dbName;
  static const _store = 'keys';
  static const _entry = 'data-key-v1';

  Future<web.IDBDatabase> _open() {
    final c = Completer<web.IDBDatabase>();
    final req = web.window.indexedDB.open(dbName, 1);
    req.onupgradeneeded = ((web.Event _) {
      (req.result as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    req.onsuccess = ((web.Event _) => c.complete(req.result as web.IDBDatabase)).toJS;
    req.onerror = ((web.Event _) => c.completeError(StateError('IndexedDB: ${req.error?.message}'))).toJS;
    return c.future;
  }

  Future<T?> _run<T extends JSAny?>(String mode, web.IDBRequest Function(web.IDBObjectStore s) op) async {
    final db = await _open();
    try {
      final c = Completer<T?>();
      final tx = db.transaction(_store.toJS, mode);
      final req = op(tx.objectStore(_store));
      tx.oncomplete = ((web.Event _) {
        if (!c.isCompleted) c.complete(req.result as T?);
      }).toJS;
      tx.onerror = ((web.Event _) {
        if (!c.isCompleted) c.completeError(StateError('IndexedDB: ${tx.error?.message}'));
      }).toJS;
      tx.onabort = tx.onerror;
      return await c.future;
    } finally {
      db.close();
    }
  }

  web.SubtleCrypto get _subtle => web.window.crypto.subtle;

  static JSObject _aesGcm(JSUint8Array iv) => JSObject()
    ..setProperty('name'.toJS, 'AES-GCM'.toJS)
    ..setProperty('iv'.toJS, iv);

  @override
  Future<StoredKey?> read() async {
    final entry = await _run<JSObject?>('readonly', (s) => s.get(_entry.toJS));
    if (entry == null) return null;
    final key = entry.getProperty<web.CryptoKey>('key'.toJS);
    final iv = entry.getProperty<JSUint8Array>('iv'.toJS);
    final data = entry.getProperty<JSUint8Array>('data'.toJS);
    final user = entry.getProperty<JSString>('user'.toJS).toDart;
    final plain = await _subtle
        .decrypt(_aesGcm(iv), key, data)
        .toDart;
    return StoredKey(user, (plain as JSArrayBuffer).toDart.asUint8List());
  }

  @override
  Future<void> write(StoredKey k) async {
    final aes = await _subtle
        .generateKey(
          JSObject()
            ..setProperty('name'.toJS, 'AES-GCM'.toJS)
            ..setProperty('length'.toJS, 256.toJS),
          false, // Not extractable.
          ['encrypt'.toJS, 'decrypt'.toJS].toJS,
        )
        .toDart as web.CryptoKey;
    final iv = Uint8List(12);
    web.window.crypto.getRandomValues(iv.toJS);
    final sealed = await _subtle
        .encrypt(_aesGcm(iv.toJS), aes, k.dataKey.toJS)
        .toDart as JSArrayBuffer;
    final entry = JSObject()
      ..setProperty('key'.toJS, aes)
      ..setProperty('iv'.toJS, iv.toJS)
      ..setProperty('data'.toJS, sealed.toDart.asUint8List().toJS)
      ..setProperty('user'.toJS, k.userId.toJS);
    await _run<JSAny?>('readwrite', (s) => s.put(entry, _entry.toJS));
  }

  @override
  Future<void> clear() => _run<JSAny?>('readwrite', (s) => s.delete(_entry.toJS));
}

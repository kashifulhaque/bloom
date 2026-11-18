/// End-to-end encryption for sync.
///
/// - A random 32-byte **data key** encrypts everything. It never leaves the
///   device unwrapped.
/// - Two subkeys come from the data key with HKDF-SHA256: one encrypts
///   records with XChaCha20-Poly1305, the other makes record ids with
///   HMAC-SHA256, so the server can't see which dates have logs.
/// - The recovery phrase's entropy and a random salt go through Argon2id to
///   make a **key-encryption key**, which wraps the data key for `sync_keys`.
///
/// Every box is `[format byte][24-byte nonce][ciphertext][16-byte tag]`. The
/// associated data binds a record's ciphertext to its kind, id, version, and
/// deleted flag, so the server can't swap rows or pair old content with a
/// new version without the tag failing.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'kdf.dart';

export 'kdf.dart' show KdfParams;

/// The ciphertext didn't verify: the wrong key, or data that was changed.
class SyncCryptoException implements Exception {
  const SyncCryptoException(this.message);
  final String message;
  @override
  String toString() => 'SyncCryptoException: $message';
}

/// The recovery phrase didn't unwrap the data key.
class WrongPhraseException implements Exception {
  const WrongPhraseException();
  @override
  String toString() => 'That recovery phrase doesn\'t match this account.';
}

class SyncCrypto {
  SyncCrypto._(this._encKey, this._idKey);

  static const format = 1;
  static const keyLength = 32;
  static const nonceLength = 24;
  static const tagLength = 16;
  static const saltLength = 16;

  /// The smallest possible box: format byte, nonce, and tag.
  static const overhead = 1 + nonceLength + tagLength;

  static final _aead = Xchacha20.poly1305Aead();
  static final _hmac = Hmac.sha256();

  final SecretKey _encKey;
  final SecretKey _idKey;

  /// Derives the record subkeys from a 32-byte data key.
  static Future<SyncCrypto> fromDataKey(Uint8List dataKey) async {
    if (dataKey.length != keyLength) throw ArgumentError('The data key must be $keyLength bytes');
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyLength);
    final master = SecretKeyData(dataKey);
    final enc = await hkdf.deriveKey(secretKey: master, nonce: const [], info: utf8.encode('bloom/v1/record-encryption'));
    final id = await hkdf.deriveKey(secretKey: master, nonce: const [], info: utf8.encode('bloom/v1/record-id'));
    return SyncCrypto._(enc, id);
  }

  static Uint8List randomBytes(int n, [Random? random]) {
    final r = random ?? Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  static Uint8List newDataKey() => randomBytes(keyLength);
  static Uint8List newSalt() => randomBytes(saltLength);

  /// The server-visible id of a record: base64url (no padding) of
  /// HMAC-SHA256(idKey, "kind\nkey"). 43 characters.
  Future<String> recordId(String kind, String key) async {
    final mac = await _hmac.calculateMac(utf8.encode('$kind\n$key'), secretKey: _idKey);
    return base64Url.encode(mac.bytes).replaceAll('=', '');
  }

  static List<int> _recordAad(String kind, String recordId, int version, bool deleted) =>
      utf8.encode('bloom/v1/record\n$kind\n$recordId\n$version\n${deleted ? 1 : 0}');

  /// Encrypts one record's plaintext.
  Future<Uint8List> seal({
    required String kind,
    required String recordId,
    required int version,
    required bool deleted,
    required List<int> plaintext,
  }) =>
      _seal(_encKey, plaintext, _recordAad(kind, recordId, version, deleted));

  /// Decrypts one record. Throws [SyncCryptoException] if anything doesn't
  /// match.
  Future<Uint8List> open({
    required String kind,
    required String recordId,
    required int version,
    required bool deleted,
    required Uint8List box,
  }) =>
      _open(_encKey, box, _recordAad(kind, recordId, version, deleted));

  // ---------------------------------------------------------------- data key

  static final _keyAad = utf8.encode('bloom/v1/data-key');

  /// Derives the key-encryption key from the phrase entropy.
  static Future<Uint8List> deriveKek(Uint8List entropy, Uint8List salt, KdfParams params) {
    if (salt.length != saltLength) throw ArgumentError('The salt must be $saltLength bytes');
    return argon2id(entropy, salt, params);
  }

  /// Wraps the data key for `sync_keys.wrapped_key` (73 bytes).
  static Future<Uint8List> wrapDataKey(Uint8List dataKey, Uint8List kek) =>
      _seal(SecretKeyData(kek), dataKey, _keyAad);

  /// Unwraps the data key. Throws [WrongPhraseException] when [kek] came from
  /// a different phrase.
  static Future<Uint8List> unwrapDataKey(Uint8List wrapped, Uint8List kek) async {
    try {
      final key = await _open(SecretKeyData(kek), wrapped, _keyAad);
      if (key.length != keyLength) throw const SyncCryptoException('Wrong key length');
      return key;
    } on SyncCryptoException {
      throw const WrongPhraseException();
    }
  }

  // ---------------------------------------------------------------- boxes

  /// Seals [plaintext] under a raw 32-byte [key] in the same box format as
  /// records. Report share links use it with a fresh key per link.
  static Future<Uint8List> sealWithKey(Uint8List key, List<int> plaintext, List<int> aad) {
    if (key.length != keyLength) throw ArgumentError('The key must be $keyLength bytes');
    return _seal(SecretKeyData(key), plaintext, aad);
  }

  /// Opens a box made by [sealWithKey]. Throws [SyncCryptoException] if the
  /// key, the associated data, or the box doesn't match.
  static Future<Uint8List> openWithKey(Uint8List key, Uint8List box, List<int> aad) {
    if (key.length != keyLength) throw const SyncCryptoException('Wrong key length');
    return _open(SecretKeyData(key), box, aad);
  }

  static Future<Uint8List> _seal(SecretKey key, List<int> plaintext, List<int> aad) async {
    final nonce = randomBytes(nonceLength);
    final box = await _aead.encrypt(plaintext, secretKey: key, nonce: nonce, aad: aad);
    return Uint8List.fromList([format, ...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> _open(SecretKey key, Uint8List data, List<int> aad) async {
    if (data.length < overhead) throw const SyncCryptoException('Too short');
    if (data[0] != format) throw SyncCryptoException('Unknown format ${data[0]}');
    final nonce = data.sublist(1, 1 + nonceLength);
    final cipherText = data.sublist(1 + nonceLength, data.length - tagLength);
    final mac = Mac(data.sublist(data.length - tagLength));
    try {
      final plain = await _aead.decrypt(SecretBox(cipherText, nonce: nonce, mac: mac), secretKey: key, aad: aad);
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const SyncCryptoException('The tag didn\'t verify');
    }
  }
}

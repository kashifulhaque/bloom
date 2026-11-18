/// End-to-end encryption for report share links.
///
/// Each link gets a fresh random 32-byte key. The report PDF is sealed with
/// XChaCha20-Poly1305 in the same box format as sync records, and the key
/// travels only in the link's URL fragment
/// (`https://bloom.ifkash.dev/r/<id>#<key>`), which browsers never send to a
/// server. The viewer page in `web/r/` opens the box with libsodium.js.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/sync/crypto/sync_crypto.dart';

export '../../../core/sync/crypto/sync_crypto.dart' show SyncCryptoException;

/// A report sealed for upload, and the key that opens it.
class SealedReport {
  const SealedReport({required this.key, required this.box});
  final Uint8List key;
  final Uint8List box;
}

abstract final class ReportShareCrypto {
  /// Associated data that binds a box to report sharing, so a sync record
  /// can't be passed off as a report, or the reverse.
  static final aad = utf8.encode('bloom/v1/report-share');

  /// Encrypts [pdf] with a new random key.
  static Future<SealedReport> seal(Uint8List pdf, {Uint8List? key}) async {
    final k = key ?? SyncCrypto.newDataKey();
    return SealedReport(key: k, box: await SyncCrypto.sealWithKey(k, pdf, aad));
  }

  /// Decrypts a box. Throws [SyncCryptoException] for a wrong key or a
  /// changed box.
  static Future<Uint8List> open(Uint8List box, Uint8List key) => SyncCrypto.openWithKey(key, box, aad);

  /// The key as it appears in a link: base64url without padding (43
  /// characters).
  static String encodeKey(Uint8List key) => base64Url.encode(key).replaceAll('=', '');

  /// Reads a key from a link fragment. Throws [FormatException] if it isn't
  /// a 32-byte base64url value.
  static Uint8List decodeKey(String text) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(text)) throw const FormatException('Not a report key');
    return base64Url.decode('$text=');
  }
}

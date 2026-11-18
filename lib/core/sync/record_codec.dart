/// Turns store records into encrypted rows and back.
///
/// A record's plaintext is canonical JSON: `{"k": key, "v": value}`, with map
/// keys sorted at every level and a day log's option lists sorted (they're
/// sets). A deleted record (a tombstone) has `"v": null`. The plaintext key
/// travels inside the ciphertext, because the server only sees its HMAC.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import '../sync_records.dart';
import 'crypto/sync_crypto.dart';
import 'sync_models.dart';

/// A row that couldn't be decrypted or parsed.
class RecordFormatException implements Exception {
  const RecordFormatException(this.message);
  final String message;
  @override
  String toString() => 'RecordFormatException: $message';
}

class DecodedRecord {
  const DecodedRecord(this.ref, this.value);
  final SyncRef ref;
  final Object? value;
}

class RecordCodec {
  RecordCodec(this.crypto);

  final SyncCrypto crypto;

  /// Canonical JSON for [value] in a record of [kind].
  static String canonical(SyncKind kind, Object? value) =>
      jsonEncode(_sorted(kind == SyncKind.day ? _sortDaySelections(value) : value));

  /// A short hash of a record's canonical plaintext, for change detection.
  /// Null for a deleted record.
  static String? fingerprint(SyncKind kind, Object? value) {
    if (value == null) return null;
    final hash = const DartSha256().hashSync(utf8.encode(canonical(kind, value))).bytes;
    return base64Url.encode(hash.sublist(0, 12));
  }

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is Iterable) return [for (final e in v) _sorted(e)];
    return v;
  }

  static Object? _sortDaySelections(Object? v) {
    if (v is! Map || v['selections'] is! Map) return v;
    final sel = v['selections'] as Map;
    return {
      ...v,
      'selections': {
        for (final e in sel.entries) e.key: (List<Object?>.from(e.value as Iterable)..sort((a, b) => '$a'.compareTo('$b'))),
      },
    };
  }

  Future<String> recordId(SyncRef ref) => crypto.recordId(ref.kind.name, ref.key);

  /// Encrypts [value] (null for a tombstone) as a row ready to upload.
  Future<RemoteRow> encode(SyncRef ref, Object? value, {required int version, String? recordId}) async {
    final rid = recordId ?? await this.recordId(ref);
    final deleted = value == null;
    final plaintext = utf8.encode('{"k":${jsonEncode(ref.key)},"v":${canonical(ref.kind, value)}}');
    final box = await crypto.seal(
      kind: ref.kind.name,
      recordId: rid,
      version: version,
      deleted: deleted,
      plaintext: plaintext,
    );
    return RemoteRow(kind: ref.kind.name, recordId: rid, version: version, deleted: deleted, ciphertext: box);
  }

  /// Decrypts a downloaded row. Throws [RecordFormatException] or
  /// [SyncCryptoException] when it can't be trusted.
  Future<DecodedRecord> decode(RemoteRow row) async {
    final kind = SyncKind.values.asNameMap()[row.kind];
    if (kind == null) throw RecordFormatException('Unknown kind ${row.kind}');
    final Uint8List plain = await crypto.open(
      kind: row.kind,
      recordId: row.recordId,
      version: row.version,
      deleted: row.deleted,
      box: row.ciphertext,
    );
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(plain));
    } on FormatException catch (e) {
      throw RecordFormatException('Bad JSON: ${e.message}');
    }
    if (json is! Map || json['k'] is! String) throw const RecordFormatException('Missing key');
    final ref = SyncRef(kind, json['k'] as String);
    // The id is an HMAC of the key, so a mismatch means a forged or mixed-up row.
    if (await recordId(ref) != row.recordId) throw const RecordFormatException('The id doesn\'t match the key');
    final value = json['v'];
    if (row.deleted != (value == null)) throw const RecordFormatException('Deleted flag mismatch');
    return DecodedRecord(ref, value);
  }
}

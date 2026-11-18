/// Data types shared by the sync engine, its backends, and its state.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'crypto/kdf.dart';

/// One row of `public.sync_records`, as the client sends or receives it.
class RemoteRow {
  const RemoteRow({
    required this.kind,
    required this.recordId,
    required this.version,
    required this.deleted,
    required this.ciphertext,
    this.updatedAt,
  });

  final String kind;
  final String recordId;
  final int version;
  final bool deleted;
  final Uint8List ciphertext;

  /// The server's `updated_at`, exactly as the server sent it. Null on rows
  /// the client is about to send.
  final String? updatedAt;

  /// `kind:recordId`.
  String get id => '$kind:$recordId';
}

/// The server's answer for an accepted write.
class RowVersion {
  const RowVersion(this.kind, this.recordId, this.version);
  final String kind;
  final String recordId;
  final int version;
  String get id => '$kind:$recordId';
}

/// A position in the pull order `(updated_at, record_id)`.
class PullCursor {
  const PullCursor(this.updatedAt, this.recordId);
  final String updatedAt;
  final String recordId;

  Map<String, String> toJson() => {'at': updatedAt, 'id': recordId};

  static PullCursor? fromJson(Object? j) =>
      j is Map ? PullCursor(j['at'] as String, j['id'] as String) : null;
}

/// One row of `public.sync_keys`.
class WrappedKey {
  const WrappedKey({required this.wrappedKey, required this.salt, required this.params});
  final Uint8List wrappedKey;
  final Uint8List salt;
  final KdfParams params;
}

/// What this device knows about one record.
class RecordMeta {
  RecordMeta({required this.version, this.dirty = false, this.deleted = false, this.fingerprint, this.recordId});

  /// The record's current HLC version on this device.
  int version;

  /// True when this version still has to be uploaded.
  bool dirty;

  bool deleted;

  /// A hash of the record's plaintext when [version] was set. A change in the
  /// hash means the record changed and needs a new version.
  String? fingerprint;

  /// The server-visible id, cached so it isn't recomputed.
  String? recordId;

  List<Object?> toJson() => [version, dirty ? 1 : 0, deleted ? 1 : 0, fingerprint, recordId];

  factory RecordMeta.fromJson(List<dynamic> j) => RecordMeta(
        version: j[0] as int,
        dirty: j[1] == 1,
        deleted: j[2] == 1,
        fingerprint: j[3] as String?,
        recordId: j[4] as String?,
      );
}

/// Bytea values travel through the Data API as `\x`-prefixed hex.
String byteaToHex(Uint8List bytes) {
  final b = StringBuffer(r'\x');
  for (final x in bytes) {
    b.write(x.toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

Uint8List byteaFromJson(Object? value) {
  if (value is! String) throw FormatException('Expected bytea, got ${value.runtimeType}');
  if (value.startsWith(r'\x')) {
    final hex = value.substring(2);
    if (hex.length.isOdd) throw const FormatException('Odd bytea hex length');
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
  return base64.decode(value);
}

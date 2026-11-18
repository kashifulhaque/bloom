/// The release manifest that the web host serves at
/// `/downloads/manifest.json`, and a fetcher for it.
///
/// Shape:
///
/// ```json
/// {
///   "version": "1.0.0+42",
///   "builtAt": "2026-11-18T10:00:00Z",
///   "apk": {"file": "bloom.apk", "bytes": 21456789, "sha256": "<64 hex>"},
///   "ipa": {"file": "bloom-unsigned.ipa", "bytes": 19876543, "sha256": "<64 hex>"},
///   "signingCertSha256": "8F:F7:...:74",
///   "notes": "Add an update nudge"
/// }
/// ```
///
/// `version` and at least one of `apk` or `ipa` are required. A file entry
/// with a bad name, size, or hash is dropped. `notes`, a short summary of
/// the release, is optional.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// The manifest's path on the web host.
const String kManifestPath = '/downloads/manifest.json';

/// One downloadable file.
class DownloadFile {
  const DownloadFile({required this.file, required this.bytes, required this.sha256});

  /// The file name inside `/downloads/`, such as `bloom.apk`.
  final String file;
  final int bytes;

  /// The SHA-256 hash, lowercase hex.
  final String sha256;

  /// The path on the web host.
  String get path => '/downloads/$file';

  static final _name = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
  static final _hex = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Parses an entry, or returns null when it's missing or malformed.
  static DownloadFile? tryParse(Object? j) {
    if (j is! Map) return null;
    final file = j['file'], bytes = j['bytes'], hash = j['sha256'];
    if (file is! String || !_name.hasMatch(file) || file.contains('..')) return null;
    if (bytes is! int || bytes <= 0) return null;
    if (hash is! String || !_hex.hasMatch(hash)) return null;
    return DownloadFile(file: file, bytes: bytes, sha256: hash.toLowerCase());
  }
}

/// A parsed `/downloads/manifest.json`.
class DownloadManifest {
  const DownloadManifest({
    required this.version,
    this.builtAt,
    this.apk,
    this.ipa,
    this.signingCertSha256,
    this.notes,
  });

  /// The app version, such as `1.0.0+42`.
  final String version;
  final DateTime? builtAt;
  final DownloadFile? apk;
  final DownloadFile? ipa;

  /// The SHA-256 fingerprint of the APK signing certificate, as
  /// colon-separated uppercase hex.
  final String? signingCertSha256;

  /// A one-line summary of the release, such as the latest commit's subject.
  /// Null when the manifest has none.
  final String? notes;

  /// The longest [notes] kept, in characters.
  static const maxNotesLength = 200;

  static final _fingerprint = RegExp(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){31}$');

  /// Parses [json], or returns null when it isn't a usable manifest.
  static DownloadManifest? tryParse(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    if (version is! String || version.trim().isEmpty) return null;
    final apk = DownloadFile.tryParse(json['apk']);
    final ipa = DownloadFile.tryParse(json['ipa']);
    if (apk == null && ipa == null) return null;
    final built = json['builtAt'];
    final cert = json['signingCertSha256'];
    return DownloadManifest(
      notes: _notes(json['notes']),
      version: version.trim(),
      builtAt: built is String ? DateTime.tryParse(built) : null,
      apk: apk,
      ipa: ipa,
      signingCertSha256: cert is String && _fingerprint.hasMatch(cert.trim()) ? cert.trim().toUpperCase() : null,
    );
  }

  /// Collapses [raw] to one trimmed line of at most [maxNotesLength]
  /// characters, or returns null when it isn't a non-empty string.
  static String? _notes(Object? raw) {
    if (raw is! String) return null;
    final line = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ').replaceAll(RegExp(r' {2,}'), ' ').trim();
    if (line.isEmpty) return null;
    return line.length <= maxNotesLength ? line : '${line.substring(0, maxNotesLength - 1).trimRight()}…';
  }

  /// Parses a response body, or returns null when it isn't valid JSON or
  /// a usable manifest.
  static DownloadManifest? tryParseBody(String body) {
    try {
      return tryParse(jsonDecode(body));
    } on FormatException {
      return null;
    }
  }
}

/// Loads the manifest. Returns null when there isn't one.
typedef ManifestLoader = Future<DownloadManifest?> Function();

/// Fetches the manifest from the same origin as the page ([base], which
/// defaults to [Uri.base]). Returns null when it's missing, malformed, or
/// unreachable.
Future<DownloadManifest?> fetchDownloadManifest({http.Client? client, Uri? base}) async {
  final c = client ?? http.Client();
  try {
    final res = await c
        // no-cache makes a browser revalidate its cached copy, so a check
        // never reads a stale manifest. It sends nothing about the user.
        .get(
          (base ?? Uri.base).resolve(kManifestPath),
          headers: {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return DownloadManifest.tryParseBody(utf8.decode(res.bodyBytes, allowMalformed: true));
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// A file size for people: `21.5 MB`.
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes bytes';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).toStringAsFixed(0)} KB';
  return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
}

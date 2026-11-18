/// Detects what a picked file is and runs the matching parser.
///
/// Everything works through [ImportFile], so the same code runs in a
/// background isolate on Android and iOS, on the web's main thread, and in
/// tests. Nothing here sends data anywhere.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;

import 'apple_health_parser.dart';
import 'clue_parser.dart';
import 'csv_parser.dart';
import 'flo_parser.dart';
import 'import_data.dart';
import 'import_file.dart';
import 'mensinator_parser.dart';
import 'zip_reader.dart';

/// Largest JSON or CSV file Bloom reads whole. Real Clue, Flo, and drip
/// exports are far smaller.
const maxTextBytes = 150 * 1024 * 1024;

/// Largest encrypted ZIP Bloom decrypts. Decryption needs the whole archive
/// in memory.
const maxEncryptedZipBytes = 150 * 1024 * 1024;

/// Why a file can't be imported. The UI explains each case.
enum UnsupportedReason { empty, pdf, healthConnect, bloomBackup, unknownZip, unknownJson, notText, tooLarge }

/// What [inspectImportFile] found.
class FileInspection {
  const FileInspection._({
    this.format,
    this.entry,
    this.needsPassword = false,
    this.unsupported,
    this.csvHeader = const [],
    this.csvSample = const [],
  });

  const FileInspection.recognized(ImportFormat format, {String? entry})
      : this._(format: format, entry: entry);

  /// An encrypted ZIP. Its format is known only after decryption.
  const FileInspection.encrypted(String entry) : this._(entry: entry, needsPassword: true);

  const FileInspection.csv(List<String> header, List<List<String>> sample)
      : this._(format: ImportFormat.genericCsv, csvHeader: header, csvSample: sample);

  const FileInspection.unsupported(UnsupportedReason reason) : this._(unsupported: reason);

  /// Null while the file needs a password or isn't supported.
  final ImportFormat? format;

  /// The ZIP entry to read, when the file is a ZIP.
  final String? entry;
  final bool needsPassword;
  final UnsupportedReason? unsupported;

  /// The header and first rows of a generic CSV, for the mapping step.
  final List<String> csvHeader;
  final List<List<String>> csvSample;
}

/// Options for [runImport].
class ImportRequest {
  const ImportRequest({this.password, this.csvMapping, this.today});

  /// The password of an encrypted Clue or Flo ZIP.
  final String? password;

  /// The column mapping for a generic CSV.
  final CsvMapping? csvMapping;

  /// Overrides "today", for tests. Days after it are skipped.
  final DateTime? today;
}

/// Reports progress from 0 to 1.
typedef ImportProgress = void Function(double fraction);

/// Called between chunks of a large file. On the web it waits for the next
/// event-loop turn, so the page can draw frames while a large export is
/// read.
typedef ImportBreather = Future<void> Function();

/// Works out what [file] is, without reading more than it must: the start of
/// the file, and for a ZIP its directory and one small entry.
Future<FileInspection> inspectImportFile(ImportFile file) async {
  if (file.length == 0) return const FileInspection.unsupported(UnsupportedReason.empty);
  final head = await file.read(0, file.length < 4096 ? file.length : 4096);

  if (looksLikeZip(head)) return _inspectZip(file);
  if (_startsWith(head, '%PDF')) return const FileInspection.unsupported(UnsupportedReason.pdf);
  if (_startsWith(head, 'SQLite format 3')) return const FileInspection.unsupported(UnsupportedReason.healthConnect);

  final text = _headText(head);
  if (text == null) return const FileInspection.unsupported(UnsupportedReason.notText);
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('<')) {
    return trimmed.contains('HealthData')
        ? const FileInspection.recognized(ImportFormat.appleHealth)
        : const FileInspection.unsupported(UnsupportedReason.unknownJson);
  }
  if (file.length > maxTextBytes) return const FileInspection.unsupported(UnsupportedReason.tooLarge);
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return _inspectJson(await _readText(file));
  }
  return _inspectCsv(await _readText(file));
}

Future<FileInspection> _inspectZip(ImportFile file) async {
  final entries = (await readZipDirectory(file)).where((e) => !e.isDirectory && !_isJunk(e.name)).toList();
  if (entries.isEmpty) return const FileInspection.unsupported(UnsupportedReason.empty);

  final health = entries.where((e) => e.baseName == 'export.xml').firstOrNull;
  if (health != null) return FileInspection.recognized(ImportFormat.appleHealth, entry: health.name);
  if (entries.any((e) => e.baseName.endsWith('.db') || e.baseName.contains('health_connect'))) {
    return const FileInspection.unsupported(UnsupportedReason.healthConnect);
  }

  final candidate = _pickDataEntry(entries);
  if (candidate == null) return const FileInspection.unsupported(UnsupportedReason.unknownZip);
  if (candidate.encrypted) return FileInspection.encrypted(candidate.name);
  if (candidate.size > maxTextBytes) return const FileInspection.unsupported(UnsupportedReason.tooLarge);
  final text = await _decodeUtf8(openZipEntry(file, candidate));
  final inner = candidate.baseName.endsWith('.csv') ? _inspectCsv(text) : _inspectJson(text);
  if (inner.format == null) return inner;
  return FileInspection._(
    format: inner.format,
    entry: candidate.name,
    csvHeader: inner.csvHeader,
    csvSample: inner.csvSample,
  );
}

/// The entry most likely to hold the data: Clue's `measurements.json`, then
/// the largest JSON (or `.cluedata`) file, then the largest CSV.
ZipEntry? _pickDataEntry(List<ZipEntry> entries) {
  final measurements = entries.where((e) => e.baseName == 'measurements.json').firstOrNull;
  if (measurements != null) return measurements;
  ZipEntry? largest(bool Function(ZipEntry) test) {
    final list = entries.where(test).toList()..sort((a, b) => b.size.compareTo(a.size));
    return list.firstOrNull;
  }

  return largest((e) => e.baseName.endsWith('.json') || e.baseName.endsWith('.cluedata')) ??
      largest((e) => e.baseName.endsWith('.csv'));
}

bool _isJunk(String name) => name.startsWith('__MACOSX/') || name.split('/').last.startsWith('.');

FileInspection _inspectJson(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return const FileInspection.unsupported(UnsupportedReason.unknownJson);
  }
  final format = detectJsonFormat(json);
  if (format != null) return FileInspection.recognized(format);
  if (json is Map && json['app'] == 'bloom') return const FileInspection.unsupported(UnsupportedReason.bloomBackup);
  return const FileInspection.unsupported(UnsupportedReason.unknownJson);
}

/// Recognizes a decoded JSON export, or returns null.
ImportFormat? detectJsonFormat(Object? json) {
  if (json is List) {
    if (json.isEmpty) return ImportFormat.clue;
    final first = json.firstWhere((e) => e is Map, orElse: () => null);
    if (first is Map && first.containsKey('type') && first.containsKey('date')) return ImportFormat.clue;
    return null;
  }
  if (json is! Map) return null;
  if (json['operationalData'] is Map) return ImportFormat.flo;
  if (json['periods'] is List && (json.containsKey('symptom_date') || json.containsKey('symptoms'))) {
    return ImportFormat.mensinator;
  }
  if (json['data'] is List && json['app'] != 'bloom') return ImportFormat.clueLegacy;
  return null;
}

FileInspection _inspectCsv(String text) {
  final rows = parseCsv(text);
  if (rows.isEmpty) return const FileInspection.unsupported(UnsupportedReason.empty);
  final header = rows.first.map((h) => h.trim()).toList();
  if (isDripHeader(header)) return const FileInspection.recognized(ImportFormat.drip);
  if (header.length < 2 && rows.length < 2) return const FileInspection.unsupported(UnsupportedReason.notText);
  return FileInspection.csv(header, rows.skip(1).take(5).toList());
}

/// Reads [file] as described by [inspection] and returns the mapped data.
///
/// Throws [ImportException] with a message for the user when the file can't
/// be read, and `wrongPassword` set when an encrypted archive needs a
/// (different) password.
Future<ImportedData> runImport(
  ImportFile file,
  FileInspection inspection,
  ImportRequest request, {
  ImportProgress? onProgress,
  ImportBreather? breathe,
}) async {
  if (inspection.unsupported != null) throw const ImportException('Bloom can\'t read this file.');
  try {
    if (inspection.needsPassword) return await _runEncrypted(file, inspection, request, onProgress);
    final format = inspection.format!;
    if (format == ImportFormat.appleHealth) return await _runAppleHealth(file, inspection, request, onProgress, breathe);

    final String text;
    if (inspection.entry != null) {
      final entry = (await readZipDirectory(file)).firstWhere((e) => e.name == inspection.entry);
      text = await _decodeUtf8(openZipEntry(file, entry));
    } else {
      text = await _readText(file);
    }
    onProgress?.call(0.6);
    final result = parseText(format, text, request);
    onProgress?.call(1);
    return result;
  } on ImportException {
    rethrow;
  } on FormatException catch (e) {
    throw ImportException('Bloom couldn\'t read this file. ${e.message}');
  }
}

/// Parses the text of a JSON or CSV export.
ImportedData parseText(ImportFormat format, String text, ImportRequest request) {
  final today = request.today;
  if (format == ImportFormat.drip) return parseDrip(text, today: today);
  if (format == ImportFormat.genericCsv) {
    final mapping = request.csvMapping;
    if (mapping == null) throw const ImportException('Choose which column holds the date.');
    return parseGenericCsv(text, mapping, today: today);
  }
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const ImportException('This file isn\'t valid JSON. It may be incomplete.');
  }
  return parseJson(format, json, today: today);
}

ImportedData parseJson(ImportFormat format, Object? json, {DateTime? today}) => switch (format) {
      ImportFormat.clue || ImportFormat.clueLegacy => parseClue(json, today: today),
      ImportFormat.flo => parseFlo(json, today: today),
      ImportFormat.mensinator => parseMensinator(json, today: today),
      _ => throw ImportException('Bloom can\'t read ${format.label} files as JSON.'),
    };

Future<ImportedData> _runAppleHealth(
  ImportFile file,
  FileInspection inspection,
  ImportRequest request,
  ImportProgress? onProgress,
  ImportBreather? breathe,
) async {
  final Stream<List<int>> bytes;
  if (inspection.entry != null) {
    final entry = (await readZipDirectory(file)).firstWhere((e) => e.name == inspection.entry);
    final total = entry.compressedSize == 0 ? 1 : entry.compressedSize;
    bytes = openZipEntry(file, entry, onRead: (read) => onProgress?.call(read / total));
  } else {
    var read = 0;
    final total = file.length;
    bytes = file.openRead().map((c) {
      read += c.length;
      onProgress?.call(read / total);
      return c;
    });
  }
  final parser = AppleHealthParser(today: request.today);
  var n = 0;
  await for (final chunk in bytes.transform(const Utf8Decoder(allowMalformed: true))) {
    parser.add(chunk);
    if (breathe != null && ++n % 4 == 0) await breathe();
  }
  return parser.finish();
}

Future<ImportedData> _runEncrypted(
  ImportFile file,
  FileInspection inspection,
  ImportRequest request,
  ImportProgress? onProgress,
) async {
  final password = request.password ?? '';
  if (password.isEmpty) {
    throw const ImportException('This file is locked with a password.', wrongPassword: true);
  }
  if (file.length > maxEncryptedZipBytes) {
    throw const ImportException('This locked file is too large for Bloom to open. Unzip it first, then choose the file inside.');
  }
  final bytes = await file.read(0, file.length);
  onProgress?.call(0.3);
  final Uint8List content;
  try {
    final archive = zip.ZipDecoder().decodeBytes(bytes, password: password);
    final entry = archive.findFile(inspection.entry!);
    final data = entry?.readBytes();
    if (data == null) throw const ImportException('Bloom couldn\'t find the data inside this file.');
    content = data;
  } on zip.ArchivePasswordException {
    throw const ImportException('That password didn\'t open the file. Check it and try again.', wrongPassword: true);
  } on zip.ArchiveException catch (e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('password') || msg.contains('mac') || msg.contains('crc')) {
      throw const ImportException('That password didn\'t open the file. Check it and try again.', wrongPassword: true);
    }
    throw ImportException('Bloom couldn\'t open this ZIP file. ${e.message}');
  }
  onProgress?.call(0.6);
  final text = utf8.decode(content, allowMalformed: true);
  final ImportFormat format;
  if (inspection.entry!.toLowerCase().endsWith('.csv')) {
    format = isDripHeader(parseCsv(text).firstOrNull ?? const []) ? ImportFormat.drip : ImportFormat.genericCsv;
    if (format == ImportFormat.genericCsv) {
      throw const ImportException('Unzip this file first, then choose the CSV file inside.');
    }
  } else {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const ImportException('The file inside isn\'t valid JSON. It may be incomplete.');
    }
    format = detectJsonFormat(json) ?? (throw const ImportException('Bloom didn\'t recognize the data inside this file.'));
    final result = parseJson(format, json, today: request.today);
    onProgress?.call(1);
    return result;
  }
  final result = parseText(format, text, request);
  onProgress?.call(1);
  return result;
}

Future<String> _readText(ImportFile file) async {
  if (file.length > maxTextBytes) {
    throw const ImportException('This file is too large for Bloom to read.');
  }
  return _decodeUtf8(file.openRead());
}

Future<String> _decodeUtf8(Stream<List<int>> bytes) async {
  final out = StringBuffer();
  await for (final s in bytes.transform(const Utf8Decoder(allowMalformed: true))) {
    out.write(s);
  }
  final text = out.toString();
  return text.startsWith('﻿') ? text.substring(1) : text;
}

bool _startsWith(Uint8List head, String ascii) {
  if (head.length < ascii.length) return false;
  for (var i = 0; i < ascii.length; i++) {
    if (head[i] != ascii.codeUnitAt(i)) return false;
  }
  return true;
}

/// Decodes the start of a file as UTF-8 (or UTF-8 with a byte order mark).
/// Returns null when it holds binary data.
String? _headText(Uint8List head) {
  final text = utf8.decode(head, allowMalformed: true);
  final bad = '�'.allMatches(text).length + RegExp(r'[\x00-\x08\x0E-\x1F]').allMatches(text).length;
  // A multibyte character cut at the 4 KB boundary leaves one replacement
  // character at the end; binary data leaves many.
  if (bad > 2) return null;
  return text.startsWith('﻿') ? text.substring(1) : text;
}

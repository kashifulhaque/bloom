/// Export helpers: CSV of daily logs and saving files on web and Android.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/store.dart';

/// Builds a CSV with one row per day that has a log or a period day.
/// Values are metric; choice categories list option labels separated by `; `.
String buildLogsCsv(AppStore store) {
  final keys = {...store.logs.keys, ...store.periodDays}.toList()..sort();
  final header = [
    'date',
    'period',
    for (final c in kCategories) c.id,
    for (final m in kMetrics) '${m.id} (${m.unit})',
    'note',
  ];
  final rows = <List<String>>[header];
  for (final k in keys) {
    final log = store.logs[k];
    rows.add([
      k,
      store.periodDays.contains(k) ? 'yes' : '',
      for (final c in kCategories) (log?.get(c.id) ?? const <String>{}).map((o) => optionLabel(c.id, o)).join('; '),
      for (final m in kMetrics) _num(log?.metrics[m.id]),
      log?.note ?? '',
    ]);
  }
  return rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
}

String _num(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

String _csvCell(String v) {
  if (v.contains(RegExp(r'[",\r\n]'))) return '"${v.replaceAll('"', '""')}"';
  return v;
}

/// File name stamped with today's date, such as `bloom-backup-2026-03-14.json`.
String datedFileName(String base, String ext) => '$base-${dayKey(DateTime.now())}.$ext';

/// Saves [text] as a file. On the web this downloads it; on Android it opens
/// the system save dialog, falling back to the share sheet. Returns false
/// when the user cancels.
Future<bool> saveTextFile({required String fileName, required String text, required String mimeType}) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  try {
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
    return uri != null;
  } catch (_) {
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
      subject: fileName,
    ));
    return result.status != ShareResultStatus.dismissed;
  }
}

/// Lets the user pick a backup file and returns its text, or null on cancel.
Future<String?> pickTextFile() async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  if (files.isEmpty) return null;
  final bytes = await files.first.readAsBytes();
  return utf8.decode(bytes);
}

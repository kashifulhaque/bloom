// Streaming an Apple Health export from a ZIP, with no dart:io in the test,
// so it also runs in a browser, where inflating uses DecompressionStream:
//
//   flutter test --platform chrome test/import/streaming_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bloom/features/import/import_data.dart';
import 'package:bloom/features/import/import_file.dart';
import 'package:bloom/features/import/import_runner.dart';
import 'package:flutter_test/flutter_test.dart';

String record(String type, String day, String value, {String extra = ''}) =>
    ' <Record type="$type" sourceName="Health" startDate="$day 12:00:00 +0000" endDate="$day 12:00:00 +0000" value="$value"$extra/>\n';

void main() {
  test('a deflated export.xml streams through the platform inflater', () async {
    final xml = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<HealthData locale="en_US">\n');
    // About 3 MB of unrelated records around a few flow records, so the
    // entry spans many chunks on both sides of the inflater.
    for (var i = 0; i < 15000; i++) {
      xml.write(record('HKQuantityTypeIdentifierStepCount', '2024-01-01', '$i'));
      if (i == 7000) {
        xml
          ..write(record('HKCategoryTypeIdentifierMenstrualFlow', '2024-01-05', 'HKCategoryValueMenstrualFlowHeavy'))
          ..write(record('HKCategoryTypeIdentifierMenstrualFlow', '2024-01-06', 'HKCategoryValueMenstrualFlowLight'));
      }
    }
    xml.write('</HealthData>\n');
    final archive = Archive()..add(ArchiveFile.bytes('apple_health_export/export.xml', utf8.encode(xml.toString())));
    final zip = BytesImportFile('export.zip', ZipEncoder().encodeBytes(archive));
    expect(zip.length, lessThan(xml.length ~/ 5), reason: 'the entry is compressed');

    final inspection = await inspectImportFile(zip);
    expect(inspection.format, ImportFormat.appleHealth);
    final d = await runImport(zip, inspection, ImportRequest(today: DateTime(2025)));
    expect(d.periodDays, {'2024-01-05', '2024-01-06'});
    expect(d.logs['2024-01-05']!.get('flow'), {'heavy'});
    expect(d.unrelatedRecords, 15000);
  });

  test('damaged compressed data fails with a message', () async {
    final archive = Archive()..add(ArchiveFile.bytes('export.xml', utf8.encode('<HealthData>${'x' * 5000}</HealthData>')));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    // Scramble the deflate stream, which starts after the 30-byte header
    // and the 10-byte name.
    for (var i = 45; i < 80; i++) {
      bytes[i] ^= 0x5a;
    }
    final zip = BytesImportFile('export.zip', bytes);
    final inspection = await inspectImportFile(zip);
    expect(() => runImport(zip, inspection, const ImportRequest()), throwsA(isA<Exception>()));
  });
}

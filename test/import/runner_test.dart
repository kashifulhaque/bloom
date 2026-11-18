// Tests for file detection, the ZIP reader, encrypted archives, and the
// end-to-end runner, with archives built from the synthetic fixtures.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bloom/features/import/import_data.dart';
import 'package:bloom/features/import/import_file.dart';
import 'package:bloom/features/import/import_runner.dart';
import 'package:bloom/features/import/zip_reader.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2025, 1, 1);

Uint8List fixtureBytes(String name) => File('test/import/fixtures/$name').readAsBytesSync();

BytesImportFile file(String name, List<int> bytes) => BytesImportFile(name, Uint8List.fromList(bytes));

Uint8List zipOf(Map<String, List<int>> files, {String? password, bool store = false}) {
  final archive = Archive();
  for (final e in files.entries) {
    final f = ArchiveFile.bytes(e.key, e.value);
    if (store) f.compression = CompressionType.none;
    archive.add(f);
  }
  return ZipEncoder(password: password).encodeBytes(archive);
}

Future<ImportedData> importFile(ImportFile f, {String? password}) async {
  final inspection = await inspectImportFile(f);
  return runImport(f, inspection, ImportRequest(password: password, today: today));
}

void main() {
  group('detection', () {
    test('recognizes each fixture by its contents, not its name', () async {
      final cases = {
        'apple_health_export.xml': ImportFormat.appleHealth,
        'clue_measurements.json': ImportFormat.clue,
        'clue_legacy.cluedata': ImportFormat.clueLegacy,
        'flo_export.json': ImportFormat.flo,
        'mensinator_export.json': ImportFormat.mensinator,
        'drip_export.csv': ImportFormat.drip,
        'generic_days.csv': ImportFormat.genericCsv,
      };
      for (final e in cases.entries) {
        final i = await inspectImportFile(file('download.bin', fixtureBytes(e.key)));
        expect(i.format, e.value, reason: e.key);
      }
    });

    test('a generic CSV comes with its header and sample rows', () async {
      final i = await inspectImportFile(file('periods.csv', fixtureBytes('generic_days.csv')));
      expect(i.csvHeader, ['Date', 'Flow', 'Notes']);
      expect(i.csvSample.first.first, '2024-06-01');
    });

    test('explains files it can\'t read', () async {
      Future<UnsupportedReason?> reason(List<int> bytes) async => (await inspectImportFile(file('f', bytes))).unsupported;
      expect(await reason(const []), UnsupportedReason.empty);
      expect(await reason(utf8.encode('%PDF-1.7 ...')), UnsupportedReason.pdf);
      expect(await reason(utf8.encode('SQLite format 3\u0000....')), UnsupportedReason.healthConnect);
      expect(await reason(utf8.encode('{"app":"bloom","schema":1}')), UnsupportedReason.bloomBackup);
      expect(await reason(utf8.encode('{"foo": 1}')), UnsupportedReason.unknownJson);
      expect(await reason(utf8.encode('{"truncated": [')), UnsupportedReason.unknownJson);
      expect(await reason(utf8.encode('<?xml version="1.0"?><gpx></gpx>')), UnsupportedReason.unknownJson);
      expect(await reason(List.generate(600, (i) => (i * 7919) % 256)), UnsupportedReason.notText);
      expect(await reason(zipOf({'readme.txt': utf8.encode('hi')})), UnsupportedReason.unknownZip);
      expect(await reason(zipOf({'Health Connect/health_connect_export.db': utf8.encode('SQLite format 3')})),
          UnsupportedReason.healthConnect);
    });

    test('a damaged ZIP throws a FormatException', () async {
      final zip = zipOf({'measurements.json': fixtureBytes('clue_measurements.json')});
      expect(() => inspectImportFile(file('cut.zip', zip.sublist(0, zip.length ~/ 2))), throwsFormatException);
    });
  });

  group('ZIP reader', () {
    test('lists entries and streams deflated and stored ones', () async {
      final xml = fixtureBytes('apple_health_export.xml');
      for (final store in [false, true]) {
        final zip = file('export.zip', zipOf({'apple_health_export/export.xml': xml, 'apple_health_export/export_cda.xml': [1]}, store: store));
        final entries = await readZipDirectory(zip);
        expect(entries.map((e) => e.name), contains('apple_health_export/export.xml'));
        final entry = entries.firstWhere((e) => e.baseName == 'export.xml');
        expect(entry.method, store ? 0 : 8);
        final out = <int>[];
        await for (final c in openZipEntry(zip, entry)) {
          out.addAll(c);
        }
        expect(out, xml);
      }
    });

    test('reads ZIP64 sizes and offsets', () async {
      // A hand-built ZIP64 archive with one stored entry, as tools write
      // when an entry passes 4 GB.
      final data = utf8.encode('hello');
      final name = utf8.encode('measurements.json');
      final b = BytesBuilder();
      void u16(int v) => b.add([v & 0xff, v >> 8 & 0xff]);
      void u32(int v) => b.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
      void u64(int v) {
        u32(v);
        u32(0);
      }

      // Local header.
      u32(0x04034b50); u16(45); u16(0); u16(0); u32(0); u32(0); u32(0xffffffff); u32(0xffffffff);
      u16(name.length); u16(20); b.add(name); u16(1); u16(16); u64(data.length); u64(data.length);
      b.add(data);
      final cdStart = b.length;
      u32(0x02014b50); u16(45); u16(45); u16(0); u16(0); u32(0); u32(0);
      u32(0xffffffff); u32(0xffffffff); u16(name.length); u16(28); u16(0); u16(0); u16(0); u32(0); u32(0xffffffff);
      b.add(name);
      u16(1); u16(24); u64(data.length); u64(data.length); u64(0);
      final cdSize = b.length - cdStart;
      final z64 = b.length;
      u32(0x06064b50); u64(44); u16(45); u16(45); u32(0); u32(0); u64(1); u64(1); u64(cdSize); u64(cdStart);
      u32(0x07064b50); u32(0); u64(z64); u32(1);
      u32(0x06054b50); u16(0); u16(0); u16(0xffff); u16(0xffff); u32(0xffffffff); u32(0xffffffff); u16(0);

      final zip = file('z64.zip', b.toBytes());
      final entries = await readZipDirectory(zip);
      expect(entries.single.size, 5);
      final out = <int>[];
      await for (final c in openZipEntry(zip, entries.single)) {
        out.addAll(c);
      }
      expect(utf8.decode(out), 'hello');
    });
  });

  group('runner', () {
    test('Apple Health export.zip streams to the same result as export.xml', () async {
      final xml = fixtureBytes('apple_health_export.xml');
      final zipped = await importFile(file('export.zip', zipOf({'apple_health_export/export.xml': xml})));
      final plain = await importFile(file('export.xml', xml));
      expect(zipped.format, ImportFormat.appleHealth);
      expect(zipped.periodDays, plain.periodDays);
      expect(zipped.logs.length, plain.logs.length);
      expect(zipped.periodCount, 2);
    });

    test('reports progress up to 1 and pauses between chunks', () async {
      // Pad the export so it spans many chunks.
      final xml = utf8.decode(fixtureBytes('apple_health_export.xml'));
      final pad = List.filled(4000, ' <Record type="HKQuantityTypeIdentifierStepCount" startDate="2024-03-01 09:00:00 +0200" value="1"/>\n').join();
      final big = xml.replaceFirst(' <Workout', '$pad <Workout');
      final f = file('export.zip', zipOf({'apple_health_export/export.xml': utf8.encode(big)}));
      final progress = <double>[];
      var pauses = 0;
      final d = await runImport(f, await inspectImportFile(f), ImportRequest(today: today),
          onProgress: progress.add, breathe: () async => pauses++);
      expect(d.unrelatedRecords, 4002);
      expect(progress.last, closeTo(1, 1e-9));
      expect(pauses, greaterThan(0));
    });

    test('Clue ZIP with a password', () async {
      final zip = file('clue.zip', zipOf({'measurements.json': fixtureBytes('clue_measurements.json')}, password: 'tulip-42'));
      final inspection = await inspectImportFile(zip);
      expect(inspection.needsPassword, isTrue);
      expect(inspection.entry, 'measurements.json');

      Future<Object?> attempt(String? pw) async {
        try {
          return await runImport(zip, inspection, ImportRequest(password: pw, today: today));
        } on ImportException catch (e) {
          return e;
        }
      }

      expect((await attempt(null) as ImportException).wrongPassword, isTrue);
      expect((await attempt('wrong') as ImportException).wrongPassword, isTrue);
      final d = await attempt('tulip-42') as ImportedData;
      expect(d.format, ImportFormat.clue);
      expect(d.periodCount, 2);
    });

    test('Flo ZIP with a password, among other files', () async {
      final zip = file('flo.zip', zipOf({
        'export/readme.txt': utf8.encode('Your data'),
        'export/data.json': fixtureBytes('flo_export.json'),
      }, password: 'secret'));
      final d = await importFile(zip, password: 'secret');
      expect(d.format, ImportFormat.flo);
      expect(d.periodCount, 3);
    });

    test('an unencrypted ZIP with JSON inside', () async {
      final zip = file('m.zip', zipOf({'mensinator.json': fixtureBytes('mensinator_export.json')}));
      final i = await inspectImportFile(zip);
      expect(i.format, ImportFormat.mensinator);
      expect(i.entry, 'mensinator.json');
      final d = await runImport(zip, i, ImportRequest(today: today));
      expect(d.periodDays.length, 3);
    });

    test('a generic CSV needs a mapping', () async {
      final f = file('p.csv', fixtureBytes('generic_days.csv'));
      final i = await inspectImportFile(f);
      expect(() => runImport(f, i, ImportRequest(today: today)), throwsA(isA<ImportException>()));
    });
  });
}

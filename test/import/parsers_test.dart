// Unit tests for the import parsers, against the synthetic fixtures in
// test/import/fixtures/. None of them is real user data.
import 'dart:convert';
import 'dart:io';

import 'package:bloom/features/import/apple_health_parser.dart';
import 'package:bloom/features/import/clue_parser.dart';
import 'package:bloom/features/import/csv_parser.dart';
import 'package:bloom/features/import/flo_parser.dart';
import 'package:bloom/features/import/import_data.dart';
import 'package:bloom/features/import/mensinator_parser.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2025, 1, 1);

String fixture(String name) => File('test/import/fixtures/$name').readAsStringSync();

Set<String> sel(ImportedData d, String day, String category) => d.logs[day]?.selections[category] ?? const {};

ImportedData parseAppleText(String xml, {int? chunk}) {
  final p = AppleHealthParser(today: today);
  if (chunk == null) {
    p.add(xml);
  } else {
    for (var i = 0; i < xml.length; i += chunk) {
      p.add(xml.substring(i, i + chunk > xml.length ? xml.length : i + chunk));
    }
  }
  return p.finish();
}

void main() {
  group('Apple Health', () {
    late ImportedData d;
    setUpAll(() => d = parseAppleText(fixture('apple_health_export.xml')));

    test('maps flow levels, including the iOS 18 enum names', () {
      expect(sel(d, '2024-03-02', 'flow'), {'medium'});
      expect(sel(d, '2024-03-03', 'flow'), {'heavy'});
      expect(sel(d, '2024-03-04', 'flow'), {'light'});
      expect(sel(d, '2024-03-05', 'flow'), isEmpty, reason: 'Unspecified flow is a period day without a level');
      expect(d.periodDays, {'2024-03-02', '2024-03-03', '2024-03-04', '2024-03-05', '2024-03-31', '2024-04-01'});
      expect(d.periodCount, 2);
      expect(d.skipped['Days logged as "no flow"'], 1);
    });

    test('maps spotting, tests, sex, mucus, and symptoms', () {
      expect(sel(d, '2024-03-15', 'flow'), {'spotting'});
      expect(d.periodDays.contains('2024-03-15'), isFalse);
      expect(sel(d, '2024-03-16', 'ovulation_test'), {'negative'});
      expect(sel(d, '2024-03-17', 'ovulation_test'), {'positive'});
      expect(sel(d, '2024-03-30', 'pregnancy_test'), {'negative'});
      expect(sel(d, '2024-03-17', 'sex'), {'protected'});
      expect(sel(d, '2024-03-16', 'discharge'), {'egg_white'});
      expect(sel(d, '2024-03-02', 'symptoms'), {'cramps', 'headache'});
      expect(sel(d, '2024-03-03', 'mood'), {'swings'});
      expect(sel(d, '2024-03-03', 'digestion'), isEmpty);
    });

    test('keeps the earliest temperature and converts °F', () {
      expect(d.logs['2024-03-16']!.metrics['bbt'], 36.42);
      expect(d.logs['2024-03-19']!.metrics['bbt'], closeTo(36.72, 0.001));
      expect(d.adjusted['Extra temperatures on the same day (kept the earliest)'], 1);
    });

    test('counts everything it leaves out', () {
      expect(d.skipped['Ovulation tests showing an estrogen surge'], 1);
      expect(d.skipped['Sexual activity with no protection recorded'], 1);
      expect(d.skipped['Symptoms marked "not present"'], 1);
      expect(d.skipped['Appetite changes'], 1);
      expect(d.unrelatedRecords, 2, reason: 'steps and heart rate');
      expect(d.recordsRead, 23);
    });

    test('gives the same result whatever the chunk size', () {
      final xml = fixture('apple_health_export.xml');
      for (final size in [1, 7, 64, 1000]) {
        final c = parseAppleText(xml, chunk: size);
        expect(jsonEncode(c.logs.map((k, v) => MapEntry(k, v.toJson()))),
            jsonEncode(d.logs.map((k, v) => MapEntry(k, v.toJson()))),
            reason: 'chunk $size');
        expect(c.periodDays, d.periodDays);
        expect(c.skipped, d.skipped);
      }
    });

    test('rejects XML that is not a Health export', () {
      expect(() => parseAppleText('<?xml version="1.0"?><Other><Record type="x"/></Other>'),
          throwsA(isA<ImportException>()));
    });

    test('an export with no records is empty', () {
      final e = parseAppleText('<?xml version="1.0"?>\n<HealthData locale="en_US">\n</HealthData>\n');
      expect(e.isEmpty, isTrue);
    });

    test('a file cut off mid-record reports the lost record', () {
      final xml = fixture('apple_health_export.xml');
      final cut = xml.substring(0, xml.indexOf('value="HKCategoryValueMenstrualFlowLight"'));
      final e = parseAppleText(cut);
      expect(e.skipped['A record cut off at the end of the file'], 1);
      expect(e.periodDays.contains('2024-03-31'), isFalse);
    });

    test('skips days after today', () {
      final p = AppleHealthParser(today: DateTime(2024, 3, 3))..add(fixture('apple_health_export.xml'));
      final e = p.finish();
      expect(e.periodDays, {'2024-03-02', '2024-03-03'});
      expect(e.skipped['Health records dated after today'], greaterThan(0));
    });
  });

  group('Clue', () {
    test('reads the current measurements.json', () {
      final d = parseClue(jsonDecode(fixture('clue_measurements.json')), today: today);
      expect(d.format, ImportFormat.clue);
      expect(sel(d, '2024-02-01', 'flow'), {'medium'});
      expect(sel(d, '2024-02-02', 'flow'), {'heavy'});
      expect(d.adjusted['Very heavy flow, saved as heavy'], 1);
      expect(sel(d, '2024-02-10', 'flow'), {'spotting'});
      expect(d.periodCount, 2);
      expect(sel(d, '2024-02-01', 'symptoms'), {'cramps', 'headache'});
      expect(sel(d, '2024-02-02', 'mood'), {'sad'});
      expect(sel(d, '2024-02-02', 'symptoms'), {'fatigue'});
      expect(d.logs['2024-02-14']!.metrics['bbt'], 36.55);
      expect(sel(d, '2024-02-14', 'discharge'), {'egg_white'});
      expect(sel(d, '2024-02-14', 'ovulation_test'), {'positive'});
      expect(sel(d, '2024-02-14', 'sex'), {'protected', 'high_drive'});
      expect(sel(d, '2024-02-16', 'digestion'), {'bloating'});
      expect(sel(d, '2024-02-16', 'pill'), {'taken'});
      expect(d.skipped['Pain: ovulation'], 1);
      expect(d.skipped['Feelings: sensitive'], 1);
      expect(d.skipped['Custom tags: beach day'], 1);
      expect(d.skipped['Temperatures you excluded in Clue'], 1);
      expect(d.skipped['Entries with a date Bloom couldn\'t read'], 1);
    });

    test('reads the older .cluedata backup', () {
      final d = parseClue(jsonDecode(fixture('clue_legacy.cluedata')), today: today);
      expect(d.format, ImportFormat.clueLegacy);
      expect(sel(d, '2023-11-05', 'flow'), {'heavy'});
      expect(sel(d, '2023-11-05', 'symptoms'), {'cramps', 'headache'});
      expect(sel(d, '2023-11-06', 'symptoms'), {'acne'});
      expect(sel(d, '2023-11-07', 'flow'), {'spotting'});
      expect(d.periodCount, 1);
      expect(d.skipped['Sleep: 6 to 9 hours'], 1);
    });

    test('empty and malformed input', () {
      expect(parseClue(const [], today: today).isEmpty, isTrue);
      final junk = parseClue([1, 'x', null, <String, Object>{}], today: today);
      expect(junk.isEmpty, isTrue);
      expect(junk.skippedCount, 4);
      expect(() => parseClue({'other': 1}), throwsA(isA<ImportException>()));
      expect(() => parseClue('text'), throwsA(isA<ImportException>()));
    });
  });

  group('Flo', () {
    test('turns cycles into period days and maps known events', () {
      final d = parseFlo(jsonDecode(fixture('flo_export.json')), today: today);
      expect(d.periodCount, 3);
      expect(d.periodDays.length, 11);
      expect(d.periodDays, containsAll(['2024-01-03', '2024-01-07', '2024-02-04', '2024-02-28']));
      expect(d.logs['2024-01-03']?.get('flow') ?? const <String>{}, isEmpty, reason: 'Flo has no flow levels');
      expect(sel(d, '2024-01-17', 'ovulation_test'), {'positive'});
      expect(sel(d, '2024-02-14', 'ovulation_test'), {'my_method'});
      expect(d.skipped['Symptom: cramps'], 1);
      expect(d.skipped['Mood: happy'], 1);
      expect(d.skipped['Periods with a date Bloom couldn\'t read'], 1);
      expect(d.adjusted['Periods with no end date, saved as one day'], 1);
    });

    test('caps very long periods', () {
      final d = parseFlo({
        'operationalData': {
          'cycles': [
            {'period_start_date': '2024-01-01', 'period_end_date': '2024-03-01'},
          ],
        },
      }, today: today);
      expect(d.periodDays.length, 15);
      expect(d.adjusted.keys.single, startsWith('Periods longer than'));
    });

    test('empty and malformed input', () {
      expect(() => parseFlo({'operationalData': <String, Object>{}}), throwsA(isA<ImportException>()));
      expect(() => parseFlo({'cycles': []}), throwsA(isA<ImportException>()));
      final empty = parseFlo({
        'operationalData': {'cycles': [], 'point_events_manual_v2': []},
      }, today: today);
      expect(empty.isEmpty, isTrue);
    });
  });

  group('Mensinator', () {
    test('reads periods, flow and named symptoms, and ovulations', () {
      final d = parseMensinator(jsonDecode(fixture('mensinator_export.json')), today: today);
      expect(d.periodDays, {'2024-05-01', '2024-05-02', '2024-05-03'});
      expect(sel(d, '2024-05-01', 'flow'), {'heavy'});
      expect(sel(d, '2024-05-02', 'symptoms'), {'headache'});
      expect(sel(d, '2024-05-15', 'ovulation_test'), {'my_method'});
      expect(d.skipped['Symptom: Sore knee'], 1);
    });

    test('malformed input', () {
      expect(() => parseMensinator({'symptoms': []}), throwsA(isA<ImportException>()));
      expect(parseMensinator({'periods': []}, today: today).isEmpty, isTrue);
    });
  });

  group('drip', () {
    test('maps bleeding, temperature, mucus, sex, pain, mood, and notes', () {
      final d = parseDrip(fixture('drip_export.csv'), today: today);
      expect(sel(d, '2024-04-01', 'flow'), {'heavy'});
      expect(sel(d, '2024-04-02', 'flow'), {'light'});
      expect(sel(d, '2024-04-03', 'flow'), {'spotting'});
      expect(d.periodDays, {'2024-04-01', '2024-04-02'});
      expect(sel(d, '2024-03-25', 'flow'), {'spotting'});
      expect(d.adjusted['Bleeding you excluded from cycles in drip, saved as spotting'], 1);
      expect(d.logs['2024-04-20']!.metrics['bbt'], 36.85);
      expect(sel(d, '2024-04-20', 'discharge'), {'egg_white'});
      expect(sel(d, '2024-04-20', 'sex'), {'high_drive', 'protected'});
      expect(sel(d, '2024-04-01', 'symptoms'), {'cramps', 'headache'});
      expect(sel(d, '2024-04-01', 'mood'), {'sad', 'calm'});
      expect(sel(d, '2024-04-01', 'sex'), {'masturbation'});
      expect(d.logs['2024-04-01']!.note, 'first day, heavy');
      expect(d.logs['2024-04-02']!.note, 'Temperature: woke early, then slept');
      expect(d.skipped['Temperatures you excluded in drip'], 1);
      expect(d.skipped['Cervical mucus feeling'], 1);
      expect(d.skipped['Cervix observations'], 1);
      expect(d.skipped['Pain: ovulation pain'], 1);
      expect(d.skipped['Mood: fine'], 1);
      expect(d.skipped['Sex with no contraception recorded'], 1);
    });

    test('header only, and a file that is not drip', () {
      final header = fixture('drip_export.csv').split('\n').first;
      expect(parseDrip(header, today: today).isEmpty, isTrue);
      expect(() => parseDrip('date,flow\n2024-01-01,light'), throwsA(isA<ImportException>()));
      expect(() => parseDrip(''), throwsA(isA<ImportException>()));
    });
  });

  group('Generic CSV', () {
    test('tokenizer handles quotes, separators, line endings, and a BOM', () {
      expect(parseCsv('﻿a,b\r\n"x, y","say ""hi"""\n\n1,2'), [
        ['a', 'b'],
        ['x, y', 'say "hi"'],
        ['1', '2'],
      ]);
      expect(parseCsv('a;b\n1;2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(parseCsv('a\tb\n"multi\nline"\t2'), [
        ['a', 'b'],
        ['multi\nline', '2'],
      ]);
      expect(parseCsv(''), isEmpty);
    });

    test('guesses the mapping for one row per day', () {
      final rows = parseCsv(fixture('generic_days.csv'));
      final m = guessCsvMapping(rows.first, rows.skip(1).toList())!;
      expect(m.date, 0);
      expect(m.flow, 1);
      expect(m.note, 2);
      expect(m.endDate, isNull);
      expect(m.dateFormat, CsvDateFormat.iso);

      final d = parseGenericCsv(fixture('generic_days.csv'), m, today: today);
      expect(sel(d, '2024-06-01', 'flow'), {'medium'});
      expect(sel(d, '2024-06-02', 'flow'), {'heavy'});
      expect(sel(d, '2024-06-03', 'flow'), {'medium'});
      expect(d.periodDays, {'2024-06-01', '2024-06-02', '2024-06-03', '2024-06-04'});
      expect(sel(d, '2024-06-15', 'flow'), {'spotting'});
      expect(d.logs['2024-06-01']!.note, 'Started, with cramps');
      expect(d.skipped['Flow values Bloom didn\'t recognize ("purple")'], 1);
    });

    test('guesses the mapping for one row per period, with day-first dates', () {
      final rows = parseCsv(fixture('generic_ranges.csv'));
      final m = guessCsvMapping(rows.first, rows.skip(1).toList())!;
      expect(m.date, 0);
      expect(m.endDate, 1);
      expect(m.temperature, 2);
      expect(m.dateFormat, CsvDateFormat.dayMonthYear);

      final d = parseGenericCsv(fixture('generic_ranges.csv'), m, today: today);
      expect(d.periodCount, 2);
      expect(d.periodDays.length, 9);
      expect(d.periodDays, containsAll(['2024-05-03', '2024-05-07', '2024-05-31', '2024-06-03']));
      expect(d.logs['2024-05-31']!.metrics['bbt'], 36.6);
    });

    test('dates', () {
      expect(parseCsvDate('2024-02-29', CsvDateFormat.iso), '2024-02-29');
      expect(parseCsvDate('2023-02-29', CsvDateFormat.iso), isNull);
      expect(parseCsvDate('03/04/2024', CsvDateFormat.dayMonthYear), '2024-04-03');
      expect(parseCsvDate('03/04/2024', CsvDateFormat.monthDayYear), '2024-03-04');
      expect(parseCsvDate('3.4.24', CsvDateFormat.dayMonthYear), '2024-04-03');
      expect(parseCsvDate('yesterday', CsvDateFormat.iso), isNull);
      expect(guessDateFormat(['12/25/2024', '01/02/2024']), CsvDateFormat.monthDayYear);
    });

    test('flow cells', () {
      expect(readFlowCell('Heavy'), 'heavy');
      expect(readFlowCell(' 1 '), 'light');
      expect(readFlowCell('x'), 'period');
      expect(readFlowCell('no'), '');
      expect(readFlowCell('lots'), isNull);
    });

    test('no usable rows, and no date column', () {
      expect(() => parseGenericCsv('Date,Flow', const CsvMapping(date: 0, flow: 1)), throwsA(isA<ImportException>()));
      expect(guessCsvMapping(['Flow', 'Mood'], const []), isNull);
      final d = parseGenericCsv('Date,Flow\nsoon,heavy\n', const CsvMapping(date: 0, flow: 1), today: today);
      expect(d.isEmpty, isTrue);
      expect(d.skipped['Rows with a date Bloom couldn\'t read'], 1);
    });
  });

  group('ImportBuilder', () {
    test('a heavier flow wins and spotting never overrides a period day', () {
      final b = ImportBuilder(ImportFormat.genericCsv, today: today)
        ..flow('2024-01-01', 'light')
        ..flow('2024-01-01', 'heavy')
        ..flow('2024-01-01', 'medium')
        ..flow('2024-01-01', 'spotting')
        ..flow('2024-01-02', 'spotting')
        ..period('2024-01-02')
        ..option('2024-01-03', 'ovulation_test', 'positive')
        ..option('2024-01-03', 'ovulation_test', 'negative');
      final d = b.build();
      expect(sel(d, '2024-01-01', 'flow'), {'heavy'});
      expect(sel(d, '2024-01-02', 'flow'), isEmpty);
      expect(d.periodDays, {'2024-01-01', '2024-01-02'});
      expect(sel(d, '2024-01-03', 'ovulation_test'), {'positive'});
    });

    test('temperatures outside Bloom\'s range are counted, not kept', () {
      final d = (ImportBuilder(ImportFormat.genericCsv, today: today)..bbt('2024-01-01', 41)).build();
      expect(d.isEmpty, isTrue);
      expect(d.skipped['Temperatures outside 35 to 38.5 °C'], 1);
    });
  });
}

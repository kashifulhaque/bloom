/// CSV reading for imports: a tokenizer, drip's export, and a generic
/// "date plus flow" file with a user-chosen column mapping.
library;

import '../../core/dates.dart';
import 'import_data.dart';

// ---------------------------------------------------------------- tokenizer

/// Parses CSV [text] into rows of cells (RFC 4180: quoted cells may hold the
/// separator, quotes doubled as `""`, and line breaks). Strips a UTF-8 byte
/// order mark. When [separator] is null, it's guessed from the first line:
/// `,`, `;` (common in European spreadsheets), or a tab.
List<List<String>> parseCsv(String text, {String? separator}) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final sep = (separator ?? guessSeparator(text)).codeUnitAt(0);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var i = 0;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (quoted) {
      if (c == 0x22) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x22) {
          cell.writeCharCode(0x22);
          i += 2;
          continue;
        }
        quoted = false;
      } else {
        cell.writeCharCode(c);
      }
      i++;
      continue;
    }
    if (c == 0x22 && cell.isEmpty) {
      quoted = true;
    } else if (c == sep) {
      row.add(cell.toString());
      cell.clear();
    } else if (c == 0x0a || c == 0x0d) {
      row.add(cell.toString());
      cell.clear();
      if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
      row = <String>[];
      if (c == 0x0d && i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0a) i++;
    } else {
      cell.writeCharCode(c);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
  }
  return rows;
}

String guessSeparator(String text) {
  final end = text.indexOf('\n');
  final first = end < 0 ? text : text.substring(0, end);
  var best = ',';
  var bestCount = 0;
  for (final s in const [',', ';', '\t']) {
    final n = s.allMatches(first).length;
    if (n > bestCount) {
      best = s;
      bestCount = n;
    }
  }
  return best;
}

String _norm(String header) => header.trim().toLowerCase();

// ---------------------------------------------------------------- drip

/// True when [header] is drip's export header.
bool isDripHeader(List<String> header) {
  final h = header.map(_norm).toSet();
  return h.contains('date') && h.contains('bleeding.value') && h.contains('temperature.value');
}

/// Parses drip's CSV export. Columns are `date`, then `group.field` cells
/// such as `bleeding.value` (0 spotting, 1 light, 2 medium, 3 heavy),
/// `temperature.value` (°C), and `true`/`false` flags for `sex.*`, `pain.*`,
/// and `mood.*`. See `docs/IMPORT_FORMATS.md`.
ImportedData parseDrip(String text, {DateTime? today}) {
  final rows = parseCsv(text, separator: ',');
  if (rows.isEmpty || !isDripHeader(rows.first)) {
    throw const ImportException('This file doesn\'t look like a drip export.');
  }
  final header = rows.first.map(_norm).toList();
  final b = ImportBuilder(ImportFormat.drip, today: today);
  for (final r in rows.skip(1)) {
    b.records++;
    final cells = <String, String>{
      for (var i = 0; i < header.length && i < r.length; i++)
        if (r[i].trim().isNotEmpty) header[i]: r[i].trim(),
    };
    final day = b.day(isoDayKey(cells['date']), what: 'Rows');
    if (day == null) continue;
    _dripRow(b, day, cells);
  }
  return b.build();
}

bool _true(String? v) => v != null && v.toLowerCase() == 'true';

void _dripRow(ImportBuilder b, String day, Map<String, String> c) {
  // Bleeding.
  final bleeding = int.tryParse(c['bleeding.value'] ?? '');
  if (bleeding != null) {
    const levels = ['spotting', 'light', 'medium', 'heavy'];
    if (bleeding < 0 || bleeding > 3) {
      b.skip('Bleeding with an unknown value');
    } else if (_true(c['bleeding.exclude']) && bleeding > 0) {
      b.flow(day, 'spotting');
      b.adjust('Bleeding you excluded from cycles in drip, saved as spotting');
    } else {
      b.flow(day, levels[bleeding]);
    }
  }

  // Temperature.
  final temp = double.tryParse(c['temperature.value'] ?? '');
  if (temp != null) {
    if (_true(c['temperature.exclude'])) {
      b.skip('Temperatures you excluded in drip');
    } else {
      b.bbt(day, temp);
    }
  }

  // Cervical mucus: texture maps to discharge; the feeling and drip's
  // computed score don't have a place in Bloom.
  switch (c['mucus.texture']) {
    case '0':
      b.option(day, 'discharge', 'none');
    case '1':
      b.option(day, 'discharge', 'creamy');
    case '2':
      b.option(day, 'discharge', 'egg_white');
  }
  if (c.containsKey('mucus.feeling')) b.skip('Cervical mucus feeling');
  if (c.containsKey('cervix.opening') || c.containsKey('cervix.firmness') || c.containsKey('cervix.position')) {
    b.skip('Cervix observations');
  }

  // Desire.
  switch (c['desire.value']) {
    case '0':
      b.option(day, 'sex', 'low_drive');
    case '1':
      b.option(day, 'sex', 'neutral_drive');
    case '2':
      b.option(day, 'sex', 'high_drive');
  }

  // Sex.
  if (_true(c['sex.solo'])) b.option(day, 'sex', 'masturbation');
  if (_true(c['sex.partner'])) {
    const methods = ['sex.condom', 'sex.pill', 'sex.iud', 'sex.patch', 'sex.ring', 'sex.implant', 'sex.diaphragm'];
    if (methods.any((m) => _true(c[m]))) {
      b.option(day, 'sex', 'protected');
    } else if (_true(c['sex.none'])) {
      b.option(day, 'sex', 'unprotected');
    } else {
      b.skip('Sex with no contraception recorded');
    }
  }
  if (_true(c['sex.other'])) b.skip('Sex: other contraception');

  // Pain and mood flags.
  const pain = {
    'pain.cramps': ('symptoms', 'cramps'),
    'pain.headache': ('symptoms', 'headache'),
    'pain.backache': ('symptoms', 'backache'),
    'pain.nausea': ('digestion', 'nausea'),
    'pain.tenderbreasts': ('symptoms', 'tender_breasts'),
    'pain.migraine': ('symptoms', 'migraine'),
  };
  const mood = {
    'mood.happy': ('mood', 'happy'),
    'mood.sad': ('mood', 'sad'),
    'mood.stressed': ('other', 'stress'),
    'mood.balanced': ('mood', 'calm'),
    'mood.anxious': ('mood', 'anxious'),
    'mood.energetic': ('mood', 'energetic'),
    'mood.fatigue': ('symptoms', 'fatigue'),
    'mood.angry': ('mood', 'irritated'),
  };
  for (final e in {...pain, ...mood}.entries) {
    if (_true(c[e.key])) b.option(day, e.value.$1, e.value.$2);
  }
  if (_true(c['pain.ovulationpain'])) b.skip('Pain: ovulation pain');
  if (_true(c['pain.other'])) b.skip('Pain: other');
  if (_true(c['mood.fine'])) b.skip('Mood: fine');
  if (_true(c['mood.other'])) b.skip('Mood: other');

  // Notes.
  final notes = [
    c['note.value'],
    if (c['temperature.note'] != null) 'Temperature: ${c['temperature.note']}',
    if (c['sex.note'] != null) 'Sex: ${c['sex.note']}',
    if (c['pain.note'] != null) 'Pain: ${c['pain.note']}',
    if (c['mood.note'] != null) 'Mood: ${c['mood.note']}',
  ];
  for (final n in notes) {
    if (n != null) b.note(day, n);
  }
}

// ---------------------------------------------------------------- generic CSV

/// How dates are written in a generic CSV.
enum CsvDateFormat { iso, dayMonthYear, monthDayYear }

extension CsvDateFormatLabel on CsvDateFormat {
  String get label => switch (this) {
        CsvDateFormat.iso => '2024-03-14',
        CsvDateFormat.dayMonthYear => '14/03/2024',
        CsvDateFormat.monthDayYear => '03/14/2024',
      };
}

/// Which columns of a generic CSV hold what. Column values are indexes into
/// the header row; null means "not in this file".
class CsvMapping {
  const CsvMapping({
    required this.date,
    this.flow,
    this.endDate,
    this.temperature,
    this.note,
    this.dateFormat = CsvDateFormat.iso,
  });

  /// The date, or the first day of a period when [endDate] is set.
  final int date;

  /// Flow or bleeding: a level (`spotting`, `light`, `medium`, `heavy`), a
  /// number (0 to 3, or 1 to 4), or a yes/no mark.
  final int? flow;

  /// The last day of a period, for files with one row per period.
  final int? endDate;

  /// Basal body temperature, in °C or °F (values above 50 are read as °F).
  final int? temperature;
  final int? note;
  final CsvDateFormat dateFormat;

  CsvMapping copyWith({
    int? date,
    int? Function()? flow,
    int? Function()? endDate,
    int? Function()? temperature,
    int? Function()? note,
    CsvDateFormat? dateFormat,
  }) =>
      CsvMapping(
        date: date ?? this.date,
        flow: flow == null ? this.flow : flow(),
        endDate: endDate == null ? this.endDate : endDate(),
        temperature: temperature == null ? this.temperature : temperature(),
        note: note == null ? this.note : note(),
        dateFormat: dateFormat ?? this.dateFormat,
      );

  /// Whether the mapping can import anything: a date plus at least one
  /// column with data.
  bool get usable => flow != null || endDate != null || temperature != null || note != null;
}

/// Guesses a mapping from the header names and the first rows, or returns
/// null when no column looks like a date.
CsvMapping? guessCsvMapping(List<String> header, List<List<String>> sample) {
  int? find(List<String> names) {
    for (final n in names) {
      for (var i = 0; i < header.length; i++) {
        if (_norm(header[i]) == n) return i;
      }
    }
    for (final n in names) {
      for (var i = 0; i < header.length; i++) {
        if (_norm(header[i]).contains(n)) return i;
      }
    }
    return null;
  }

  final start = find(['start date', 'period start', 'start', 'from']);
  final end = find(['end date', 'period end', 'end', 'to']);
  final rangeMode = start != null && end != null && start != end;
  final date = rangeMode ? start : find(['date', 'day', 'datum', 'fecha']) ?? start;
  if (date == null) return null;
  final flow = find(['flow', 'bleeding', 'period', 'menstruation', 'menstrual flow', 'blood']);
  final temp = find(['basal body temperature', 'bbt', 'temperature', 'temp']);
  final note = find(['note', 'notes', 'comment', 'comments']);
  final dates = [for (final r in sample) if (r.length > date) r[date]];
  return CsvMapping(
    date: date,
    endDate: rangeMode ? end : null,
    flow: flow == date || (rangeMode && flow == end) ? null : flow,
    temperature: temp,
    note: note,
    dateFormat: guessDateFormat(dates),
  );
}

/// Picks the date format that reads every sample. Slash or dot dates where
/// both readings work stay day-first unless a value shows month-first.
CsvDateFormat guessDateFormat(List<String> samples) {
  var dayFirstOk = true;
  var monthFirstOk = true;
  var anySlash = false;
  for (final s in samples) {
    final t = s.trim();
    if (t.isEmpty) continue;
    if (isoDayKey(t) != null) continue;
    anySlash = true;
    if (parseCsvDate(t, CsvDateFormat.dayMonthYear) == null) dayFirstOk = false;
    if (parseCsvDate(t, CsvDateFormat.monthDayYear) == null) monthFirstOk = false;
  }
  if (!anySlash) return CsvDateFormat.iso;
  if (!dayFirstOk && monthFirstOk) return CsvDateFormat.monthDayYear;
  return CsvDateFormat.dayMonthYear;
}

/// Reads a date cell as a day key, or null.
String? parseCsvDate(String raw, CsvDateFormat format) {
  final t = raw.trim();
  final iso = isoDayKey(t);
  if (iso != null) return iso;
  final m = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2}|\d{4})\b').firstMatch(t);
  if (m == null) return null;
  final a = int.parse(m[1]!);
  final b = int.parse(m[2]!);
  var y = int.parse(m[3]!);
  if (m[3]!.length == 2) y += 2000;
  return switch (format) {
    CsvDateFormat.monthDayYear => validDayKey(y, a, b),
    _ => validDayKey(y, b, a),
  };
}

/// Reads a flow cell. Returns the level, `period` for "yes" without a level,
/// an empty string for "no flow", or null when it can't tell.
String? readFlowCell(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return '';
  switch (v) {
    case 'spotting' || 'spot':
      return 'spotting';
    case 'light' || 'low' || 'l':
      return 'light';
    case 'medium' || 'moderate' || 'normal' || 'm':
      return 'medium';
    case 'heavy' || 'high' || 'very heavy' || 'very_heavy' || 'h':
      return 'heavy';
    case 'yes' || 'y' || 'true' || 'x' || 'period' || 'bleeding' || '✓':
      return 'period';
    case 'no' || 'n' || 'false' || 'none' || '0' || '-':
      return '';
  }
  final n = int.tryParse(v);
  if (n != null) {
    return switch (n) {
      1 => 'light',
      2 => 'medium',
      3 || 4 => 'heavy',
      _ => null,
    };
  }
  return null;
}

/// Parses a generic CSV with [mapping]. The first row is the header.
ImportedData parseGenericCsv(String text, CsvMapping mapping, {DateTime? today}) {
  final rows = parseCsv(text);
  if (rows.length < 2) throw const ImportException('This CSV file has no rows under its header.');
  final b = ImportBuilder(ImportFormat.genericCsv, today: today);
  String cell(List<String> r, int? i) => i == null || i >= r.length ? '' : r[i];
  for (final r in rows.skip(1)) {
    b.records++;
    final day = b.day(parseCsvDate(cell(r, mapping.date), mapping.dateFormat), what: 'Rows');
    if (day == null) continue;

    final flowRaw = cell(r, mapping.flow);
    final flow = mapping.flow == null ? null : readFlowCell(flowRaw);
    if (mapping.flow != null && flow == null) b.skip('Flow values Bloom didn\'t recognize ("${flowRaw.trim()}")');

    if (mapping.endDate != null) {
      final endRaw = cell(r, mapping.endDate);
      final end = parseCsvDate(endRaw, mapping.dateFormat);
      var last = end == null ? parseDayKey(day) : parseDayKey(end);
      final first = parseDayKey(day);
      if (end == null) b.adjust('Periods with no end date, saved as one day');
      if (last.isBefore(first) || daysBetween(first, last) > 14) {
        b.adjust('Periods with an unlikely end date, saved as one day');
        last = first;
      }
      final now = dayOf(today ?? DateTime.now());
      if (last.isAfter(now)) last = now;
      for (var d = first; !d.isAfter(last); d = addDays(d, 1)) {
        final level = flow;
        if (level != null && level != '' && level != 'period' && level != 'spotting') {
          b.flow(dayKey(d), level);
        } else {
          b.period(dayKey(d));
        }
      }
    } else if (flow != null && flow.isNotEmpty) {
      flow == 'period' ? b.period(day) : b.flow(day, flow);
    }

    if (mapping.temperature != null) {
      final raw = cell(r, mapping.temperature).trim().replaceAll(',', '.');
      if (raw.isNotEmpty) {
        final t = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.\-]'), ''));
        if (t == null) {
          b.skip('Temperatures Bloom couldn\'t read');
        } else {
          b.bbt(day, t > 50 ? (t - 32) * 5 / 9 : t);
        }
      }
    }
    if (mapping.note != null) b.note(day, cell(r, mapping.note));
  }
  return b.build();
}

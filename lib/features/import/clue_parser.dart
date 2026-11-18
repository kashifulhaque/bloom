/// Reads Clue exports.
///
/// Current exports are a password-protected ZIP that holds
/// `measurements.json`: a JSON array of `{"date", "type", "value"}` entries,
/// where `value` is `{"option": ".."}`, a list of those, or
/// `{"celsius": 36.5, "excluded": false}` for temperature. Older Android
/// backups (`.cluedata`) are `{"data": [{"day": "..", "period": "light",
/// "pain": ["cramps"]}]}`. See `docs/IMPORT_FORMATS.md`.
library;

import 'import_data.dart';

/// Clue option → Bloom option, by Clue category. Options that aren't listed
/// are counted as skipped.
const Map<String, Map<String, (String, String)>> _clueOptions = {
  'pain': {
    'period_cramps': ('symptoms', 'cramps'),
    'cramps': ('symptoms', 'cramps'),
    'lower_back': ('symptoms', 'backache'),
    'breast_tenderness': ('symptoms', 'tender_breasts'),
    'tender_breasts': ('symptoms', 'tender_breasts'),
    'headache': ('symptoms', 'headache'),
    'migraine': ('symptoms', 'migraine'),
    'migraine_with_aura': ('symptoms', 'migraine'),
  },
  'feelings': {
    'happy': ('mood', 'happy'),
    'sad': ('mood', 'sad'),
    'angry': ('mood', 'irritated'),
    'anxious': ('mood', 'anxious'),
    'indifferent': ('mood', 'apathetic'),
    'calm': ('mood', 'calm'),
  },
  'emotions': {
    'happy': ('mood', 'happy'),
    'sad': ('mood', 'sad'),
    'sensitive': ('mood', 'swings'),
    'pms': ('mood', 'swings'),
  },
  'energy': {
    'energetic': ('mood', 'energetic'),
    'fully_energized': ('mood', 'energetic'),
    'high': ('mood', 'energetic'),
    'tired': ('mood', 'low_energy'),
    'low': ('mood', 'low_energy'),
    'exhausted': ('symptoms', 'fatigue'),
  },
  'sex_life': {
    'unprotected': ('sex', 'unprotected'),
    'protected': ('sex', 'protected'),
    'no_sex_today': ('sex', 'none'),
    'masturbation': ('sex', 'masturbation'),
    'high_sex_drive': ('sex', 'high_drive'),
    'low_sex_drive': ('sex', 'low_drive'),
  },
  'sex': {
    'unprotected': ('sex', 'unprotected'),
    'protected': ('sex', 'protected'),
    'high_sex_drive': ('sex', 'high_drive'),
  },
  'discharge': {
    'none': ('discharge', 'none'),
    'sticky': ('discharge', 'sticky'),
    'creamy': ('discharge', 'creamy'),
    'egg_white': ('discharge', 'egg_white'),
    'atypical': ('discharge', 'unusual'),
  },
  'digestion': {
    'nauseous': ('digestion', 'nausea'),
    'nausea': ('digestion', 'nausea'),
    'bloated': ('digestion', 'bloating'),
    'gassy': ('digestion', 'gas'),
    'constipated': ('digestion', 'constipation'),
    'diarrhea': ('digestion', 'diarrhea'),
  },
  'stool': {
    'constipated': ('digestion', 'constipation'),
    'diarrhea': ('digestion', 'diarrhea'),
  },
  'skin': {
    'acne': ('symptoms', 'acne'),
  },
  'tests': {
    'ovulation_positive': ('ovulation_test', 'positive'),
    'ovulation_negative': ('ovulation_test', 'negative'),
    'pregnancy_positive': ('pregnancy_test', 'positive'),
    'pregnancy_negative': ('pregnancy_test', 'negative'),
  },
  'birth_control_pill': {
    'taken': ('pill', 'taken'),
    'late': ('pill', 'late'),
    'missed': ('pill', 'missed'),
    'double': ('pill', 'double'),
  },
  'pill': {
    'taken': ('pill', 'taken'),
    'late': ('pill', 'late'),
    'missed': ('pill', 'missed'),
    'double': ('pill', 'double'),
  },
  'exercise': {
    'running': ('activity', 'running'),
    'biking': ('activity', 'cycling'),
    'cycling': ('activity', 'cycling'),
    'swimming': ('activity', 'swimming'),
    'yoga': ('activity', 'yoga'),
    'team_sports': ('activity', 'team_sports'),
    'walking': ('activity', 'walking'),
  },
};

/// Readable names for Clue categories, for the skipped list.
String _categoryLabel(String type) => switch (type) {
      'sex_life' || 'sex' => 'Sex',
      'feelings' || 'emotions' => 'Feelings',
      'birth_control_pill' || 'pill' => 'Pill',
      'tags' => 'Custom tags',
      'bbt' => 'Temperature',
      _ => type.isEmpty ? 'Unknown' : '${type[0].toUpperCase()}${type.substring(1).replaceAll('_', ' ')}',
    };

String _optionLabel(String option) => option.replaceAll('_', ' ');

/// Parses a Clue `measurements.json` or a legacy `.cluedata` file that
/// [jsonDecode] already read.
ImportedData parseClue(Object? json, {DateTime? today}) {
  if (json is List) return _parseCurrent(json, today);
  if (json is Map && json['data'] is List) return _parseLegacy(json['data'] as List, today);
  throw const ImportException('This file doesn\'t look like a Clue export.');
}

ImportedData _parseCurrent(List entries, DateTime? today) {
  final b = ImportBuilder(ImportFormat.clue, today: today);
  for (final e in entries) {
    b.records++;
    if (e is! Map) {
      b.skip('Entries Bloom couldn\'t read');
      continue;
    }
    final day = b.day(isoDayKey(e['date']));
    if (day == null) continue;
    final type = '${e['type'] ?? ''}';
    final value = e['value'];
    switch (type) {
      case 'bbt':
        _bbt(b, day, value);
      case 'note' || 'notes':
        final text = value is Map ? value['text'] ?? value['note'] : value;
        if (text is String) b.note(day, text);
      default:
        for (final option in _options(value)) {
          _apply(b, day, type, option);
        }
    }
  }
  return b.build();
}

ImportedData _parseLegacy(List days, DateTime? today) {
  final b = ImportBuilder(ImportFormat.clueLegacy, today: today);
  for (final d in days) {
    b.records++;
    if (d is! Map) {
      b.skip('Entries Bloom couldn\'t read');
      continue;
    }
    final day = b.day(isoDayKey(d['day'] ?? d['date']));
    if (day == null) continue;
    for (final entry in d.entries) {
      final type = '${entry.key}';
      if (type == 'day' || type == 'date') continue;
      final value = entry.value;
      if (type == 'bbt' || type == 'temperature') {
        _bbt(b, day, value);
      } else if (type == 'note' || type == 'notes') {
        if (value is String) b.note(day, value);
      } else if (value is String) {
        _apply(b, day, type, value);
      } else {
        for (final option in _options(value)) {
          _apply(b, day, type, option);
        }
      }
    }
  }
  return b.build();
}

/// The option strings in a Clue value: `{"option": x}`, a list of those, a
/// plain string, or a list of strings.
List<String> _options(Object? value) {
  if (value is String) return [value];
  if (value is Map) {
    final o = value['option'] ?? value['value'];
    return o is String ? [o] : const [];
  }
  if (value is List) return [for (final v in value) ..._options(v)];
  return const [];
}

void _bbt(ImportBuilder b, String day, Object? value) {
  if (value is Map && value['excluded'] == true) {
    b.skip('Temperatures you excluded in Clue');
    return;
  }
  final raw = value is Map ? (value['celsius'] ?? value['value']) : value;
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null) {
    b.skip('Temperatures with no value');
    return;
  }
  b.bbt(day, v);
}

void _apply(ImportBuilder b, String day, String type, String option) {
  switch (type) {
    case 'period':
      switch (option) {
        case 'light' || 'medium' || 'heavy':
          b.flow(day, option);
        case 'very_heavy':
          b.flow(day, 'heavy');
          b.adjust('Very heavy flow, saved as heavy');
        case 'spotting':
          b.flow(day, 'spotting');
        default:
          b.period(day);
          b.adjust('Period days with an unknown flow, saved without a level');
      }
      return;
    case 'spotting':
      b.flow(day, 'spotting');
      return;
  }
  final target = _clueOptions[type]?[option];
  if (target == null) {
    b.skip('${_categoryLabel(type)}: ${_optionLabel(option)}');
  } else {
    b.option(day, target.$1, target.$2);
  }
}

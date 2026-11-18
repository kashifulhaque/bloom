/// Reads Mensinator's JSON export, an open-source Android tracker.
///
/// The file is a dump of its database tables, with every value as a string:
/// `periods` (`date`, `period_id`), `symptoms` (`id`, `symptom_name`),
/// `symptom_date` (`symptom_date`, `symptom_id`), and `ovulations` (`date`).
/// Symptom names are free text, so they're matched against Bloom's option
/// labels. See `docs/IMPORT_FORMATS.md`.
library;

import '../../core/catalog.dart';
import 'import_data.dart';

ImportedData parseMensinator(Object? json, {DateTime? today}) {
  if (json is! Map || json['periods'] is! List) {
    throw const ImportException('This file doesn\'t look like a Mensinator export.');
  }
  final b = ImportBuilder(ImportFormat.mensinator, today: today);

  for (final p in json['periods'] as List) {
    b.records++;
    final day = b.day(p is Map ? isoDayKey(p['date']) : null, what: 'Period days');
    if (day != null) b.period(day);
  }

  final names = <String, String>{};
  final symptoms = json['symptoms'];
  if (symptoms is List) {
    for (final s in symptoms) {
      if (s is Map) names['${s['id']}'] = '${s['symptom_name'] ?? ''}';
    }
  }
  final symptomDays = json['symptom_date'];
  if (symptomDays is List) {
    for (final s in symptomDays) {
      b.records++;
      if (s is! Map) {
        b.skip('Symptoms Bloom couldn\'t read');
        continue;
      }
      final day = b.day(isoDayKey(s['symptom_date']), what: 'Symptoms');
      if (day == null) continue;
      final name = names['${s['symptom_id']}'] ?? '';
      final target = _matchSymptom(name);
      if (target == null) {
        b.skip(name.isEmpty ? 'Symptoms with no name' : 'Symptom: ${name.replaceAll('_', ' ')}');
      } else {
        b.option(day, target.$1, target.$2);
      }
    }
  }

  final ovulations = json['ovulations'];
  if (ovulations is List) {
    for (final o in ovulations) {
      b.records++;
      final day = b.day(o is Map ? isoDayKey(o['date']) : null, what: 'Ovulation days');
      if (day != null) b.option(day, 'ovulation_test', 'my_method');
    }
  }
  return b.build();
}

/// Maps a symptom name to a Bloom option: Mensinator's built-in flow
/// symptoms (`Heavy_Flow`, `Medium_Flow`, `Light_Flow`, `Spotting`) first,
/// then any option whose label matches, ignoring case.
(String, String)? _matchSymptom(String raw) {
  final name = raw.replaceAll('_', ' ').trim().toLowerCase();
  if (name.isEmpty) return null;
  if (name.contains('flow')) {
    for (final level in const ['heavy', 'medium', 'light']) {
      if (name.contains(level)) return ('flow', level);
    }
  }
  if (name == 'spotting') return ('flow', 'spotting');
  for (final c in kCategories) {
    if (c.id == 'flow') continue;
    for (final o in c.options) {
      if (o.label.toLowerCase() == name || o.id.replaceAll('_', ' ') == name) return (c.id, o.id);
    }
  }
  return null;
}

/// Reads the cycle-tracking records of an Apple Health `export.xml`.
///
/// The file can be several gigabytes, so this is a streaming scanner, not a
/// DOM parser: feed it text with [AppleHealthParser.add] in chunks of any
/// size, then call [AppleHealthParser.finish]. It holds only the current
/// record and the mapped days in memory.
///
/// Each `<Record>` has `type`, `startDate` (`2024-01-05 08:00:00 -0500`, the
/// local time of the entry), and `value` attributes. Category values are
/// written as enum names, such as `HKCategoryValueMenstrualFlowMedium`, and
/// some records carry `<MetadataEntry key=".." value=".."/>` children. See
/// `docs/IMPORT_FORMATS.md`.
library;

import 'import_data.dart';

/// Symptom record types and the Bloom option each maps to.
const _symptoms = <String, (String, String)>{
  'AbdominalCramps': ('symptoms', 'cramps'),
  'Acne': ('symptoms', 'acne'),
  'Bloating': ('digestion', 'bloating'),
  'BreastPain': ('symptoms', 'tender_breasts'),
  'Constipation': ('digestion', 'constipation'),
  'Diarrhea': ('digestion', 'diarrhea'),
  'Dizziness': ('symptoms', 'dizziness'),
  'Fatigue': ('symptoms', 'fatigue'),
  'HairLoss': ('menopause', 'hair_thinning'),
  'Headache': ('symptoms', 'headache'),
  'HotFlashes': ('menopause', 'hot_flashes'),
  'LowerBackPain': ('symptoms', 'backache'),
  'MemoryLapse': ('menopause', 'brain_fog'),
  'MoodChanges': ('mood', 'swings'),
  'Nausea': ('digestion', 'nausea'),
  'NightSweats': ('menopause', 'night_sweats'),
  'PelvicPain': ('symptoms', 'abdominal_pain'),
  'VaginalDryness': ('menopause', 'vaginal_dryness'),
};

/// Readable names for cycle-related types that Bloom has no place for.
const _unmapped = <String, String>{
  'AppetiteChanges': 'Appetite changes',
  'BladderIncontinence': 'Bladder incontinence',
  'Chills': 'Chills',
  'DrySkin': 'Dry skin',
  'Fainting': 'Fainting',
  'Fever': 'Fever',
  'Heartburn': 'Heartburn',
  'LossOfSmell': 'Loss of smell',
  'LossOfTaste': 'Loss of taste',
  'RunnyNose': 'Runny nose',
  'ShortnessOfBreath': 'Shortness of breath',
  'SinusCongestion': 'Sinus congestion',
  'SkippedHeartbeat': 'Skipped heartbeat',
  'SleepChanges': 'Sleep changes',
  'SoreThroat': 'Sore throat',
  'Vomiting': 'Vomiting',
  'Wheezing': 'Wheezing',
  'Coughing': 'Coughing',
  'ChestTightnessOrPain': 'Chest tightness or pain',
  'GeneralizedBodyAche': 'Body ache',
  'RapidPoundingOrFlutteringHeartbeat': 'Rapid or fluttering heartbeat',
  'Contraceptive': 'Contraceptive entries',
  'Lactation': 'Lactation entries',
  'Pregnancy': 'Pregnancy entries',
  'ProgesteroneTestResult': 'Progesterone tests',
  'BleedingDuringPregnancy': 'Bleeding during pregnancy',
  'BleedingAfterPregnancy': 'Bleeding after pregnancy',
  'InfrequentMenstrualCycles': 'Cycle deviation alerts',
  'IrregularMenstrualCycles': 'Cycle deviation alerts',
  'PersistentIntermenstrualBleeding': 'Cycle deviation alerts',
  'ProlongedMenstrualPeriods': 'Cycle deviation alerts',
};

const _cat = 'HKCategoryTypeIdentifier';
const _bbtType = 'HKQuantityTypeIdentifierBasalBodyTemperature';

class AppleHealthParser {
  AppleHealthParser({DateTime? today}) : _b = ImportBuilder(ImportFormat.appleHealth, today: today);

  final ImportBuilder _b;
  String _tail = '';
  bool _sawRoot = false;
  String _probe = '';
  int _scanned = 0;

  /// The earliest temperature time kept for each day.
  final Map<String, String> _bbtTime = {};

  static const _maxPending = 1 << 20;

  /// Reads the next piece of the file.
  void add(String chunk) {
    final s = _tail.isEmpty ? chunk : _tail + chunk;
    if (!_sawRoot && _scanned < 4 << 20) {
      // A short rolling window, so the root tag is found however the text
      // is split into chunks.
      final probe = _probe + chunk;
      _sawRoot = probe.contains('<HealthData');
      _probe = probe.length > 16 ? probe.substring(probe.length - 16) : probe;
      _scanned += chunk.length;
    }
    var i = 0;
    while (true) {
      final lt = s.indexOf('<Record', i);
      if (lt < 0 || lt + 8 > s.length) {
        _keep(s, lt < 0 ? s.length - 7 : lt, i);
        return;
      }
      final next = s.codeUnitAt(lt + 7);
      if (next != 0x20 && next != 0x0a && next != 0x09 && next != 0x0d) {
        i = lt + 7; // A longer tag name, such as <RecordX>.
        continue;
      }
      final gt = _tagEnd(s, lt);
      if (gt < 0) {
        _keep(s, lt, i);
        return;
      }
      final type = _attr(s, lt, gt, 'type') ?? '';
      if (!_interesting(type)) {
        _b.unrelated++;
        i = gt + 1;
        continue;
      }
      var after = gt + 1;
      Map<String, String>? meta;
      if (s.codeUnitAt(gt - 1) != 0x2f) {
        final close = s.indexOf('</Record>', gt);
        if (close < 0) {
          _keep(s, lt, i);
          return;
        }
        meta = _metadata(s, gt + 1, close);
        after = close + 9;
      }
      _record(type, _attrs(s.substring(lt, gt + 1)), meta ?? const {});
      i = after;
    }
  }

  void _keep(String s, int from, int consumed) {
    final start = from < consumed ? consumed : (from < 0 ? 0 : from);
    _tail = start >= s.length ? '' : s.substring(start);
    if (_tail.length > _maxPending) {
      throw const ImportException('This export.xml has a record Bloom couldn\'t read. The file may be damaged.');
    }
  }

  /// Returns the mapped data. Throws when the text wasn't an Apple Health
  /// export.
  ImportedData finish() {
    if (!_sawRoot) {
      throw const ImportException('This XML file isn\'t an Apple Health export.');
    }
    if (_tail.contains('<Record')) _b.skip('A record cut off at the end of the file');
    _tail = '';
    return _b.build();
  }

  static bool _interesting(String type) =>
      type == _bbtType || (type.startsWith(_cat) && _categoryTypes.contains(type.substring(_cat.length)));

  static final Set<String> _categoryTypes = {
    'MenstrualFlow',
    'IntermenstrualBleeding',
    'OvulationTestResult',
    'PregnancyTestResult',
    'SexualActivity',
    'CervicalMucusQuality',
    ..._symptoms.keys,
    ..._unmapped.keys,
  };

  void _record(String type, Map<String, String> a, Map<String, String> meta) {
    _b.records++;
    final day = _b.day(isoDayKey(a['startDate']), what: 'Health records');
    if (day == null) return;
    final value = a['value'] ?? '';
    if (type == _bbtType) {
      _temperature(day, a);
      return;
    }
    final kind = type.substring(_cat.length);
    switch (kind) {
      case 'MenstrualFlow':
        final level = _suffix(value, const ['HKCategoryValueMenstrualFlow', 'HKCategoryValueVaginalBleeding']);
        switch (level) {
          case 'Light' || '2':
            _b.flow(day, 'light');
          case 'Medium' || '3':
            _b.flow(day, 'medium');
          case 'Heavy' || '4':
            _b.flow(day, 'heavy');
          case 'Unspecified' || '1':
            _b.period(day);
          case 'None' || '5':
            _b.skip('Days logged as "no flow"');
          default:
            _b.skip('Menstrual flow entries with an unknown value');
        }
      case 'IntermenstrualBleeding':
        _b.flow(day, 'spotting');
      case 'OvulationTestResult':
        switch (_suffix(value, const ['HKCategoryValueOvulationTestResult'])) {
          case 'LuteinizingHormoneSurge' || 'Positive' || '2':
            _b.option(day, 'ovulation_test', 'positive');
          case 'Negative' || '1':
            _b.option(day, 'ovulation_test', 'negative');
          case 'EstrogenSurge' || '4':
            _b.skip('Ovulation tests showing an estrogen surge');
          default:
            _b.skip('Ovulation tests with no clear result');
        }
      case 'PregnancyTestResult':
        switch (_suffix(value, const ['HKCategoryValuePregnancyTestResult'])) {
          case 'Positive' || '2':
            _b.option(day, 'pregnancy_test', 'positive');
          case 'Negative' || '1':
            _b.option(day, 'pregnancy_test', 'negative');
          default:
            _b.skip('Pregnancy tests with no clear result');
        }
      case 'SexualActivity':
        switch (meta['HKSexualActivityProtectionUsed']) {
          case '1':
            _b.option(day, 'sex', 'protected');
          case '0':
            _b.option(day, 'sex', 'unprotected');
          default:
            _b.skip('Sexual activity with no protection recorded');
        }
      case 'CervicalMucusQuality':
        switch (_suffix(value, const ['HKCategoryValueCervicalMucusQuality'])) {
          case 'Dry' || '1':
            _b.option(day, 'discharge', 'none');
          case 'Sticky' || '2':
            _b.option(day, 'discharge', 'sticky');
          case 'Creamy' || '3':
            _b.option(day, 'discharge', 'creamy');
          case 'Watery' || '4':
            _b.option(day, 'discharge', 'watery');
          case 'EggWhite' || '5':
            _b.option(day, 'discharge', 'egg_white');
          default:
            _b.skip('Cervical mucus entries with an unknown value');
        }
      default:
        final target = _symptoms[kind];
        if (target == null) {
          _b.skip(_unmapped[kind] ?? kind);
        } else if (_present(value)) {
          _b.option(day, target.$1, target.$2);
        } else {
          _b.skip('Symptoms marked "not present"');
        }
    }
  }

  void _temperature(String day, Map<String, String> a) {
    final v = double.tryParse(a['value'] ?? '');
    final unit = (a['unit'] ?? 'degC').toLowerCase();
    if (v == null) {
      _b.skip('Temperatures with no value');
      return;
    }
    final celsius = switch (unit) {
      'degc' || 'c' || '°c' => v,
      'degf' || 'f' || '°f' => (v - 32) * 5 / 9,
      _ => double.nan,
    };
    if (celsius.isNaN) {
      _b.skip('Temperatures in an unknown unit');
      return;
    }
    // Basal temperature is taken on waking, so the earliest reading wins.
    final time = a['startDate'] ?? '';
    final earlier = _bbtTime[day];
    final replace = earlier != null && time.compareTo(earlier) < 0;
    if (earlier != null && !replace) {
      _b.adjust('Extra temperatures on the same day (kept the earliest)');
      return;
    }
    if (replace) _b.adjust('Extra temperatures on the same day (kept the earliest)');
    _bbtTime[day] = time;
    _b.bbt(day, celsius, replace: true);
  }

  /// A symptom counts unless it says "not present".
  static bool _present(String value) => !value.endsWith('NotPresent') && value != '1';

  static String _suffix(String value, List<String> prefixes) {
    for (final p in prefixes) {
      if (value.startsWith(p)) return value.substring(p.length);
    }
    return value;
  }

  /// The index of the `>` that closes the tag starting at [lt], skipping any
  /// `>` inside quoted attribute values. Returns -1 when the tag isn't
  /// complete yet.
  static int _tagEnd(String s, int lt) {
    var gt = s.indexOf('>', lt);
    while (gt >= 0) {
      var quotes = 0;
      var q = s.indexOf('"', lt);
      while (q >= 0 && q < gt) {
        quotes++;
        q = s.indexOf('"', q + 1);
      }
      if (quotes.isEven) return gt;
      gt = s.indexOf('>', gt + 1);
    }
    return -1;
  }

  static String? _attr(String s, int start, int end, String name) {
    final key = ' $name="';
    final i = s.indexOf(key, start);
    if (i < 0 || i > end) return null;
    final j = s.indexOf('"', i + key.length);
    if (j < 0 || j > end) return null;
    return s.substring(i + key.length, j);
  }

  static final _attrRe = RegExp(r'([A-Za-z_:][\w:.-]*)\s*=\s*"([^"]*)"');

  static Map<String, String> _attrs(String tag) => {
        for (final m in _attrRe.allMatches(tag)) m[1]!: _unescape(m[2]!),
      };

  static Map<String, String> _metadata(String s, int from, int to) {
    final out = <String, String>{};
    var i = s.indexOf('<MetadataEntry', from);
    while (i >= 0 && i < to) {
      final gt = _tagEnd(s, i);
      if (gt < 0 || gt > to) break;
      final a = _attrs(s.substring(i, gt + 1));
      final k = a['key'];
      if (k != null) out[k] = a['value'] ?? '';
      i = s.indexOf('<MetadataEntry', gt);
    }
    return out;
  }

  static String _unescape(String v) {
    if (!v.contains('&')) return v;
    return v.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'), (m) {
      final e = m[1]!;
      switch (e) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = e.startsWith('#x') ? int.tryParse(e.substring(2), radix: 16) : int.tryParse(e.substring(1));
      return code == null ? m[0]! : String.fromCharCode(code);
    });
  }
}

/// Birth control settings, saved in the store under the `contraception` key,
/// plus the pure date math for pill packs, rings, patches, and so on.
library;

import '../../core/dates.dart';
import '../../core/store.dart';

enum BirthControlMethod { none, pill, ring, patch, injection, iud, implant }

extension BirthControlMethodLabel on BirthControlMethod {
  String get label => switch (this) {
        BirthControlMethod.none => 'None',
        BirthControlMethod.pill => 'Pill',
        BirthControlMethod.ring => 'Vaginal ring',
        BirthControlMethod.patch => 'Patch',
        BirthControlMethod.injection => 'Injection',
        BirthControlMethod.iud => 'IUD',
        BirthControlMethod.implant => 'Implant',
      };

  String get emoji => switch (this) {
        BirthControlMethod.none => '🚫',
        BirthControlMethod.pill => '💊',
        BirthControlMethod.ring => '⭕',
        BirthControlMethod.patch => '🩹',
        BirthControlMethod.injection => '💉',
        BirthControlMethod.iud => '🔱',
        BirthControlMethod.implant => '📍',
      };

  /// Label for the date the user enters for this method.
  String get startLabel => switch (this) {
        BirthControlMethod.pill => 'Current pack started on',
        BirthControlMethod.ring => 'Current ring inserted on',
        BirthControlMethod.patch => 'First patch of this cycle applied on',
        BirthControlMethod.injection => 'Last injection on',
        BirthControlMethod.iud || BirthControlMethod.implant => 'Inserted on',
        BirthControlMethod.none => 'Start date',
      };
}

enum PillPack { combo21, combo24, continuous28, progestin28 }

extension PillPackInfo on PillPack {
  String get label => switch (this) {
        PillPack.combo21 => '21 active + 7-day break',
        PillPack.combo24 => '24 active + 4 placebo',
        PillPack.continuous28 => '28 active (continuous)',
        PillPack.progestin28 => 'Progestin-only (28 active)',
      };

  /// Number of active (hormone) pills in a 28-day pack.
  int get activeDays => switch (this) {
        PillPack.combo21 => 21,
        PillPack.combo24 => 24,
        PillPack.continuous28 || PillPack.progestin28 => 28,
      };

  /// True when the non-active days are a pill-free break (no pills at all).
  bool get hasBreak => this == PillPack.combo21;
}

const kPackLength = 28;

/// Where today falls in a pill pack.
class PackDay {
  PackDay({required this.packStart, required this.dayInPack, required this.active, required this.isBreak});

  /// First day of the pack that contains the day.
  final DateTime packStart;

  /// 1-based pill number (1-28).
  final int dayInPack;

  /// True on an active hormone pill day.
  final bool active;

  /// True on a pill-free break day.
  final bool isBreak;

  DateTime get nextPackStart => addDays(packStart, kPackLength);
}

class Contraception {
  Contraception({
    this.method = BirthControlMethod.none,
    this.pack = PillPack.combo21,
    this.startDate,
    this.hour = 21,
    this.minute = 0,
    this.refillReminder = true,
    this.refillDaysBefore = 5,
    this.injectionWeeks = 12,
    this.expiryYears,
  });

  static const storageKey = 'contraception';

  BirthControlMethod method;
  PillPack pack;

  /// Pack start, ring insertion, first patch, last injection, or insertion date.
  DateTime? startDate;

  /// Daily reminder time (pill) or time for other method reminders.
  int hour;
  int minute;
  bool refillReminder;
  int refillDaysBefore;

  /// Weeks between injections (12-13).
  int injectionWeeks;

  /// IUD or implant lifetime in years. Null uses the method default.
  int? expiryYears;

  int get effectiveExpiryYears => expiryYears ?? (method == BirthControlMethod.implant ? 3 : 5);

  /// Pill-pack position of [day], or null when not on the pill or no start date.
  PackDay? packDay(DateTime day) {
    if (method != BirthControlMethod.pill || startDate == null) return null;
    final diff = daysBetween(startDate!, day);
    final packIndex = (diff / kPackLength).floor();
    final packStart = addDays(startDate!, packIndex * kPackLength);
    final n = daysBetween(packStart, day) + 1;
    final active = n <= pack.activeDays;
    return PackDay(packStart: packStart, dayInPack: n, active: active, isBreak: !active && pack.hasBreak);
  }

  /// Ring: inserted for 21 days, then a 7-day break. Returns day in the 28-day cycle.
  int? ringDay(DateTime day) => _cycleDay(day, BirthControlMethod.ring);

  /// Patch: one patch a week for 3 weeks, then a patch-free week.
  int? patchDay(DateTime day) => _cycleDay(day, BirthControlMethod.patch);

  int? _cycleDay(DateTime day, BirthControlMethod m) {
    if (method != m || startDate == null) return null;
    final diff = daysBetween(startDate!, day);
    return (diff % kPackLength) + 1;
  }

  DateTime? get nextInjection =>
      method == BirthControlMethod.injection && startDate != null ? addDays(startDate!, injectionWeeks * 7) : null;

  DateTime? get expiryDate {
    if ((method != BirthControlMethod.iud && method != BirthControlMethod.implant) || startDate == null) return null;
    final s = startDate!;
    return DateTime(s.year + effectiveExpiryYears, s.month, s.day);
  }

  /// One-line status for today, such as "Pill 5 of 28 (active)".
  String status(DateTime day) {
    switch (method) {
      case BirthControlMethod.none:
        return 'No birth control set';
      case BirthControlMethod.pill:
        final p = packDay(day);
        if (p == null) return 'Set your pack start date';
        if (p.isBreak) return 'Pill-free break, day ${p.dayInPack - pack.activeDays} of ${kPackLength - pack.activeDays}';
        return 'Pill ${p.dayInPack} of $kPackLength${p.active ? '' : ' (placebo)'}';
      case BirthControlMethod.ring:
        final d = ringDay(day);
        if (d == null) return 'Set your ring insertion date';
        return d <= 21 ? 'Ring in: day $d of 21' : 'Ring-free week: day ${d - 21} of 7';
      case BirthControlMethod.patch:
        final d = patchDay(day);
        if (d == null) return 'Set your patch start date';
        return d <= 21 ? 'Patch week ${(d - 1) ~/ 7 + 1} of 3' : 'Patch-free week: day ${d - 21} of 7';
      case BirthControlMethod.injection:
        final n = nextInjection;
        if (n == null) return 'Set your last injection date';
        final left = daysBetween(day, n);
        return left >= 0 ? 'Next injection in $left days (${fmtFull(n)})' : 'Injection overdue by ${-left} days';
      case BirthControlMethod.iud:
      case BirthControlMethod.implant:
        final e = expiryDate;
        if (e == null) return 'Set your insertion date';
        return 'Replace by ${fmtFull(e)}';
    }
  }

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'pack': pack.name,
        'startDate': startDate == null ? null : dayKey(startDate!),
        'hour': hour,
        'minute': minute,
        'refillReminder': refillReminder,
        'refillDaysBefore': refillDaysBefore,
        'injectionWeeks': injectionWeeks,
        'expiryYears': expiryYears,
      };

  factory Contraception.fromJson(Map<String, dynamic> j) {
    DateTime? start;
    final s = j['startDate'];
    if (s is String && s.isNotEmpty) {
      try {
        start = s.length == 10 ? parseDayKey(s) : dayOf(DateTime.parse(s));
      } catch (_) {}
    }
    return Contraception(
      method: BirthControlMethod.values.asNameMap()[j['method']] ?? BirthControlMethod.none,
      pack: PillPack.values.asNameMap()[j['pack']] ?? PillPack.combo21,
      startDate: start,
      hour: (j['hour'] as num?)?.toInt() ?? 21,
      minute: (j['minute'] as num?)?.toInt() ?? 0,
      refillReminder: j['refillReminder'] as bool? ?? true,
      refillDaysBefore: (j['refillDaysBefore'] as num?)?.toInt() ?? 5,
      injectionWeeks: (j['injectionWeeks'] as num?)?.toInt() ?? 12,
      expiryYears: (j['expiryYears'] as num?)?.toInt(),
    );
  }

  /// Saved settings, or a default prefilled from onboarding's `birthControl`.
  static Contraception of(AppStore store) {
    final raw = store.feature<Object>(storageKey);
    if (raw is Map) return Contraception.fromJson(Map<String, dynamic>.from(raw));
    return Contraception(method: methodFromOnboarding(store));
  }

  /// Maps onboarding's free-form `birthControl` value to a method.
  static BirthControlMethod methodFromOnboarding(AppStore store) {
    final onboarding = store.feature<Object>('onboarding');
    if (onboarding is! Map) return BirthControlMethod.none;
    final v = (onboarding['birthControl'] ?? '').toString().toLowerCase();
    if (v.contains('pill')) return BirthControlMethod.pill;
    if (v.contains('ring')) return BirthControlMethod.ring;
    if (v.contains('patch')) return BirthControlMethod.patch;
    if (v.contains('inject') || v.contains('shot')) return BirthControlMethod.injection;
    if (v.contains('iud') || v.contains('coil')) return BirthControlMethod.iud;
    if (v.contains('implant')) return BirthControlMethod.implant;
    return BirthControlMethod.none;
  }

  void save(AppStore store) => store.setFeature(storageKey, toJson());
}

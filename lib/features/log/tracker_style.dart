/// Accent colors for trackers in the log sheet, the edit screen, and the
/// Today summary.
///
/// Almanac uses color only for meaning, so every tracker maps to one of the
/// palette's meaning colors (period, fertile, follicular, luteal, pregnancy)
/// or to quiet ink. The color appears only as a small dot next to a label.
library;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'trackers.dart';

/// Dot color for a choice category, by category id.
Color categoryColor(String id) => switch (id) {
      'flow' || 'clots' || 'products' => BloomColors.period,
      'sex' => BloomColors.predicted,
      'mood' => BloomColors.follicular,
      'symptoms' || 'menopause' => BloomColors.luteal,
      'discharge' => BloomColors.fertile,
      'ovulation_test' => BloomColors.ovulation,
      'pregnancy_test' || 'pregnancy_symptoms' || 'postpartum' => BloomColors.pregnancy,
      'activity' => BloomColors.success,
      'pill' || 'digestion' => BloomColors.info,
      _ => BloomColors.ink2,
    };

/// Dot color for a numeric tracker.
Color metricColor(String id) => switch (id) {
      'water' => BloomColors.info,
      'sleep' => BloomColors.luteal,
      'bbt' => BloomColors.follicular,
      'steps' => BloomColors.success,
      'energy' => BloomColors.follicular,
      _ => BloomColors.ink2,
    };

/// Dot color for any tracker.
Color trackerColor(TrackerItem t) => t.category != null ? categoryColor(t.category!.id) : metricColor(t.metric!.id);

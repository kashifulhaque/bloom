/// Accent colors and icons for trackers in the log sheet and the edit
/// screen.
library;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'trackers.dart';

/// Accent color for a numeric tracker.
Color metricColor(String id) => switch (id) {
      'water' => BloomColors.info,
      'sleep' => BloomColors.luteal,
      'weight' => BloomColors.coral,
      'bbt' => BloomColors.warning,
      'steps' => BloomColors.success,
      'energy' => BloomColors.pregnancy,
      _ => BloomColors.brand,
    };

/// Accent color for any tracker.
Color trackerColor(TrackerItem t) =>
    t.category != null ? Color(t.category!.colorHex) : metricColor(t.metric!.id);

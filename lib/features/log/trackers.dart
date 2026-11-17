/// One list of every tracker (choice categories and numeric metrics) shown in
/// the log sheet, filtered by goal and ordered by the user's preferences.
library;

import '../../core/catalog.dart';
import '../../core/models.dart';

/// A tracker row: either a choice [category] or a numeric [metric].
class TrackerItem {
  const TrackerItem.category(LogCategory this.category) : metric = null;
  const TrackerItem.metric(MetricDef this.metric) : category = null;

  final LogCategory? category;
  final MetricDef? metric;

  String get id => category?.id ?? metric!.id;
  String get title => category?.title ?? metric!.title;
  String get emoji => category?.emoji ?? metric!.emoji;
}

/// Every tracker that can appear for [goal], in catalog order.
List<TrackerItem> trackersForGoal(Goal goal) => [
      for (final c in kCategories)
        if (c.visibleFor(goal)) TrackerItem.category(c),
      for (final m in kMetrics)
        if (!m.hiddenIn.contains(goal)) TrackerItem.metric(m),
    ];

/// Trackers for the profile's goal sorted by `trackerOrder`. Trackers missing
/// from the saved order keep their catalog position after the ordered ones.
/// Hidden trackers are left out unless [includeHidden] is true.
List<TrackerItem> orderedTrackers(Profile profile, {bool includeHidden = false}) {
  final all = trackersForGoal(profile.goal);
  final order = profile.trackerOrder;
  int rank(TrackerItem t) {
    final i = order.indexOf(t.id);
    return i < 0 ? order.length + all.indexOf(t) : i;
  }

  final sorted = [...all]..sort((a, b) => rank(a).compareTo(rank(b)));
  if (includeHidden) return sorted;
  return sorted.where((t) => !profile.hiddenTrackers.contains(t.id)).toList();
}

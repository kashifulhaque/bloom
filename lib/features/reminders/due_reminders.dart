/// In-app list of reminders due today. Works on every platform, including
/// the web where system notifications aren't scheduled.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart';
import 'contraception_model.dart';
import 'notification_service.dart';
import 'reminder_model.dart';
import 'reminders_screen.dart';
import 'scheduler.dart';

const _logKey = 'notifications_log';

/// Reminder types the user dismissed on [day], from `notifications_log`.
Set<String> dismissedOn(AppStore store, DateTime day) {
  final log = store.feature<Object>(_logKey);
  if (log is! Map) return {};
  final dismissed = log['dismissed'];
  if (dismissed is! Map) return {};
  return Set<String>.from(dismissed[dayKey(day)] as List? ?? const []);
}

/// Marks [type] dismissed for [day], keeping the last 14 days of history.
void dismissReminder(AppStore store, DateTime day, ReminderType type) {
  final raw = store.feature<Object>(_logKey);
  final log = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final dismissed = Map<String, dynamic>.from(log['dismissed'] as Map? ?? {});
  final cutoff = dayKey(addDays(day, -14));
  dismissed.removeWhere((k, _) => k.compareTo(cutoff) < 0);
  dismissed[dayKey(day)] = {...dismissedOn(store, day), type.name}.toList();
  log['dismissed'] = dismissed;
  store.setFeature(_logKey, log);
}

/// Today's occurrences grouped by reminder type, minus dismissed ones.
List<List<ReminderOccurrence>> dueToday(AppStore store, DateTime now) {
  final occ = computeOccurrences(
    settings: ReminderSettings.of(store),
    contraception: Contraception.of(store),
    engine: store.engine,
    goal: store.profile.goal,
    now: now,
    horizonDays: 1,
  );
  final dismissed = dismissedOn(store, now);
  final groups = <ReminderType, List<ReminderOccurrence>>{};
  for (final o in occ) {
    if (dismissed.contains(o.type.name)) continue;
    groups.putIfAbsent(o.type, () => []).add(o);
  }
  return groups.values.toList();
}

/// In-app banner listing reminders due today (used on the web, where
/// system notifications are unavailable). Renders nothing when none are due.
class DueRemindersBanner extends StatefulWidget {
  const DueRemindersBanner({super.key});

  @override
  State<DueRemindersBanner> createState() => _DueRemindersBannerState();
}

class _DueRemindersBannerState extends State<DueRemindersBanner> {
  @override
  void initState() {
    super.initState();
    // Refresh scheduled notifications once per session on Android so they
    // follow the latest predictions. No-op on the web.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationService.syncOnce(context.read<AppStore>());
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final groups = dueToday(store, now);
    final theme = Theme.of(context);
    const c = BloomColors.warning;
    final fg = readableTint(c, theme.brightness);

    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.curve,
      alignment: Alignment.topCenter,
      child: groups.isEmpty
          ? const SizedBox(width: double.infinity)
          : BloomCard.tinted(
              color: c,
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.xs, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, size: 20, color: fg),
                      Gap.h8,
                      Expanded(
                        child: Text(
                          'Today\'s reminders',
                          style: theme.textTheme.titleSmall!.copyWith(color: fg, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: fg, visualDensity: VisualDensity.compact),
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen())),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  for (final g in groups) _tile(context, store, g, now),
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, AppStore store, List<ReminderOccurrence> g, DateTime now) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final first = g.first;
    final upcoming = g.where((o) => o.when.isAfter(now)).toList();
    final times = g.length == 1
        ? fmtTimeOfDay(first.when.hour, first.when.minute)
        : upcoming.isEmpty
        ? '${g.length}x today'
        : 'Next ${fmtTimeOfDay(upcoming.first.when.hour, upcoming.first.when.minute)}';
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        children: [
          IconBadge(emoji: first.type.emoji, color: reminderColor(first.type), size: 36),
          Gap.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        first.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Gap.h8,
                    Text(times, style: theme.textTheme.labelSmall!.copyWith(color: tokens.muted)),
                  ],
                ),
                Text(
                  first.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss for today',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 20, color: tokens.muted),
            onPressed: () => dismissReminder(store, now, first.type),
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../reminders/notification_service.dart';
import '../reminders/scheduler.dart';
import 'settings_widgets.dart';

/// Chooses how much reminder notifications reveal on the lock screen.
class NotificationPrivacyScreen extends StatelessWidget {
  const NotificationPrivacyScreen({super.key});

  static const _info = {
    NotificationPrivacy.detailed: ('Detailed', 'Shows what the reminder is about.', Icons.visibility_rounded),
    NotificationPrivacy.minimal: (
      'Minimal',
      'Hides cycle and birth control details. Wellness reminders keep their name.',
      Icons.visibility_off_rounded,
    ),
    NotificationPrivacy.private: ('Private', 'Every notification uses the same neutral text.', Icons.lock_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final current = store.profile.notificationPrivacy;
    void select(NotificationPrivacy? v) {
      if (v == null) return;
      store.updateProfile((p) => p.notificationPrivacy = v);
      NotificationService.sync(store);
    }

    return SettingsPage(
      title: 'Notification privacy',
      subtitle: 'Choose what others might see if your phone shows a Bloom notification.',
      children: [
        RadioGroup<NotificationPrivacy>(
          groupValue: current,
          onChanged: select,
          child: Column(
            children: [
              for (final p in NotificationPrivacy.values) ...[
                if (p.index > 0) Gap.v12,
                _Option(privacy: p, selected: p == current, onTap: () => select(p)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.privacy, required this.selected, required this.onTap});
  final NotificationPrivacy privacy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final (title, body, icon) = NotificationPrivacyScreen._info[privacy]!;
    final c = theme.colorScheme.primary;
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.curve,
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        border: Border.all(color: selected ? c : Colors.transparent, width: 2),
      ),
      child: BloomCard(
        onTap: onTap,
        padding: Insets.cardCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, color: selected ? c : tokens.muted),
                Gap.h12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                      Text(body, style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted)),
                    ],
                  ),
                ),
                Radio<NotificationPrivacy>(value: privacy),
              ],
            ),
            Gap.v12,
            _NotificationPreview(text: privacyExample(privacy)),
          ],
        ),
      ),
    );
  }
}

/// A miniature lock-screen notification.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final i = text.indexOf(': ');
    final heading = i < 0 ? null : text.substring(0, i);
    final message = i < 0 ? text : text.substring(i + 2);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: tokens.subtle, borderRadius: Radii.mdAll),
      child: Row(
        children: [
          const BloomLogo(size: 28),
          Gap.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Bloom', style: theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('now', style: theme.textTheme.labelSmall!.copyWith(color: tokens.muted)),
                  ],
                ),
                Gap.v4,
                if (heading != null && heading != 'Bloom')
                  Text(heading, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w800)),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

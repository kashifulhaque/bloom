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
    NotificationPrivacy.detailed: ('Detailed', 'Shows what the reminder is about.'),
    NotificationPrivacy.minimal: (
      'Minimal',
      'Hides cycle and birth control details. Wellness reminders keep their name.',
    ),
    NotificationPrivacy.private: ('Private', 'Every notification uses the same neutral text.'),
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final current = store.profile.notificationPrivacy;
    void select(NotificationPrivacy v) {
      store.updateProfile((p) => p.notificationPrivacy = v);
      NotificationService.sync(store);
    }

    return SettingsPage(
      eyebrow: 'Settings',
      title: 'Notification privacy',
      subtitle: 'Choose what others might see if your phone shows a Bloom notification.',
      children: [
        MenuSection(
          title: 'How much to say',
          children: [
            for (final p in NotificationPrivacy.values)
              _Option(privacy: p, selected: p == current, onTap: () => select(p)),
          ],
        ),
      ],
    );
  }
}

/// One choice: a hairline radio, a serif name, a note, and a specimen of
/// the notification it produces.
class _Option extends StatelessWidget {
  const _Option({required this.privacy, required this.selected, required this.onTap});
  final NotificationPrivacy privacy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final (title, body) = NotificationPrivacyScreen._info[privacy]!;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Pressable(
        onTap: selected
            ? null
            : () {
                Almanac.tick();
                onTap();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: AnimatedContainer(
                  duration: Motion.medium,
                  curve: Motion.curve,
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? p.ink : p.ink2.withValues(alpha: 0.6)),
                  ),
                  child: AnimatedContainer(
                    duration: Motion.medium,
                    curve: Motion.curve,
                    width: selected ? 8 : 0,
                    height: selected ? 8 : 0,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.ink),
                  ),
                ),
              ),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Almanac.serif(size: 20, weight: selected ? 400 : 350, color: p.ink, height: 1.2)),
                    Gap.v4,
                    Text(body, style: theme.textTheme.bodyMedium!.copyWith(color: p.ink2)),
                    Gap.v12,
                    _NotificationPreview(text: privacyExample(privacy)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A specimen of a lock-screen notification, set like a printed slip.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final i = text.indexOf(': ');
    final heading = i < 0 ? null : text.substring(0, i);
    final message = i < 0 ? text : text.substring(i + 2);
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.hairline, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BloomLogo(size: 16),
              Gap.h8,
              const Expanded(child: MonoLabel('Bloom', size: 10)),
              MonoLabel('now', size: 10, color: p.ink2.withValues(alpha: 0.8)),
            ],
          ),
          Gap.v4,
          if (heading != null && heading != 'Bloom')
            Text(heading, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600)),
          Text(message, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

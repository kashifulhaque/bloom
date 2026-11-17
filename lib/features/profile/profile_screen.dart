/// The "Me" tab: profile header and the menu for every setting and tool.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../analysis/analysis_screen.dart';
import '../modes/goal_screen.dart';
import '../partner/partner_screen.dart';
import '../reminders/contraception_model.dart';
import '../reminders/contraception_screen.dart';
import '../reminders/reminder_model.dart';
import '../reminders/reminders_screen.dart';
import '../reports/doctor_report_screen.dart';
import '../settings/about_screen.dart';
import '../settings/app_lock_screen.dart';
import '../settings/appearance_screen.dart';
import '../settings/cycle_settings_screen.dart';
import '../settings/my_data_screen.dart';
import '../settings/notification_privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Also re-locks the app when it returns from more than a minute in the
/// background. This tab stays mounted inside the home shell's IndexedStack,
/// so its observer runs whenever the app is unlocked.
class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  static const _relockAfter = Duration(minutes: 1);
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      final store = context.read<AppStore>();
      if (since != null && store.profile.pin != null && DateTime.now().difference(since) > _relockAfter) {
        store.lock();
      }
    }
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile;
    final reminders = ReminderSettings.of(store).enabled.length;
    final bc = Contraception.of(store).method;
    final pregnant = p.goal == Goal.trackPregnancy;

    return Scaffold(
      body: BloomPage(
        title: 'Me',
        heroColor: BloomColors.brand,
        actions: [
          IconButton(
            tooltip: 'About & privacy',
            onPressed: () => _push(const AboutPrivacyScreen()),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
        children: [
          _Header(onEdit: () => _editProfile(context, store), onGoal: () => _push(const GoalScreen())),
          MenuSection(
            title: 'My health',
            children: [
              MenuTile(
                icon: Icons.flag_rounded,
                color: BloomColors.coral,
                title: 'My goal',
                subtitle: p.goal.label,
                onTap: () => _push(const GoalScreen()),
              ),
              MenuTile(
                icon: Icons.insights_rounded,
                color: BloomColors.info,
                title: 'Graphs & reports',
                subtitle: 'Trends across your cycles',
                onTap: () => _push(const AnalysisScreen()),
              ),
              MenuTile(
                icon: Icons.description_rounded,
                color: BloomColors.luteal,
                title: 'Report for a doctor',
                subtitle: pregnant ? 'Pregnancy summary' : 'PDF of your last 6 cycles',
                onTap: () => _push(const DoctorReportScreen()),
              ),
              MenuTile(
                icon: Icons.notifications_rounded,
                color: BloomColors.warning,
                title: 'Reminders',
                subtitle: reminders == 0 ? 'Off' : '$reminders on',
                onTap: () => _push(const RemindersScreen()),
              ),
              MenuTile(
                icon: Icons.medication_rounded,
                color: BloomColors.fertile,
                title: 'Birth control',
                subtitle: bc.label,
                onTap: () => _push(const ContraceptionScreen()),
              ),
              MenuTile(
                icon: Icons.favorite_rounded,
                color: BloomColors.period,
                title: 'Partner sharing',
                subtitle: 'Share a read-only snapshot',
                onTap: () => _push(const PartnerScreen()),
              ),
            ],
          ),
          MenuSection(
            title: 'Settings',
            children: [
              MenuTile(
                icon: Icons.autorenew_rounded,
                color: BloomColors.brand,
                title: 'Cycle & ovulation',
                subtitle: '${p.cycleLength}-day cycle · ${p.periodLength}-day period',
                onTap: () => _push(const CycleSettingsScreen()),
              ),
              MenuTile(
                icon: Icons.tune_rounded,
                color: BloomColors.follicular,
                title: 'Tracking categories',
                subtitle: 'Choose what you log',
                onTap: () => _trackingInfo(context),
              ),
              MenuTile(
                icon: Icons.lock_rounded,
                color: BloomColors.luteal,
                title: 'App lock',
                value: p.pin == null ? 'Off' : 'On',
                onTap: () => _push(const AppLockSettingsScreen()),
              ),
              MenuTile(
                icon: Icons.visibility_off_rounded,
                color: BloomColors.info,
                title: 'Notification privacy',
                value: switch (p.notificationPrivacy) {
                  NotificationPrivacy.detailed => 'Detailed',
                  NotificationPrivacy.minimal => 'Minimal',
                  NotificationPrivacy.private => 'Private',
                },
                onTap: () => _push(const NotificationPrivacyScreen()),
              ),
              MenuTile(
                icon: Icons.palette_rounded,
                color: BloomColors.coral,
                title: 'Units & appearance',
                subtitle:
                    '${p.tempUnit == TempUnit.celsius ? '°C' : '°F'} · ${p.weightUnit.name} · ${switch (p.themeMode) {
                      'light' => 'Light',
                      'dark' => 'Dark',
                      _ => 'System theme',
                    }}',
                onTap: () => _push(const AppearanceScreen()),
              ),
            ],
          ),
          MenuSection(
            title: 'Data & privacy',
            footer: 'Bloom keeps everything on this device. No account, no server, no analytics.',
            children: [
              MenuTile(
                icon: Icons.folder_rounded,
                color: BloomColors.success,
                title: 'My data',
                subtitle: 'Export, import, or delete',
                onTap: () => _push(const MyDataScreen()),
              ),
              MenuTile(
                icon: Icons.local_florist_rounded,
                color: BloomColors.brand,
                title: 'About & privacy',
                subtitle: 'Open source · offline · no analytics',
                onTap: () => _push(const AboutPrivacyScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _trackingInfo(BuildContext context) => showAppBottomSheet<void>(
    context,
    builder: (c) => AppBottomSheet(
      title: 'Tracking categories',
      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Got it'))],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.tune_rounded, color: BloomColors.follicular),
          Gap.h16,
          Expanded(
            child: Text(
              'Choose and reorder what you track from the daily log: open the log for any day and use its '
              'customize option. Hiding a category keeps its past data.',
              style: Theme.of(c).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _editProfile(BuildContext context, AppStore store) async {
    final name = TextEditingController(text: store.profile.name);
    final year = TextEditingController(text: store.profile.birthYear?.toString() ?? '');
    final nowYear = DateTime.now().year;
    final saved = await showAppBottomSheet<bool>(
      context,
      builder: (c) => AppBottomSheet(
        title: 'Edit profile',
        subtitle: 'Both are optional and stay on this device.',
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: store.profile.name.isEmpty,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline_rounded)),
            ),
            Gap.v12,
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(labelText: 'Year of birth', prefixIcon: Icon(Icons.cake_outlined)),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final y = int.tryParse(year.text);
      store.updateProfile((p) {
        p.name = name.text.trim();
        p.birthYear = y != null && y > nowYear - 100 && y <= nowYear - 8 ? y : null;
      });
    }
  }
}

/// Up to two initials from [name], or an empty string.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  final first = words.first.characters.first;
  final last = words.length > 1 ? words.last.characters.first : '';
  return (first + last).toUpperCase();
}

class _Header extends StatelessWidget {
  const _Header({required this.onEdit, required this.onGoal});
  final VoidCallback onEdit;
  final VoidCallback onGoal;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile;
    final e = store.engine;
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final name = p.name.trim();
    final initials = initialsOf(name);
    final age = p.birthYear == null ? null : DateTime.now().year - p.birthYear!;
    final logged = e.cycles.where((c) => c.length != null).length;
    final keys = [...store.periodDays, ...store.logs.keys]..sort();
    final tracked = keys.isEmpty ? 0 : daysBetween(parseDayKey(keys.first), today()) + 1;

    return BloomCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.sm, Space.lg),
            child: Row(
              children: [
                Semantics(
                  label: 'Profile picture',
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: BloomGradients.brand,
                      boxShadow: theme.brightness == Brightness.light ? BloomShadows.glow(BloomColors.brand) : null,
                    ),
                    alignment: Alignment.center,
                    child: initials.isEmpty
                        ? const Icon(Icons.local_florist_rounded, color: Colors.white, size: 34)
                        : Text(
                            initials,
                            style: theme.textTheme.headlineSmall!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                Gap.h16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Hello there' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                      ),
                      Gap.v4,
                      Text(
                        age != null ? '$age years old' : 'Add your name and age',
                        style: theme.textTheme.bodyMedium!.copyWith(color: tokens.muted),
                      ),
                      Gap.v8,
                      InkWell(
                        onTap: onGoal,
                        borderRadius: Radii.pillAll,
                        child: PillChip(p.goal.label, icon: Icons.flag_rounded, color: BloomColors.brand),
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Edit profile', onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.border),
          IntrinsicHeight(
            child: Row(
              children: [
                _HeaderStat(value: e.hasData ? '${e.avgCycleLength}' : '–', label: 'Avg cycle'),
                VerticalDivider(width: 1, color: tokens.border, indent: Space.md, endIndent: Space.md),
                _HeaderStat(value: '$logged', label: logged == 1 ? 'Cycle logged' : 'Cycles logged'),
                VerticalDivider(width: 1, color: tokens.border, indent: Space.md, endIndent: Space.md),
                _HeaderStat(value: '$tracked', label: 'Days tracked'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.xs),
        child: Column(
          children: [
            Text(value, style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700)),
            Gap.v4,
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium!.copyWith(color: BloomTokens.of(context).muted),
            ),
          ],
        ),
      ),
    );
  }
}

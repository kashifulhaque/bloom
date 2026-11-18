/// The "You" tab: an ex libris bookplate, a few figures, and an editorial index of every setting and tool.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../analysis/analysis_screen.dart';
import '../assistant/ai/ai_settings_screen.dart';
import '../downloads/get_app_screen.dart';
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
import '../settings/settings_widgets.dart';

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
    var n = 0;
    String no() => (++n).toString().padLeft(2, '0');

    return Scaffold(
      body: BloomPage(
        eyebrow: 'Your notebook',
        title: 'You',
        spacing: Space.xxl,
        actions: [
          IconButton(
            tooltip: 'About & privacy',
            onPressed: () => _push(const AboutPrivacyScreen()),
            icon: Icon(Icons.info_outline, size: 20, color: BloomColors.of(context).ink2),
          ),
        ],
        children: [
          _Bookplate(onEdit: () => _editProfile(context, store), onGoal: () => _push(const GoalScreen())),
          const _Stats(),
          MenuSection(
            title: 'Contents · Your health',
            children: [
              IndexEntry(
                number: no(),
                title: 'My goal',
                subtitle: p.goal.label,
                onTap: () => _push(const GoalScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Graphs & reports',
                subtitle: 'Trends across your cycles',
                onTap: () => _push(const AnalysisScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Report for a doctor',
                subtitle: pregnant ? 'Pregnancy summary' : 'A PDF of your last 6 cycles',
                onTap: () => _push(const DoctorReportScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Reminders',
                subtitle: reminders == 0 ? 'None set' : '$reminders on',
                onTap: () => _push(const RemindersScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Birth control',
                subtitle: bc.label,
                onTap: () => _push(const ContraceptionScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Partner sharing',
                subtitle: 'A read-only snapshot for someone close',
                onTap: () => _push(const PartnerScreen()),
              ),
            ],
          ),
          MenuSection(
            title: 'Settings',
            children: [
              IndexEntry(
                number: no(),
                title: 'Cycle & ovulation',
                subtitle: '${p.cycleLength}-day cycle · ${p.periodLength}-day period',
                onTap: () => _push(const CycleSettingsScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Tracking categories',
                subtitle: 'Choose what you log',
                onTap: () => _trackingInfo(context),
              ),
              IndexEntry(
                number: no(),
                title: 'App lock',
                value: p.pin == null ? 'Off' : 'On',
                onTap: () => _push(const AppLockSettingsScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Notification privacy',
                value: switch (p.notificationPrivacy) {
                  NotificationPrivacy.detailed => 'Detailed',
                  NotificationPrivacy.minimal => 'Minimal',
                  NotificationPrivacy.private => 'Private',
                },
                onTap: () => _push(const NotificationPrivacyScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'Units & appearance',
                subtitle:
                    '${p.tempUnit == TempUnit.celsius ? '°C' : '°F'} · ${p.weightUnit.name} · ${switch (p.themeMode) {
                      'light' => 'Paper',
                      'dark' => 'Lamplight',
                      _ => 'Follows the system',
                    }}',
                onTap: () => _push(const AppearanceScreen()),
              ),
            ],
          ),
          MenuSection(
            title: 'Data & privacy',
            footer: 'Bloom keeps everything on this device. No account, no server, no analytics. '
                'Only optional AI answers go online, and only when you turn them on.',
            children: [
              IndexEntry(
                number: no(),
                title: 'My data',
                subtitle: 'Export, import, or delete',
                onTap: () => _push(const MyDataScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'AI answers in Ask',
                subtitle: 'Optional · sends typed questions online',
                value: aiStatusLabel(store),
                onTap: () => _push(const AiSettingsScreen()),
              ),
              IndexEntry(
                number: no(),
                title: 'About & privacy',
                subtitle: 'Colophon · open source · offline',
                onTap: () => _push(const AboutPrivacyScreen()),
              ),
              if (showGetTheApp)
                IndexEntry(
                  number: no(),
                  title: 'Get the app',
                  subtitle: 'Android APK · iPhone',
                  onTap: () => _push(const GetAppScreen()),
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
      eyebrow: 'Settings',
      title: 'Tracking categories',
      actions: [InkButton(label: 'Got it', onPressed: () => Navigator.pop(c))],
      child: Text(
        'Choose and reorder what you track from the daily log: open the log for any day and use its '
        'customize option. Hiding a category keeps its past data.',
        style: Theme.of(c).textTheme.bodyLarge,
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
        eyebrow: 'Ex libris',
        title: 'Your name on the plate',
        subtitle: 'Both are optional and stay on this device.',
        actions: [
          InkButton.outlined(label: 'Cancel', onPressed: () => Navigator.pop(c, false)),
          InkButton(label: 'Save', onPressed: () => Navigator.pop(c, true)),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: store.profile.name.isEmpty,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            Gap.v16,
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(labelText: 'Year of birth'),
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

/// The "ex libris" bookplate: a double hairline frame around the flower
/// mark, the name in Fraunces, the goal in italic, and a mono colophon line.
class _Bookplate extends StatelessWidget {
  const _Bookplate({required this.onEdit, required this.onGoal});
  final VoidCallback onEdit;
  final VoidCallback onGoal;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final prof = store.profile;
    final e = store.engine;
    final p = BloomColors.of(context);
    final name = prof.name.trim();
    final cycles = e.cycles.where((c) => c.length != null).length;
    final keys = [...store.periodDays, ...store.logs.keys]..sort();
    final first = keys.isEmpty ? null : parseDayKey(keys.first);
    final days = first == null ? 0 : daysBetween(first, today()) + 1;
    final colophon = [
      'Since ${(first ?? today()).year}',
      '$cycles ${cycles == 1 ? 'cycle' : 'cycles'}',
      '$days ${days == 1 ? 'day' : 'days'}',
    ].join(' · ');

    return Semantics(
      container: true,
      label: 'Profile',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: p.hairline), borderRadius: Radii.smAll),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
          decoration: BoxDecoration(border: Border.all(color: p.hairline), borderRadius: Radii.xsAll),
          child: Column(
            children: [
              const MonoLabel('Ex libris', size: 10),
              Gap.v12,
              const BloomLogo(size: 44),
              Gap.v12,
              Pressable(
                onTap: onEdit,
                tooltip: 'Edit profile',
                child: Text(
                  name.isEmpty ? 'Your name here' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: name.isEmpty
                      ? Almanac.serif(size: 28, weight: 300, italic: true, color: p.ink2)
                      : Almanac.serif(size: 30, weight: 360, color: p.ink, height: 1.1),
                ),
              ),
              Gap.v4,
              Pressable(
                onTap: onGoal,
                tooltip: 'Change goal',
                child: Text(prof.goal.label, textAlign: TextAlign.center, style: Almanac.italic(context, size: 16, color: p.ink2)),
              ),
              Gap.v16,
              const Hairline(indent: Space.huge, endIndent: Space.huge),
              Gap.v12,
              MonoLabel(colophon, textAlign: TextAlign.center),
              Gap.v8,
              InkLink(name.isEmpty ? 'Add your name' : 'Edit', onTap: onEdit, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three figures under the bookplate, set as serif numerals.
class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final e = store.engine;
    final prof = store.profile;
    final age = prof.birthYear == null ? null : DateTime.now().year - prof.birthYear!;
    final p = BloomColors.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Figure(value: e.hasData ? '${e.avgCycleLength}' : '–', unit: 'days', label: 'Cycle')),
          VerticalDivider(width: Space.xxl, thickness: 1, color: p.hairline),
          Expanded(
            child: _Figure(
              value: e.hasData ? '${e.avgPeriodLength}' : '–',
              unit: 'days',
              label: 'Period',
              color: BloomColors.period,
            ),
          ),
          VerticalDivider(width: Space.xxl, thickness: 1, color: p.hairline),
          Expanded(
            child: age != null
                ? _Figure(value: '$age', unit: 'years', label: 'Age')
                : _Figure(value: '${store.logs.length}', unit: 'days', label: 'Logged'),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.unit, required this.label, this.color});
  final String value;
  final String unit;
  final String label;

  /// A meaning color for the small dot before the label.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Semantics(
      label: '$label: $value $unit',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (color != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: BloomColors.resolve(context, color!), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(child: MonoLabel(label, maxLines: 1, size: 10)),
            ],
          ),
          Gap.v8,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: Almanac.numeral(context, size: 36, weight: 320)),
                TextSpan(text: ' $unit', style: Almanac.italic(context, size: 14, color: p.ink2)),
              ]),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

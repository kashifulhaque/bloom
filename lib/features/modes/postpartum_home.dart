/// After-birth (postpartum) home: baby age, recovery timeline and
/// checklist, bleeding note, feeding log, mood support, and period return.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../log/log_sheet.dart';
import 'goal_screen.dart';
import 'modes_common.dart';

/// Recovery tips for weeks 0-12 after birth. Original, educational content.
const List<String> kRecoveryWeeks = [
  'The first days: rest as much as you can. Bleeding is heaviest now and usually bright red. '
      'Accept help with meals, chores, and visitors.',
  'Week 1: your uterus is shrinking, which can cause cramps, especially while feeding. '
      'Keep any stitches clean and use a peri bottle with warm water.',
  'Week 2: bleeding usually becomes lighter and pinker. Baby blues often fade by now. '
      'If low mood continues or gets worse, talk to someone.',
  'Week 3: short, gentle walks can lift your mood and help circulation. Keep lifting light.',
  'Week 4: bleeding may turn brownish or yellowish. Hunger and thirst can be strong if you breastfeed.',
  'Week 5: start gentle pelvic floor exercises if you haven\'t yet. A few squeezes several times a day is enough.',
  'Week 6: many people have a postnatal checkup around now. Bring up any pain, bleeding, mood, '
      'or contraception questions.',
  'Week 7: after your checkup, you may be able to return to more exercise. Build up slowly.',
  'Week 8: hair shedding is common in the months after birth. It is temporary.',
  'Week 9: sleep is still broken for most parents. Nap when you can and share night duties if possible.',
  'Week 10: if you aren\'t breastfeeding exclusively, your period may return any time. '
      'You can get pregnant before your first period.',
  'Week 11: check in with yourself. Persistent sadness, anxiety, or intrusive thoughts deserve care.',
  'Week 12: many people feel more settled now. Recovery can take months; go at your own pace.',
];

class RecoveryItem {
  const RecoveryItem(this.id, this.label);
  final String id;
  final String label;
}

const List<RecoveryItem> kRecoveryChecklist = [
  RecoveryItem('pp_checkup', 'Book and attend your 6-week postnatal checkup'),
  RecoveryItem('pp_baby_checks', 'Book your baby\'s first health checks'),
  RecoveryItem('pp_contraception', 'Talk about contraception with a care provider'),
  RecoveryItem('pp_pelvic', 'Start gentle pelvic floor exercises'),
  RecoveryItem('pp_mood', 'Do an honest check-in on your mood'),
  RecoveryItem('pp_support', 'Line up help with meals and chores'),
  RecoveryItem('pp_feeding', 'Get feeding support if you need it'),
  RecoveryItem('pp_vitamin', 'Ask whether to keep taking a vitamin'),
  RecoveryItem('pp_register', 'Register the birth'),
  RecoveryItem('pp_exercise', 'Get the all-clear before high-impact exercise'),
];

Map<String, dynamic> _pp(AppStore s) => Map<String, dynamic>.from(s.feature<Map>('postpartum') ?? const {});

/// Baby age as "N weeks, M days" (or days only in the first week).
String babyAgeLabel(DateTime birth, DateTime on) {
  final d = daysBetween(birth, on);
  if (d < 0) return 'Not born yet';
  if (d < 7) return '$d ${d == 1 ? 'day' : 'days'} old';
  final w = d ~/ 7, r = d % 7;
  return '$w ${w == 1 ? 'week' : 'weeks'}${r > 0 ? ', $r ${r == 1 ? 'day' : 'days'}' : ''} old';
}

class PostpartumHome extends StatelessWidget {
  const PostpartumHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context);
    final pp = _pp(store);
    final birth = pp['birthDate'] is String ? parseDayKey(pp['birthDate']) : null;
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    if (birth == null) {
      return BloomCard(
        child: EmptyState(
          compact: true,
          emoji: '👶',
          color: BloomColors.follicular,
          title: 'After birth',
          body: 'Add your baby\'s birth date to see recovery tips for each week.',
          actionLabel: 'Add birth date',
          onAction: () async {
            final d = await pickDay(context, initial: today(), first: addDays(today(), -730), last: today());
            if (d != null) store.setFeature('postpartum', {...pp, 'birthDate': dayKey(d)});
          },
        ),
      );
    }

    final days = daysBetween(birth, today());
    final week = (days ~/ 7).clamp(0, 12);
    final checklist = List<String>.from(pp['checklist'] ?? const []);
    final done = checklist.where((id) => kRecoveryChecklist.any((c) => c.id == id)).length;
    final white = Colors.white.withValues(alpha: 0.9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BloomCard.gradient(
          gradient: BloomGradients.follicular,
          onTap: () => open(RecoveryTimelineScreen(currentWeek: days > 90 ? null : week)),
          child: Row(
            children: [
              ProgressRing(
                value: days / 84,
                size: 96,
                stroke: 8,
                color: Colors.white,
                trackColor: Colors.white.withValues(alpha: 0.28),
                child: const Text('👶', style: TextStyle(fontSize: 40, height: 1.1)),
              ),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your baby is', style: t.textTheme.bodyMedium!.copyWith(color: white)),
                    Text(babyAgeLabel(birth, today()), style: t.textTheme.headlineSmall!.copyWith(color: Colors.white)),
                    Gap.v4,
                    Text('Born ${fmtFull(birth)}', style: t.textTheme.bodySmall!.copyWith(color: white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Gap.v16,
        SectionCard(
          title: days > 90 ? 'Recovery' : 'Recovery: ${week == 0 ? 'first days' : 'week $week'}',
          icon: Icons.healing_rounded,
          accent: BloomColors.follicular,
          trailing: const CardChevron(),
          onTap: () => open(RecoveryTimelineScreen(currentWeek: days > 90 ? null : week)),
          child: Text(
            days > 90
                ? 'You are past the first 12 weeks. Recovery is different for everyone; keep listening to your body.'
                : kRecoveryWeeks[week],
          ),
        ),
        Gap.v16,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniCard(
                  icon: Icons.baby_changing_station_rounded,
                  color: BloomColors.fertile,
                  title: 'Feeding log',
                  body: _lastFeedSummary(pp),
                  onTap: () => open(const FeedingLogScreen()),
                ),
              ),
              Gap.h12,
              Expanded(
                child: _MiniCard(
                  icon: Icons.checklist_rounded,
                  color: BloomColors.success,
                  title: 'Recovery checklist',
                  body: '$done/${kRecoveryChecklist.length} done',
                  footer: SoftBar(value: done / kRecoveryChecklist.length, color: BloomColors.success, height: 6),
                  onTap: () => open(const RecoveryChecklistScreen()),
                ),
              ),
            ],
          ),
        ),
        Gap.v16,
        SectionCard(
          title: 'Bleeding after birth',
          icon: Icons.water_drop_rounded,
          accent: BloomColors.period,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bleeding (lochia) usually lasts up to about 6 weeks and slowly gets lighter. '
                'Log it to keep an eye on how it changes. Get medical help right away if you soak a pad in an hour, '
                'pass clots bigger than a plum, have a fever, or the bleeding smells bad.',
              ),
              Gap.v12,
              OutlinedButton.icon(
                onPressed: () => showLogSheet(context, today()),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Log today'),
              ),
            ],
          ),
        ),
        Gap.v16,
        const SectionCard(
          title: 'How are you feeling?',
          icon: Icons.favorite_rounded,
          color: BloomColors.luteal,
          child: Text(
            'Up to 4 in 5 new parents get the baby blues: tearfulness and mood swings in the first two weeks. '
            'If low mood, anxiety, or not enjoying things lasts longer than two weeks, or you have thoughts of '
            'harming yourself or your baby, it could be postpartum depression or anxiety. It is common and '
            'treatable. Tell your care provider, a health visitor, or someone you trust. In a crisis, contact '
            'emergency services or a local crisis line.',
          ),
        ),
        Gap.v16,
        FilledButton.tonalIcon(
          onPressed: () => startPeriodBackFlow(context),
          icon: const Icon(Icons.water_drop_rounded),
          label: const Text('My period is back'),
        ),
        Gap.v8,
        const EduNote(),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return BloomCard(
      onTap: onTap,
      padding: Insets.cardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 36),
              const Spacer(),
              const CardChevron(),
            ],
          ),
          Gap.v12,
          Text(title, style: t.textTheme.titleSmall),
          const SizedBox(height: Space.xxs),
          Text(body, style: t.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
          if (footer != null) ...[Gap.v8, footer!],
        ],
      ),
    );
  }
}

String _lastFeedSummary(Map<String, dynamic> pp) {
  final feeds = List<Map>.from(pp['feeds'] ?? const []);
  if (feeds.isEmpty) return 'Time breastfeeding on each side or log bottle feeds.';
  final last = feeds.last;
  final start = DateTime.parse(last['start']);
  return 'Last feed: ${_feedLabel(last['type'])}, ${_ago(DateTime.now().difference(start))}.';
}

String _ago(Duration ago) =>
    ago.inMinutes < 60 ? '${ago.inMinutes} min ago' : '${ago.inHours} h ${ago.inMinutes % 60} min ago';

String _feedLabel(Object? type) => switch (type) {
  'left' => 'left breast',
  'right' => 'right breast',
  _ => 'bottle',
};

class RecoveryTimelineScreen extends StatelessWidget {
  const RecoveryTimelineScreen({super.key, this.currentWeek});
  final int? currentWeek;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    const c = BloomColors.follicular;
    final last = kRecoveryWeeks.length - 1;
    return ModePage(
      title: 'Recovery timeline',
      subtitle: 'What to expect in the first 12 weeks',
      heroColor: c,
      children: [
        Column(
          children: [
            for (var i = 0; i <= last; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          SizedBox(
                            height: i == currentWeek ? 19 : 22,
                            child: Center(
                              child: Container(width: 2, color: i == 0 ? Colors.transparent : tokens.border),
                            ),
                          ),
                          Container(
                            width: i == currentWeek ? 18 : 12,
                            height: i == currentWeek ? 18 : 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: currentWeek != null && i <= currentWeek! ? BloomGradients.follicular : null,
                              color: currentWeek != null && i <= currentWeek!
                                  ? null
                                  : tokens.muted.withValues(alpha: 0.3),
                              border: i == currentWeek ? Border.all(color: t.colorScheme.surface, width: 3) : null,
                              boxShadow: i == currentWeek ? BloomShadows.glow(c) : null,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(width: 2, color: i == last ? Colors.transparent : tokens.border),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.h12,
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: i == currentWeek
                            ? BloomCard.tinted(color: c, padding: Insets.cardCompact, child: _week(context, i, true))
                            : BloomCard(padding: Insets.cardCompact, child: _week(context, i, false)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const EduNote(),
      ],
    );
  }

  Widget _week(BuildContext context, int i, bool now) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(i == 0 ? 'First days' : 'Week $i', style: t.textTheme.titleMedium)),
            if (now) const PillChip('This week', color: BloomColors.follicular, dense: true),
          ],
        ),
        Gap.v4,
        Text(kRecoveryWeeks[i], style: t.textTheme.bodyMedium),
      ],
    );
  }
}

class RecoveryChecklistScreen extends StatelessWidget {
  const RecoveryChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final store = context.watch<AppStore>();
    final pp = _pp(store);
    final done = List<String>.from(pp['checklist'] ?? const []);
    final n = kRecoveryChecklist.where((i) => done.contains(i.id)).length;
    final total = kRecoveryChecklist.length;
    return ModePage(
      title: 'Recovery checklist',
      subtitle: 'Small steps for your first weeks',
      children: [
        BloomCard(
          child: Row(
            children: [
              ProgressRing(
                value: n / total,
                size: 72,
                stroke: 8,
                gradient: BloomGradients.follicular,
                child: Text('$n/$total', style: t.textTheme.labelLarge),
              ),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n == total ? 'All done. Well done!' : '$n of $total done', style: t.textTheme.titleMedium),
                    Text('Go at your own pace. There is no deadline.', style: t.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        BloomCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            children: [
              for (final i in kRecoveryChecklist)
                CheckRow(
                  label: i.label,
                  checked: done.contains(i.id),
                  color: BloomColors.success,
                  onChanged: (v) {
                    v ? done.add(i.id) : done.remove(i.id);
                    store.setFeature('postpartum', {...pp, 'checklist': done});
                  },
                ),
            ],
          ),
        ),
        const EduNote(),
      ],
    );
  }
}

/// Breastfeeding timer (left or right) and bottle feeds, saved to
/// `postpartum.feeds` as `{start, end, type, ml?}`.
class FeedingLogScreen extends StatefulWidget {
  const FeedingLogScreen({super.key});

  @override
  State<FeedingLogScreen> createState() => _FeedingLogScreenState();
}

class _FeedingLogScreenState extends State<FeedingLogScreen> {
  late final AppStore _store = context.read<AppStore>();
  String? _type;
  DateTime? _start;
  Timer? _ticker;

  void _begin(String type) {
    if (_type != null) _stop();
    setState(() {
      _type = type;
      _start = DateTime.now();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stop() {
    _ticker?.cancel();
    final start = _start, type = _type;
    if (start != null && type != null) {
      _save({'start': start.toIso8601String(), 'end': DateTime.now().toIso8601String(), 'type': type});
    }
    if (mounted) {
      setState(() {
        _type = null;
        _start = null;
      });
    }
  }

  void _save(Map<String, dynamic> feed) {
    final pp = _pp(_store);
    final feeds = [...List<Map>.from(pp['feeds'] ?? const []), feed];
    if (feeds.length > 500) feeds.removeRange(0, feeds.length - 500);
    _store.setFeature('postpartum', {...pp, 'feeds': feeds});
  }

  Future<void> _bottle() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bottle feed'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (optional)', suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    final ml = double.tryParse(ctrl.text);
    ctrl.dispose();
    if (ok != true) return;
    final now = DateTime.now().toIso8601String();
    _save({'start': now, 'end': now, 'type': 'bottle', 'ml': ?ml});
  }

  @override
  void dispose() {
    if (_type != null) _stop();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final store = context.watch<AppStore>();
    final feeds = List<Map>.from(_pp(store)['feeds'] ?? const []).reversed.toList();
    final lastBreast = feeds.where((f) => f['type'] != 'bottle').firstOrNull;
    final suggest = lastBreast == null ? null : (lastBreast['type'] == 'left' ? 'right' : 'left');
    final now = DateTime.now();
    final todayCount = feeds.where((f) => sameDay(DateTime.parse(f['start']), now)).length;

    Widget side(String type, String label) => Expanded(
      child: _SideButton(
        label: label,
        active: _type == type,
        suggested: suggest == type && _type == null,
        elapsed: _type == type ? now.difference(_start!) : null,
        onTap: _type == type ? _stop : () => _begin(type),
      ),
    );

    return ModePage(
      title: 'Feeding log',
      subtitle: 'Tap a side to start the timer, and tap again to stop.',
      heroColor: BloomColors.fertile,
      children: [
        AnimatedSize(
          duration: Motion.medium,
          child: suggest != null && _type == null
              ? InfoBanner(
                  tone: BannerTone.success,
                  icon: Icons.swap_horiz_rounded,
                  message: 'Last time you started on the ${lastBreast!['type']}. Try the $suggest side next.',
                )
              : const SizedBox(width: double.infinity),
        ),
        Row(children: [side('left', 'Left'), Gap.h12, side('right', 'Right')]),
        OutlinedButton.icon(
          onPressed: _bottle,
          icon: const Icon(Icons.local_drink_rounded),
          label: const Text('Log a bottle feed'),
        ),
        if (feeds.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '$todayCount',
                  label: 'Feeds today',
                  icon: Icons.today_rounded,
                  color: BloomColors.fertile,
                ),
              ),
              Gap.h12,
              Expanded(
                child: StatTile(
                  value: _ago(now.difference(DateTime.parse(feeds.first['start']))).replaceAll(' ago', ''),
                  label: 'Since last feed',
                  icon: Icons.schedule_rounded,
                  color: BloomColors.info,
                ),
              ),
            ],
          ),
        const SectionHeader('History'),
        if (feeds.isNotEmpty)
          ListCard(
            children: [
              for (final f in feeds.take(50))
                Builder(
                  builder: (_) {
                    final s = DateTime.parse(f['start']);
                    final e = DateTime.parse(f['end']);
                    final bottle = f['type'] == 'bottle';
                    final detail = bottle
                        ? (f['ml'] != null ? '${(f['ml'] as num).round()} ml' : '')
                        : fmtDuration(e.difference(s));
                    final label = _feedLabel(f['type']);
                    return HistoryRow(
                      icon: bottle ? Icons.local_drink_rounded : Icons.baby_changing_station_rounded,
                      color: bottle ? BloomColors.info : BloomColors.fertile,
                      title: '${label[0].toUpperCase()}${label.substring(1)}',
                      subtitle: '${fmtShort(s)}, ${fmtTime(s)}',
                      trailing: detail.isEmpty
                          ? null
                          : Text(detail, style: t.textTheme.titleSmall!.copyWith(fontFeatures: tabular)),
                    );
                  },
                ),
            ],
          )
        else
          const BloomCard(
            child: EmptyState(
              compact: true,
              emoji: '🍼',
              color: BloomColors.fertile,
              title: 'No feeds logged yet.',
              body: 'Your feeds will show up here.',
            ),
          ),
        const EduNote(
          text:
              'Newborns often feed 8 to 12 times a day. If you have pain while feeding or worries about how your '
              'baby is feeding, a midwife, lactation consultant, or doctor can help.',
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.active,
    required this.suggested,
    required this.elapsed,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool suggested;
  final Duration? elapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    final tokens = BloomTokens.of(context);
    const c = BloomColors.fertile;
    final fg = active ? Colors.white : t.colorScheme.onSurface;
    return Semantics(
      button: true,
      label: '$label side, ${active ? 'stop' : 'start'}',
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        height: 148,
        decoration: BoxDecoration(
          borderRadius: Radii.lgAll,
          gradient: active ? BloomGradients.fertile : null,
          color: active ? null : (dark ? t.colorScheme.surfaceContainer : Colors.white),
          border: Border.all(
            color: active ? Colors.transparent : (suggested ? c.withValues(alpha: 0.7) : tokens.border),
            width: suggested ? 2 : 1,
          ),
          boxShadow: active && !dark ? BloomShadows.glow(c) : tokens.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: Radii.lgAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                if (suggested)
                  const Positioned(
                    top: Space.md,
                    right: Space.md,
                    child: PillChip('Next', color: c, dense: true),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 32,
                        color: active ? Colors.white : readableTint(c, t.brightness),
                      ),
                      Gap.v4,
                      Text(label, style: t.textTheme.headlineSmall!.copyWith(color: fg)),
                      AnimatedSwitcher(
                        duration: Motion.fast,
                        child: Text(
                          active ? 'Stop ${fmtDuration(elapsed!)}' : 'Start',
                          key: ValueKey(active),
                          style: t.textTheme.titleSmall!.copyWith(
                            color: active ? Colors.white : tokens.muted,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

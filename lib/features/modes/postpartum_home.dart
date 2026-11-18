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

/// [kRecoveryWeeks] text without its "Week N: " lead, for places that
/// already show the week as a heading.
String recoveryBody(int i) {
  final s = kRecoveryWeeks[i];
  final cut = s.indexOf(': ');
  if (cut < 0 || cut > 16) return s;
  final rest = s.substring(cut + 2);
  return '${rest[0].toUpperCase()}${rest.substring(1)}';
}

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
    final p = BloomColors.of(context);
    final pp = _pp(store);
    final birth = pp['birthDate'] is String ? parseDayKey(pp['birthDate']) : null;
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    if (birth == null) {
      return EmptyState(
        compact: true,
        glyph: Botanical.bud,
        title: 'After birth',
        body: 'Add your baby\'s birth date to see recovery tips for each week.',
        actionLabel: 'Add birth date',
        onAction: () async {
          final d = await pickDay(context, initial: today(), first: addDays(today(), -730), last: today());
          if (d != null) store.setFeature('postpartum', {...pp, 'birthDate': dayKey(d)});
        },
      );
    }

    final days = daysBetween(birth, today());
    final week = (days ~/ 7).clamp(0, 12);
    final checklist = List<String>.from(pp['checklist'] ?? const []);
    final done = checklist.where((id) => kRecoveryChecklist.any((c) => c.id == id)).length;
    final timelineWeek = days > 90 ? null : week;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonoLabel('After birth · Born ${fmtFull(birth)}'),
        Gap.v8,
        Text('Your baby is', style: Almanac.serif(size: 22, weight: 340, color: p.ink2)),
        Pressable(
          onTap: () => open(RecoveryTimelineScreen(currentWeek: timelineWeek)),
          child: PhaseTitle(italic: babyAgeLabel(birth, today()), size: 38),
        ),
        Gap.v20,
        WeekLedger(
          total: 12,
          value: (days / 7).clamp(0, 12).toDouble(),
          marks: const {0: 'Birth', 6: '6 wk', 12: '12 wk'},
          semanticLabel: 'Week $week of the first 12',
        ),
        Gap.v20,
        const Hairline(),
        Gap.v16,
        Marginalia(
          label: days > 90 ? 'Recovery' : (week == 0 ? 'Days 1–6' : 'Week $week'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                days > 90
                    ? 'You are past the first 12 weeks. Recovery is different for everyone; keep listening to your body.'
                    : recoveryBody(week),
                style: t.textTheme.bodyLarge!.copyWith(height: 1.6),
              ),
              Gap.v4,
              InkLink(
                'Recovery timeline',
                arrow: true,
                size: 13.5,
                onTap: () => open(RecoveryTimelineScreen(currentWeek: timelineWeek)),
              ),
            ],
          ),
        ),
        const SectionHeader(
          'Your notebook',
          label: 'Index',
          padding: EdgeInsets.only(top: Space.xxxl),
        ),
        Gap.v12,
        ToolGrid(
          items: [
            ToolItem(
              Icons.baby_changing_station_outlined,
              'Feeding log',
              BloomColors.fertile,
              () => open(const FeedingLogScreen()),
              caption: _lastFeedSummary(pp),
            ),
            ToolItem(
              Icons.checklist,
              'Recovery checklist',
              BloomColors.success,
              () => open(const RecoveryChecklistScreen()),
              caption: '$done of ${kRecoveryChecklist.length} done',
            ),
            ToolItem(
              Icons.timeline,
              'Recovery timeline',
              BloomColors.follicular,
              () => open(RecoveryTimelineScreen(currentWeek: timelineWeek)),
              caption: 'The first twelve weeks',
            ),
          ],
        ),
        const SectionHeader(
          'Bleeding after birth',
          label: 'Lochia',
          padding: EdgeInsets.only(top: Space.xxxl),
        ),
        Gap.v8,
        const Text(
          'Bleeding (lochia) usually lasts up to about 6 weeks and slowly gets lighter. '
          'Log it to keep an eye on how it changes. Get medical help right away if you soak a pad in an hour, '
          'pass clots bigger than a plum, have a fever, or the bleeding smells bad.',
        ),
        Gap.v12,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkButton.outlined(
            label: 'Log today',
            icon: Icons.edit_note,
            dense: true,
            color: BloomColors.period,
            onPressed: () => showLogSheet(context, today()),
          ),
        ),
        const SectionHeader(
          'How are you feeling?',
          label: 'Mood',
          padding: EdgeInsets.only(top: Space.xxxl),
        ),
        Gap.v8,
        const Text(
          'Up to 4 in 5 new parents get the baby blues: tearfulness and mood swings in the first two weeks. '
          'If low mood, anxiety, or not enjoying things lasts longer than two weeks, or you have thoughts of '
          'harming yourself or your baby, it could be postpartum depression or anxiety. It is common and '
          'treatable. Tell your care provider, a health visitor, or someone you trust. In a crisis, contact '
          'emergency services or a local crisis line.',
        ),
        Gap.v24,
        const Hairline(),
        Gap.v12,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkLink(
            'My period is back',
            arrow: true,
            color: BloomColors.period,
            onTap: () => startPeriodBackFlow(context),
          ),
        ),
        Gap.v8,
        const EduNote(),
      ],
    );
  }
}

String _lastFeedSummary(Map<String, dynamic> pp) {
  final feeds = List<Map>.from(pp['feeds'] ?? const []);
  if (feeds.isEmpty) return 'Time each side, or log bottle feeds.';
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

/// The first 12 weeks as a printed vertical timeline: mono week numbers in
/// the margin, a hairline spine with ink dots, and an ink marker on this week.
class RecoveryTimelineScreen extends StatelessWidget {
  const RecoveryTimelineScreen({super.key, this.currentWeek});
  final int? currentWeek;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = BloomColors.of(context);
    final last = kRecoveryWeeks.length - 1;
    return ModePage(
      eyebrow: 'After birth',
      title: 'Recovery timeline',
      subtitle: 'What to expect in the first 12 weeks.',
      spacing: 0,
      children: [
        for (var i = 0; i <= last; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      i == 0 ? 'DAYS' : 'WK ${indexNumber(i)}',
                      style: Almanac.label(context, color: i == currentWeek ? p.ink : null),
                    ),
                  ),
                ),
                SizedBox(
                  width: 24,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        top: i == 0 ? 8 : 0,
                        bottom: i == last ? null : 0,
                        height: i == last ? 8 : null,
                        child: Container(width: 1, color: p.hairline),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: i == currentWeek ? 2 : 4),
                        child: Container(
                          width: i == currentWeek ? 12 : 8,
                          height: i == currentWeek ? 12 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentWeek != null && i <= currentWeek! ? p.ink : p.paper,
                            border: Border.all(color: currentWeek != null && i <= currentWeek! ? p.ink : p.ink2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.h12,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: i == 0 ? 'First days' : 'Week ${Almanac.spell(i)}',
                                style: Almanac.serif(size: 19, weight: 370, color: p.ink),
                              ),
                              if (i == currentWeek)
                                TextSpan(
                                  text: '   this week',
                                  style: Almanac.italic(context, size: 15, color: p.ink2),
                                ),
                            ],
                          ),
                        ),
                        Gap.v4,
                        Text(
                          recoveryBody(i),
                          style: t.textTheme.bodyMedium!.copyWith(
                            color: currentWeek == null || i >= currentWeek! ? p.ink : p.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const EduNote(),
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
      eyebrow: 'After birth',
      title: 'Recovery checklist',
      subtitle: 'Small steps for your first weeks.',
      children: [
        SerifFigure(value: '$n', unit: n == total ? 'of $total. All done.' : 'of $total done', size: 52),
        SoftBar(value: n / total),
        Text('Go at your own pace. There is no deadline.', style: t.textTheme.bodySmall),
        Gap.v8,
        CheckList(
          children: [
            for (final i in kRecoveryChecklist)
              CheckRow(
                label: i.label,
                checked: done.contains(i.id),
                onChanged: (v) {
                  v ? done.add(i.id) : done.remove(i.id);
                  store.setFeature('postpartum', {...pp, 'checklist': done});
                },
              ),
          ],
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
  // Read in initState: dispose() saves an unfinished session, and the
  // context can't be used for lookups by then.
  late final AppStore _store;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>();
  }

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
    if (mounted && !_disposed) {
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
    void write() => _store.setFeature('postpartum', {...pp, 'feeds': feeds});
    // From dispose() the tree is locked, so save after this frame.
    _disposed ? Future.microtask(write) : write();
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
    _disposed = true;
    if (_type != null) _stop();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      eyebrow: 'After birth',
      title: 'Feeding log',
      subtitle: 'Tap a side to start the timer, and tap again to stop.',
      children: [
        AnimatedSize(
          duration: Motion.medium,
          child: suggest != null && _type == null
              ? Marginalia(
                  label: 'Next',
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Last time you started on the ${lastBreast!['type']}. Try the '),
                        TextSpan(text: '$suggest side', style: Almanac.italic(context, size: 16)),
                        const TextSpan(text: ' next.'),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Row(children: [side('left', 'Left'), Gap.h12, side('right', 'Right')]),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkButton.outlined(label: 'Log a bottle feed', icon: Icons.add, onPressed: _bottle),
        ),
        if (feeds.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: StatTile(value: '$todayCount', label: 'Feeds today'),
              ),
              Gap.h16,
              Expanded(
                child: StatTile(
                  value: _ago(now.difference(DateTime.parse(feeds.first['start']))).replaceAll(' ago', ''),
                  label: 'Since last feed',
                ),
              ),
            ],
          ),
        const SectionHeader('History', label: 'Ledger'),
        if (feeds.isNotEmpty)
          LedgerTable(
            columns: const [
              LedgerColumn('When', flex: 4),
              LedgerColumn('Side', flex: 4),
              LedgerColumn('Length', flex: 3, end: true),
            ],
            rows: [for (final f in feeds.take(50)) _feedRow(context, f)],
          )
        else
          const EmptyState(compact: true, title: 'No feeds logged yet.', body: 'Your feeds will show up here.'),
        const EduNote(
          text:
              'Newborns often feed 8 to 12 times a day. If you have pain while feeding or worries about how your '
              'baby is feeding, a midwife, lactation consultant, or doctor can help.',
        ),
      ],
    );
  }
}

LedgerRow _feedRow(BuildContext context, Map f) {
  final s = DateTime.parse(f['start']);
  final e = DateTime.parse(f['end']);
  final bottle = f['type'] == 'bottle';
  final detail = bottle ? (f['ml'] != null ? '${(f['ml'] as num).round()} ml' : '–') : fmtDuration(e.difference(s));
  final label = _feedLabel(f['type']);
  return LedgerRow([
    Text('${fmtShort(s)}, ${fmtTime(s)}', maxLines: 1, overflow: TextOverflow.ellipsis),
    Text(
      '${label[0].toUpperCase()}${label.substring(1)}',
      style: Almanac.italic(context, size: 15),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    Text(detail),
  ]);
}

/// One breast side: a hairline box with a serif label. While its timer
/// runs it turns into an inked block with the elapsed time.
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
    final p = BloomColors.of(context);
    final fg = active ? p.paper : p.ink;
    return Pressable(
      onTap: onTap,
      semanticLabel: '$label side, ${active ? 'stop' : 'start'}',
      borderRadius: Radii.lgAll,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        constraints: const BoxConstraints(minHeight: 148),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: active ? p.ink : Colors.transparent,
          borderRadius: Radii.lgAll,
          border: Border.all(color: active || suggested ? p.ink : p.hairline, width: suggested ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(
              active ? 'Timing' : (suggested ? 'Next' : 'Breast'),
              color: active ? p.paper.withValues(alpha: 0.75) : (suggested ? p.ink : null),
            ),
            Gap.v32,
            Text(label, style: Almanac.serif(size: 30, weight: 340, color: fg)),
            Gap.v4,
            AnimatedSwitcher(
              duration: Motion.fast,
              child: Text(
                active ? fmtDuration(elapsed!) : 'tap to start',
                key: ValueKey(active),
                style: active
                    ? Almanac.mono(size: 15, color: fg).copyWith(fontFeatures: tabular)
                    : Almanac.italic(context, size: 15, color: p.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

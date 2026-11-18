/// Pregnancy summary shown at the top of the Today screen, and the
/// week-by-week detail screen.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'goal_screen.dart';
import 'modes_common.dart';
import 'pregnancy_content.dart';
import 'pregnancy_math.dart';
import 'pregnancy_tools.dart';

String _lengthLabel(BabySize s) =>
    s.lengthCm < 1 ? '${(s.lengthCm * 10).round()} mm' : '${s.lengthCm.toStringAsFixed(1)} cm';

class PregnancyHome extends StatelessWidget {
  const PregnancyHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final pd = readPregnancy(store);
    final t = Theme.of(context);
    final p = BloomColors.of(context);
    if (pd == null) {
      return EmptyState(
        compact: true,
        glyph: Botanical.sprout,
        color: BloomColors.pregnancy,
        title: 'Track your pregnancy',
        body: 'Add your last period or due date to see your week-by-week progress.',
        actionLabel: 'Set up pregnancy',
        onAction: () => startPregnancyActivation(context),
      );
    }

    final now = today();
    final age = pd.ageOn(now);
    final toGo = pd.daysToGo(now);
    final size = babySizeForWeek(age.weeks);
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    final countdown = toGo > 0
        ? SerifFigure(value: '$toGo', unit: 'days to go', size: 44)
        : Text(
            toGo == 0 ? 'Due today' : '${-toGo} days past due date',
            style: Almanac.italic(context, size: 24, color: p.ink),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (age.isOverdue) ...[
          Container(
            padding: const EdgeInsets.only(left: Space.lg),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: p.ink, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Has your baby arrived?', style: t.textTheme.headlineSmall),
                Gap.v8,
                const Text(
                  'You are past 42 weeks. If your baby is here, congratulations! '
                  'Log the birth to switch to after-birth mode. If not, keep in close touch with your care provider.',
                ),
                Gap.v12,
                Wrap(
                  spacing: Space.xl,
                  runSpacing: Space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkButton(label: 'A baby is born!', dense: true, onPressed: () => startBirthFlow(context)),
                    InkLink('Edit dates', onTap: () => open(const PregnancySettingsScreen())),
                  ],
                ),
              ],
            ),
          ),
          Gap.v32,
        ],
        // Hero: the week in words, then the 40-week ledger.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MonoLabel(
                [trimesterLabel(age.trimester), if (pd.babies > 1) pd.babies == 2 ? 'Twins' : 'Multiples'].join(' · '),
              ),
            ),
            InkLink('Settings', size: 13, onTap: () => open(const PregnancySettingsScreen())),
          ],
        ),
        Gap.v4,
        Pressable(
          onTap: () => open(WeekDetailScreen(week: age.contentWeek)),
          semanticLabel: 'Week ${age.weeks}, day ${age.days}. Open this week.',
          child: PhaseTitle(
            lead: 'Week ${Almanac.spell(age.weeks)},',
            italic: 'day ${Almanac.spell(age.days)}.',
            color: BloomColors.pregnancy,
            size: 40,
          ),
        ),
        Gap.v20,
        WeekLedger(
          total: 40,
          value: (age.totalDays / 7).clamp(0, 40).toDouble(),
          accent: BloomColors.pregnancy,
          marks: const {0: '0', 13: '13', 27: '27', 40: '40'},
          semanticLabel: 'Week ${age.weeks} of 40',
        ),
        Gap.v8,
        Row(
          children: [
            Text('Week ${age.weeks} · Day ${age.days}', style: Almanac.data(context)),
            const Spacer(),
            Text('${(age.progress * 100).round()} %', style: Almanac.data(context)),
          ],
        ),
        Gap.v20,
        if (size != null) ...[
          Marginalia(
            label: 'Size',
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Your baby is about the size of '),
                  TextSpan(text: size.name, style: Almanac.italic(context, size: 16.5)),
                  TextSpan(text: '${pd.babies > 1 ? ' (each)' : ''}, around ${_lengthLabel(size)} long.'),
                ],
              ),
            ),
          ),
          Gap.v20,
        ],
        const Hairline(),
        Gap.v16,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: countdown),
            Gap.h12,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const MonoLabel('Due'),
                Gap.v4,
                Text(fmtFull(pd.dueDate), style: Almanac.serif(size: 17, weight: 360, color: p.ink)),
              ],
            ),
          ],
        ),
        Gap.v16,
        const Hairline(),
        SectionHeader(
          'This week',
          padding: const EdgeInsets.only(top: Space.xxl),
          label: 'Week ${age.contentWeek} · Field notes',
          actionLabel: 'Read',
          onAction: () => open(WeekDetailScreen(week: age.contentWeek)),
        ),
        Gap.v8,
        Text(weekContent(age.contentWeek).baby, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SectionHeader(
          'Pregnancy tools',
          label: 'Index',
          padding: EdgeInsets.only(top: Space.xxxl),
        ),
        Gap.v12,
        ToolGrid(
          items: [
            ToolItem(
              Icons.touch_app_outlined,
              'Kick counter',
              BloomColors.pregnancy,
              () => open(const KickCounterScreen()),
              caption: 'Time ten movements',
            ),
            ToolItem(
              Icons.timer_outlined,
              'Contractions',
              BloomColors.period,
              () => open(const ContractionTimerScreen()),
              caption: 'Length and interval',
            ),
            ToolItem(
              Icons.monitor_weight_outlined,
              'Weight',
              BloomColors.fertile,
              () => open(const PregnancyWeightScreen()),
              caption: 'By pregnancy week',
            ),
            ToolItem(
              Icons.checklist,
              'Checklist',
              BloomColors.success,
              () => open(const PregnancyChecklistScreen()),
              caption: 'Trimester by trimester',
            ),
            ToolItem(
              Icons.event_note_outlined,
              'Appointments',
              BloomColors.info,
              () => open(const AppointmentsScreen()),
              caption: 'Checkups and questions',
            ),
            ToolItem(
              Icons.auto_stories_outlined,
              'Week by week',
              BloomColors.luteal,
              () => open(WeekDetailScreen(week: age.contentWeek)),
              caption: 'All forty-two weeks',
            ),
          ],
        ),
      ],
    );
  }
}

/// Week-by-week content, like a page in a field guide, with a strip of week
/// numerals and links to browse weeks 1-42.
class WeekDetailScreen extends StatefulWidget {
  const WeekDetailScreen({super.key, required this.week});
  final int week;

  @override
  State<WeekDetailScreen> createState() => _WeekDetailScreenState();
}

class _WeekDetailScreenState extends State<WeekDetailScreen> {
  late int _week = widget.week.clamp(1, 42);
  final _strip = ScrollController();
  static const _cell = 44.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(animate: false));
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  void _center({bool animate = true}) {
    if (!_strip.hasClients) return;
    final pos = _strip.position;
    final target = ((_week - 1) * _cell - (pos.viewportDimension - _cell) / 2).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    animate ? _strip.animateTo(target, duration: Motion.medium, curve: Motion.curve) : _strip.jumpTo(target);
  }

  void _go(int w) {
    if (w < 1 || w > 42 || w == _week) return;
    Almanac.tick();
    setState(() => _week = w);
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = BloomColors.of(context);
    final c = weekContent(_week);
    final size = babySizeForWeek(_week);
    final trimester = GestationalAge(_week * 7).trimester;
    final checklist = kPregnancyChecklist.where((i) => i.trimester == trimester).toList();
    final store = context.watch<AppStore>();
    final pd = readPregnancy(store);
    final done = pd?.checklist ?? const <String>[];
    final current = pd?.ageOn(today()).contentWeek;

    Widget section(String label, String body) => Marginalia(
      label: label,
      child: Text(body, style: t.textTheme.bodyLarge!.copyWith(height: 1.6)),
    );

    final hero = AnimatedSwitcher(
      duration: Motion.medium,
      layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
      child: Column(
        key: ValueKey(_week),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel('Week $_week of 40 · ${trimesterLabel(trimester)}'),
          Gap.v12,
          PhaseTitle(
            lead: size == null ? 'Week ${Almanac.spell(_week)},' : 'The size of',
            italic: size == null ? 'tiny beginnings.' : '${size.name}.',
            color: BloomColors.pregnancy,
            size: 38,
          ),
          if (size != null) ...[
            Gap.v8,
            Text('Around ${_lengthLabel(size)} long', style: Almanac.italic(context, size: 17, color: p.ink2)),
          ],
        ],
      ),
    );

    return ModePage(
      title: 'Week $_week',
      header: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -200) _go(_week + 1);
          if (v > 200) _go(_week - 1);
        },
        child: hero,
      ),
      children: [
        SizedBox(
          height: 48,
          child: ListView.builder(
            controller: _strip,
            scrollDirection: Axis.horizontal,
            itemCount: 42,
            itemExtent: _cell,
            itemBuilder: (context, i) {
              final w = i + 1;
              final sel = w == _week;
              return Pressable(
                onTap: () => _go(w),
                selected: sel,
                semanticLabel: 'Week $w',
                borderRadius: Radii.smAll,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: Motion.medium,
                      width: 34,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: Radii.smAll,
                        border: Border.all(color: sel ? p.ink : Colors.transparent),
                      ),
                      child: Text(
                        '$w',
                        style: Almanac.numeral(
                          context,
                          size: 18,
                          weight: sel ? 420 : 320,
                          color: sel || w == current ? p.ink : p.ink2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 14,
                      height: 1.5,
                      color: w == current ? BloomColors.resolve(context, BloomColors.pregnancy) : Colors.transparent,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          children: [
            if (_week > 1) InkLink('← Week ${_week - 1}', size: 13.5, onTap: () => _go(_week - 1)),
            const Spacer(),
            if (current != null && current != _week) ...[
              InkLink('This week', size: 13.5, onTap: () => _go(current)),
              const Spacer(),
            ],
            if (_week < 42) InkLink('Week ${_week + 1}', size: 13.5, arrow: true, onTap: () => _go(_week + 1)),
          ],
        ),
        const Hairline(),
        AnimatedSwitcher(
          duration: Motion.medium,
          child: Column(
            key: ValueKey(_week),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap.v8,
              section('Baby', c.baby),
              Gap.v24,
              section('Body', c.body),
              Gap.v24,
              section('Tip', c.tip),
              Gap.v8,
            ],
          ),
        ),
        const Hairline(),
        SectionHeader(
          '${trimesterLabel(trimester)} checklist',
          label: 'To do',
          actionLabel: 'Open',
          onAction: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PregnancyChecklistScreen())),
        ),
        CheckList(
          children: [
            for (final i in checklist)
              CheckRow(
                label: i.label,
                checked: done.contains(i.id),
                onChanged: pd == null
                    ? null
                    : (v) {
                        v ? pd.checklist.add(i.id) : pd.checklist.remove(i.id);
                        savePregnancy(store, pd);
                      },
              ),
          ],
        ),
        const EduNote(),
      ],
    );
  }
}

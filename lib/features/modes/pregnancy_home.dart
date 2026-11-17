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
    final p = readPregnancy(store);
    final t = Theme.of(context);
    if (p == null) {
      return BloomCard(
        child: EmptyState(
          compact: true,
          emoji: '🤰',
          color: BloomColors.pregnancy,
          title: 'Track your pregnancy',
          body: 'Add your last period or due date to see your week-by-week progress.',
          actionLabel: 'Set up pregnancy',
          onAction: () => startPregnancyActivation(context),
        ),
      );
    }

    final now = today();
    final age = p.ageOn(now);
    final toGo = p.daysToGo(now);
    final size = babySizeForWeek(age.weeks);
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    final muted = BloomTokens.of(context).muted;
    final accent = readableTint(BloomColors.pregnancy, t.brightness);

    final countdown = toGo > 0
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$toGo',
                  style: t.textTheme.headlineSmall!.copyWith(color: accent),
                ),
                TextSpan(
                  text: ' days to go',
                  style: t.textTheme.bodyMedium!.copyWith(color: muted),
                ),
              ],
            ),
          )
        : Text(
            toGo == 0 ? 'Due today' : '${-toGo} days past due date',
            style: t.textTheme.titleMedium!.copyWith(color: accent),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (age.isOverdue) ...[
          SectionCard(
            color: BloomColors.info,
            title: 'Has your baby arrived?',
            icon: Icons.child_friendly_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'You are past 42 weeks. If your baby is here, congratulations! '
                  'Log the birth to switch to after-birth mode. If not, keep in close touch with your care provider.',
                ),
                Gap.v12,
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    FilledButton(onPressed: () => startBirthFlow(context), child: const Text('A baby is born!')),
                    OutlinedButton(
                      onPressed: () => open(const PregnancySettingsScreen()),
                      child: const Text('Edit dates'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap.v16,
        ],
        // Hero.
        BloomCard(
          padding: EdgeInsets.zero,
          onTap: () => open(WeekDetailScreen(week: age.contentWeek)),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: BloomGradients.wash(BloomColors.pregnancy, t.brightness)),
            child: Padding(
              padding: Insets.card,
              child: Column(
                children: [
                  Row(
                    children: [
                      PillChip(trimesterLabel(age.trimester), color: BloomColors.pregnancy, icon: Icons.spa_rounded),
                      if (p.babies > 1) ...[
                        Gap.h8,
                        PillChip(p.babies == 2 ? 'Twins' : 'Multiples', color: BloomColors.coral),
                      ],
                      const Spacer(),
                      IconButton(
                        tooltip: 'Pregnancy settings',
                        onPressed: () => open(const PregnancySettingsScreen()),
                        icon: Icon(Icons.tune_rounded, color: muted),
                      ),
                    ],
                  ),
                  Gap.v8,
                  ProgressRing(
                    value: age.progress,
                    size: 196,
                    stroke: 14,
                    gradient: BloomGradients.pregnancy,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(size?.emoji ?? '🌱', style: const TextStyle(fontSize: 64, height: 1.1)),
                        Gap.v4,
                        Text('${(age.progress * 100).round()}%', style: t.textTheme.labelLarge!.copyWith(color: muted)),
                      ],
                    ),
                  ),
                  Gap.v16,
                  Text(
                    'Week ${age.weeks} · Day ${age.days}',
                    style: t.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (size != null) ...[
                    Gap.v4,
                    Text(
                      'Your baby is about the size of ${size.name}${p.babies > 1 ? ' (each)' : ''}, '
                      'around ${_lengthLabel(size)} long.',
                      style: t.textTheme.bodyMedium!.copyWith(color: muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  Gap.v16,
                  Divider(height: 1, color: BloomTokens.of(context).border),
                  Gap.v12,
                  Row(
                    children: [
                      Expanded(child: countdown),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Due date', style: t.textTheme.bodySmall),
                          Text(fmtFull(p.dueDate), style: t.textTheme.titleSmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Gap.v16,
        SectionCard(
          title: 'This week',
          icon: Icons.auto_stories_rounded,
          accent: BloomColors.pregnancy,
          trailing: const CardChevron(),
          onTap: () => open(WeekDetailScreen(week: age.contentWeek)),
          child: Text(weekContent(age.contentWeek).baby, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        Gap.v8,
        const SectionHeader('Pregnancy tools'),
        Gap.v12,
        ToolGrid(
          items: [
            ToolItem(
              Icons.touch_app_rounded,
              'Kick counter',
              BloomColors.pregnancy,
              () => open(const KickCounterScreen()),
            ),
            ToolItem(
              Icons.timer_rounded,
              'Contractions',
              BloomColors.period,
              () => open(const ContractionTimerScreen()),
            ),
            ToolItem(
              Icons.monitor_weight_rounded,
              'Weight',
              BloomColors.fertile,
              () => open(const PregnancyWeightScreen()),
            ),
            ToolItem(
              Icons.checklist_rounded,
              'Checklist',
              BloomColors.success,
              () => open(const PregnancyChecklistScreen()),
            ),
            ToolItem(
              Icons.event_note_rounded,
              'Appointments',
              BloomColors.info,
              () => open(const AppointmentsScreen()),
            ),
            ToolItem(
              Icons.auto_stories_rounded,
              'Week by week',
              BloomColors.luteal,
              () => open(WeekDetailScreen(week: age.contentWeek)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Week-by-week content, with a week strip and arrows to browse weeks 1-42.
class WeekDetailScreen extends StatefulWidget {
  const WeekDetailScreen({super.key, required this.week});
  final int week;

  @override
  State<WeekDetailScreen> createState() => _WeekDetailScreenState();
}

class _WeekDetailScreenState extends State<WeekDetailScreen> {
  late int _week = widget.week.clamp(1, 42);
  final _strip = ScrollController();
  static const _dot = 44.0;
  static const _gap = Space.sm;

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
    final target = ((_week - 1) * (_dot + _gap) - (pos.viewportDimension - _dot) / 2).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    animate ? _strip.animateTo(target, duration: Motion.medium, curve: Motion.curve) : _strip.jumpTo(target);
  }

  void _go(int w) {
    if (w < 1 || w > 42 || w == _week) return;
    setState(() => _week = w);
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final c = weekContent(_week);
    final size = babySizeForWeek(_week);
    final trimester = GestationalAge(_week * 7).trimester;
    final checklist = kPregnancyChecklist.where((i) => i.trimester == trimester).toList();
    final store = context.watch<AppStore>();
    final p = readPregnancy(store);
    final done = p?.checklist ?? const <String>[];
    final current = p?.ageOn(today()).contentWeek;

    Widget section(String title, IconData icon, Color color, String body) => SectionCard(
      title: title,
      icon: icon,
      accent: color,
      child: Text(body, style: t.textTheme.bodyLarge),
    );

    return ModePage(
      eyebrow: 'Week by week',
      title: 'Week $_week',
      subtitle: trimesterLabel(trimester),
      heroColor: BloomColors.pregnancy,
      children: [
        SizedBox(
          height: _dot + 18,
          child: ListView.separated(
            controller: _strip,
            scrollDirection: Axis.horizontal,
            itemCount: 42,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, i) {
              final w = i + 1;
              final sel = w == _week;
              return Column(
                children: [
                  InkWell(
                    onTap: () => _go(w),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      width: _dot,
                      height: _dot,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: sel ? BloomGradients.pregnancy : null,
                        color: sel
                            ? null
                            : (t.brightness == Brightness.dark ? t.colorScheme.surfaceContainer : Colors.white),
                        border: Border.all(color: sel ? Colors.transparent : tokens.border),
                      ),
                      child: Text(
                        '$w',
                        style: t.textTheme.titleSmall!.copyWith(
                          color: sel ? BloomColors.onColor(BloomGradients.pregnancy.colors.first) : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  if (w == current)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: BloomColors.pregnancy, shape: BoxShape.circle),
                    ),
                ],
              );
            },
          ),
        ),
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) _go(_week + 1);
            if (v > 200) _go(_week - 1);
          },
          child: BloomCard.gradient(
            gradient: BloomGradients.pregnancy,
            padding: const EdgeInsets.symmetric(vertical: Space.xl, horizontal: Space.sm),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: _week > 1 ? () => _go(_week - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 32),
                  color: Colors.white,
                  disabledColor: Colors.white38,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
                    ),
                    child: Column(
                      key: ValueKey(_week),
                      children: [
                        Text(size?.emoji ?? '🌱', style: const TextStyle(fontSize: 72, height: 1.1)),
                        Gap.v12,
                        Text(
                          size == null ? 'Tiny beginnings' : 'About the size of ${size.name}.',
                          style: t.textTheme.titleLarge!.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        if (size != null) ...[
                          Gap.v4,
                          Text(
                            'Around ${_lengthLabel(size)} long',
                            style: t.textTheme.bodyMedium!.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: _week < 42 ? () => _go(_week + 1) : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 32),
                  color: Colors.white,
                  disabledColor: Colors.white38,
                ),
              ],
            ),
          ),
        ),
        section('Your baby', Icons.child_care_rounded, BloomColors.pregnancy, c.baby),
        section('Your body', Icons.self_improvement_rounded, BloomColors.coral, c.body),
        section('Tip', Icons.lightbulb_rounded, BloomColors.luteal, c.tip),
        SectionHeader(
          '${trimesterLabel(trimester)} checklist',
          actionLabel: 'Open',
          onAction: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PregnancyChecklistScreen())),
        ),
        BloomCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Column(
            children: [
              for (final i in checklist)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
                  child: Row(
                    children: [
                      Icon(
                        done.contains(i.id) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: done.contains(i.id) ? BloomColors.success : tokens.muted.withValues(alpha: 0.6),
                      ),
                      Gap.h12,
                      Expanded(child: Text(i.label, style: t.textTheme.bodyMedium)),
                    ],
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

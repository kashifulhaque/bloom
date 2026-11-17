/// "My goal" screen plus the flows that move between goals: activating
/// pregnancy, logging a birth, ending a pregnancy, and logging the first
/// period after birth.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'modes_common.dart';
import 'pregnancy_content.dart';
import 'pregnancy_math.dart';

class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key});

  static const _icons = {
    Goal.trackCycle: Icons.water_drop_rounded,
    Goal.getPregnant: Icons.favorite_rounded,
    Goal.trackPregnancy: Icons.pregnant_woman_rounded,
    Goal.postpartum: Icons.child_friendly_rounded,
    Goal.perimenopause: Icons.spa_rounded,
  };

  static const _subtitles = {
    Goal.trackCycle: 'Predict periods and learn your patterns',
    Goal.getPregnant: 'Focus on your fertile window and ovulation',
    Goal.trackPregnancy: 'Follow your pregnancy week by week',
    Goal.postpartum: 'Recovery, feeding, and your period returning',
    Goal.perimenopause: 'Track symptoms and understand the transition',
  };

  static const _gradients = {
    Goal.trackCycle: BloomGradients.period,
    Goal.getPregnant: BloomGradients.fertile,
    Goal.trackPregnancy: BloomGradients.pregnancy,
    Goal.postpartum: BloomGradients.follicular,
    Goal.perimenopause: BloomGradients.luteal,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final current = store.profile.goal;
    final pregnancy = current == Goal.trackPregnancy ? readPregnancy(store) : null;

    return ModePage(
      title: 'My goal',
      subtitle: 'Bloom shapes your home screen, predictions, and tips around what matters to you now.',
      children: [
        for (final g in Goal.values)
          _GoalCard(
            icon: _icons[g]!,
            title: g.label,
            subtitle: _subtitles[g]!,
            gradient: _gradients[g]!,
            selected: g == current,
            onTap: g == current ? null : () => switchGoal(context, g),
          ),
        if (current == Goal.trackPregnancy) ...[
          const SectionHeader('Your pregnancy'),
          if (pregnancy == null)
            BloomCard(
              child: EmptyState(
                compact: true,
                emoji: '🤰',
                color: BloomColors.pregnancy,
                title: 'Let\'s set up your pregnancy',
                body: 'Add your last period or due date to follow along week by week.',
                actionLabel: 'Set up pregnancy',
                onAction: () => startPregnancyActivation(context),
              ),
            )
          else
            MenuSection(
              children: [
                MenuTile(
                  icon: Icons.tune_rounded,
                  color: BloomColors.pregnancy,
                  title: 'Pregnancy settings',
                  subtitle: 'Due ${fmtFull(pregnancy.dueDate)}',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const PregnancySettingsScreen())),
                ),
                MenuTile(
                  icon: Icons.celebration_rounded,
                  color: BloomColors.coral,
                  title: 'A baby is born!',
                  subtitle: 'Switch to after-birth mode',
                  onTap: () => startBirthFlow(context),
                ),
                MenuTile(
                  icon: Icons.favorite_border_rounded,
                  color: BloomColors.luteal,
                  title: 'End pregnancy',
                  subtitle: 'For a pregnancy loss',
                  onTap: () => startLossFlow(context),
                ),
              ],
            ),
        ],
        if (current == Goal.postpartum) ...[
          const SectionHeader('After birth'),
          MenuSection(
            children: [
              MenuTile(
                icon: Icons.water_drop_rounded,
                color: BloomColors.period,
                title: 'My period is back',
                subtitle: 'Log it and return to cycle tracking',
                onTap: () => startPeriodBackFlow(context),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final dark = t.brightness == Brightness.dark;
    final c = gradient.colors.first;
    final fg = readableTint(c, t.brightness);
    final base = dark ? t.colorScheme.surfaceContainer : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: selected ? Color.alphaBlend(c.withValues(alpha: dark ? 0.18 : 0.08), base) : base,
          borderRadius: Radii.lgAll,
          border: Border.all(
            color: selected ? c.withValues(alpha: dark ? 0.85 : 0.75) : (dark ? tokens.border : base),
            width: 2,
          ),
          boxShadow: tokens.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: Radii.lgAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: Insets.cardCompact,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Motion.medium,
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.md),
                      gradient: selected ? gradient : null,
                      color: selected ? null : c.withValues(alpha: dark ? 0.22 : 0.13),
                    ),
                    child: Icon(icon, size: 28, color: selected ? Colors.white : fg),
                  ),
                  Gap.h16,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.textTheme.titleMedium),
                        const SizedBox(height: Space.xxs),
                        Text(subtitle, style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Gap.h8,
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    switchInCurve: Motion.spring,
                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                    child: selected
                        ? Icon(Icons.check_circle_rounded, key: const ValueKey(1), color: fg, size: 26)
                        : Icon(
                            Icons.radio_button_unchecked_rounded,
                            key: const ValueKey(0),
                            color: tokens.muted.withValues(alpha: 0.45),
                            size: 26,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Switches to [g], running the right flow for pregnancy and postpartum.
Future<void> switchGoal(BuildContext context, Goal g) async {
  final store = context.read<AppStore>();
  final from = store.profile.goal;
  if (from == Goal.trackPregnancy && readPregnancy(store) != null && g != Goal.trackPregnancy) {
    final ok = await confirmDialog(
      context,
      title: 'Leave pregnancy mode?',
      body:
          'Your pregnancy details stay saved. To log a birth or a pregnancy loss, '
          'use "A baby is born!" or "End pregnancy" instead.',
      confirm: 'Switch goal',
    );
    if (!ok) return;
  }
  if (!context.mounted) return;
  switch (g) {
    case Goal.trackPregnancy:
      await startPregnancyActivation(context);
    case Goal.postpartum:
      final pp = store.feature<Map>('postpartum');
      if (pp == null || pp['birthDate'] == null) {
        final birth = await pickDay(
          context,
          initial: today(),
          first: addDays(today(), -730),
          last: today(),
          help: "Baby's birth date",
        );
        if (birth == null) return;
        store.setFeature('postpartum', {...?pp, 'birthDate': dayKey(birth)});
      }
      store.setGoal(g);
    default:
      store.setGoal(g);
  }
}

/// Opens the activation flow; on confirm saves `pregnancy` and sets the goal.
Future<void> startPregnancyActivation(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PregnancyActivationScreen()));
}

enum _DateBasis { lmp, due, conception }

class PregnancyActivationScreen extends StatefulWidget {
  const PregnancyActivationScreen({super.key});

  @override
  State<PregnancyActivationScreen> createState() => _PregnancyActivationScreenState();
}

class _PregnancyActivationScreenState extends State<PregnancyActivationScreen> {
  _DateBasis _basis = _DateBasis.lmp;
  late DateTime _date;
  int _babies = 1;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final existing = readPregnancy(store);
    _date = existing?.lmp ?? store.engine.currentCycle?.start ?? addDays(today(), -28);
    if (existing != null) _babies = existing.babies;
  }

  DateTime get _lmp => switch (_basis) {
    _DateBasis.lmp => _date,
    _DateBasis.due => lmpFromDue(_date),
    _DateBasis.conception => lmpFromConception(_date),
  };

  void _setBasis(_DateBasis b) {
    final lmp = _lmp;
    setState(() {
      _basis = b;
      _date = switch (b) {
        _DateBasis.lmp => lmp,
        _DateBasis.due => dueFromLmp(lmp),
        _DateBasis.conception => addDays(lmp, 14),
      };
    });
  }

  Future<void> _pick() async {
    final now = today();
    final (first, last) = switch (_basis) {
      _DateBasis.due => (addDays(now, -21), addDays(now, kPregnancyDays)),
      _ => (addDays(now, -kPregnancyDays - 21), now),
    };
    final d = await pickDay(context, initial: _date, first: first, last: last);
    if (d != null) setState(() => _date = d);
  }

  void _confirm() {
    final store = context.read<AppStore>();
    final existing = PregnancyData.fromJson(store.feature<Map>('pregnancy'));
    final p = existing ?? PregnancyData(lmp: _lmp, babies: _babies, startedAt: DateTime.now().toIso8601String());
    p
      ..lmp = _lmp
      ..babies = _babies;
    savePregnancy(store, p);
    store.setGoal(Goal.trackPregnancy);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final age = gestationalAge(_lmp, today());
    final valid = age.totalDays >= 0 && age.weeks <= 44;
    final size = babySizeForWeek(age.weeks);
    final label = switch (_basis) {
      _DateBasis.lmp => 'First day of your last period',
      _DateBasis.due => 'Due date',
      _DateBasis.conception => 'Conception date',
    };
    return ModePage(
      title: 'Track pregnancy',
      subtitle: 'Congratulations! Let\'s set up a few details so Bloom can follow along with you.',
      heroColor: BloomColors.pregnancy,
      children: [
        const SectionHeader('What date do you know?'),
        SegmentedButton<_DateBasis>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _DateBasis.lmp, label: Text('Last period')),
            ButtonSegment(value: _DateBasis.due, label: Text('Due date')),
            ButtonSegment(value: _DateBasis.conception, label: Text('Conception')),
          ],
          selected: {_basis},
          onSelectionChanged: (s) => _setBasis(s.first),
        ),
        DateField(label: label, date: _date, onTap: _pick, color: BloomColors.pregnancy),
        const SectionHeader('How many babies?'),
        BabiesSelector(value: _babies, onChanged: (v) => setState(() => _babies = v)),
        Gap.v4,
        AnimatedSwitcher(
          duration: Motion.medium,
          child: valid
              ? BloomCard.tinted(
                  key: const ValueKey('ok'),
                  color: BloomColors.pregnancy,
                  child: Row(
                    children: [
                      IconBadge(emoji: size?.emoji ?? '🌱', color: BloomColors.pregnancy, size: 56),
                      Gap.h16,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Week ${age.weeks} · Day ${age.days}', style: t.textTheme.titleLarge),
                            Text(trimesterLabel(age.trimester), style: t.textTheme.bodyMedium),
                            Gap.v4,
                            Text('Estimated due date: ${fmtFull(dueFromLmp(_lmp))}', style: t.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : const InfoBanner(
                  key: ValueKey('bad'),
                  tone: BannerTone.warning,
                  message: 'That date gives a pregnancy length that is out of range. Please check it.',
                ),
        ),
        Gap.v4,
        GradientButton(
          label: 'Start pregnancy mode',
          icon: Icons.favorite_rounded,
          gradient: BloomGradients.pregnancy,
          expanded: true,
          onPressed: valid ? _confirm : null,
        ),
        const EduNote(
          text:
              'Due dates are estimates. Your care provider may adjust yours after an ultrasound; '
              'you can update it any time in Pregnancy settings.',
        ),
      ],
    );
  }
}

class BabiesSelector extends StatelessWidget {
  const BabiesSelector({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 1, label: Text('One')),
        ButtonSegment(value: 2, label: Text('Twins')),
        ButtonSegment(value: 3, label: Text('Three+')),
      ],
      selected: {value.clamp(1, 3)},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Edit LMP or due date (kept consistent: due = LMP + 280 days) and babies.
class PregnancySettingsScreen extends StatelessWidget {
  const PregnancySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = readPregnancy(store);
    if (p == null) {
      return ModePage(
        title: 'Pregnancy settings',
        children: [
          EmptyState(
            emoji: '🤰',
            color: BloomColors.pregnancy,
            title: 'No active pregnancy',
            body: 'Set up your pregnancy to see your week-by-week progress.',
            actionLabel: 'Set up pregnancy',
            onAction: () => startPregnancyActivation(context),
          ),
        ],
      );
    }
    final age = p.ageOn(today());
    void save() => savePregnancy(store, p);
    return ModePage(
      title: 'Pregnancy settings',
      subtitle: 'Due ${fmtFull(p.dueDate)}',
      children: [
        MenuSection(
          title: 'Dates',
          footer: 'Changing the last period date also moves the due date, and the other way around (280 days apart).',
          children: [
            MenuTile(
              icon: Icons.water_drop_rounded,
              color: BloomColors.period,
              title: 'First day of last period',
              subtitle: fmtFull(p.lmp),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final d = await pickDay(
                  context,
                  initial: p.lmp,
                  first: addDays(today(), -kPregnancyDays - 30),
                  last: today(),
                );
                if (d == null) return;
                p.lmp = d;
                save();
              },
            ),
            MenuTile(
              icon: Icons.event_available_rounded,
              color: BloomColors.pregnancy,
              title: 'Due date',
              subtitle: fmtFull(p.dueDate),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final d = await pickDay(
                  context,
                  initial: p.dueDate,
                  first: addDays(today(), -30),
                  last: addDays(today(), kPregnancyDays),
                );
                if (d == null) return;
                p.lmp = lmpFromDue(d);
                save();
              },
            ),
            MenuTile(
              icon: Icons.timelapse_rounded,
              color: BloomColors.luteal,
              title: 'Gestational age today',
              value: 'Week ${age.weeks} · Day ${age.days}',
              showChevron: false,
            ),
          ],
        ),
        const SectionHeader('Number of babies'),
        BabiesSelector(
          value: p.babies,
          onChanged: (v) {
            p.babies = v;
            save();
          },
        ),
        if (p.babies > 1)
          const InfoBanner(
            message: 'Twins and other multiples are often born before the due date. Your care team will guide you.',
          ),
        const EduNote(),
      ],
    );
  }
}

/// "A baby is born!": asks the birth date, archives the pregnancy, and
/// switches to postpartum mode.
Future<void> startBirthFlow(BuildContext context) async {
  final store = context.read<AppStore>();
  final p = readPregnancy(store);
  final birth = await pickDay(
    context,
    initial: today(),
    first: p != null ? addDays(p.lmp, 140) : addDays(today(), -365),
    last: today(),
    help: 'When was your baby born?',
  );
  if (birth == null || !context.mounted) return;
  archivePregnancy(store, outcome: 'birth', endDate: birth);
  final pp = store.feature<Map>('postpartum');
  store.setFeature('postpartum', {...?pp, 'birthDate': dayKey(birth), 'babies': p?.babies ?? 1});
  store.setGoal(Goal.postpartum);
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(const SnackBar(content: Text('Congratulations! Welcome to your new chapter.')));
}

/// Ends the pregnancy after a loss, with supportive copy.
Future<void> startLossFlow(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PregnancyLossScreen()));
}

class PregnancyLossScreen extends StatefulWidget {
  const PregnancyLossScreen({super.key});

  @override
  State<PregnancyLossScreen> createState() => _PregnancyLossScreenState();
}

class _PregnancyLossScreenState extends State<PregnancyLossScreen> {
  DateTime _date = today();

  void _confirm() {
    final store = context.read<AppStore>();
    archivePregnancy(store, outcome: 'loss', endDate: _date);
    store.setGoal(Goal.trackCycle);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const calm = BloomColors.luteal;
    Widget care(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: calm, size: 32),
          Gap.h12,
          Expanded(child: Text(text, style: t.textTheme.bodyMedium)),
        ],
      ),
    );

    return ModePage(
      title: 'End pregnancy',
      heroColor: calm,
      children: [
        BloomCard.tinted(
          color: calm,
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxxl, Space.xxl, Space.xxl),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: calm.withValues(alpha: t.brightness == Brightness.dark ? 0.26 : 0.16),
                ),
                child: Icon(Icons.favorite_rounded, size: 34, color: readableTint(calm, t.brightness)),
              ),
              Gap.v20,
              Text('We\'re so sorry.', style: t.textTheme.headlineSmall, textAlign: TextAlign.center),
              Gap.v12,
              Text(
                'Losing a pregnancy is painful, at any stage. Whatever you are feeling right now, grief, numbness, '
                'relief, confusion, or all of these at once, is valid. You don\'t have to do anything else here today.',
                style: t.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SectionHeader('Taking care of yourself'),
        BloomCard(
          child: Column(
            children: [
              care(
                Icons.water_drop_rounded,
                'Bleeding and cramping can continue for a while. Contact a care provider or emergency services if '
                'you soak through a pad an hour for two hours, pass large clots, have a fever, or feel faint.',
              ),
              care(
                Icons.spa_rounded,
                'Your body may take a few weeks to recover, and your period usually returns within 4 to 8 weeks.',
              ),
              care(Icons.people_alt_rounded, 'Lean on people you trust. Partners grieve too, sometimes differently.'),
              care(
                Icons.support_agent_rounded,
                'Pregnancy loss support groups, a counselor, or your care provider can help. If you feel hopeless '
                'or think about harming yourself, contact a local crisis line or emergency services right away.',
              ),
            ],
          ),
        ),
        const SectionHeader('When it happened'),
        DateField(
          label: 'Date',
          date: _date,
          color: calm,
          onTap: () async {
            final d = await pickDay(context, initial: _date, first: addDays(today(), -365), last: today());
            if (d != null) setState(() => _date = d);
          },
        ),
        Text(
          'When you continue, your pregnancy is saved privately in your history and the app returns to cycle '
          'tracking. You can change your goal again at any time.',
          style: t.textTheme.bodyMedium!.copyWith(color: BloomTokens.of(context).muted),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(onPressed: _confirm, child: const Text('Continue')),
            Gap.v8,
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Not now')),
          ],
        ),
      ],
    );
  }
}

/// "My period is back": logs a period start and switches to cycle tracking.
Future<void> startPeriodBackFlow(BuildContext context) async {
  final store = context.read<AppStore>();
  final pp = store.feature<Map>('postpartum');
  final birth = pp?['birthDate'] is String ? parseDayKey(pp!['birthDate']) : addDays(today(), -365);
  final d = await pickDay(context, initial: today(), first: birth, last: today(), help: 'When did your period start?');
  if (d == null || !context.mounted) return;
  store.setFeature('postpartum', {...?pp, 'periodReturned': dayKey(d)});
  store.startPeriod(d);
  store.setGoal(Goal.trackCycle);
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(const SnackBar(content: Text('Period logged. Bloom is tracking your cycle again.')));
}

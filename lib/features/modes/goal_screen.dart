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

  static const _subtitles = {
    Goal.trackCycle: 'Predict periods and learn your patterns.',
    Goal.getPregnant: 'Follow your fertile window and ovulation.',
    Goal.trackPregnancy: 'Follow your pregnancy week by week.',
    Goal.postpartum: 'Recovery, feeding, and your period returning.',
    Goal.perimenopause: 'Track symptoms and understand the transition.',
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final current = store.profile.goal;
    final pregnancy = current == Goal.trackPregnancy ? readPregnancy(store) : null;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    return ModePage(
      eyebrow: 'Contents',
      title: 'My goal',
      subtitle: 'Bloom shapes your home screen, predictions, and tips around what matters to you now.',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Hairline(),
            for (var i = 0; i < Goal.values.length; i++) ...[
              _GoalEntry(
                number: i + 1,
                title: Goal.values[i].label,
                subtitle: _subtitles[Goal.values[i]]!,
                selected: Goal.values[i] == current,
                onTap: Goal.values[i] == current ? null : () => switchGoal(context, Goal.values[i]),
              ),
              const Hairline(),
            ],
          ],
        ),
        if (current == Goal.trackPregnancy) ...[
          const SectionHeader('Your pregnancy', label: 'Chapter'),
          if (pregnancy == null)
            EmptyState(
              compact: true,
              glyph: Botanical.sprout,
              color: BloomColors.pregnancy,
              title: 'Let\'s set up your pregnancy',
              body: 'Add your last period or due date to follow along week by week.',
              actionLabel: 'Set up pregnancy',
              onAction: () => startPregnancyActivation(context),
            )
          else
            MenuSection(
              children: [
                MenuTile(
                  icon: Icons.tune,
                  title: 'Pregnancy settings',
                  value: 'Due ${fmtShort(pregnancy.dueDate)}',
                  onTap: () => push(const PregnancySettingsScreen()),
                ),
                MenuTile(
                  icon: Icons.child_friendly_outlined,
                  title: 'A baby is born!',
                  subtitle: 'Switch to after-birth mode',
                  onTap: () => startBirthFlow(context),
                ),
                MenuTile(
                  icon: Icons.spa_outlined,
                  title: 'End pregnancy',
                  subtitle: 'For a pregnancy loss',
                  onTap: () => startLossFlow(context),
                ),
              ],
            ),
        ],
        if (current == Goal.postpartum) ...[
          const SectionHeader('After birth', label: 'Chapter'),
          MenuSection(
            children: [
              MenuTile(
                icon: Icons.water_drop_outlined,
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

/// One goal on the contents page: a mono number, a serif title, an italic
/// description, and an ink check on the current goal.
class _GoalEntry extends StatelessWidget {
  const _GoalEntry({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return IndexEntry(
      number: number,
      title: title,
      caption: subtitle,
      selected: selected,
      titleSize: 23,
      onTap: onTap,
      trailing: AnimatedSwitcher(
        duration: Motion.medium,
        child: selected
            ? Row(
                key: const ValueKey(1),
                mainAxisSize: MainAxisSize.min,
                children: [
                  MonoLabel('Now', color: p.ink),
                  Gap.h8,
                  Icon(Icons.check, size: 20, color: p.ink),
                ],
              )
            : const SizedBox(key: ValueKey(0), width: 20, height: 20),
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
    final p = BloomColors.of(context);
    final age = gestationalAge(_lmp, today());
    final valid = age.totalDays >= 0 && age.weeks <= 44;
    final size = babySizeForWeek(age.weeks);
    final label = switch (_basis) {
      _DateBasis.lmp => 'First day of your last period',
      _DateBasis.due => 'Due date',
      _DateBasis.conception => 'Conception date',
    };
    return ModePage(
      eyebrow: 'Pregnancy',
      title: 'Track pregnancy',
      subtitle: 'Congratulations. A few details, and Bloom can follow along with you week by week.',
      children: [
        const SectionHeader('What date do you know?', label: 'No. 1'),
        UnderlineTabs<_DateBasis>(
          options: const [
            (_DateBasis.lmp, 'Last period'),
            (_DateBasis.due, 'Due date'),
            (_DateBasis.conception, 'Conception'),
          ],
          selected: _basis,
          onChanged: _setBasis,
        ),
        DateField(label: label, date: _date, onTap: _pick),
        const SectionHeader('How many babies?', label: 'No. 2'),
        BabiesSelector(value: _babies, onChanged: (v) => setState(() => _babies = v)),
        Gap.v8,
        AnimatedSwitcher(
          duration: Motion.medium,
          child: valid
              ? Column(
                  key: const ValueKey('ok'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Hairline(),
                    Gap.v20,
                    MonoLabel('Today · ${trimesterLabel(age.trimester)}'),
                    Gap.v8,
                    PhaseTitle(
                      lead: 'Week ${Almanac.spell(age.weeks)},',
                      italic: 'day ${Almanac.spell(age.days)}.',
                      color: BloomColors.pregnancy,
                      size: 32,
                    ),
                    Gap.v16,
                    Marginalia(
                      label: 'Due',
                      child: Text(
                        'Estimated ${fmtFull(dueFromLmp(_lmp))}',
                        style: Almanac.serif(size: 17, weight: 360, color: p.ink),
                      ),
                    ),
                    if (size != null) ...[
                      Gap.v8,
                      Marginalia(
                        label: 'Size',
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'About the size of '),
                              TextSpan(text: size.name, style: Almanac.italic(context, size: 16.5)),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Gap.v20,
                    const Hairline(),
                  ],
                )
              : const InfoBanner(
                  key: ValueKey('bad'),
                  tone: BannerTone.warning,
                  message: 'That date gives a pregnancy length that is out of range. Please check it.',
                ),
        ),
        Gap.v8,
        InkButton(label: 'Start pregnancy mode', expanded: true, onPressed: valid ? _confirm : null),
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
    return UnderlineTabs<int>(
      options: const [(1, 'One'), (2, 'Twins'), (3, 'Three or more')],
      selected: value.clamp(1, 3),
      onChanged: onChanged,
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
        eyebrow: 'Pregnancy',
        title: 'Pregnancy settings',
        children: [
          EmptyState(
            glyph: Botanical.sprout,
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
      eyebrow: 'Pregnancy · Week ${age.weeks} · Day ${age.days}',
      title: 'Pregnancy settings',
      subtitle: 'Due ${fmtFull(p.dueDate)}',
      children: [
        const SectionHeader('Dates', label: 'No. 1'),
        DateField(
          label: 'First day of last period',
          date: p.lmp,
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
        Gap.v4,
        DateField(
          label: 'Due date',
          date: p.dueDate,
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
        Text(
          'Changing the last period date also moves the due date, and the other way around: they are 280 days apart.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Marginalia(
          label: 'Today',
          child: Text(
            'Week ${age.weeks} · Day ${age.days}',
            style: Almanac.mono(size: 13.5, color: BloomColors.of(context).ink),
          ),
        ),
        const SectionHeader('Number of babies', label: 'No. 2'),
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
    final p = BloomColors.of(context);
    Widget care(String label, String text) => Marginalia(
      label: label,
      labelWidth: 80,
      child: Text(text, style: t.textTheme.bodyLarge!.copyWith(color: p.ink, height: 1.6)),
    );

    return ModePage(
      title: 'End pregnancy',
      spacing: Space.xxl,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BotanicalGlyph(Botanical.sprig, size: 40, color: p.ink2),
          Gap.v24,
          Text('We\'re so sorry.', style: Almanac.italic(context, size: 34, color: p.ink)),
          Gap.v20,
          Text(
            'Losing a pregnancy is painful, at any stage. Whatever you are feeling right now, grief, numbness, '
            'relief, confusion, or all of these at once, is valid. You don\'t have to do anything else here today.',
            style: t.textTheme.bodyLarge!.copyWith(color: p.ink2, height: 1.7),
          ),
        ],
      ),
      children: [
        const Hairline(),
        Text('Taking care of yourself', style: Almanac.italic(context, size: 22, color: p.ink)),
        care(
          'Body',
          'Bleeding and cramping can continue for a while. Contact a care provider or emergency services if '
              'you soak through a pad an hour for two hours, pass large clots, have a fever, or feel faint.',
        ),
        care(
          'Recovery',
          'Your body may take a few weeks to recover, and your period usually returns within 4 to 8 weeks.',
        ),
        care('People', 'Lean on people you trust. Partners grieve too, sometimes differently.'),
        care(
          'Help',
          'Pregnancy loss support groups, a counselor, or your care provider can help. If you feel hopeless '
              'or think about harming yourself, contact a local crisis line or emergency services right away.',
        ),
        const Hairline(),
        DateField(
          label: 'When it happened',
          date: _date,
          onTap: () async {
            final d = await pickDay(context, initial: _date, first: addDays(today(), -365), last: today());
            if (d != null) setState(() => _date = d);
          },
        ),
        Text(
          'When you continue, your pregnancy is saved privately in your history and the app returns to cycle '
          'tracking. You can change your goal again at any time.',
          style: t.textTheme.bodyMedium!.copyWith(color: p.ink2, height: 1.6),
        ),
        Wrap(
          spacing: Space.xl,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkButton.outlined(label: 'Continue', onPressed: _confirm),
            InkLink('Not now', onTap: () => Navigator.of(context).pop()),
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

/// First-run questionnaire: goal, profile basics, and cycle defaults.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../log/almanac_rows.dart';
import 'demo_data.dart';

enum _Step {
  welcome,
  goal,
  name,
  birthYear,
  lastPeriod,
  pregnancyDate,
  periodLength,
  cycleLength,
  regularity,
  conditions,
  birthControl,
  appLock,
}

const _conditions = {
  'pcos': 'PCOS',
  'endometriosis': 'Endometriosis',
  'fibroids': 'Fibroids',
  'thyroid': 'Thyroid condition',
};

const _birthControl = {
  'none': 'None',
  'pill': 'Pill',
  'ring': 'Vaginal ring',
  'patch': 'Patch',
  'injection': 'Injection',
  'iud': 'IUD',
  'implant': 'Implant',
  'condoms': 'Condoms',
};

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _index = 0;

  /// Direction of the last step change: 1 forward, -1 back.
  int _dir = 1;

  Goal _goal = Goal.trackCycle;
  final _nameCtrl = TextEditingController();
  int? _birthYear;
  DateTime? _lastPeriod;
  bool _lastPeriodUnknown = false;
  bool _useDueDate = false;
  DateTime? _pregnancyDate;
  int _periodLength = 5;
  bool _periodUnknown = false;
  int _cycleLength = 28;
  bool _cycleUnknown = false;
  bool? _irregular;
  final Set<String> _conds = {};
  String _birthControlChoice = 'none';

  List<_Step> get _steps => _goal == Goal.trackPregnancy
      ? const [_Step.welcome, _Step.goal, _Step.name, _Step.birthYear, _Step.pregnancyDate, _Step.conditions, _Step.appLock]
      : const [
          _Step.welcome,
          _Step.goal,
          _Step.name,
          _Step.birthYear,
          _Step.lastPeriod,
          _Step.periodLength,
          _Step.cycleLength,
          _Step.regularity,
          _Step.conditions,
          _Step.birthControl,
          _Step.appLock,
        ];

  _Step get _step => _steps[_index];

  int? get _age => _birthYear == null ? null : today().year - _birthYear!;

  bool get _canContinue => switch (_step) {
        _Step.birthYear => _age == null || _age! >= 13,
        _Step.lastPeriod => _lastPeriod != null || _lastPeriodUnknown,
        _Step.pregnancyDate => _pregnancyDate != null,
        _ => true,
      };

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _steps.length - 1) {
      _finish();
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _dir = 1;
        _index++;
      });
    }
  }

  void _back() {
    if (_index > 0) {
      FocusScope.of(context).unfocus();
      setState(() {
        _dir = -1;
        _index--;
      });
    }
  }

  void _finish() {
    final store = context.read<AppStore>();
    final pregnant = _goal == Goal.trackPregnancy;
    store.setFeature('onboarding', {
      if (!pregnant) 'birthControl': _birthControlChoice,
      if (pregnant && _pregnancyDate != null) (_useDueDate ? 'dueDate' : 'pregnancyLmp'): dayKey(_pregnancyDate!),
    });
    final periodLen = _periodUnknown ? 5 : _periodLength;
    if (!pregnant && _lastPeriod != null) {
      // Don't mark days after today as logged period days.
      final len = periodLen.clamp(1, daysBetween(_lastPeriod!, today()) + 1);
      store.startPeriod(_lastPeriod!, length: len);
    }
    store.updateProfile((p) {
      p
        ..goal = _goal
        ..name = _nameCtrl.text.trim()
        ..birthYear = _birthYear
        ..cycleLength = _cycleUnknown ? 28 : _cycleLength
        ..periodLength = periodLen
        ..irregular = _irregular ?? false
        ..conditions = _conds.toList()
        ..onboarded = true;
    });
  }

  String? get _eyebrow => switch (_step) {
        _Step.welcome => null,
        _Step.goal => 'Your goal',
        _Step.name || _Step.birthYear => 'About you',
        _Step.lastPeriod || _Step.periodLength || _Step.cycleLength || _Step.regularity => 'Your cycle',
        _Step.pregnancyDate => 'Your pregnancy',
        _Step.conditions || _Step.birthControl => 'Your health',
        _Step.appLock => 'Privacy',
      };

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final isLast = _index == _steps.length - 1;
    final welcome = _step == _Step.welcome;
    final total = _steps.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
            child: Column(
              children: [
                // Top bar: back arrow, mono step count, and a hairline of progress.
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.gutter, 0),
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      child: welcome
                          ? const SizedBox.expand(key: ValueKey('none'))
                          : Row(
                              key: const ValueKey('bar'),
                              children: [
                                IconButton(
                                  tooltip: 'Back',
                                  onPressed: _back,
                                  icon: Icon(Icons.arrow_back, size: 20, color: p.ink),
                                ),
                                Gap.h8,
                                Expanded(child: _ProgressRule(value: _index / total)),
                                Gap.h16,
                                Text(
                                  '${_index.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                                  style: Almanac.label(context),
                                  semanticsLabel: 'Step $_index of $total',
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      switchInCurve: Motion.curve,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, a) {
                        final incoming = child.key == ValueKey(_step);
                        final dx = (incoming ? 0.06 : -0.06) * _dir;
                        return FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        );
                      },
                      child: SingleChildScrollView(
                        key: ValueKey(_step),
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
                        child: _body(context),
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
                    child: InkButton(
                      expanded: true,
                      icon: isLast ? Icons.check : null,
                      onPressed: _canContinue ? _next : null,
                      label: switch (_step) {
                        _Step.welcome => 'Get started',
                        _ when isLast => 'Finish',
                        _ => 'Continue',
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) => switch (_step) {
        _Step.welcome => _welcome(context),
        _Step.goal => _goalStep(context),
        _Step.name => _nameStep(context),
        _Step.birthYear => _birthYearStep(context),
        _Step.lastPeriod => _lastPeriodStep(context),
        _Step.pregnancyDate => _pregnancyStep(context),
        _Step.periodLength => _lengthStep(
            context,
            title: 'How long does your period usually last?',
            value: _periodLength,
            min: 1,
            max: 12,
            unknown: _periodUnknown,
            onChanged: (v) => setState(() => _periodLength = v),
            onUnknown: (v) => setState(() => _periodUnknown = v),
            hint: 'Most periods last 2 to 7 days. If you skip this, Bloom starts with 5 days.',
            color: BloomColors.period,
          ),
        _Step.cycleLength => _lengthStep(
            context,
            title: 'How long is your cycle usually?',
            value: _cycleLength,
            min: 15,
            max: 90,
            unknown: _cycleUnknown,
            onChanged: (v) => setState(() => _cycleLength = v),
            onUnknown: (v) => setState(() => _cycleUnknown = v),
            hint: 'Count from the first day of one period to the day before the next. '
                'Many cycles are 21 to 35 days. If you skip this, Bloom starts with 28 days.',
          ),
        _Step.regularity => _regularityStep(context),
        _Step.conditions => _conditionsStep(context),
        _Step.birthControl => _birthControlStep(context),
        _Step.appLock => _appLockStep(context),
      };

  /// The page opener: a mono section label, a large serif question, and a
  /// quiet explanation.
  Widget _title(BuildContext context, String text, [String? sub]) {
    final theme = Theme.of(context);
    final eyebrow = _eyebrow;
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[MonoLabel(eyebrow), Gap.v12],
          Text(text, style: Almanac.serif(size: 34, weight: 340, color: BloomColors.of(context).ink, height: 1.12)),
          if (sub != null) ...[
            Gap.v12,
            Text(sub, style: theme.textTheme.bodyLarge!.copyWith(color: BloomColors.of(context).ink2)),
          ],
        ],
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    Widget promise(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: p.ink2)),
              Gap.h12,
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap.v24,
        const MonoLabel('Bloom · a cycle almanac'),
        Gap.v24,
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.slow,
          curve: Motion.curve,
          builder: (context, v, child) => Opacity(opacity: v, child: child),
          child: const Align(alignment: Alignment.centerLeft, child: BloomLogo(size: 72)),
        ),
        Gap.v24,
        const PhaseTitle(lead: 'Welcome to', italic: 'Bloom.', size: 46),
        Gap.v16,
        Text(
          'Track your cycle, symptoms, and health. Free, private, and open source.',
          style: theme.textTheme.bodyLarge!.copyWith(color: p.ink2),
        ),
        Gap.v32,
        // An ex libris plate: the privacy promise.
        BloomCard.outlined(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MonoLabel('Ex libris'),
              Gap.v8,
              Text('This book belongs to you.', style: Almanac.italic(context, size: 22)),
              const Hairline(spacing: Space.md),
              promise(Icons.phone_android_outlined, 'All your data stays on this device.'),
              promise(Icons.person_off_outlined, 'No account, no sign-up, no email.'),
              promise(Icons.cloud_off_outlined, 'Nothing is sent to a server. Back up with an export file.'),
              promise(Icons.delete_outline, 'Delete everything at any time in settings.'),
            ],
          ),
        ),
        Gap.v24,
        Align(
          alignment: Alignment.centerLeft,
          child: InkLink('Load demo data', onTap: () => loadDemoData(context.read<AppStore>())),
        ),
        Text(
          'Fills the app with 8 months of sample data for trying it out.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _goalStep(BuildContext context) {
    final options = [
      (Goal.trackCycle, Botanical.sprig, 'Track my cycle', 'Predict periods and understand your body'),
      (Goal.getPregnant, Botanical.flower, 'Get pregnant', 'Find your fertile days'),
      (Goal.trackPregnancy, Botanical.seedHead, 'Track my pregnancy', 'Follow your baby week by week'),
      (Goal.postpartum, Botanical.bud, 'I recently gave birth', 'Recovery and return of your cycle'),
      (Goal.perimenopause, Botanical.sprout, 'Perimenopause', 'Track changes and symptoms'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'What would you like to do?', 'You can change this later in your profile.'),
        for (final (g, glyph, title, sub) in options)
          _ChoiceRow(
            selected: _goal == g,
            glyph: glyph,
            title: title,
            subtitle: sub,
            onTap: () => setState(() => _goal = g),
          ),
        const Hairline(),
      ],
    );
  }

  Widget _nameStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'What should we call you?', 'Optional. It’s only used for greetings on this device.'),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: Almanac.serif(size: 26, weight: 340, color: BloomColors.of(context).ink),
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (_) => _next(),
          ),
        ],
      );

  Widget _birthYearStep(BuildContext context) {
    final now = today().year;
    final years = [for (var y = now - 10; y >= now - 80; y--) y];
    final tooYoung = _age != null && _age! < 13;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'What year were you born?',
            'Optional. Age helps tailor cycle insights. You must be at least 13 to use Bloom.'),
        DropdownButtonFormField<int?>(
          initialValue: _birthYear,
          decoration: const InputDecoration(labelText: 'Birth year'),
          style: Almanac.serif(size: 22, weight: 340, color: BloomColors.of(context).ink),
          borderRadius: Radii.mdAll,
          menuMaxHeight: 320,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Prefer not to say')),
            for (final y in years) DropdownMenuItem<int?>(value: y, child: Text('$y')),
          ],
          onChanged: (v) => setState(() => _birthYear = v),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          child: tooYoung
              ? const Padding(
                  padding: EdgeInsets.only(top: Space.lg),
                  child: InfoBanner(
                    tone: BannerTone.error,
                    message: 'Sorry, Bloom is for people aged 13 and older. Talk to a parent, guardian, '
                        'or school nurse about tracking your period.',
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _datePicker(Widget picker) => BloomCard.outlined(
        padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
        child: picker,
      );

  Widget _lastPeriodStep(BuildContext context) {
    final now = today();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'When did your last period start?', 'Pick the first day of bleeding.'),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: _lastPeriodUnknown
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _datePicker(CalendarDatePicker(
                      initialDate: _lastPeriod ?? now,
                      firstDate: addDays(now, -365),
                      lastDate: now,
                      onDateChanged: (d) => setState(() => _lastPeriod = dayOf(d)),
                    )),
                    Gap.v12,
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      child: _lastPeriod == null
                          ? Text('Tap a day to select it',
                              key: const ValueKey('none'), style: Theme.of(context).textTheme.bodySmall)
                          : Row(
                              key: ValueKey(_lastPeriod),
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: BloomColors.of(context).period,
                                  ),
                                ),
                                Gap.h8,
                                Flexible(child: MonoLabel('Period started ${fmtFull(_lastPeriod!)}')),
                              ],
                            ),
                    ),
                    Gap.v20,
                  ],
                ),
        ),
        _ChoiceRow(
          selected: _lastPeriodUnknown,
          check: true,
          title: "I don't remember",
          subtitle: 'You can log your next period when it starts.',
          onTap: () => setState(() {
            _lastPeriodUnknown = !_lastPeriodUnknown;
            if (_lastPeriodUnknown) _lastPeriod = null;
          }),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _pregnancyStep(BuildContext context) {
    final now = today();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'Congratulations. When is your baby due?',
            'Enter the first day of your last period or your due date.'),
        Row(
          children: [
            for (final (v, label) in [(false, 'Last period'), (true, 'Due date')]) ...[
              _TextTab(
                label: label,
                selected: _useDueDate == v,
                onTap: () => setState(() {
                  _useDueDate = v;
                  _pregnancyDate = null;
                }),
              ),
              Gap.h24,
            ],
          ],
        ),
        Gap.v16,
        _datePicker(CalendarDatePicker(
          key: ValueKey(_useDueDate),
          initialDate: _pregnancyDate ?? now,
          firstDate: _useDueDate ? now : addDays(now, -300),
          lastDate: _useDueDate ? addDays(now, 300) : now,
          onDateChanged: (d) => setState(() => _pregnancyDate = dayOf(d)),
        )),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          child: _pregnancyDate == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Space.lg),
                  child: Marginalia(
                    label: 'Due',
                    child: Text(
                      _useDueDate
                          ? 'Due date: ${fmtFull(_pregnancyDate!)}'
                          : 'Estimated due date: ${fmtFull(addDays(_pregnancyDate!, 280))}',
                      style: Almanac.italic(context, size: 19),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _lengthStep(
    BuildContext context, {
    required String title,
    required int value,
    required int min,
    required int max,
    required bool unknown,
    required ValueChanged<int> onChanged,
    required ValueChanged<bool> onUnknown,
    required String hint,
    Color? color,
  }) {
    final p = BloomColors.of(context);
    final numeralColor = color == null ? p.ink : readableTint(color, Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, title, hint),
        AnimatedOpacity(
          duration: Motion.medium,
          opacity: unknown ? 0.35 : 1,
          child: Column(
            children: [
              Row(
                children: [
                  ThinIconButton(
                    icon: Icons.remove,
                    tooltip: 'Fewer days',
                    onTap: unknown || value <= min ? null : () => onChanged(value - 1),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: Motion.fast,
                          child: Text('$value',
                              key: ValueKey(value), style: Almanac.numeral(context, size: 96, color: numeralColor)),
                        ),
                        Text(value == 1 ? 'day' : 'days', style: Almanac.italic(context, size: 18, color: p.ink2)),
                      ],
                    ),
                  ),
                  ThinIconButton(
                    icon: Icons.add,
                    tooltip: 'More days',
                    onTap: unknown || value >= max ? null : () => onChanged(value + 1),
                  ),
                ],
              ),
              Gap.v12,
              Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                label: '$value',
                onChanged: unknown ? null : (v) => onChanged(v.round()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('$min', style: Almanac.data(context)), Text('$max', style: Almanac.data(context))],
                ),
              ),
            ],
          ),
        ),
        Gap.v24,
        _ChoiceRow(
          selected: unknown,
          check: true,
          title: "I don't know",
          subtitle: 'Bloom will learn from your logs.',
          onTap: () => onUnknown(!unknown),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _regularityStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'Is your cycle regular?',
              'Regular means your cycle length changes by 7 days or less from month to month.'),
          for (final (v, title, sub) in [
            (false, 'Regular', 'My period comes at about the same time'),
            (true, 'Irregular', 'My cycle length varies a lot'),
            (null, "I don't know", 'Bloom will learn from your logs'),
          ])
            _ChoiceRow(
              selected: _irregular == v,
              title: title,
              subtitle: sub,
              onTap: () => setState(() => _irregular = v),
            ),
          const Hairline(),
        ],
      );

  Widget _conditionsStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'Do you have any of these conditions?',
              'Optional. Select all that apply. This helps Bloom explain irregular cycles.'),
          for (final e in _conditions.entries)
            _ChoiceRow(
              check: true,
              title: e.value,
              selected: _conds.contains(e.key),
              onTap: () => setState(() => _conds.contains(e.key) ? _conds.remove(e.key) : _conds.add(e.key)),
            ),
          _ChoiceRow(
            check: true,
            title: 'None of these',
            selected: _conds.isEmpty,
            onTap: () => setState(_conds.clear),
          ),
          const Hairline(),
        ],
      );

  Widget _birthControlStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'Are you using birth control?',
              'Hormonal birth control can change your bleeding pattern and predictions.'),
          for (final e in _birthControl.entries)
            _ChoiceRow(
              dense: true,
              title: e.value,
              selected: _birthControlChoice == e.key,
              onTap: () => setState(() => _birthControlChoice = e.key),
            ),
          const Hairline(),
        ],
      );

  Widget _appLockStep(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'You’re all set.', 'One more thing about privacy.'),
        const Hairline(),
        Gap.v16,
        Marginalia(
          label: 'Lock',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: p.ink2),
                  Gap.h8,
                  Expanded(child: Text('Protect Bloom with a PIN', style: Almanac.italic(context, size: 20))),
                ],
              ),
              Gap.v4,
              Text('You can turn on the app lock at any time in Me > Settings.', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        Gap.v16,
        const Hairline(),
        Gap.v16,
        const Disclaimer(
          text: 'Bloom gives educational information, not medical advice. '
              'Talk to a clinician about any health concerns.',
        ),
      ],
    );
  }
}

/// A hairline track with a thin ink progress line.
class _ProgressRule extends StatelessWidget {
  const _ProgressRule({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Semantics(
      label: 'Progress',
      value: '${(value * 100).round()}%',
      child: SizedBox(
        height: 2,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(height: 1, color: p.hairline),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(height: 1.5, color: p.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text tab with an ink underline when selected, like the app's nav bar.
class _TextTab extends StatelessWidget {
  const _TextTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: Almanac.sans(size: 15, weight: FontWeight.w500, color: selected ? p.ink : p.ink2, height: 1.3)),
            Gap.v4,
            AnimatedContainer(duration: Motion.medium, height: 1.5, width: 40, color: selected ? p.ink : Colors.transparent),
          ],
        ),
      ),
    );
  }
}

/// One option on a questionnaire page: a hairline-ruled row with an optional
/// botanical glyph, a title, a muted subtitle, and a thin radio or checkbox.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.glyph,
    this.check = false,
    this.dense = false,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final Botanical? glyph;

  /// Checkbox style instead of a radio.
  final bool check;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final mark = AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.curve,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: check ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: check ? Radii.xsAll : null,
        color: check && selected ? p.ink : Colors.transparent,
        border: Border.all(color: selected ? p.ink : p.ink2.withValues(alpha: 0.6), width: selected ? 1.5 : 1),
      ),
      child: check
          ? (selected ? Icon(Icons.check, size: 14, color: p.paper) : null)
          : Center(
              child: AnimatedContainer(
                duration: Motion.medium,
                width: selected ? 10 : 0,
                height: selected ? 10 : 0,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.ink),
              ),
            ),
    );
    return Semantics(
      button: true,
      selected: selected,
      checked: check ? selected : null,
      label: title,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Pressable(
          onTap: () {
            Almanac.tick();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? Space.md : Space.lg),
            child: Row(
              children: [
                if (glyph != null) ...[
                  BotanicalGlyph(glyph!, size: 28, color: selected ? p.ink : p.ink2),
                  Gap.h16,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: Motion.medium,
                        style: selected
                            ? Almanac.serif(size: dense ? 19 : 21, weight: 330, italic: true, color: p.ink)
                            : Almanac.serif(size: dense ? 19 : 21, weight: 360, color: p.ink),
                        child: Text(title),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.xxs),
                          child: Text(subtitle!, style: theme.textTheme.bodyMedium!.copyWith(color: p.ink2)),
                        ),
                    ],
                  ),
                ),
                Gap.h12,
                mark,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

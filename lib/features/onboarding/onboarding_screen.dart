/// First-run questionnaire: goal, profile basics, and cycle defaults.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
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
  'pcos': ('PCOS', Icons.blur_circular_rounded),
  'endometriosis': ('Endometriosis', Icons.healing_rounded),
  'fibroids': ('Fibroids', Icons.bubble_chart_rounded),
  'thyroid': ('Thyroid condition', Icons.monitor_heart_rounded),
};

const _birthControl = {
  'none': ('None', '🚫'),
  'pill': ('Pill', '💊'),
  'ring': ('Vaginal ring', '⭕'),
  'patch': ('Patch', '🩹'),
  'injection': ('Injection', '💉'),
  'iud': ('IUD', '⚓'),
  'implant': ('Implant', '📍'),
  'condoms': ('Condoms', '🛡️'),
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
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final isLast = _index == _steps.length - 1;
    final welcome = _step == _Step.welcome;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.heroWash),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
              child: Column(
                children: [
                  // Top bar: back button and progress.
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
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  ),
                                  Gap.h8,
                                  Expanded(child: _ProgressBar(value: _index / (_steps.length - 1))),
                                  Gap.h12,
                                  Text(
                                    '$_index of ${_steps.length - 1}',
                                    style: theme.textTheme.labelMedium!.copyWith(color: tokens.muted),
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
                        switchInCurve: Motion.emphasized,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...previous, ?current],
                        ),
                        transitionBuilder: (child, a) {
                          final incoming = child.key == ValueKey(_step);
                          final dx = (incoming ? 0.12 : -0.12) * _dir;
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
                    child: GradientButton(
                      expanded: true,
                      icon: isLast ? Icons.check_rounded : null,
                      onPressed: _canContinue ? _next : null,
                      label: switch (_step) {
                        _Step.welcome => 'Get started',
                        _ when isLast => 'Finish',
                        _ => 'Continue',
                      },
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
            color: BloomColors.luteal,
          ),
        _Step.regularity => _regularityStep(context),
        _Step.conditions => _conditionsStep(context),
        _Step.birthControl => _birthControlStep(context),
        _Step.appLock => _appLockStep(context),
      };

  Widget _title(BuildContext context, String text, [String? sub]) {
    final theme = Theme.of(context);
    final eyebrow = _eyebrow;
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow.toUpperCase(),
              style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.primary, letterSpacing: 1.2),
            ),
            Gap.v8,
          ],
          Text(text, style: theme.textTheme.headlineLarge),
          if (sub != null) ...[
            Gap.v12,
            Text(sub, style: theme.textTheme.bodyLarge!.copyWith(color: BloomTokens.of(context).muted)),
          ],
        ],
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    Widget promise(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            children: [
              IconBadge(icon: icon, color: color, size: 36),
              Gap.h12,
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap.v16,
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: Motion.slow,
            curve: Motion.spring,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              padding: const EdgeInsets.all(Space.xxl),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  BloomColors.brand.withValues(alpha: 0.18),
                  BloomColors.brand.withValues(alpha: 0),
                ]),
              ),
              child: const BloomLogo(size: 96),
            ),
          ),
        ),
        Gap.v16,
        Text('Welcome to Bloom', textAlign: TextAlign.center, style: theme.textTheme.displaySmall),
        Gap.v12,
        Text(
          'Track your cycle, symptoms, and health.\nFree, private, and open source.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge!.copyWith(color: tokens.muted),
        ),
        Gap.v32,
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Our privacy promise', style: theme.textTheme.titleMedium),
              Gap.v8,
              promise(Icons.phone_android_rounded, BloomColors.brand, 'All your data stays on this device.'),
              promise(Icons.no_accounts_rounded, BloomColors.luteal, 'No account, no sign-up, no email.'),
              promise(Icons.cloud_off_rounded, BloomColors.info, 'Nothing is sent to a server. Back up with an export file.'),
              promise(Icons.delete_outline_rounded, BloomColors.coral, 'Delete everything at any time in settings.'),
            ],
          ),
        ),
        Gap.v24,
        Center(
          child: TextButton.icon(
            onPressed: () => loadDemoData(context.read<AppStore>()),
            icon: const Icon(Icons.science_rounded),
            label: const Text('Load demo data'),
          ),
        ),
        Text(
          'Fills the app with 8 months of sample data for trying it out.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
        ),
      ],
    );
  }

  Widget _goalStep(BuildContext context) {
    final options = [
      (Goal.trackCycle, '📅', 'Track my cycle', 'Predict periods and understand your body', BloomColors.brand),
      (Goal.getPregnant, '👶', 'Get pregnant', 'Find your fertile days', BloomColors.fertile),
      (Goal.trackPregnancy, '🤰', 'Track my pregnancy', 'Follow your baby week by week', BloomColors.pregnancy),
      (Goal.postpartum, '🍼', 'I recently gave birth', 'Recovery and return of your cycle', BloomColors.coral),
      (Goal.perimenopause, '🌡️', 'Perimenopause', 'Track changes and symptoms', BloomColors.luteal),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'What would you like to do?', 'You can change this later in your profile.'),
        for (final (g, emoji, title, sub, color) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: _ChoiceTile(
              selected: _goal == g,
              emoji: emoji,
              color: color,
              title: title,
              subtitle: sub,
              onTap: () => setState(() => _goal = g),
            ),
          ),
      ],
    );
  }

  Widget _nameStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'What should we call you?', 'Optional. It is only used for greetings on this device.'),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
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
          decoration: const InputDecoration(
            labelText: 'Birth year',
            prefixIcon: Icon(Icons.cake_outlined),
          ),
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

  Widget _datePickerCard(Widget picker) => BloomCard(
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
                    _datePickerCard(CalendarDatePicker(
                      initialDate: _lastPeriod ?? now,
                      firstDate: addDays(now, -365),
                      lastDate: now,
                      onDateChanged: (d) => setState(() => _lastPeriod = dayOf(d)),
                    )),
                    Gap.v12,
                    Center(
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        child: _lastPeriod == null
                            ? Text('Tap a day to select it',
                                key: const ValueKey('none'),
                                style: Theme.of(context).textTheme.bodySmall)
                            : PillChip(
                                'Period started ${fmtFull(_lastPeriod!)}',
                                key: ValueKey(_lastPeriod),
                                emoji: '🩸',
                                color: BloomColors.period,
                              ),
                      ),
                    ),
                    Gap.v16,
                  ],
                ),
        ),
        _ChoiceTile(
          selected: _lastPeriodUnknown,
          check: true,
          icon: Icons.help_outline_rounded,
          color: BloomColors.luteal,
          title: "I don't remember",
          subtitle: 'You can log your next period when it starts.',
          onTap: () => setState(() {
            _lastPeriodUnknown = !_lastPeriodUnknown;
            if (_lastPeriodUnknown) _lastPeriod = null;
          }),
        ),
      ],
    );
  }

  Widget _pregnancyStep(BuildContext context) {
    final now = today();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'Congratulations! When is your baby due?',
            'Enter the first day of your last period or your due date.'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Last period'), icon: Icon(Icons.water_drop_rounded)),
            ButtonSegment(value: true, label: Text('Due date'), icon: Icon(Icons.child_friendly_rounded)),
          ],
          selected: {_useDueDate},
          onSelectionChanged: (s) => setState(() {
            _useDueDate = s.first;
            _pregnancyDate = null;
          }),
        ),
        Gap.v16,
        _datePickerCard(CalendarDatePicker(
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
                  child: InfoBanner(
                    tone: BannerTone.success,
                    emoji: '👶',
                    message: _useDueDate
                        ? 'Due date: ${fmtFull(_pregnancyDate!)}'
                        : 'Estimated due date: ${fmtFull(addDays(_pregnancyDate!, 280))}',
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
    required Color color,
  }) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    Widget stepButton(String tooltip, IconData icon, VoidCallback? onPressed) => IconButton.filledTonal(
          tooltip: tooltip,
          iconSize: 28,
          style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
          onPressed: onPressed,
          icon: Icon(icon),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, title, hint),
        AnimatedOpacity(
          duration: Motion.medium,
          opacity: unknown ? 0.4 : 1,
          child: BloomCard(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.xxl, Space.lg, Space.lg),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    stepButton('Fewer days', Icons.remove_rounded,
                        unknown || value <= min ? null : () => onChanged(value - 1)),
                    SizedBox(
                      width: 136,
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: Motion.fast,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: child),
                            ),
                            child: Text(
                              '$value',
                              key: ValueKey(value),
                              style: theme.textTheme.displayLarge!.copyWith(
                                color: readableTint(color, theme.brightness),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(value == 1 ? 'day' : 'days', style: theme.textTheme.titleMedium!.copyWith(color: tokens.muted)),
                        ],
                      ),
                    ),
                    stepButton('More days', Icons.add_rounded,
                        unknown || value >= max ? null : () => onChanged(value + 1)),
                  ],
                ),
                Gap.v12,
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(activeTrackColor: color, thumbColor: color),
                  child: Slider(
                    value: value.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: max - min,
                    label: '$value',
                    onChanged: unknown ? null : (v) => onChanged(v.round()),
                  ),
                ),
              ],
            ),
          ),
        ),
        Gap.v16,
        _ChoiceTile(
          selected: unknown,
          check: true,
          icon: Icons.help_outline_rounded,
          color: BloomColors.luteal,
          title: "I don't know",
          subtitle: 'Bloom will learn from your logs.',
          onTap: () => onUnknown(!unknown),
        ),
      ],
    );
  }

  Widget _regularityStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'Is your cycle regular?',
              'Regular means your cycle length changes by 7 days or less from month to month.'),
          for (final (v, title, sub, icon, color) in [
            (false, 'Regular', 'My period comes at about the same time', Icons.event_repeat_rounded, BloomColors.fertile),
            (true, 'Irregular', 'My cycle length varies a lot', Icons.shuffle_rounded, BloomColors.coral),
            (null, "I don't know", 'Bloom will learn from your logs', Icons.help_outline_rounded, BloomColors.luteal),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: _ChoiceTile(
                selected: _irregular == v,
                icon: icon,
                color: color,
                title: title,
                subtitle: sub,
                onTap: () => setState(() => _irregular = v),
              ),
            ),
        ],
      );

  Widget _conditionsStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'Do you have any of these conditions?',
              'Optional. Select all that apply. This helps Bloom explain irregular cycles.'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final e in _conditions.entries)
                SelectChip(
                  large: true,
                  icon: e.value.$2,
                  color: BloomColors.luteal,
                  label: e.value.$1,
                  selected: _conds.contains(e.key),
                  onSelected: (on) => setState(() => on ? _conds.add(e.key) : _conds.remove(e.key)),
                ),
              SelectChip(
                large: true,
                icon: Icons.do_not_disturb_alt_rounded,
                label: 'None of these',
                selected: _conds.isEmpty,
                onSelected: (_) => setState(_conds.clear),
              ),
            ],
          ),
        ],
      );

  Widget _birthControlStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'Are you using birth control?',
              'Hormonal birth control can change your bleeding pattern and predictions.'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final e in _birthControl.entries)
                SelectChip(
                  large: true,
                  emoji: e.value.$2,
                  label: e.value.$1,
                  selected: _birthControlChoice == e.key,
                  onSelected: (_) => setState(() => _birthControlChoice = e.key),
                ),
            ],
          ),
        ],
      );

  Widget _appLockStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, "You're all set", 'One more thing about privacy.'),
        BloomCard.tinted(
          color: BloomColors.luteal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(icon: Icons.lock_rounded, color: BloomColors.luteal, size: 48),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Protect Bloom with a PIN', style: theme.textTheme.titleMedium),
                    Gap.v4,
                    Text('You can turn on the app lock at any time in Me > Settings.',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        Gap.v16,
        const Disclaimer(
          text: 'Bloom gives educational information, not medical advice. '
              'Talk to a clinician about any health concerns.',
        ),
      ],
    );
  }
}

/// A thin animated progress bar filled with the brand gradient.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progress',
      value: '${(value * 100).round()}%',
      child: Container(
        height: 8,
        decoration: BoxDecoration(color: BloomTokens.of(context).subtle, borderRadius: Radii.pillAll),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: Motion.slow,
          curve: Motion.emphasized,
          builder: (context, v, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: BloomGradients.brand, borderRadius: Radii.pillAll),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large selectable option card with a badge, title, subtitle, and an
/// animated check. Set [check] for a checkbox-style toggle.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.emoji,
    this.icon,
    this.color,
    this.check = false,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final String? emoji;
  final IconData? icon;
  final Color? color;
  final bool check;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = BloomTokens.of(context);
    final dark = theme.brightness == Brightness.dark;
    final c = color ?? scheme.primary;
    final base = dark ? scheme.surfaceContainer : Colors.white;
    final selectedIcon = check ? Icons.check_box_rounded : Icons.check_circle_rounded;
    final idleIcon = check ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked_rounded;

    return Semantics(
      button: true,
      selected: selected,
      checked: check ? selected : null,
      child: AnimatedScale(
        scale: selected ? 1 : 0.985,
        duration: Motion.medium,
        curve: Motion.spring,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          decoration: BoxDecoration(
            color: selected ? Color.alphaBlend(scheme.primary.withValues(alpha: dark ? 0.16 : 0.07), base) : base,
            borderRadius: Radii.lgAll,
            border: Border.all(
              color: selected ? scheme.primary : tokens.border,
              width: selected ? 2 : 1.2,
            ),
            boxShadow: selected || dark ? const [] : tokens.cardShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: Radii.lgAll,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
                child: Row(
                  children: [
                    if (emoji != null || icon != null) ...[
                      IconBadge(emoji: emoji, icon: icon, color: c, size: 44),
                      Gap.h16,
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.xxs),
                              child: Text(subtitle!, style: theme.textTheme.bodyMedium!.copyWith(color: tokens.muted)),
                            ),
                        ],
                      ),
                    ),
                    Gap.h12,
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                      child: Icon(
                        selected ? selectedIcon : idleIcon,
                        key: ValueKey(selected),
                        color: selected ? scheme.primary : tokens.muted.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

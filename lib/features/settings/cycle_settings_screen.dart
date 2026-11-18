import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'settings_widgets.dart';

/// Default cycle, period, and luteal lengths used until enough cycles are logged.
class CycleSettingsScreen extends StatelessWidget {
  const CycleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile;
    final e = store.engine;
    final palette = BloomColors.of(context);
    final logged = e.cycleLengths.length;
    return SettingsPage(
      eyebrow: 'Settings',
      title: 'Cycle & ovulation',
      subtitle: 'The lengths Bloom starts from.',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MonoLabel('Used for predictions now'),
            Gap.v12,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Figure(value: '${e.avgCycleLength}', label: 'day cycle')),
                Expanded(
                  child: _Figure(value: '${e.avgPeriodLength}', label: 'day period', color: palette.period),
                ),
              ],
            ),
            Gap.v12,
            Text(
              logged == 0
                  ? 'Based on your settings below until you log a full cycle.'
                  : 'Based on $logged logged cycle${logged == 1 ? '' : 's'}, blended with your settings.',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: palette.ink2),
            ),
          ],
        ),
        MenuSection(
          title: 'Your usual lengths',
          footer:
              'Most luteal phases last 12 to 14 days. Change it only if you know yours, for example '
              'from ovulation tests or basal temperature.',
          children: [
            StepperTile(
              title: 'Cycle',
              subtitle: 'First day of one period to the next',
              value: p.cycleLength,
              min: 15,
              max: 90,
              onChanged: (v) => store.updateProfile((p) => p.cycleLength = v),
            ),
            StepperTile(
              title: 'Period',
              value: p.periodLength,
              min: 1,
              max: 15,
              onChanged: (v) => store.updateProfile((p) => p.periodLength = v),
            ),
            StepperTile(
              title: 'Luteal phase',
              subtitle: 'Ovulation to your next period',
              value: p.lutealLength,
              min: 7,
              max: 20,
              onChanged: (v) => store.updateProfile((p) => p.lutealLength = v),
            ),
          ],
        ),
        MenuSection(
          title: 'Regularity',
          children: [
            MenuTile.toggle(
              title: 'My cycles are irregular',
              subtitle: 'Predictions become rough estimates.',
              value: p.irregular,
              onChanged: (v) => store.updateProfile((p) => p.irregular = v),
            ),
          ],
        ),
        const Disclaimer(
          text:
              'Predictions are estimates and can\'t be used as birth control. '
              'This isn\'t medical advice; see a clinician about cycle concerns.',
        ),
      ],
    );
  }
}

/// A large serif numeral with an italic caption: "28 *day cycle*".
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value, style: Almanac.numeral(context, size: 56, color: color)),
          TextSpan(text: ' $label', style: Almanac.italic(context, size: 17, color: p.ink2)),
        ],
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final logged = e.cycleLengths.length;
    return SettingsPage(
      title: 'Cycle & ovulation',
      subtitle: 'The lengths Bloom starts from',
      children: [
        BloomCard.tinted(
          color: BloomColors.brand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Icons.auto_graph_rounded, color: BloomColors.brand, filled: true),
                  Gap.h12,
                  Expanded(
                    child: Text(
                      'Used for predictions now',
                      style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Gap.v16,
              Row(
                children: [
                  Expanded(
                    child: _Figure(value: '${e.avgCycleLength}', label: 'day cycle'),
                  ),
                  Expanded(
                    child: _Figure(value: '${e.avgPeriodLength}', label: 'day period'),
                  ),
                ],
              ),
              Gap.v12,
              Text(
                logged == 0
                    ? 'Based on your settings below until you log a full cycle.'
                    : 'Based on $logged logged cycle${logged == 1 ? '' : 's'} blended with your settings.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        MenuSection(
          title: 'Your usual lengths',
          footer:
              'Most luteal phases last 12 to 14 days. Change it only if you know yours, for example '
              'from ovulation tests or basal temperature.',
          children: [
            StepperTile(
              icon: Icons.autorenew_rounded,
              color: BloomColors.brand,
              title: 'Cycle',
              subtitle: 'First day of one period to the next',
              value: p.cycleLength,
              min: 15,
              max: 90,
              onChanged: (v) => store.updateProfile((p) => p.cycleLength = v),
            ),
            StepperTile(
              icon: Icons.water_drop_rounded,
              color: BloomColors.period,
              title: 'Period',
              value: p.periodLength,
              min: 1,
              max: 15,
              onChanged: (v) => store.updateProfile((p) => p.periodLength = v),
            ),
            StepperTile(
              icon: Icons.nights_stay_rounded,
              color: BloomColors.luteal,
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
              icon: Icons.shuffle_rounded,
              color: BloomColors.follicular,
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

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: theme.textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: ' $label',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: BloomTokens.of(context).muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

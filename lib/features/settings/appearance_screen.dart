import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'settings_widgets.dart';

/// Units, theme, and first day of the week.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile;
    return SettingsPage(
      eyebrow: 'Settings',
      title: 'Units & appearance',
      subtitle: 'How Bloom measures, and how the page looks.',
      children: [
        MenuSection(
          title: 'Units',
          children: [
            SegmentedSetting<TempUnit>(
              label: 'Temperature',
              options: const [
                TextChoice(TempUnit.celsius, '°C', semanticLabel: 'Celsius'),
                TextChoice(TempUnit.fahrenheit, '°F', semanticLabel: 'Fahrenheit'),
              ],
              selected: p.tempUnit,
              onChanged: (v) => store.updateProfile((p) => p.tempUnit = v),
            ),
            SegmentedSetting<WeightUnit>(
              label: 'Weight',
              options: const [
                TextChoice(WeightUnit.kg, 'kg', semanticLabel: 'Kilograms'),
                TextChoice(WeightUnit.lb, 'lb', semanticLabel: 'Pounds'),
              ],
              selected: p.weightUnit,
              onChanged: (v) => store.updateProfile((p) => p.weightUnit = v),
            ),
          ],
        ),
        MenuSection(
          title: 'Appearance',
          children: [
            SegmentedSetting<String>(
              label: 'Theme',
              subtitle: 'Paper by day, lamplight by night',
              options: const [
                TextChoice('system', 'Auto', semanticLabel: 'Follow the system'),
                TextChoice('light', 'Paper', semanticLabel: 'Light'),
                TextChoice('dark', 'Lamplight', semanticLabel: 'Dark'),
              ],
              selected: p.themeMode,
              onChanged: (v) => store.updateProfile((p) => p.themeMode = v),
            ),
            SegmentedSetting<int>(
              label: 'First day of the week',
              options: const [
                TextChoice(DateTime.saturday, 'Sat', semanticLabel: 'Saturday'),
                TextChoice(DateTime.sunday, 'Sun', semanticLabel: 'Sunday'),
                TextChoice(DateTime.monday, 'Mon', semanticLabel: 'Monday'),
              ],
              selected: p.firstDayOfWeek,
              onChanged: (v) => store.updateProfile((p) => p.firstDayOfWeek = v),
            ),
          ],
        ),
      ],
    );
  }
}

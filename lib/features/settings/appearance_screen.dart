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
      title: 'Units & appearance',
      children: [
        MenuSection(
          title: 'Units',
          children: [
            SegmentedSetting<TempUnit>(
              label: 'Temperature',
              icon: Icons.thermostat_rounded,
              color: BloomColors.coral,
              segments: const [
                ButtonSegment(value: TempUnit.celsius, label: Text('°C  Celsius')),
                ButtonSegment(value: TempUnit.fahrenheit, label: Text('°F  Fahrenheit')),
              ],
              selected: p.tempUnit,
              onChanged: (v) => store.updateProfile((p) => p.tempUnit = v),
            ),
            SegmentedSetting<WeightUnit>(
              label: 'Weight',
              icon: Icons.scale_rounded,
              color: BloomColors.info,
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
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
              icon: Icons.palette_rounded,
              color: BloomColors.luteal,
              segments: const [
                ButtonSegment(value: 'system', label: Text('Auto'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: p.themeMode,
              onChanged: (v) => store.updateProfile((p) => p.themeMode = v),
            ),
            SegmentedSetting<int>(
              label: 'First day of the week',
              icon: Icons.calendar_view_week_rounded,
              color: BloomColors.fertile,
              segments: const [
                ButtonSegment(value: DateTime.saturday, label: Text('Sat')),
                ButtonSegment(value: DateTime.sunday, label: Text('Sun')),
                ButtonSegment(value: DateTime.monday, label: Text('Mon')),
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

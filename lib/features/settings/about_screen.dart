import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';
import 'settings_widgets.dart';

const kAppVersion = '1.0.0';

/// About Bloom, its privacy promises, and open-source licenses.
class AboutPrivacyScreen extends StatelessWidget {
  const AboutPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    return SettingsPage(
      title: 'About & privacy',
      children: [
        BloomCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
          child: Column(
            children: [
              const BloomLogo(size: 72),
              Gap.v16,
              Text('Bloom', style: theme.textTheme.headlineMedium),
              Gap.v4,
              PillChip('Version $kAppVersion', dense: true, color: BloomColors.brand),
              Gap.v12,
              Text(
                'A free, open-source period and health tracker. Every feature is free.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge!.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
        const MenuSection(
          title: 'Privacy',
          children: [
            MenuTile(
              icon: Icons.cloud_off_rounded,
              color: BloomColors.info,
              title: 'Works offline',
              subtitle: 'No account and no server. Your data stays on this device unless you export it.',
            ),
            MenuTile(
              icon: Icons.block_rounded,
              color: BloomColors.coral,
              title: 'No analytics or ads',
              subtitle: 'Bloom doesn\'t track how you use it and doesn\'t share data with anyone.',
            ),
            MenuTile(
              icon: Icons.verified_user_rounded,
              color: BloomColors.success,
              title: 'You stay in control',
              subtitle: 'Lock the app with a PIN, export your data any time, or erase it completely.',
            ),
          ],
        ),
        MenuSection(
          title: 'Open source',
          children: [
            const MenuTile(
              icon: Icons.code_rounded,
              color: BloomColors.luteal,
              title: 'MIT License',
              subtitle: 'You can read, change, and share the source code.',
            ),
            MenuTile(
              icon: Icons.description_rounded,
              color: BloomColors.fertile,
              title: 'Open-source licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Bloom',
                applicationVersion: kAppVersion,
                applicationLegalese: 'Released under the MIT License.',
              ),
            ),
          ],
        ),
        const Disclaimer(
          text:
              'Bloom is for information and self-tracking only. It isn\'t a medical device, isn\'t birth control, '
              'and doesn\'t replace advice from a clinician. Predictions are estimates.',
        ),
      ],
    );
  }
}

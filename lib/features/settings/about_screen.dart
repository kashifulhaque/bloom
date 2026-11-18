import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';
import 'settings_widgets.dart';

const kAppVersion = '1.0.0';

/// About Bloom as a colophon: what it is, how it's set, its privacy
/// promises, and its licenses.
class AboutPrivacyScreen extends StatelessWidget {
  const AboutPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final body = theme.textTheme.bodyMedium!;
    final muted = body.copyWith(color: p.ink2);

    Widget entry(String label, String title, String text) => Marginalia(
      label: label,
      labelWidth: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Almanac.serif(size: 18, weight: 380, color: p.ink, height: 1.25)),
          Gap.v4,
          Text(text, style: muted),
        ],
      ),
    );

    return SettingsPage(
      eyebrow: 'Colophon · Version $kAppVersion',
      title: 'About Bloom',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BloomLogo(size: 56),
            Gap.h16,
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'A private notebook ', style: Almanac.italic(context, size: 20)),
                  TextSpan(
                    text: 'for your cycle and health. Free and open source, with every feature free.',
                    style: body.copyWith(fontSize: 16),
                  ),
                ]),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Privacy', label: 'I.', padding: EdgeInsets.zero),
            Gap.v16,
            entry('Offline', 'Works without a connection', 'No account and no server. Your data stays on this device unless you export it.'),
            const Hairline(spacing: Space.md),
            entry('Quiet', 'No analytics or ads', 'Bloom doesn\'t track how you use it and doesn\'t share data with anyone.'),
            const Hairline(spacing: Space.md),
            entry('Yours', 'You stay in control', 'Lock the app with a PIN, export your data any time, or erase it completely.'),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Type', label: 'II.', padding: EdgeInsets.zero),
            Gap.v16,
            Marginalia(
              label: 'Display',
              labelWidth: 88,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Fraunces', style: Almanac.serif(size: 18, weight: 380, color: p.ink)),
                TextSpan(text: '  and its italic', style: Almanac.italic(context, size: 18, color: p.ink2)),
              ])),
            ),
            const Hairline(spacing: Space.md),
            Marginalia(
              label: 'Text',
              labelWidth: 88,
              child: Text('Hanken Grotesk', style: Almanac.sans(size: 16, weight: FontWeight.w500, color: p.ink)),
            ),
            const Hairline(spacing: Space.md),
            Marginalia(
              label: 'Data',
              labelWidth: 88,
              child: Text('IBM Plex Mono', style: Almanac.mono(size: 15, color: p.ink)),
            ),
            Gap.v12,
            Text(
              'All three are bundled with the app and licensed under the SIL Open Font License 1.1.',
              style: muted,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('License', label: 'III.', padding: EdgeInsets.zero),
            Gap.v16,
            entry('Code', 'MIT License', 'You can read, change, and share the source code.'),
            Gap.v8,
            Padding(
              padding: const EdgeInsets.only(left: 88),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkLink(
                  'Open-source licenses',
                  arrow: true,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Bloom',
                    applicationVersion: kAppVersion,
                    applicationLegalese: 'Released under the MIT License.',
                  ),
                ),
              ),
            ),
          ],
        ),
        const Hairline(),
        const Disclaimer(
          text:
              'Bloom is for information and self-tracking only. It isn\'t a medical device, isn\'t birth control, '
              'and doesn\'t replace advice from a clinician. Predictions are estimates.',
        ),
        Center(
          child: Column(
            children: [
              const BotanicalGlyph(Botanical.sprig, size: 28),
              Gap.v8,
              Text('Kept on this device, and nowhere else.', style: Almanac.italic(context, size: 15, color: p.ink2)),
            ],
          ),
        ),
      ],
    );
  }
}

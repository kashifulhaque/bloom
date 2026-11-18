import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';
import '../updates/app_version.dart';
import '../updates/update_widgets.dart';
import 'settings_widgets.dart';

/// The running version for people, such as `1.0.0 (build 7)`.
String get appVersionLabel => AppVersion.running?.label ?? '1.0.0';

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
      eyebrow: 'Colophon · Version $appVersionLabel',
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
            entry('Offline', 'Works without a connection', 'No account needed. Your data stays on this device unless you export it, turn on AI answers in Ask, turn on sync, or share a report link.'),
            const Hairline(spacing: Space.md),
            entry('Sealed', 'Sync is end-to-end encrypted', 'Optional sync encrypts every record on your device before upload. The server stores only ciphertext and can\'t read your logs or see which days you logged. Only your 12-word recovery phrase unlocks it.'),
            const Hairline(spacing: Space.md),
            entry('Shared', 'Report links are encrypted too', 'When you share a report link, Bloom encrypts the report on your device and uploads only the encrypted copy. The key is in the link itself and never reaches the server. Anyone with the link can read the report until it expires, after 1, 7, or 30 days, or until you turn it off.'),
            const Hairline(spacing: Space.md),
            entry('Quiet', 'No analytics or ads', 'Bloom doesn\'t track how you use it and doesn\'t share data with anyone.'),
            const Hairline(spacing: Space.md),
            entry('Updates', 'Update checks send nothing about you', 'To find new versions, Bloom now and then downloads one small file from its own website. The request carries no account, device ID, or notebook data. You can turn update checks off below.'),
            const Hairline(spacing: Space.md),
            entry('Yours', 'You stay in control', 'Lock the app with a PIN, export your data any time, or erase it completely.'),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Updates', label: 'II.', padding: EdgeInsets.zero),
            Gap.v16,
            const UpdateSection(),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Type', label: 'III.', padding: EdgeInsets.zero),
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
            const SectionHeader('License', label: 'IV.', padding: EdgeInsets.zero),
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
                    applicationVersion: appVersionLabel,
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
              Text('Kept on this device, unless you choose otherwise.', style: Almanac.italic(context, size: 15, color: p.ink2)),
            ],
          ),
        ),
      ],
    );
  }
}

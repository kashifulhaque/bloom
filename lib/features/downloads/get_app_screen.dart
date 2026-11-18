/// "Get the app": the Android APK and the unsigned iPhone IPA, offered on
/// the web from the release manifest at `/downloads/manifest.json`.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart' show SettingsPage;
import 'download_manifest.dart';
import 'save_url_stub.dart' if (dart.library.js_interop) 'save_url_web.dart' as save;

/// Whether to offer "Get the app". Downloads are offered only on the web.
bool get showGetTheApp => kIsWeb;

/// Opens the "Get the app" page.
Future<void> openGetTheApp(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const GetAppScreen()));

/// Saves the file at [url] as [fileName].
typedef FileSaver = void Function(Uri url, String fileName);

class GetAppScreen extends StatefulWidget {
  const GetAppScreen({super.key, this.loadManifest, this.saveFile, this.base});

  /// Loads the manifest. Defaults to [fetchDownloadManifest]. Tests pass a
  /// fake.
  final ManifestLoader? loadManifest;

  /// Starts a download. Defaults to a same-origin `<a download>` link.
  final FileSaver? saveFile;

  /// The page address that download paths resolve against. Defaults to
  /// [Uri.base].
  final Uri? base;

  @override
  State<GetAppScreen> createState() => _GetAppScreenState();
}

class _GetAppScreenState extends State<GetAppScreen> {
  late final Future<DownloadManifest?> _manifest = (widget.loadManifest ?? fetchDownloadManifest)();

  void _download(DownloadFile f) {
    final url = (widget.base ?? Uri.base).resolve(f.path);
    (widget.saveFile ?? save.saveUrl)(url, f.file);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DownloadManifest?>(
      future: _manifest,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final m = snap.data;
        return SettingsPage(
          eyebrow: m == null ? 'Downloads' : 'Downloads · Version ${m.version}',
          title: 'Get the app',
          subtitle: 'Bloom works in this browser. You can also install it on your phone. '
              'Your data stays on each device; move it with an export file.',
          children: [
            if (loading)
              Text('Checking for downloads…', style: Almanac.italic(context, size: 16))
            else if (m == null)
              const EmptyState(
                key: ValueKey('downloads-missing'),
                title: 'Downloads are not available yet',
                body: 'Check back later. You can keep using Bloom in this browser.',
                glyph: Botanical.bud,
                compact: true,
              )
            else ...[
              _AndroidSection(manifest: m, onDownload: _download),
              _IphoneSection(ipa: m.ipa, onDownload: _download),
            ],
          ],
        );
      },
    );
  }
}

/// A fact row: a mono label in the margin and a value.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.mono = false, this.copyable = false, this.display});
  final String label;
  final String value;

  /// How to show [value], when it differs (for example, broken into lines).
  /// Copy still copies [value].
  final String? display;
  final bool mono;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final style = mono
        ? Almanac.data(context, color: p.ink, size: 12).copyWith(height: 1.6)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Marginalia(
        label: label,
        labelWidth: 84,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(display ?? value, style: style),
          if (copyable)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: InkLink('Copy', size: 13, onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.maybeOf(context)
                  ?..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('$label copied')));
              }),
            ),
        ]),
      ),
    );
  }
}

/// Breaks [s] into lines of [n] characters, so long hashes don't wrap
/// mid-group.
String _lines(String s, int n) =>
    [for (var i = 0; i < s.length; i += n) s.substring(i, i + n > s.length ? s.length : i + n)].join('\n');

/// A numbered step: a mono numeral in the margin.
class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: Marginalia(
          label: n.toString().padLeft(2, '0'),
          labelWidth: 40,
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
}

class _AndroidSection extends StatelessWidget {
  const _AndroidSection({required this.manifest, required this.onDownload});
  final DownloadManifest manifest;
  final void Function(DownloadFile f) onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apk = manifest.apk;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Android', label: 'APK', padding: EdgeInsets.zero),
      Gap.v12,
      if (apk == null)
        Text('The Android app is not available yet.', style: theme.textTheme.bodyMedium)
      else ...[
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton(
            key: const ValueKey('download-apk'),
            label: 'Download for Android',
            icon: Icons.download_outlined,
            onPressed: () => onDownload(apk),
          ),
        ),
        Gap.v24,
        _Fact('Version', manifest.version, mono: true),
        if (manifest.builtAt != null) _Fact('Built', DateFormat.yMMMd().format(manifest.builtAt!.toLocal())),
        _Fact('Size', formatBytes(apk.bytes)),
        _Fact('SHA-256', apk.sha256, mono: true, copyable: true, display: _lines(apk.sha256, 32)),
        if (manifest.signingCertSha256 != null)
          _Fact('Signed by', manifest.signingCertSha256!,
              mono: true, copyable: true, display: _lines(manifest.signingCertSha256!, 24)),
        const Hairline(spacing: Space.md),
        const MonoLabel('Install'),
        Gap.v12,
        const _Step(1, 'Download the APK, then open it from your browser\'s downloads.'),
        const _Step(
          2,
          'If Android asks, turn on Install unknown apps for your browser. You can turn it off '
          'again after you install Bloom.',
        ),
        const _Step(
          3,
          'Google Play Protect might warn that the app comes from a developer that Google hasn\'t '
          'verified. To check the file, compare its SHA-256 with the one on this page, then choose '
          'to install anyway.',
        ),
        const _Step(
          4,
          'To update, install a newer APK over the old one. Every release is signed with the same '
          'key, so your data stays.',
        ),
        Gap.v4,
        Text(
          'In some countries, certified Android devices install apps only from verified developers. '
          'Google plans to roll this out worldwide in 2027. If your phone won\'t install the APK, '
          'use Bloom in the browser.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    ]);
  }
}

class _IphoneSection extends StatelessWidget {
  const _IphoneSection({required this.ipa, required this.onDownload});
  final DownloadFile? ipa;
  final void Function(DownloadFile f) onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ipa = this.ipa;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('iPhone', label: 'Web app · IPA', padding: EdgeInsets.zero),
      Gap.v12,
      Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Use the web app. ', style: Almanac.italic(context, size: 17)),
          const TextSpan(
            text: 'Open Bloom in Safari, tap Share, then tap Add to Home Screen. '
                'It works offline and keeps your data on the phone.',
          ),
        ]),
        style: theme.textTheme.bodyMedium,
      ),
      if (ipa != null) ...[
        const Hairline(spacing: Space.lg),
        Text(
          'An unsigned IPA is here for people who already sideload apps. An iPhone can\'t install '
          'it directly: you must re-sign it with a sideloading tool and your own Apple ID.',
          style: theme.textTheme.bodyMedium,
        ),
        Gap.v16,
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton.outlined(
            key: const ValueKey('download-ipa'),
            label: 'Download unsigned IPA',
            icon: Icons.download_outlined,
            onPressed: () => onDownload(ipa),
          ),
        ),
        Gap.v24,
        _Fact('Size', formatBytes(ipa.bytes)),
        _Fact('SHA-256', ipa.sha256, mono: true, copyable: true, display: _lines(ipa.sha256, 32)),
      ],
    ]);
  }
}

/// The update note on Today, the Updates section in About and Settings, and
/// the lifecycle hook that runs automatic checks.
library;

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart' show SettingsPage;
import 'app_version.dart';
import 'update_controller.dart';

/// Runs an automatic check a few seconds after launch and whenever the app
/// comes back to the foreground. [UpdateController.maybeCheck] decides
/// whether one is due, so this never adds more than one request a day on
/// Android.
class UpdateLifecycle extends StatefulWidget {
  const UpdateLifecycle({super.key, required this.controller, required this.child, this.startDelay = const Duration(seconds: 5)});

  final UpdateController controller;
  final Widget child;

  /// The wait after launch, so a check never competes with startup.
  final Duration startDelay;

  @override
  State<UpdateLifecycle> createState() => _UpdateLifecycleState();
}

class _UpdateLifecycleState extends State<UpdateLifecycle> with WidgetsBindingObserver {
  Timer? _start;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start = Timer(widget.startDelay, () => unawaited(widget.controller.maybeCheck()));
  }

  @override
  void dispose() {
    _start?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.controller.maybeCheck());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A quiet note on Today that a newer version is out: a hairline in the
/// margin, a mono label, one serif line, and the platform's actions.
class UpdateNote extends StatelessWidget {
  const UpdateNote({super.key, required this.controller, required this.version});

  final UpdateController controller;

  /// The newer version, from [UpdateController.pending].
  final AppVersion version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final notes = controller.notes;
    final ios = controller.platform == UpdatePlatform.ios;
    final (label, title, body) = switch (controller.platform) {
      UpdatePlatform.ios => (
          'New version · ${version.label}',
          'A new version of Bloom is available.',
          'This app can\'t update itself. The web app always has the newest version, and its '
              'Get the app page has the new IPA to re-sign.',
        ),
      UpdatePlatform.web => (
          'Update · ${version.label}',
          'A new version of Bloom is ready.',
          'Reload to use it. Your data stays in this browser.',
        ),
      _ => (
          'Update · ${version.label}',
          'A new version of Bloom is ready.',
          'Download it, then open the file and tap Update. It installs over this app and keeps your data.',
        ),
    };
    final notNow = InkLink('Not now', key: const ValueKey('update-not-now'), size: 13.5, color: p.ink2, onTap: controller.snooze);
    final actions = switch (controller.platform) {
      UpdatePlatform.ios => <Widget>[
          InkLink('Open the web app', key: const ValueKey('update-web-app'), size: 13.5, arrow: true,
              onTap: () => controller.open(controller.webAppUrl)),
          InkLink('Get the app', key: const ValueKey('update-get-app'), size: 13.5, arrow: true,
              onTap: () => controller.open(controller.getAppUrl)),
          notNow,
        ],
      UpdatePlatform.web => <Widget>[
          InkButton.outlined(
            key: const ValueKey('update-reload'),
            label: 'Reload',
            icon: Icons.refresh,
            dense: true,
            onPressed: controller.reloadNow,
          ),
          notNow,
        ],
      _ => <Widget>[
          InkButton.outlined(
            key: const ValueKey('update-download'),
            label: 'Download update',
            icon: Icons.download_outlined,
            dense: true,
            onPressed: controller.downloadUpdate,
          ),
          notNow,
        ],
    };

    return Semantics(
      container: true,
      child: Container(
        key: const ValueKey('update-note'),
        // A note in the margin, like the due-reminders note: a hairline rule
        // on the left, no box, no color.
        padding: const EdgeInsets.only(left: Space.lg),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: p.ink2.withValues(alpha: ios ? 0.3 : 0.5)))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MonoLabel(label),
            Gap.v4,
            Text(title, style: Almanac.serif(size: ios ? 16 : 17, weight: 380, color: p.ink, height: 1.25)),
            if (notes != null) ...[
              Gap.v4,
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'What\'s new: ', style: Almanac.italic(context, size: 14, color: p.ink2)),
                  TextSpan(text: notes),
                ]),
                key: const ValueKey('update-notes'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            Gap.v4,
            Text(body, style: theme.textTheme.bodySmall),
            Gap.v12,
            Wrap(
              spacing: Space.xl,
              runSpacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

/// What a check costs in privacy, for the About and Updates pages.
const kUpdatePrivacyNote =
    'Each check downloads one small file, /downloads/manifest.json, from Bloom\'s own server. It sends no '
    'account, device ID, or notebook data. Like any web request, it shows the server your IP address.';

/// The version, a "Check for updates" action, and the automatic-check
/// switch. Used on the About page and the Updates settings page.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key, this.labelWidth = 88});

  /// The width of the mono margin labels.
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final c = watchUpdates(context);
    final running = c?.running ?? AppVersion.running;
    final muted = theme.textTheme.bodyMedium!.copyWith(color: p.ink2);

    Widget row(String label, Widget child) => Marginalia(label: label, labelWidth: labelWidth, child: child);

    final version = row(
      'Version',
      SelectableText(running?.label ?? 'Unknown', key: const ValueKey('update-version'), style: Almanac.mono(size: 15, color: p.ink)),
    );
    if (c == null || !c.supported) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        version,
        Gap.v12,
        Text('Update checks run in the Android, iPhone, and web apps.', style: muted),
      ]);
    }

    final latest = c.latest;
    final status = c.checking
        ? 'Checking…'
        : c.lastResult == UpdateCheckResult.failed
            ? 'Couldn\'t check. Try again when you\'re online.'
            : c.updateAvailable
                ? '${latest!.label} is available.'
                : latest != null
                    ? 'You have the latest version.'
                    : 'Not checked yet.';
    final checked = c.checkedAt;
    final every = switch (c.platform) {
      UpdatePlatform.android => 'Once a day at most.',
      UpdatePlatform.ios => 'Once a week at most.',
      _ => 'Every few hours at most, while Bloom is open.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        version,
        const Hairline(spacing: Space.md),
        row(
          'Latest',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status, key: const ValueKey('update-status'), style: theme.textTheme.bodyMedium),
            if (checked != null)
              Text('Checked ${DateFormat.yMMMd().add_jm().format(checked.toLocal())}', style: Almanac.data(context)),
            Gap.v8,
            Wrap(spacing: Space.xl, runSpacing: Space.sm, children: [
              InkLink(
                'Check for updates',
                key: const ValueKey('update-check'),
                onTap: c.checking ? null : () => unawaited(c.check()),
              ),
              if (c.updateAvailable && !c.checking)
                switch (c.platform) {
                  UpdatePlatform.android => InkLink('Download update', arrow: true, onTap: c.downloadUpdate),
                  UpdatePlatform.web => InkLink('Reload', arrow: true, onTap: c.reloadNow),
                  _ => InkLink('Open the web app', arrow: true, onTap: () => c.open(c.webAppUrl)),
                },
            ]),
          ]),
        ),
        const Hairline(spacing: Space.md),
        MenuTile.toggle(
          key: const ValueKey('update-auto'),
          title: 'Check for updates automatically',
          subtitle: every,
          value: c.enabled,
          onChanged: (v) => c.enabled = v,
        ),
        Gap.v8,
        Text(kUpdatePrivacyNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// You > Settings > Updates.
class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsPage(
        eyebrow: 'Settings',
        title: 'Updates',
        subtitle: 'Bloom isn\'t in an app store, so it checks its own website for new versions.',
        children: [UpdateSection()],
      );
}

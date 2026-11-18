/// The "Share link" sheet and the list of links the user has made.
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/store.dart';
import '../../../widgets/widgets.dart';
import '../../settings/settings_widgets.dart';
import 'share_api.dart';
import 'share_link.dart';

/// The one warning every share surface repeats.
const kShareWarning =
    'Anyone with the link can open and read this report until it expires or you turn it off. '
    'Send it only to people you trust.';

/// How the server side works, in one paragraph.
const kShareExplainer =
    'Bloom encrypts the report on this device and uploads only the encrypted copy. The key that '
    'unlocks it is part of the link and is never sent to the server, so the server can\'t read it.';

String fmtExpiry(DateTime d) => DateFormat('MMM d, yyyy, h:mm a').format(d.toLocal());

/// Sends [text] to the system share sheet, or copies it where there's none.
Future<void> shareLinkText(BuildContext context, String text) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Cycle report from Bloom'));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showSnack(context, 'Link copied.');
  }
}

Future<void> copyLinkText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, 'Link copied.');
}

/// Opens the sheet that makes a new link.
Future<void> showShareLinkSheet(
  BuildContext context, {
  required ReportSharer sharer,
  required Future<Uint8List> Function() buildPdf,
}) =>
    showAppBottomSheet(
      context,
      builder: (_) => ShareLinkSheet(sharer: sharer, buildPdf: buildPdf, store: context.read<AppStore>()),
    );

class ShareLinkSheet extends StatefulWidget {
  const ShareLinkSheet({super.key, required this.sharer, required this.buildPdf, required this.store});

  final ReportSharer sharer;
  final Future<Uint8List> Function() buildPdf;
  final AppStore store;

  @override
  State<ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends State<ShareLinkSheet> {
  ShareExpiry _expiry = ShareExpiry.fallback;
  bool _busy = false;
  String? _error;
  SharedReportLink? _link;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pdf = await widget.buildPdf();
      final link = await widget.sharer.create(widget.store, pdf, _expiry);
      if (mounted) setState(() => _link = link);
    } on ShareApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn\'t create the link: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return link == null ? _chooser(context) : _done(context, link);
  }

  Widget _chooser(BuildContext context) {
    final theme = Theme.of(context);
    return AppBottomSheet(
      eyebrow: 'Share link',
      title: 'Share this report as a link',
      subtitle: 'Your clinician can open it in any browser. They don\'t need Bloom.',
      actions: [
        InkButton(
          label: 'Create link',
          icon: Icons.link,
          loading: _busy,
          onPressed: _busy ? null : _create,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(tone: BannerTone.warning, title: 'Anyone with the link can read it', message: kShareWarning),
          Gap.v20,
          const MonoLabel('The link lasts'),
          Gap.v8,
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final e in ShareExpiry.values)
                SelectChip(
                  label: e.label,
                  selected: _expiry == e,
                  onSelected: _busy ? null : (_) => setState(() => _expiry = e),
                ),
            ],
          ),
          Gap.v20,
          Text(kShareExplainer, style: theme.textTheme.bodySmall),
          if (_error != null) ...[
            Gap.v16,
            InfoBanner(tone: BannerTone.error, message: _error!),
          ],
        ],
      ),
    );
  }

  Widget _done(BuildContext context, SharedReportLink link) {
    final p = BloomColors.of(context);
    return AppBottomSheet(
      eyebrow: 'Share link',
      title: 'Your link is ready',
      subtitle: 'It stops working on ${fmtExpiry(link.expiresAt)}.',
      actions: [
        InkButton.outlined(label: 'Copy link', icon: Icons.copy, onPressed: () => copyLinkText(context, link.url)),
        InkButton(label: 'Share', icon: Icons.ios_share, onPressed: () => shareLinkText(context, link.url)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(border: Border.all(color: p.hairline), borderRadius: Radii.mdAll),
            child: SelectableText(link.url, key: const Key('share-link-url'), style: Almanac.data(context, color: p.ink)),
          ),
          Gap.v16,
          Text(kShareWarning, style: Theme.of(context).textTheme.bodyMedium),
          Gap.v8,
          Text(
            'To stop it sooner, turn it off under Shared links on the report screen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The links the user has made that still work, each with Copy, Share, and
/// Turn off.
class SharedLinksSection extends StatefulWidget {
  const SharedLinksSection({super.key, required this.sharer, this.clock});

  final ReportSharer sharer;
  final DateTime Function()? clock;

  @override
  State<SharedLinksSection> createState() => _SharedLinksSectionState();
}

class _SharedLinksSectionState extends State<SharedLinksSection> {
  final Set<String> _revoking = {};

  Future<void> _revoke(SharedReportLink link) async {
    final ok = await confirmDialog(
      context,
      title: 'Turn off this link?',
      message: 'Bloom deletes the encrypted report from the server. Anyone who opens the link after that '
          'sees that it was turned off.',
      confirm: 'Turn off',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _revoking.add(link.id));
    try {
      await widget.sharer.revoke(context.read<AppStore>(), link);
      if (mounted) showSnack(context, 'Link turned off.');
    } on ShareApiException catch (e) {
      if (mounted) showSnack(context, 'Couldn\'t turn off the link. ${e.message}');
    } finally {
      if (mounted) setState(() => _revoking.remove(link.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = (widget.clock ?? DateTime.now)();
    final links = store.activeReportLinks(now);
    if (links.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MonoLabel('Shared links'),
        Gap.v8,
        Text(kShareWarning, style: theme.textTheme.bodySmall),
        Gap.v8,
        for (final link in links) ...[
          const Hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expires ${fmtExpiry(link.expiresAt)}', style: theme.textTheme.titleSmall),
                Gap.v4,
                Text(
                  'Made ${fmtExpiry(link.createdAt)}',
                  style: Almanac.data(context, size: 11.5),
                ),
                Gap.v8,
                Wrap(
                  spacing: Space.lg,
                  runSpacing: Space.sm,
                  children: [
                    InkLink('Copy', onTap: () => copyLinkText(context, link.url)),
                    InkLink('Share', onTap: () => shareLinkText(context, link.url)),
                    InkLink(
                      _revoking.contains(link.id) ? 'Turning off…' : 'Turn off',
                      color: BloomColors.of(context).error,
                      onTap: _revoking.contains(link.id) ? null : () => _revoke(link),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const Hairline(),
      ],
    );
  }
}

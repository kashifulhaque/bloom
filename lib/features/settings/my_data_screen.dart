import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'data_export.dart';
import 'settings_widgets.dart';

/// Export, import, and delete everything Bloom stores.
class MyDataScreen extends StatelessWidget {
  const MyDataScreen({super.key});

  Future<void> _exportJson(BuildContext context) async {
    final store = context.read<AppStore>();
    try {
      final ok = await saveTextFile(
        fileName: datedFileName('bloom-backup', 'json'),
        text: store.exportJson(),
        mimeType: 'application/json',
      );
      if (ok && context.mounted) showSnack(context, 'Backup saved');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Couldn\'t save the backup: $e');
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final store = context.read<AppStore>();
    try {
      final ok = await saveTextFile(
        fileName: datedFileName('bloom-logs', 'csv'),
        text: buildLogsCsv(store),
        mimeType: 'text/csv',
      );
      if (ok && context.mounted) showSnack(context, 'CSV saved');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Couldn\'t save the CSV: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final store = context.read<AppStore>();
    String? raw;
    try {
      raw = await pickTextFile();
    } catch (e) {
      if (context.mounted) showSnack(context, 'Couldn\'t open the file: $e');
      return;
    }
    if (raw == null || !context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Replace your data?',
      message:
          'Importing replaces everything in Bloom on this device with the backup. '
          'Export a backup first if you want to keep your current data.',
      confirm: 'Import',
    );
    if (!ok || !context.mounted) return;
    try {
      store.importJson(raw);
      showSnack(context, 'Backup imported');
    } catch (e) {
      final message = e is FormatException ? e.message : e.toString();
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Couldn\'t import this file'),
          content: Text('Make sure it\'s a Bloom backup (.json) file.\n\nDetails: $message'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final store = context.read<AppStore>();
    final confirmed = await showDialog<bool>(context: context, builder: (_) => const _DeleteDialog());
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await store.deleteAll();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return SettingsPage(
      title: 'My data',
      subtitle: 'Everything you log stays on this device.',
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: '${store.periodDays.length}',
                label: 'Period days',
                icon: Icons.water_drop_rounded,
                color: BloomColors.period,
              ),
            ),
            Gap.h12,
            Expanded(
              child: StatTile(
                value: '${store.logs.length}',
                label: 'Logged days',
                icon: Icons.edit_calendar_rounded,
                color: BloomColors.luteal,
              ),
            ),
          ],
        ),
        const InfoBanner(
          tone: BannerTone.brand,
          icon: Icons.shield_rounded,
          message:
              'Bloom has no account and no server, so a backup file is the only way to move your data '
              'or keep it safe.',
        ),
        _ActionCard(
          icon: Icons.download_rounded,
          color: BloomColors.success,
          title: 'Export',
          body: 'Save a copy of your data. Backup files aren\'t encrypted, so store them somewhere private.',
          children: [
            FilledButton.icon(
              onPressed: () => _exportJson(context),
              icon: const Icon(Icons.backup_rounded),
              label: const Text('Export full backup (JSON)'),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportCsv(context),
              icon: const Icon(Icons.table_chart_rounded),
              label: const Text('Export logs (CSV)'),
            ),
          ],
        ),
        _ActionCard(
          icon: Icons.upload_rounded,
          color: BloomColors.info,
          title: 'Import',
          body: 'Replace everything in Bloom with a backup file you exported earlier.',
          children: [
            OutlinedButton.icon(
              onPressed: () => _import(context),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import backup'),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
              child: Text(
                'DANGER ZONE',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: readableTint(error, theme.brightness),
                  letterSpacing: 1,
                ),
              ),
            ),
            BloomCard.tinted(
              color: error,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(icon: Icons.delete_forever_rounded, color: error),
                      Gap.h16,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete all data',
                              style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Gap.v4,
                            Text(
                              'Permanently erase everything Bloom stores on this device. This can\'t be undone.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Gap.v16,
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: readableTint(error, theme.brightness),
                      side: BorderSide(color: error.withValues(alpha: 0.6)),
                    ),
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Erase everything'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.children,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: icon, color: color),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                    Gap.v4,
                    Text(body, style: theme.textTheme.bodyMedium!.copyWith(color: BloomTokens.of(context).muted)),
                  ],
                ),
              ),
            ],
          ),
          Gap.v16,
          for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.v8, children[i]],
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim() == 'DELETE';
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This permanently erases your periods, logs, reminders, and settings. It can\'t be undone.'),
          Gap.v16,
          const Text('Type DELETE to confirm.'),
          Gap.v8,
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'DELETE'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete everything'),
        ),
      ],
    );
  }
}

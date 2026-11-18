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
    final p = BloomColors.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(color: p.ink2);
    return SettingsPage(
      eyebrow: 'Data & privacy',
      title: 'My data',
      subtitle: 'Everything you log stays on this device unless you turn on sync or share a report link.',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MonoLabel('What Bloom holds'),
            Gap.v12,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Count(value: store.periodDays.length, label: 'period days', color: p.period)),
                Expanded(child: _Count(value: store.logs.length, label: 'logged days')),
              ],
            ),
            Gap.v12,
            Text(
              'To move your data to another device or keep a copy, export a backup file, or turn on '
              'encrypted sync in You > Sync if this copy of Bloom has it.',
              style: muted,
            ),
          ],
        ),
        _Section(
          label: 'Export',
          title: 'Keep a copy',
          body: 'Save a copy of your data. Backup files aren\'t encrypted, so keep them somewhere private.',
          children: [
            InkButton(label: 'Export full backup (JSON)', onPressed: () => _exportJson(context)),
            InkButton.outlined(label: 'Export logs (CSV)', onPressed: () => _exportCsv(context)),
          ],
        ),
        _Section(
          label: 'Import',
          title: 'Bring a backup back',
          body: 'Replace everything in Bloom with a backup file you exported earlier.',
          children: [InkButton.outlined(label: 'Import backup', onPressed: () => _import(context))],
        ),
        Gap.v8,
        DangerSection(
          title: 'Delete all data',
          body: 'Permanently erase everything Bloom stores on this device: periods, logs, reminders, and '
              'settings. This can\'t be undone. If sync is on, it turns off here first, so the synced copy '
              'stays in your account.',
          action: Align(
            alignment: Alignment.centerLeft,
            child: InkButton.outlined(
              label: 'Erase everything',
              color: BloomColors.error,
              onPressed: () => _delete(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// A serif count with an italic caption: "142 *period days*".
class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.color});
  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: [
      TextSpan(text: '$value', style: Almanac.numeral(context, size: 44, color: color)),
      TextSpan(text: '  $label', style: Almanac.italic(context, size: 16, color: BloomColors.of(context).ink2)),
    ]),
  );
}

/// A ruled section: a mono label, a serif title, a plain-language note, and
/// its buttons.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.title, required this.body, required this.children});
  final String label;
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BloomCard(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label),
          Gap.v8,
          Text(title, style: theme.textTheme.titleLarge),
          Gap.v4,
          Text(body, style: theme.textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2)),
          Gap.v16,
          Wrap(spacing: Space.md, runSpacing: Space.md, children: children),
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
    return AlertDialog(
      title: const Text('Delete all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This permanently erases your periods, logs, reminders, and settings. It can\'t be undone.'),
          Gap.v16,
          Text('Type DELETE to confirm.', style: Almanac.label(context)),
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
        InkButton(
          label: 'Delete everything',
          dense: true,
          color: BloomColors.error,
          onPressed: ready ? () => Navigator.pop(context, true) : null,
        ),
      ],
    );
  }
}

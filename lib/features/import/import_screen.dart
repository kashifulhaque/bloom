/// **Import from another app**: pick the app, read its how-to, pick the
/// file, preview what Bloom found, choose how to merge, and import.
///
/// Opened from **You > My data** and from the onboarding welcome page.
/// Files are read on the device; nothing is uploaded. Imported days go
/// through [AppStore.applyImport], so sync uploads them like any other edit.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../core/sync/sync_controller.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart';
import '../sync/sync_screen.dart';
import 'csv_parser.dart';
import 'import_data.dart';
import 'import_platform.dart';
import 'import_runner.dart';
import 'import_sources.dart';
import 'merge.dart';

/// Opens the file picker and returns the chosen file, or null on cancel.
typedef ImportPicker = Future<PickedImportFile?> Function();

Future<PickedImportFile?> _pickWithFilePicker() async {
  final files = await FilePicker.pickFiles();
  if (files.isEmpty) return null;
  return openPickedFile(files.first);
}

enum _Stage { source, guide, reading, password, mapping, preview, done }

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.fromOnboarding = false, this.picker});

  /// Opened from the welcome page: the last step returns to setup.
  final bool fromOnboarding;

  /// Replaces the system file picker, for tests.
  final ImportPicker? picker;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  _Stage _stage = _Stage.source;
  ImportSource? _source;
  PickedImportFile? _file;
  FileInspection? _inspection;
  ImportedData? _data;
  CsvMapping? _mapping;
  ImportJob? _job;
  double? _progress;
  String? _error;
  MergeMode _mode = MergeMode.add;
  MergePlan? _applied;
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  SourceGuide get _guide => kSourceGuides[_source]!;

  @override
  void dispose() {
    _job?.cancel();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _go(_Stage stage) => setState(() => _stage = stage);

  void _chooseSource(ImportSource s) => setState(() {
        _source = s;
        _error = null;
        _stage = _Stage.guide;
      });

  Future<void> _pick() async {
    setState(() => _error = null);
    final PickedImportFile? picked;
    try {
      picked = await (widget.picker ?? _pickWithFilePicker)();
    } catch (e) {
      if (mounted) setState(() => _error = 'Bloom couldn\'t open the file. $e');
      return;
    }
    if (picked == null || !mounted) return;
    setState(() {
      _file = picked;
      _inspection = null;
      _data = null;
      _password.clear();
      _progress = null;
      _stage = _Stage.reading;
    });
    try {
      final inspection = await inspectPicked(picked);
      if (!mounted) return;
      final unsupported = inspection.unsupported;
      if (unsupported != null) {
        setState(() {
          _error = _unsupportedMessage(unsupported);
          _stage = _Stage.guide;
        });
        return;
      }
      _inspection = inspection;
      if (inspection.needsPassword) {
        _go(_Stage.password);
      } else if (inspection.format == ImportFormat.genericCsv) {
        setState(() {
          _mapping = guessCsvMapping(inspection.csvHeader, inspection.csvSample) ?? const CsvMapping(date: 0);
          _stage = _Stage.mapping;
        });
      } else {
        await _parse();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ImportException
            ? e.message
            : 'Bloom couldn\'t read this file. ${e is FormatException ? e.message : e}';
        _stage = _Stage.guide;
      });
    }
  }

  Future<void> _parse() async {
    final file = _file;
    final inspection = _inspection;
    if (file == null || inspection == null) return;
    final back = _stage;
    setState(() {
      _error = null;
      _progress = 0;
      _stage = _Stage.reading;
    });
    final job = startImport(
      file,
      inspection,
      ImportRequest(password: _password.text, csvMapping: _mapping),
      (f) {
        if (mounted && _stage == _Stage.reading) setState(() => _progress = f.clamp(0, 1).toDouble());
      },
    );
    _job = job;
    try {
      final data = await job.result;
      if (!mounted || _job != job) return;
      setState(() {
        _data = data;
        _mode = MergeMode.add;
        _confirm.clear();
        _stage = _Stage.preview;
      });
    } on ImportCancelled {
      if (mounted) _go(back == _Stage.reading ? _Stage.guide : back);
    } on ImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _stage = e.wrongPassword
            ? _Stage.password
            : inspection.format == ImportFormat.genericCsv
                ? _Stage.mapping
                : _Stage.guide;
      });
    } finally {
      if (_job == job) _job = null;
    }
  }

  void _cancel() {
    _job?.cancel();
    _job = null;
    _go(_Stage.guide);
  }

  void _apply(MergePlan plan) {
    context.read<AppStore>().applyImport(
          logs: plan.logs,
          periodDays: plan.periodDays,
          replace: plan.mode == MergeMode.replace,
        );
    setState(() {
      _applied = plan;
      _stage = _Stage.done;
    });
  }

  String _unsupportedMessage(UnsupportedReason r) => switch (r) {
        UnsupportedReason.empty => 'This file is empty.',
        UnsupportedReason.pdf =>
          'This is a PDF. Bloom can\'t read data from a PDF summary. Ask the app for a JSON, CSV, or ZIP export instead.',
        UnsupportedReason.healthConnect =>
          'This looks like a Health Connect backup. Bloom can\'t read those yet, because the format isn\'t documented.',
        UnsupportedReason.bloomBackup =>
          'This is a Bloom backup. To restore it, go back to My data and use Import backup.',
        UnsupportedReason.unknownZip =>
          'Bloom didn\'t find any data it recognizes in this ZIP file. Check that it\'s the export from your app.',
        UnsupportedReason.unknownJson =>
          'Bloom didn\'t recognize this file. Check that it\'s the export from your app, or try Another app (CSV).',
        UnsupportedReason.notText => 'Bloom can\'t read this kind of file. Choose the ZIP, JSON, CSV, or XML file from your app.',
        UnsupportedReason.tooLarge => 'This file is too large for Bloom to read.',
      };

  @override
  Widget build(BuildContext context) {
    final (eyebrow, title, subtitle, children) = switch (_stage) {
      _Stage.source => (
          'Import',
          'Coming from another app?',
          'Bring your history with you. Bloom reads the file on this device and never uploads it.',
          _sourceStep(context),
        ),
      _Stage.guide => ('Import · ${_guide.name}', 'From ${_guide.name}', _guide.intro, _guideStep(context)),
      _Stage.reading => ('Import · ${_guide.name}', 'Reading your file', _file?.file.name, _readingStep(context)),
      _Stage.password => (
          'Import · ${_guide.name}',
          'This file is locked',
          'Enter the password that came with your export.',
          _passwordStep(context),
        ),
      _Stage.mapping => (
          'Import · CSV',
          'Which column is which?',
          'Tell Bloom where the dates and your flow are. Everything else is optional.',
          _mappingStep(context),
        ),
      _Stage.preview => ('Import · Preview', 'What Bloom found', null, _previewStep(context)),
      _Stage.done => ('Import · Done', 'Your history is here', null, _doneStep(context)),
    };
    return PopScope(
      canPop: _stage == _Stage.source || _stage == _Stage.done,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        switch (_stage) {
          case _Stage.reading:
            _cancel();
          case _Stage.guide:
            setState(() {
              _error = null;
              _stage = _Stage.source;
            });
          case _Stage.preview || _Stage.password || _Stage.mapping:
            _go(_Stage.guide);
          case _Stage.source || _Stage.done:
            break;
        }
      },
      child: SettingsPage(
        key: ValueKey(_stage),
        eyebrow: eyebrow,
        title: title,
        subtitle: subtitle,
        children: children,
      ),
    );
  }

  // ---------------------------------------------------------------- steps

  List<Widget> _sourceStep(BuildContext context) => [
        MenuSection(
          title: 'Choose the app',
          children: [
            for (final s in ImportSource.values)
              MenuTile(
                key: ValueKey('import-source-${s.name}'),
                title: kSourceGuides[s]!.name,
                value: kSourceGuides[s]!.fileHint,
                onTap: () => _chooseSource(s),
              ),
          ],
        ),
        const _PrivacyNote(),
      ];

  List<Widget> _guideStep(BuildContext context) {
    final g = _guide;
    final muted = Theme.of(context).textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2);
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(g.supported ? 'How to export' : 'What you can do'),
          Gap.v12,
          for (var i = 0; i < g.steps.length; i++) ...[
            if (i > 0) const Hairline(spacing: Space.sm),
            Marginalia(
              label: (i + 1).toString().padLeft(2, '0'),
              labelWidth: 40,
              child: Text(g.steps[i]),
            ),
          ],
        ],
      ),
      if (g.notes.isNotEmpty)
        BloomCard(
          padding: const EdgeInsets.only(top: Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MonoLabel('What comes across'),
              Gap.v8,
              for (final n in g.notes) Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: Text(n, style: muted)),
            ],
          ),
        ),
      if (_error != null) InfoBanner(tone: BannerTone.error, title: 'That didn\'t work', message: _error!),
      if (g.supported)
        Wrap(
          spacing: Space.lg,
          runSpacing: Space.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkButton(label: 'Choose file', icon: Icons.upload_file_outlined, onPressed: _pick),
            InkLink('Choose another app', onTap: () => _go(_Stage.source)),
          ],
        )
      else
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton.outlined(label: 'Choose another app', onPressed: () => _go(_Stage.source)),
        ),
      if (g.supported) const _PrivacyNote(),
    ];
  }

  List<Widget> _readingStep(BuildContext context) {
    final p = BloomColors.of(context);
    final pct = _progress == null ? null : (_progress! * 100).floor();
    final format = _inspection?.format;
    final large = (_file?.file.length ?? 0) > 50 * 1024 * 1024;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(format == null ? 'Looking at the file' : 'Reading ${format.label}'),
          Gap.v12,
          ClipRRect(
            borderRadius: Radii.smAll,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 2,
              color: p.ink,
              backgroundColor: p.hairline,
            ),
          ),
          Gap.v8,
          Text(pct == null ? '…' : '$pct%', style: Almanac.data(context)),
        ],
      ),
      if (large)
        Text(
          kIsWeb
              ? 'Large exports take a few minutes in the browser. Keep this tab open until Bloom finishes.'
              : 'Large exports take a minute or two. You can keep using your phone.',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.ink2),
        ),
      Align(alignment: Alignment.centerLeft, child: InkLink('Cancel', onTap: _cancel)),
    ];
  }

  List<Widget> _passwordStep(BuildContext context) {
    final hint = switch (_source) {
      ImportSource.clue => 'Clue showed this password when you requested your data.',
      ImportSource.flo => 'Flo sends the password in a separate email.',
      _ => 'The app that made this file gave you the password.',
    };
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('import-password'),
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _parse(),
            onChanged: (_) => setState(() {}),
          ),
          Gap.v8,
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      if (_error != null) InfoBanner(tone: BannerTone.error, message: _error!),
      Wrap(
        spacing: Space.lg,
        runSpacing: Space.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkButton(label: 'Open file', onPressed: _password.text.isEmpty ? null : _parse),
          InkLink('Choose another file', onTap: () => _go(_Stage.guide)),
        ],
      ),
      Text(
        'The password only unlocks the file here. Bloom doesn\'t keep it.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _mappingStep(BuildContext context) {
    final inspection = _inspection!;
    final m = _mapping!;
    final header = inspection.csvHeader;
    final theme = Theme.of(context);

    Widget column(String label, int? value, ValueChanged<int?> onChanged, {bool required = false, String? help}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(label),
          DropdownButton<int?>(
            key: ValueKey('import-map-$label'),
            isExpanded: true,
            value: value,
            underline: const Hairline(),
            items: [
              if (!required) const DropdownMenuItem<int?>(value: null, child: Text('Not in this file')),
              for (var i = 0; i < header.length; i++)
                DropdownMenuItem<int?>(value: i, child: Text(header[i].isEmpty ? 'Column ${i + 1}' : header[i])),
            ],
            onChanged: (v) {
              if (required && v == null) return;
              onChanged(v);
            },
          ),
          if (help != null) Text(help, style: theme.textTheme.bodySmall),
        ],
      );
    }

    final first = inspection.csvSample.isEmpty ? null : inspection.csvSample.first;
    String? readsAs;
    if (first != null && m.date < first.length) {
      final d = parseCsvDate(first[m.date], m.dateFormat);
      final flow = m.flow == null || m.flow! >= first.length ? null : readFlowCell(first[m.flow!]);
      readsAs = d == null
          ? 'The first date, "${first[m.date]}", doesn\'t read as a date. Check the column and the date format.'
          : 'The first row reads as ${fmtFull(parseDayKey(d))}'
              '${flow == null || flow.isEmpty ? '' : ', ${flow == 'period' ? 'a period day' : '$flow flow'}'}.';
    }

    return [
      column(m.endDate == null ? 'Date' : 'Period start', m.date, (v) => setState(() => _mapping = m.copyWith(date: v)),
          required: true),
      column('Period end', m.endDate, (v) => setState(() => _mapping = m.copyWith(endDate: () => v)),
          help: 'Only for files with one row per period.'),
      column('Flow or bleeding', m.flow, (v) => setState(() => _mapping = m.copyWith(flow: () => v)),
          help: 'Words like light or heavy, numbers from 1 to 3, or yes and no.'),
      column('Basal temperature', m.temperature, (v) => setState(() => _mapping = m.copyWith(temperature: () => v)),
          help: '°C or °F. Bloom works out which.'),
      column('Notes', m.note, (v) => setState(() => _mapping = m.copyWith(note: () => v))),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonoLabel('Dates look like'),
          TextChoices<CsvDateFormat>(
            options: [for (final f in CsvDateFormat.values) TextChoice(f, f.label)],
            selected: m.dateFormat,
            onChanged: (f) => setState(() => _mapping = m.copyWith(dateFormat: f)),
          ),
        ],
      ),
      if (readsAs != null) Marginalia(label: 'Check', child: Text(readsAs)),
      if (_error != null) InfoBanner(tone: BannerTone.error, message: _error!),
      Wrap(
        spacing: Space.lg,
        runSpacing: Space.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkButton(label: 'Continue', onPressed: m.usable ? _parse : null),
          InkLink('Choose another file', onTap: () => _go(_Stage.guide)),
        ],
      ),
    ];
  }

  List<Widget> _previewStep(BuildContext context) {
    final store = context.watch<AppStore>();
    final data = _data!;
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(color: p.ink2);
    final hasData = store.periodDays.isNotEmpty || store.logs.isNotEmpty;
    final mode = hasData ? _mode : MergeMode.add;
    final plan = planMerge(existingPeriodDays: store.periodDays, existingLogs: store.logs, data: data, mode: mode);
    final range = data.range;
    final syncOn = watchSync(context)?.phase == SyncPhase.active;
    final existingDays = {...store.periodDays, ...store.logs.keys}.length;
    final confirmed = mode == MergeMode.add || _confirm.text.trim() == 'REPLACE';

    if (data.isEmpty) {
      return [
        EmptyState(
          title: 'Nothing to import',
          body: 'Bloom read ${data.recordsRead} ${data.recordsRead == 1 ? 'entry' : 'entries'} in this '
              '${data.format.label}, but none of them had period days or logs it can use.',
          actionLabel: 'Choose another file',
          onAction: () => _go(_Stage.guide),
        ),
        if (data.skipped.isNotEmpty || data.unrelatedRecords > 0) _SkippedList(data: data),
      ];
    }

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(data.format.label),
          Gap.v8,
          if (range != null)
            Text(
              '${fmtFull(range.first)} to ${fmtFull(range.last)}',
              style: Almanac.italic(context, size: 20, color: p.ink),
            ),
          Gap.v16,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatTile(
                  value: '${data.periodCount}',
                  unit: data.periodCount == 1 ? 'period' : 'periods',
                  label: 'Periods',
                  color: BloomColors.period,
                ),
              ),
              Gap.h16,
              Expanded(
                child: StatTile(
                  value: '${data.logs.length}',
                  unit: data.logs.length == 1 ? 'day' : 'days',
                  label: 'Days with logs',
                ),
              ),
            ],
          ),
        ],
      ),
      _SkippedList(data: data),
      if (hasData)
        BloomCard(
          padding: const EdgeInsets.only(top: Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MonoLabel('Your data in Bloom'),
              Gap.v4,
              TextChoices<MergeMode>(
                options: const [
                  TextChoice(MergeMode.add, 'Add to my data'),
                  TextChoice(MergeMode.replace, 'Replace everything'),
                ],
                selected: mode,
                onChanged: (v) => setState(() {
                  _mode = v;
                  _confirm.clear();
                }),
              ),
              Gap.v8,
              if (mode == MergeMode.add)
                Text(
                  plan.keptDays == 0
                      ? 'Bloom adds the imported days. None of them overlap with days you already have.'
                      : 'Bloom adds the imported days. ${plan.keptDays} of them already have entries in Bloom, '
                          'so Bloom keeps yours and leaves those imported days out.',
                  style: muted,
                )
              else ...[
                Text(
                  'Bloom removes the periods and logs on all $existingDays days it has now, then adds the import. '
                  'Your settings, reminders, and journal stay. This can\'t be undone, so export a backup first '
                  'if you might want your current data back.',
                  style: muted,
                ),
                Gap.v16,
                Text('Type REPLACE to confirm.', style: Almanac.label(context)),
                TextField(
                  key: const ValueKey('import-confirm'),
                  controller: _confirm,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'REPLACE'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      if (syncOn)
        Marginalia(
          label: 'Sync',
          child: Text('Sync is on, so the imported days also sync, encrypted, to your other devices.', style: muted),
        ),
      Wrap(
        spacing: Space.lg,
        runSpacing: Space.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkButton(
            key: const ValueKey('import-apply'),
            label: plan.importedDays == 0
                ? 'Nothing new to add'
                : mode == MergeMode.replace
                    ? 'Replace with ${plan.importedDays} days'
                    : 'Import ${plan.importedDays} ${plan.importedDays == 1 ? 'day' : 'days'}',
            color: mode == MergeMode.replace ? BloomColors.error : null,
            onPressed: plan.importedDays == 0 || !confirmed ? null : () => _apply(plan),
          ),
          InkLink('Choose another file', onTap: () => _go(_Stage.guide)),
        ],
      ),
    ];
  }

  List<Widget> _doneStep(BuildContext context) {
    final plan = _applied!;
    final data = _data!;
    final muted = Theme.of(context).textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatTile(
              value: '${plan.importedDays}',
              unit: plan.importedDays == 1 ? 'day' : 'days',
              label: 'Imported',
            ),
          ),
          Gap.h16,
          Expanded(
            child: StatTile(
              value: '${plan.periodCount}',
              unit: plan.periodCount == 1 ? 'period' : 'periods',
              label: 'Periods',
              color: BloomColors.period,
            ),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan.keptDays > 0)
            Marginalia(label: 'Kept', child: Text('${plan.keptDays} days already in Bloom stayed as they were.', style: muted)),
          if (plan.removedDays > 0)
            Marginalia(label: 'Removed', child: Text('${plan.removedDays} earlier days were replaced.', style: muted)),
          if (data.skippedCount > 0)
            Marginalia(
              label: 'Left out',
              child: Text('${data.skippedCount} items had no place in Bloom and weren\'t imported.', style: muted),
            ),
          Marginalia(
            label: 'Next',
            child: Text(
              'Bloom\'s averages and predictions now include your imported cycles. Check the calendar to see them.',
              style: muted,
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: InkButton(
          key: const ValueKey('import-finish'),
          label: widget.fromOnboarding ? 'Continue setup' : 'Done',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
    ];
  }
}

/// What won't be imported, and what was adjusted on the way in.
class _SkippedList extends StatelessWidget {
  const _SkippedList({required this.data});
  final ImportedData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2);
    final skipped = data.skipped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final adjusted = data.adjusted.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    Widget row(String label, int count) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Gap.h12,
              Text('$count', style: Almanac.data(context)),
            ],
          ),
        );

    return BloomCard(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MonoLabel('Won\'t be imported'),
          Gap.v8,
          if (skipped.isEmpty && data.unrelatedRecords == 0)
            Text('Everything Bloom read has a place in Bloom.', style: muted)
          else ...[
            for (final e in skipped) row(e.key, e.value),
            if (data.unrelatedRecords > 0) row('Other data, such as steps and heart rate', data.unrelatedRecords),
          ],
          if (adjusted.isNotEmpty) ...[
            Gap.v16,
            const MonoLabel('Imported a little differently'),
            Gap.v8,
            for (final e in adjusted) row(e.key, e.value),
          ],
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Marginalia(
        label: 'Privacy',
        child: Text(
          'Bloom reads the file on this device. It never uploads the file or keeps a copy of it.',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2),
        ),
      );
}

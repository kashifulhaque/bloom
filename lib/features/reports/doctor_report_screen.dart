/// "Report for a doctor": an on-screen preview, a PDF to print or share, and
/// end-to-end encrypted share links (see `share/`).
library;

import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart';
import 'pregnancy_info.dart';
import 'report_data.dart';
import 'report_pdf.dart';
import 'share/share_api.dart';
import 'share/share_link_sheet.dart';

class DoctorReportScreen extends StatefulWidget {
  const DoctorReportScreen({super.key, this.shareApi, this.buildPdf});

  /// The share service. Defaults to the one this build was configured with
  /// ([kShareApiSetting]); with none, the Share link button is hidden.
  final ReportShareApi? shareApi;

  /// Renders the PDF. Tests pass a fake; the app uses [buildReportPdf].
  final Future<Uint8List> Function(ReportData d)? buildPdf;

  @override
  State<DoctorReportScreen> createState() => _DoctorReportScreenState();
}

class _DoctorReportScreenState extends State<DoctorReportScreen> {
  bool _busy = false;
  late final ReportSharer? _sharer = () {
    final api = widget.shareApi ?? switch (resolveShareApi()) { final Uri url => HttpReportShareApi(url), null => null };
    return api == null ? null : ReportSharer(api);
  }();

  Future<Uint8List> _pdf(ReportData d) => (widget.buildPdf ?? buildReportPdf)(d);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, 'Couldn\'t create the PDF: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final preg = pregnancyInfo(store);
    if (preg != null) return _PregnancySummary(info: preg);

    final d = buildReportData(store);
    final fileName = 'bloom-report-${dayKey(d.generated)}.pdf';

    return Scaffold(
      body: BloomPage(
        eyebrow: 'For your clinician',
        title: 'Report for a doctor',
        subtitle: 'A summary of your last 6 cycles to bring to an appointment.',
        spacing: Space.xxl,
        children: [
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              InkButton(
                label: 'Print or save PDF',
                icon: Icons.print_outlined,
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await Printing.layoutPdf(
                          name: fileName,
                          onLayout: (format) => buildReportPdf(d, format: format),
                        );
                      }),
              ),
              InkButton.outlined(
                label: 'Share PDF',
                icon: Icons.ios_share,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await Printing.sharePdf(bytes: await _pdf(d), filename: fileName);
                      }),
              ),
              if (_sharer case final sharer?)
                InkButton.outlined(
                  label: 'Share link',
                  icon: Icons.link,
                  onPressed: _busy ? null : () => showShareLinkSheet(context, sharer: sharer, buildPdf: () => _pdf(d)),
                ),
            ],
          ),
          if (_sharer case final sharer?) SharedLinksSection(sharer: sharer),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MonoLabel('Proof · what the PDF shows'),
              Gap.v12,
              _ReportPreview(d: d),
            ],
          ),
          const Disclaimer(
            text:
                'The report uses only what you logged. Ovulation days are estimates. '
                'It isn\'t a diagnosis or medical advice.',
          ),
        ],
      ),
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];

/// A preview of the PDF, set like a typeset document on a sheet of paper:
/// a serif title, mono labels, hairline tables, and thin phase-colored bars.
class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.d});
  final ReportData d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final muted = theme.textTheme.bodySmall!;
    var section = 0;
    Widget heading(String t) => _Heading('${_roman[section++]}.  $t');

    return Container(
      decoration: BoxDecoration(
        color: p.raised,
        border: Border.all(color: p.hairline),
        borderRadius: Radii.xsAll,
      ),
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: MonoLabel('Bloom · Cycle report', size: 10)),
              const BloomLogo(size: 22),
            ],
          ),
          Gap.v12,
          Text('Menstrual cycle report', style: Almanac.serif(size: 26, weight: 350, color: p.ink, height: 1.1)),
          Gap.v4,
          Text('${fmtFull(d.from)} to ${fmtFull(d.generated)}', style: Almanac.data(context, size: 12)),
          const Hairline(spacing: Space.md),
          if (d.name.isNotEmpty) _KeyValue('Patient', d.name),
          if (d.age != null) _KeyValue('Age', '${d.age}'),
          _KeyValue('Goal', d.goal),
          heading('Summary'),
          Wrap(
            spacing: Space.xl,
            runSpacing: Space.md,
            children: [
              _Stat('Average cycle', '${d.avgCycle}', 'days'),
              _Stat('Average period', '${d.avgPeriod}', 'days', color: p.period),
              if (d.longestCycle > 0) _Stat('Range', '${d.shortestCycle}–${d.longestCycle}', 'days'),
            ],
          ),
          Gap.v12,
          Text(_capitalize(d.regularityText), style: theme.textTheme.bodyMedium),
          if (d.conditions.isNotEmpty || d.contraception != null) Gap.v8,
          if (d.conditions.isNotEmpty) _KeyValue('Conditions', d.conditions.join(', ')),
          if (d.contraception != null) _KeyValue('Birth control', d.contraception!),
          heading(d.cycles.isEmpty ? 'Cycles' : 'Last ${d.cycles.length} cycles'),
          if (d.cycles.isEmpty)
            Text('No periods logged yet. Log your periods to fill this report.', style: muted)
          else ...[
            _CycleTable(d.cycles),
            Gap.v16,
            for (final c in d.cycles.reversed) _CycleRow(c),
            Gap.v8,
            Wrap(
              spacing: Space.md,
              runSpacing: Space.xs,
              children: [
                _legend(context, p.period, 'Period'),
                _legend(context, p.fertile.withValues(alpha: 0.5), 'Fertile (est.)'),
                _legend(context, p.ovulation, 'Ovulation (est.)'),
              ],
            ),
          ],
          heading('Most logged symptoms'),
          _Counts(d.topSymptoms, 'None logged'),
          heading('Most logged moods'),
          _Counts(d.topMoods, 'None logged'),
          if (d.bbtSummary != null || d.weightSummary != null) heading('Measurements'),
          if (d.bbtSummary != null) _KeyValue('Basal temp.', d.bbtSummary!),
          if (d.weightSummary != null) _KeyValue('Weight', d.weightSummary!),
          if (d.notes.isNotEmpty) ...[
            heading('Notes'),
            for (final (date, note) in d.notes) _KeyValue(fmtShort(date), note),
          ],
          const Hairline(spacing: Space.lg),
          MonoLabel('Generated by Bloom on ${fmtFull(d.generated)}', size: 9.5),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 4, color: c),
      Gap.h4,
      Flexible(child: MonoLabel(label, size: 9.5)),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(text, color: BloomColors.of(context).ink),
          Gap.v4,
          const Hairline(),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.unit, {this.color});
  final String label;
  final String value;
  final String unit;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value, style: Almanac.numeral(context, size: 30, weight: 330, color: color)),
            TextSpan(text: ' $unit', style: Almanac.italic(context, size: 13, color: p.ink2)),
          ]),
        ),
        Gap.v4,
        MonoLabel(label, size: 9.5),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Padding(padding: const EdgeInsets.only(top: 3), child: MonoLabel(k, size: 9.5)),
          ),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// The cycles as a hairline table: start, cycle length, period length, and
/// estimated ovulation day.
class _CycleTable extends StatelessWidget {
  const _CycleTable(this.cycles);
  final List<ReportCycle> cycles;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final cell = Almanac.data(context, size: 12, color: p.ink);
    Widget row(List<Widget> cells, {bool header = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: header ? p.ink2.withValues(alpha: 0.5) : p.hairline))),
      child: Row(
        children: [
          Expanded(flex: 5, child: cells[0]),
          Expanded(flex: 3, child: cells[1]),
          Expanded(flex: 3, child: cells[2]),
          Expanded(flex: 3, child: cells[3]),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(header: true, const [
          MonoLabel('Start', size: 9),
          MonoLabel('Cycle', size: 9),
          MonoLabel('Period', size: 9),
          MonoLabel('Ovul.', size: 9),
        ]),
        for (final c in cycles.reversed)
          row([
            Text(fmtShort(c.start), style: cell),
            c.length != null
                ? Text('${c.length} d', style: cell)
                : Text('day ${c.currentDay}', style: Almanac.italic(context, size: 13, color: p.ink2)),
            Text('${c.periodLength} d', style: cell),
            Text('day ${c.ovulationDay}', style: cell),
          ]),
      ],
    );
  }
}

/// One cycle as a thin bar on a shared 45-day scale: an oxblood period, a
/// sage fertile window, and the ovulation day, over a hairline track.
class _CycleRow extends StatelessWidget {
  const _CycleRow(this.c);
  final ReportCycle c;
  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final total = c.length ?? c.currentDay ?? 1;
    const scale = 45;
    final ov = c.ovulationDay;
    Color? dayColor(int day) {
      if (day <= c.periodLength) return p.period;
      if (day == ov) return p.ovulation;
      if (day >= ov - 5 && day <= ov + 1) return p.fertile.withValues(alpha: 0.5);
      return null;
    }

    // Merge consecutive days of the same color into one segment.
    final days = total.clamp(1, scale);
    final runs = <(Color?, int)>[];
    for (var day = 1; day <= days; day++) {
      final col = dayColor(day);
      if (runs.isNotEmpty && runs.last.$1 == col) {
        runs.last = (col, runs.last.$2 + 1);
      } else {
        runs.add((col, 1));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(fmtShort(c.start), style: Almanac.data(context, size: 10.5))),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: days,
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (color, n) in runs)
                          Expanded(
                            flex: n,
                            child: color == null
                                ? Center(child: Container(height: 1, color: p.ink2.withValues(alpha: 0.45)))
                                : ColoredBox(color: color),
                          ),
                      ],
                    ),
                  ),
                ),
                if (days < scale) Spacer(flex: scale - days),
              ],
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              c.length != null ? '${c.length} d' : 'day ${c.currentDay}',
              textAlign: TextAlign.right,
              style: Almanac.data(context, size: 10.5, color: c.length == null ? p.ink : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts(this.items, this.empty);
  final List<CountItem> items;
  final String empty;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    if (items.isEmpty) return Text(empty, style: theme.textTheme.bodySmall);
    final max = items.first.count;
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(i.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                ),
                Gap.h8,
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: i.count / max,
                      child: Container(height: 2, color: p.ink),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${i.count} d', textAlign: TextAlign.right, style: Almanac.data(context, size: 11)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PregnancySummary extends StatelessWidget {
  const _PregnancySummary({required this.info});
  final PregnancyInfo info;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Scaffold(
      body: BloomPage(
        eyebrow: 'For your clinician · Trimester ${info.trimester}',
        header: PhaseTitle(
          lead: '${info.weeks} weeks, ${info.days} days,',
          italic: info.daysToGo >= 0 ? '${info.daysToGo} days to go.' : 'past the due date.',
          color: BloomColors.pregnancy,
        ),
        spacing: Space.xxl,
        children: [
          Text(
            'Report for a doctor: a pregnancy summary.',
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: p.ink2),
          ),
          Column(
            children: [
              const Hairline(),
              Gap.v12,
              Marginalia(
                label: 'Due',
                labelWidth: 96,
                child: Text(fmtFull(info.dueDate), style: Almanac.serif(size: 20, weight: 360, color: p.ink)),
              ),
              Gap.v12,
              const Hairline(),
              Gap.v12,
              Marginalia(
                label: 'Last period',
                labelWidth: 96,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: fmtFull(info.lmp), style: Almanac.serif(size: 20, weight: 360, color: p.ink)),
                  TextSpan(text: '  estimated', style: Almanac.italic(context, size: 15, color: p.ink2)),
                ])),
              ),
              Gap.v12,
              const Hairline(),
            ],
          ),
          const Marginalia(
            label: 'Note',
            child: Text(
              'The cycle report isn\'t available in pregnancy mode, because cycle data doesn\'t apply while '
              'you\'re pregnant. Your care team uses their own dating scans and records.',
            ),
          ),
        ],
      ),
    );
  }
}

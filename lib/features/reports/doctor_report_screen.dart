/// "Report for a doctor": an on-screen preview and a PDF to print or share.
library;

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

class DoctorReportScreen extends StatefulWidget {
  const DoctorReportScreen({super.key});

  @override
  State<DoctorReportScreen> createState() => _DoctorReportScreenState();
}

class _DoctorReportScreenState extends State<DoctorReportScreen> {
  bool _busy = false;

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
        title: 'Report for a doctor',
        subtitle: 'A summary of your last 6 cycles to bring to an appointment.',
        children: [
          GradientButton(
            label: 'Print or save PDF',
            icon: Icons.print_rounded,
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
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await Printing.sharePdf(bytes: await buildReportPdf(d), filename: fileName);
                  }),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share PDF'),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader('Preview'),
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

/// A document-like preview of the PDF.
class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.d});
  final ReportData d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final muted = theme.textTheme.bodySmall!.copyWith(color: tokens.muted);
    return BloomCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 6, decoration: const BoxDecoration(gradient: BloomGradients.brand)),
          Padding(
            padding: Insets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Menstrual cycle report', style: theme.textTheme.titleLarge),
                          Gap.v4,
                          Text('${fmtFull(d.from)} to ${fmtFull(d.generated)}', style: muted),
                        ],
                      ),
                    ),
                    Gap.h12,
                    const BloomLogo(size: 32),
                  ],
                ),
                Gap.v12,
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    if (d.name.isNotEmpty)
                      PillChip(d.name, icon: Icons.person_rounded, dense: true, color: BloomColors.brand),
                    if (d.age != null) PillChip('Age ${d.age}', dense: true, color: BloomColors.info),
                    PillChip(d.goal, icon: Icons.flag_rounded, dense: true, color: BloomColors.luteal),
                  ],
                ),
                Gap.v16,
                Divider(height: 1, color: tokens.border),
                const _Heading('Summary'),
                Row(
                  children: [
                    Expanded(child: _Stat('Avg cycle', '${d.avgCycle}', 'days', BloomColors.brand)),
                    Gap.h8,
                    Expanded(child: _Stat('Avg period', '${d.avgPeriod}', 'days', BloomColors.period)),
                    if (d.longestCycle > 0) ...[
                      Gap.h8,
                      Expanded(
                        child: _Stat('Range', '${d.shortestCycle}-${d.longestCycle}', 'days', BloomColors.luteal),
                      ),
                    ],
                  ],
                ),
                Gap.v12,
                Text(_capitalize(d.regularityText), style: theme.textTheme.bodyMedium),
                if (d.conditions.isNotEmpty) ...[
                  Gap.v4,
                  Text('Reported conditions: ${d.conditions.join(', ')}', style: theme.textTheme.bodyMedium),
                ],
                if (d.contraception != null) ...[
                  Gap.v4,
                  Text('Birth control: ${d.contraception}', style: theme.textTheme.bodyMedium),
                ],
                _Heading(d.cycles.isEmpty ? 'Cycles' : 'Last ${d.cycles.length} cycles'),
                if (d.cycles.isEmpty)
                  Text('No periods logged yet. Log your periods to fill this report.', style: muted)
                else ...[
                  for (final c in d.cycles.reversed) _CycleRow(c),
                  Gap.v4,
                  Wrap(
                    spacing: Space.md,
                    runSpacing: Space.xs,
                    children: [
                      _legend(context, BloomColors.period, 'Period'),
                      _legend(context, BloomColors.fertile.withValues(alpha: 0.45), 'Fertile (est.)'),
                      _legend(context, BloomColors.ovulation, 'Ovulation (est.)'),
                    ],
                  ),
                ],
                const _Heading('Most logged symptoms'),
                _Counts(d.topSymptoms, 'None logged', BloomColors.coral),
                const _Heading('Most logged moods'),
                _Counts(d.topMoods, 'None logged', BloomColors.luteal),
                if (d.bbtSummary != null || d.weightSummary != null) const _Heading('Measurements'),
                if (d.bbtSummary != null) _KeyValue('Basal temperature', d.bbtSummary!),
                if (d.weightSummary != null) _KeyValue('Weight', d.weightSummary!),
                if (d.notes.isNotEmpty) ...[
                  const _Heading('Notes'),
                  for (final (date, note) in d.notes) _KeyValue(fmtShort(date), note),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      Gap.h4,
      Flexible(child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.primary, letterSpacing: 1),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.unit, this.color);
  final String label;
  final String value;
  final String unit;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.09),
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall!.copyWith(color: readableTint(color, theme.brightness)),
          ),
          Gap.v4,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: theme.textTheme.labelSmall!.copyWith(color: BloomTokens.of(context).muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(k, style: theme.textTheme.bodySmall!.copyWith(color: BloomTokens.of(context).muted)),
          ),
          Expanded(child: Text(v, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _CycleRow extends StatelessWidget {
  const _CycleRow(this.c);
  final ReportCycle c;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final total = c.length ?? c.currentDay ?? 1;
    const scale = 45;
    final ov = c.ovulationDay;
    Color dayColor(int day) {
      if (day <= c.periodLength) return BloomColors.period;
      if (day == ov) return BloomColors.ovulation;
      if (day >= ov - 5 && day <= ov + 1) return BloomColors.fertile.withValues(alpha: 0.45);
      return tokens.subtle;
    }

    // Merge consecutive days of the same color into one segment.
    final days = total.clamp(1, scale);
    final runs = <(Color, int)>[];
    for (var day = 1; day <= days; day++) {
      final c = dayColor(day);
      if (runs.isNotEmpty && runs.last.$1 == c) {
        runs.last = (c, runs.last.$2 + 1);
      } else {
        runs.add((c, 1));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(fmtShort(c.start), style: theme.textTheme.labelSmall)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: days,
                  child: ClipRRect(
                    borderRadius: Radii.pillAll,
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (color, n) in runs)
                            Expanded(
                              flex: n,
                              child: ColoredBox(color: color),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (days < scale) Spacer(flex: scale - days),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              c.length != null ? '${c.length} d' : 'Day ${c.currentDay}',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall!.copyWith(
                color: c.length == null ? theme.colorScheme.primary : tokens.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts(this.items, this.empty, this.color);
  final List<CountItem> items;
  final String empty;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    if (items.isEmpty) return Text(empty, style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted));
    final max = items.first.count;
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  child: Text(i.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: Radii.pillAll,
                    child: LinearProgressIndicator(
                      value: i.count / max,
                      minHeight: 8,
                      color: color,
                      backgroundColor: tokens.subtle,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text('${i.count} d', textAlign: TextAlign.right, style: theme.textTheme.labelSmall),
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
    final theme = Theme.of(context);
    final white = Colors.white.withValues(alpha: 0.85);
    return Scaffold(
      body: BloomPage(
        title: 'Report for a doctor',
        subtitle: 'Pregnancy summary',
        heroColor: BloomColors.pregnancy,
        children: [
          BloomCard.gradient(
            gradient: BloomGradients.pregnancy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillChip('Trimester ${info.trimester}', solid: true, color: Colors.white),
                Gap.v12,
                Text(
                  '${info.weeks} weeks, ${info.days} days',
                  style: theme.textTheme.headlineMedium!.copyWith(color: Colors.white),
                ),
                if (info.daysToGo >= 0) ...[
                  Gap.v4,
                  Text('${info.daysToGo} days to go', style: theme.textTheme.bodyLarge!.copyWith(color: white)),
                ],
              ],
            ),
          ),
          MenuSection(
            children: [
              MenuTile(
                icon: Icons.child_friendly_rounded,
                color: BloomColors.pregnancy,
                title: 'Estimated due date',
                subtitle: fmtFull(info.dueDate),
              ),
              MenuTile(
                icon: Icons.water_drop_rounded,
                color: BloomColors.period,
                title: 'Last period (estimated)',
                subtitle: fmtFull(info.lmp),
              ),
            ],
          ),
          const InfoBanner(
            tone: BannerTone.info,
            message:
                'The cycle report isn\'t available in pregnancy mode, because cycle data doesn\'t apply while '
                'you\'re pregnant. Your care team uses their own dating scans and records.',
          ),
        ],
      ),
    );
  }
}

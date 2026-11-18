/// Renders [ReportData] as an Almanac-style PDF with the `pdf` package: a
/// serif title, mono labels, hairline tables, and thin phase-colored bars.
///
/// The PDF embeds the app's bundled Hanken Grotesk and IBM Plex Mono from
/// `assets/fonts`, so body text and marginalia match the app and work
/// offline. The serif lines (title, numerals, italic units) use static
/// Fraunces cuts from `assets/pdf` (roman at weight 350 and italic at
/// weight 320, both at optical size 72). The `pdf` package can't set
/// variable-font axes, so these are instanced from the app's variable
/// Fraunces files; see `bloom_docs/DESIGN.md` for how to rebuild them.
///
/// If the bundled fonts can't be loaded (for example in a plain unit test
/// without a Flutter binding), the PDF falls back to built-in Helvetica and
/// Courier. Either way, every string passes through [_Fonts.clean] or
/// [_Fonts.cleanSerif], which replace characters the fonts can't draw (emoji,
/// non-Latin scripts) with `?` instead of leaving blank boxes.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/dates.dart';
import 'report_data.dart';

// The Almanac paper palette, for print.
const _ink = PdfColor.fromInt(0xFF2A2420);
const _ink2 = PdfColor.fromInt(0xFF6E645A);
const _line = PdfColor.fromInt(0xFFE2D9C8);
const _period = PdfColor.fromInt(0xFFA23B2A);
const _fertile = PdfColor.fromInt(0xFFA9B8AC); // Sage at about 50 % on white.
const _ovulation = PdfColor.fromInt(0xFF3C5446);
const _track = PdfColor.fromInt(0xFFB3A693);

/// The fonts for one PDF, and the characters they can draw.
class _Fonts {
  _Fonts({
    required this.serif,
    required this.serifItalic,
    required this.sans,
    required this.sansBold,
    required this.mono,
    required this.monoMedium,
    required this.supports,
    required this.serifSupports,
    required this.embedded,
  });

  final pw.Font serif;
  final pw.Font serifItalic;
  final pw.Font sans;
  final pw.Font sansBold;
  final pw.Font mono;
  final pw.Font monoMedium;

  /// True when the bundled TTFs are embedded; false for the built-in
  /// fallback fonts.
  final bool embedded;
  final bool Function(int rune) supports;

  /// The characters the serif can draw.
  final bool Function(int rune) serifSupports;

  /// [v] with every character the fonts can't draw replaced by `?`.
  /// Typographic punctuation the fonts lack falls back to its plain ASCII
  /// form first, so a note with curly quotes stays readable.
  String clean(String v) => _replace(v, supports);

  /// Like [clean], for text set in the serif.
  String cleanSerif(String v) => _replace(v, serifSupports);

  static String _replace(String v, bool Function(int) ok) {
    final out = StringBuffer();
    for (final r in v.runes) {
      if (ok(r)) {
        out.writeCharCode(r);
      } else {
        out.write(_ascii[r] ?? '?');
      }
    }
    return out.toString();
  }

  static const _ascii = {
    0x2018: "'", 0x2019: "'", 0x201A: "'", 0x201C: '"', 0x201D: '"', 0x201E: '"', //
    0x2013: '-', 0x2014: '-', 0x2212: '-', 0x2026: '...', 0x2022: '*', 0x2248: '~',
    0x2264: '<=', 0x2265: '>=', 0x2192: '->', 0x2190: '<-', 0x00A0: ' ', 0x2009: ' ', 0x202F: ' ',
  };

  static bool _latin1(int r) => r == 0x0A || (r >= 0x20 && r <= 0xFF && !(r >= 0x7F && r < 0xA0));

  static Future<_Fonts>? _cached;

  /// Loads the bundled fonts once, or the built-in ones if that fails.
  static Future<_Fonts> load() => _cached ??= _loadBundled().catchError((Object _) {
    _cached = null;
    return _builtIn();
  });

  static Future<_Fonts> _loadBundled() async {
    // Copy each font into its own buffer: the parser expects the data to
    // start at offset 0, and asset loads can return a view into a larger one.
    Future<ByteData> f(String name) async {
      final d = await rootBundle.load('assets/fonts/$name');
      return ByteData.sublistView(Uint8List.fromList(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes)));
    }

    Future<ByteData> fp(String name) async {
      final d = await rootBundle.load('assets/pdf/$name');
      return ByteData.sublistView(Uint8List.fromList(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes)));
    }
    final data = await Future.wait([
      f('HankenGrotesk-400.ttf'),
      f('HankenGrotesk-600.ttf'),
      f('IBMPlexMono-Regular.ttf'),
      f('IBMPlexMono-Medium.ttf'),
    ]);
    final serifData = await Future.wait([
      fp('Fraunces-Light.ttf'),
      fp('Fraunces-LightItalic.ttf'),
    ]);
    // Only characters both families can draw, so no style shows a blank box.
    Set<int> map(ByteData d) => TtfParser(d).charToGlyphIndexMap.keys.toSet();
    final common = map(data[0]).intersection(map(data[2]));
    final serifCommon = map(serifData[0]).intersection(map(serifData[1]));
    return _Fonts(
      serif: pw.Font.ttf(serifData[0]),
      serifItalic: pw.Font.ttf(serifData[1]),
      sans: pw.Font.ttf(data[0]),
      sansBold: pw.Font.ttf(data[1]),
      mono: pw.Font.ttf(data[2]),
      monoMedium: pw.Font.ttf(data[3]),
      supports: (r) => r < 0x20 ? r == 0x0A : common.contains(r),
      serifSupports: (r) => r < 0x20 ? r == 0x0A : serifCommon.contains(r),
      embedded: true,
    );
  }

  static _Fonts _builtIn() => _Fonts(
    serif: pw.Font.times(),
    serifItalic: pw.Font.timesItalic(),
    sans: pw.Font.helvetica(),
    sansBold: pw.Font.helveticaBold(),
    mono: pw.Font.courier(),
    monoMedium: pw.Font.courierBold(),
    // The built-in fonts cover Latin-1 only.
    supports: _latin1,
    serifSupports: _latin1,
    embedded: false,
  );
}

/// Whether the last PDF built embedded the bundled fonts. For tests.
bool lastReportUsedBundledFonts = false;

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];

Future<Uint8List> buildReportPdf(ReportData d, {PdfPageFormat format = PdfPageFormat.a4}) async {
  final f = await _Fonts.load();
  lastReportUsedBundledFonts = f.embedded;
  final doc = pw.Document(title: 'Bloom cycle report', author: 'Bloom');
  final theme = pw.ThemeData.withFont(
    base: f.sans,
    bold: f.sansBold,
    italic: f.serifItalic,
    boldItalic: f.serifItalic,
  ).copyWith(defaultTextStyle: pw.TextStyle(font: f.sans, fontSize: 10, color: _ink, lineSpacing: 2));
  final s = _Styles(f);
  var section = 0;
  pw.Widget heading(String t) => s.heading('${_roman[section++]}.  $t');

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 36),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 18),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            s.label('Generated by Bloom on ${fmtFull(d.generated)}', size: 6.5),
            s.label('Page ${ctx.pageNumber} of ${ctx.pagesCount}', size: 6.5),
          ],
        ),
      ),
      build: (ctx) => [
        _header(d, s),
        heading('Summary'),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            s.stat('Average cycle', '${d.avgCycle}', 'days'),
            s.stat('Average period', '${d.avgPeriod}', 'days', color: _period),
            if (d.longestCycle > 0) s.stat('Shortest to longest', '${d.shortestCycle}–${d.longestCycle}', 'days'),
          ],
        ),
        pw.SizedBox(height: 12),
        s.keyValue('Assessment', _cap(d.regularityText)),
        if (d.conditions.isNotEmpty) s.keyValue('Reported conditions', d.conditions.join(', ')),
        if (d.contraception != null) s.keyValue('Birth control', d.contraception!),
        heading(d.cycles.isEmpty ? 'Cycles' : 'Last ${d.cycles.length} cycles'),
        if (d.cycles.isEmpty)
          s.body('No periods logged yet.', color: _ink2)
        else ...[
          _cycleTable(d, s),
          pw.SizedBox(height: 16),
          _cycleBars(d, s),
        ],
        heading('Most logged symptoms'),
        _counts(d.topSymptoms, 'No symptoms logged in this period.', s),
        heading('Most logged moods'),
        _counts(d.topMoods, 'No moods logged in this period.', s),
        if (d.bbtSummary != null || d.weightSummary != null) heading('Measurements'),
        if (d.bbtSummary != null) s.keyValue('Basal body temperature', d.bbtSummary!),
        if (d.weightSummary != null) s.keyValue('Weight', d.weightSummary!),
        if (d.notes.isNotEmpty) ...[
          heading('Notes'),
          for (final (date, note) in d.notes) s.keyValue(fmtFull(date), note),
        ],
        pw.SizedBox(height: 22),
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5))),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 120, child: s.label('Note')),
              pw.Expanded(
                child: s.body(
                  'This report summarizes data the patient entered in Bloom, an open-source period tracker. '
                  'Ovulation days and averages are estimates, not clinical measurements. It is not a diagnosis '
                  'and is not medical advice.',
                  color: _ink2,
                  size: 8.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Text helpers bound to one set of fonts.
class _Styles {
  _Styles(this.f);
  final _Fonts f;

  /// Mono uppercase marginalia.
  pw.Widget label(String t, {double size = 7.5, PdfColor color = _ink2, pw.TextAlign? align}) => pw.Text(
    f.clean(t.toUpperCase()),
    textAlign: align,
    style: pw.TextStyle(font: f.monoMedium, fontSize: size, color: color, letterSpacing: size * 0.12),
  );

  pw.Widget body(String t, {PdfColor? color, double size = 10}) =>
      pw.Text(f.clean(t), style: pw.TextStyle(font: f.sans, fontSize: size, color: color, lineSpacing: 2.5));

  pw.Widget data(String t, {PdfColor color = _ink, double size = 9, pw.TextAlign? align}) => pw.Text(
    f.clean(t),
    textAlign: align,
    style: pw.TextStyle(font: f.mono, fontSize: size, color: color),
  );

  pw.Widget heading(String t) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 22, bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.75))),
    child: label(t, size: 8, color: _ink),
  );

  pw.Widget keyValue(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 120, child: pw.Padding(padding: const pw.EdgeInsets.only(top: 1.5), child: label(k))),
        pw.Expanded(child: body(v)),
      ],
    ),
  );

  pw.Widget stat(String l, String value, String unit, {PdfColor color = _ink}) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: f.cleanSerif(value), style: pw.TextStyle(font: f.serif, fontSize: 25, color: color)),
              pw.TextSpan(text: f.cleanSerif(' $unit'), style: pw.TextStyle(font: f.serifItalic, fontSize: 11, color: _ink2)),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        label(l, size: 6.8),
      ],
    ),
  );
}

pw.Widget _header(ReportData d, _Styles s) {
  final f = s.f;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.SizedBox(width: 16, height: 16, child: pw.CustomPaint(painter: _paintMark)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: s.label('Bloom · Cycle report')),
          s.label(fmtFull(d.generated)),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Menstrual cycle report', style: pw.TextStyle(font: f.serif, fontSize: 28, color: _ink)),
                pw.SizedBox(height: 4),
                s.data('Period covered: ${fmtFull(d.from)} to ${fmtFull(d.generated)}', color: _ink2),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (d.name.isNotEmpty) _who(s, 'Patient', d.name),
              if (d.age != null) _who(s, 'Age', '${d.age}'),
              _who(s, 'Goal', d.goal),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(height: 0.75, color: _ink),
    ],
  );
}

pw.Widget _who(_Styles s, String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 2),
  child: pw.Row(
    children: [
      pw.SizedBox(width: 48, child: s.label(k, size: 6.8)),
      s.body(v, size: 9.5),
    ],
  ),
);

/// The Bloom mark: five line petals in oxblood and an ink stem.
void _paintMark(PdfGraphics g, PdfPoint size) {
  final k = size.x / 100;
  // PDF y grows upward; the mark is drawn in a 100-unit box, y down.
  PdfPoint pt(double x, double y) => PdfPoint(x * k, size.y - y * k);
  void quad(PdfPoint from, PdfPoint c, PdfPoint to) {
    // A quadratic Bezier as a cubic.
    g.curveTo(
      from.x + 2 / 3 * (c.x - from.x),
      from.y + 2 / 3 * (c.y - from.y),
      to.x + 2 / 3 * (c.x - to.x),
      to.y + 2 / 3 * (c.y - to.y),
      to.x,
      to.y,
    );
  }

  g
    ..setLineWidth(5 * k)
    ..setLineCap(PdfLineCap.round)
    ..setLineJoin(PdfLineJoin.round)
    ..setStrokeColor(_period);
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 5;
    final dx = math.cos(a), dy = math.sin(a);
    final nx = -dy, ny = dx;
    final base = pt(50 + dx * 6, 40 + dy * 6);
    final tip = pt(50 + dx * 30, 40 + dy * 30);
    final c1 = pt(50 + dx * 19 + nx * 13, 40 + dy * 19 + ny * 13);
    final c2 = pt(50 + dx * 19 - nx * 13, 40 + dy * 19 - ny * 13);
    g.moveTo(base.x, base.y);
    quad(base, c1, tip);
    quad(tip, c2, base);
    g.strokePath();
  }
  g
    ..setStrokeColor(_ink)
    ..moveTo(pt(50, 70).x, pt(50, 70).y);
  quad(pt(50, 70), pt(47, 82), pt(51, 96));
  g.strokePath();
}

pw.Widget _cycleTable(ReportData d, _Styles s) {
  pw.Widget cell(String t, {bool head = false, bool italic = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: head
        ? s.label(t)
        : italic
        ? pw.Text(s.f.cleanSerif(t), style: pw.TextStyle(font: s.f.serifItalic, fontSize: 10.5, color: _ink2))
        : s.data(t, size: 9.5),
  );
  return pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(2),
      3: pw.FlexColumnWidth(2),
    },
    border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink2, width: 0.75))),
        children: [
          cell('Start', head: true),
          cell('Cycle length', head: true),
          cell('Period', head: true),
          cell('Est. ovulation', head: true),
        ],
      ),
      for (final c in d.cycles.reversed)
        pw.TableRow(
          children: [
            cell(fmtFull(c.start)),
            c.length != null ? cell('${c.length} days') : cell('current, day ${c.currentDay}', italic: true),
            cell('${c.periodLength} days'),
            cell('day ${c.ovulationDay}'),
          ],
        ),
    ],
  );
}

pw.Widget _counts(List<CountItem> items, String empty, _Styles s) {
  if (items.isEmpty) return s.body(empty, color: _ink2);
  final max = items.first.count;
  return pw.Column(
    children: [
      for (final i in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 120, child: s.body(i.label, size: 9.5)),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: math.max(1, (i.count * 100 / max).round()),
                      child: pw.Container(height: 1.5, color: _ink),
                    ),
                    pw.Expanded(flex: math.max(0, 100 - (i.count * 100 / max).round()) + 1, child: pw.SizedBox()),
                  ],
                ),
              ),
              pw.SizedBox(
                width: 54,
                child: s.data('${i.count} day${i.count == 1 ? '' : 's'}', color: _ink2, size: 8.5, align: pw.TextAlign.right),
              ),
            ],
          ),
        ),
    ],
  );
}

/// One bar per cycle on a shared day scale: period, estimated fertile
/// window, and estimated ovulation, with week ticks underneath.
pw.Widget _cycleBars(ReportData d, _Styles s) {
  const scale = 45; // Days shown across the full width.
  const label = 64.0;
  const trail = 46.0;
  PdfColor? dayColor(ReportCycle c, int day) {
    if (day <= c.periodLength) return _period;
    if (day == c.ovulationDay) return _ovulation;
    if (day >= c.ovulationDay - 5 && day <= c.ovulationDay + 1) return _fertile;
    return null;
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final c in d.cycles.reversed)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: label,
                child: s.data(fmtShort(c.start), color: _ink2, size: 8),
              ),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    for (var day = 1; day <= math.min(scale, c.length ?? c.currentDay ?? 1); day++)
                      pw.Expanded(
                        child: dayColor(c, day) == null
                            // Other days: a hairline track.
                            ? pw.Container(height: 6, alignment: pw.Alignment.center, child: pw.Container(height: 0.5, color: _track))
                            : pw.Container(height: 6, color: dayColor(c, day)),
                      ),
                    for (var day = math.min(scale, c.length ?? c.currentDay ?? 1); day < scale; day++)
                      pw.Expanded(child: pw.SizedBox(height: 6)),
                  ],
                ),
              ),
              pw.SizedBox(
                width: trail,
                child: s.data(
                  c.length != null ? '${c.length} days' : 'day ${c.currentDay}',
                  color: c.length == null ? _ink : _ink2,
                  size: 8,
                  align: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      // Week ticks.
      pw.Row(
        children: [
          pw.SizedBox(width: label),
          pw.Expanded(
            child: pw.Row(
              children: [
                for (var day = 1; day <= scale; day++)
                  pw.Expanded(
                    child: day % 7 == 1 && day > 1
                        ? s.data('${day - 1}', color: _ink2, size: 6)
                        : pw.SizedBox(),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: trail),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          pw.SizedBox(width: label),
          _legend(s, _period, 'Period'),
          _legend(s, _fertile, 'Fertile window (est.)'),
          _legend(s, _ovulation, 'Ovulation (est.)'),
          _legend(s, null, 'Other days'),
        ],
      ),
    ],
  );
}

pw.Widget _legend(_Styles s, PdfColor? c, String label) => pw.Padding(
  padding: const pw.EdgeInsets.only(right: 14, top: 2),
  child: pw.Row(
    children: [
      c == null
          ? pw.Container(width: 12, height: 6, alignment: pw.Alignment.center, child: pw.Container(height: 0.5, color: _track))
          : pw.Container(width: 12, height: 6, color: c),
      pw.SizedBox(width: 4),
      s.label(label, size: 6.5),
    ],
  ),
);

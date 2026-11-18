/// Bloom's design system, "Almanac": ink on warm paper, an editorial serif,
/// hairlines instead of cards, and color only where it carries meaning.
///
/// Read `docs/DESIGN.md` for how to use these tokens. In short:
///
/// * Semantic colors live in [BloomColors]. The static constants are the
///   light ("paper") values. For colors that follow the theme brightness, use
///   `BloomColors.of(context)` (a [BloomPalette]) or
///   `BloomColors.resolve(context, color)`.
/// * Text comes from the theme's text theme plus the [Almanac] helpers:
///   `Almanac.label` (mono marginalia), `Almanac.numeral` (serif figures),
///   and `Almanac.italic` (serif italic accents).
/// * Spacing comes from [Space], [Gap], and [Insets]; corner radii from
///   [Radii]; motion from [Motion].
/// * [BloomShadows] and [BloomGradients] still exist so older code compiles,
///   but they're flat: no shadows and no gradients in Almanac.
library;

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';

import '../core/engine.dart';

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

/// Semantic colors used across the app (calendar, dial, charts).
///
/// The static constants are the light ("paper") palette, so they work in
/// `const` expressions. In dark mode ("lamplight"), get the matching color
/// with `BloomColors.of(context).period` or
/// `BloomColors.resolve(context, BloomColors.period)`. The shared widgets in
/// `lib/widgets` resolve any color you pass them, so `PillChip(color:
/// BloomColors.period)` is correct in both modes.
abstract final class BloomColors {
  // Paper and ink -----------------------------------------------------------

  /// Page background: warm paper.
  static const paper = Color(0xFFF6F1E7);

  /// Raised surface: a slightly lighter sheet (inputs, sheets, menus).
  static const raised = Color(0xFFFBF8F2);

  /// Hairline rules and outlines.
  static const hairline = Color(0xFFE2D9C8);

  /// Primary text and the "ink" accent (buttons, selected states).
  static const ink = Color(0xFF2A2420);

  /// Secondary text, captions, and thin icons.
  static const ink2 = Color(0xFF6E645A);

  // Cycle ------------------------------------------------------------------

  /// Logged period days: oxblood.
  static const period = Color(0xFFA23B2A);

  /// A soft wash of [period], for backgrounds behind period content.
  static const periodSoft = Color(0xFFE7D0C5);

  /// Predicted (not yet logged) period days. Draw predictions dotted too.
  static const predicted = Color(0xFFC48476);

  /// Fertile window: sage.
  static const fertile = Color(0xFF4F6B5A);

  /// A soft wash of [fertile].
  static const fertileSoft = Color(0xFFD8DCCF);

  /// Ovulation day: a deeper sage than [fertile].
  static const ovulation = Color(0xFF3C5446);

  /// Luteal phase: dusty plum.
  static const luteal = Color(0xFF7A5C7E);

  /// A soft wash of [luteal].
  static const lutealSoft = Color(0xFFE2D7DA);

  /// Follicular phase: ochre. It's light; for text, use [readableTint].
  static const follicular = Color(0xFFC7A15A);

  /// Pregnancy mode: a warm amber ink.
  static const pregnancy = Color(0xFF946426);

  /// A soft wash of [pregnancy].
  static const pregnancySoft = Color(0xFFE6DAC5);

  // Brand and status -------------------------------------------------------

  /// Brand accent: oxblood, the same as [period].
  static const brand = Color(0xFFA23B2A);

  /// A deeper oxblood, for emphasis.
  static const brandDeep = Color(0xFF7C2B1E);

  /// Terracotta, a warm secondary accent.
  static const coral = Color(0xFFC0654A);

  /// Positive state (on track, saved).
  static const success = Color(0xFF3E6B4E);

  /// Caution state (late, check in).
  static const warning = Color(0xFFA87A22);

  /// Info state: slate ink.
  static const info = Color(0xFF4D6475);

  /// Errors and destructive actions.
  static const error = Color(0xFF9E2B25);

  /// The brightness-aware palette for the current theme.
  static BloomPalette of(BuildContext context) =>
      Theme.of(context).extension<BloomPalette>() ?? BloomPalette.light;

  /// Returns the dark-mode ("lamplight") equivalent of a light [color]
  /// constant when [brightness] is dark. Unknown colors pass through.
  static Color adapt(Color color, Brightness brightness) {
    if (brightness == Brightness.light) return color;
    return _darkOf[color.toARGB32()] ?? color;
  }

  /// [adapt] for the theme brightness of [context].
  static Color resolve(BuildContext context, Color color) => adapt(color, Theme.of(context).brightness);

  /// Paper or ink, whichever has more contrast on [background].
  static Color onColor(Color background) {
    final l = background.computeLuminance();
    final onInk = (l + 0.05) / (ink.computeLuminance() + 0.05);
    final onPaper = (raised.computeLuminance() + 0.05) / (l + 0.05);
    return onInk > onPaper ? ink : raised;
  }

  static final Map<int, Color> _darkOf = {
    for (final (l, d) in [
      (paper, BloomPalette.dark.paper),
      (raised, BloomPalette.dark.raised),
      (hairline, BloomPalette.dark.hairline),
      (ink, BloomPalette.dark.ink),
      (ink2, BloomPalette.dark.ink2),
      (period, BloomPalette.dark.period),
      (periodSoft, BloomPalette.dark.periodSoft),
      (predicted, BloomPalette.dark.predicted),
      (fertile, BloomPalette.dark.fertile),
      (fertileSoft, BloomPalette.dark.fertileSoft),
      (ovulation, BloomPalette.dark.ovulation),
      (luteal, BloomPalette.dark.luteal),
      (lutealSoft, BloomPalette.dark.lutealSoft),
      (follicular, BloomPalette.dark.follicular),
      (pregnancy, BloomPalette.dark.pregnancy),
      (pregnancySoft, BloomPalette.dark.pregnancySoft),
      (brandDeep, BloomPalette.dark.brandDeep),
      (coral, BloomPalette.dark.coral),
      (success, BloomPalette.dark.success),
      (warning, BloomPalette.dark.warning),
      (info, BloomPalette.dark.info),
      (error, BloomPalette.dark.error),
    ])
      l.toARGB32(): d,
  };
}

/// The full Almanac palette for one brightness. Read it with
/// `BloomColors.of(context)`.
@immutable
class BloomPalette extends ThemeExtension<BloomPalette> {
  const BloomPalette({
    required this.paper,
    required this.raised,
    required this.hairline,
    required this.ink,
    required this.ink2,
    required this.period,
    required this.periodSoft,
    required this.predicted,
    required this.fertile,
    required this.fertileSoft,
    required this.ovulation,
    required this.luteal,
    required this.lutealSoft,
    required this.follicular,
    required this.pregnancy,
    required this.pregnancySoft,
    required this.brand,
    required this.brandDeep,
    required this.coral,
    required this.success,
    required this.warning,
    required this.info,
    required this.error,
  });

  /// Light mode ("paper"): warm paper and brown-black ink.
  static const light = BloomPalette(
    paper: BloomColors.paper,
    raised: BloomColors.raised,
    hairline: BloomColors.hairline,
    ink: BloomColors.ink,
    ink2: BloomColors.ink2,
    period: BloomColors.period,
    periodSoft: BloomColors.periodSoft,
    predicted: BloomColors.predicted,
    fertile: BloomColors.fertile,
    fertileSoft: BloomColors.fertileSoft,
    ovulation: BloomColors.ovulation,
    luteal: BloomColors.luteal,
    lutealSoft: BloomColors.lutealSoft,
    follicular: BloomColors.follicular,
    pregnancy: BloomColors.pregnancy,
    pregnancySoft: BloomColors.pregnancySoft,
    brand: BloomColors.brand,
    brandDeep: BloomColors.brandDeep,
    coral: BloomColors.coral,
    success: BloomColors.success,
    warning: BloomColors.warning,
    info: BloomColors.info,
    error: BloomColors.error,
  );

  /// Dark mode ("lamplight"): lamplight on dark walnut.
  static const dark = BloomPalette(
    paper: Color(0xFF1A1714),
    raised: Color(0xFF23201C),
    hairline: Color(0xFF3A342D),
    ink: Color(0xFFEFE7DA),
    ink2: Color(0xFFA79C8D),
    period: Color(0xFFE07A63),
    periodSoft: Color(0xFF3E2922),
    predicted: Color(0xFFA55C4B),
    fertile: Color(0xFF8DB09A),
    fertileSoft: Color(0xFF2F332C),
    ovulation: Color(0xFFA9CBB5),
    luteal: Color(0xFFB79BBB),
    lutealSoft: Color(0xFF362F32),
    follicular: Color(0xFFE0BE7A),
    pregnancy: Color(0xFFE0B074),
    pregnancySoft: Color(0xFF3C3224),
    brand: Color(0xFFE07A63),
    brandDeep: Color(0xFFF09A85),
    coral: Color(0xFFE8957E),
    success: Color(0xFF8DB09A),
    warning: Color(0xFFE0BE7A),
    info: Color(0xFF9DB3C4),
    error: Color(0xFFF08A7A),
  );

  /// Page background.
  final Color paper;

  /// Raised surfaces: sheets, menus, inputs.
  final Color raised;

  /// Rules and outlines.
  final Color hairline;

  /// Primary text and ink fills.
  final Color ink;

  /// Secondary text, captions, thin icons.
  final Color ink2;

  final Color period;
  final Color periodSoft;
  final Color predicted;
  final Color fertile;
  final Color fertileSoft;
  final Color ovulation;
  final Color luteal;
  final Color lutealSoft;
  final Color follicular;
  final Color pregnancy;
  final Color pregnancySoft;
  final Color brand;
  final Color brandDeep;
  final Color coral;
  final Color success;
  final Color warning;
  final Color info;
  final Color error;

  /// The color for [phase].
  Color phase(Phase phase) => switch (phase) {
        Phase.menstrual => period,
        Phase.follicular => follicular,
        Phase.ovulation => ovulation,
        Phase.luteal => luteal,
      };

  @override
  BloomPalette copyWith({Color? paper, Color? ink}) => BloomPalette(
        paper: paper ?? this.paper,
        raised: raised,
        hairline: hairline,
        ink: ink ?? this.ink,
        ink2: ink2,
        period: period,
        periodSoft: periodSoft,
        predicted: predicted,
        fertile: fertile,
        fertileSoft: fertileSoft,
        ovulation: ovulation,
        luteal: luteal,
        lutealSoft: lutealSoft,
        follicular: follicular,
        pregnancy: pregnancy,
        pregnancySoft: pregnancySoft,
        brand: brand,
        brandDeep: brandDeep,
        coral: coral,
        success: success,
        warning: warning,
        info: info,
        error: error,
      );

  @override
  BloomPalette lerp(BloomPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BloomPalette(
      paper: l(paper, other.paper),
      raised: l(raised, other.raised),
      hairline: l(hairline, other.hairline),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      period: l(period, other.period),
      periodSoft: l(periodSoft, other.periodSoft),
      predicted: l(predicted, other.predicted),
      fertile: l(fertile, other.fertile),
      fertileSoft: l(fertileSoft, other.fertileSoft),
      ovulation: l(ovulation, other.ovulation),
      luteal: l(luteal, other.luteal),
      lutealSoft: l(lutealSoft, other.lutealSoft),
      follicular: l(follicular, other.follicular),
      pregnancy: l(pregnancy, other.pregnancy),
      pregnancySoft: l(pregnancySoft, other.pregnancySoft),
      brand: l(brand, other.brand),
      brandDeep: l(brandDeep, other.brandDeep),
      coral: l(coral, other.coral),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      info: l(info, other.info),
      error: l(error, other.error),
    );
  }
}

/// The light-mode color for [phase]. In widgets, prefer
/// `BloomColors.of(context).phase(phase)`, which follows dark mode.
Color phaseColor(Phase phase) => switch (phase) {
      Phase.menstrual => BloomColors.period,
      Phase.follicular => BloomColors.follicular,
      Phase.ovulation => BloomColors.ovulation,
      Phase.luteal => BloomColors.luteal,
    };

/// A flat "inked" fill for [phase] (Almanac has no gradients). Kept for
/// `BloomCard.gradient`; see [BloomGradients].
LinearGradient phaseGradient(Phase phase) => switch (phase) {
      Phase.menstrual => BloomGradients.period,
      Phase.follicular => BloomGradients.follicular,
      Phase.ovulation => BloomGradients.fertile,
      Phase.luteal => BloomGradients.luteal,
    };

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

/// Spacing scale on a 4-pt grid (8-pt rhythm). Use these for every margin
/// and padding.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Page side margin: the editorial column's left edge.
  static const double gutter = 24;

  /// Maximum width of page content on wide screens.
  static const double maxContentWidth = 640;

  /// Bottom padding that keeps scrolled content clear of the navigation bar.
  static const double navClearance = 24;

  /// Width of the left label column in [Marginalia] rows.
  static const double margin = 64;
}

/// Fixed-size spacers built from [Space]. `Gap.v16` is a 16-px vertical gap.
abstract final class Gap {
  static const v4 = SizedBox(height: Space.xs);
  static const v8 = SizedBox(height: Space.sm);
  static const v12 = SizedBox(height: Space.md);
  static const v16 = SizedBox(height: Space.lg);
  static const v20 = SizedBox(height: Space.xl);
  static const v24 = SizedBox(height: Space.xxl);
  static const v32 = SizedBox(height: Space.xxxl);
  static const v48 = SizedBox(height: Space.huge);
  static const h4 = SizedBox(width: Space.xs);
  static const h8 = SizedBox(width: Space.sm);
  static const h12 = SizedBox(width: Space.md);
  static const h16 = SizedBox(width: Space.lg);
  static const h24 = SizedBox(width: Space.xxl);
}

/// Standard paddings.
abstract final class Insets {
  /// Page content padding (side margins, small top).
  static const page = EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl);

  /// Side margins only.
  static const pageH = EdgeInsets.symmetric(horizontal: Space.gutter);

  /// Default card padding.
  static const card = EdgeInsets.all(Space.xl);

  /// Compact card padding, for dense tiles and grids.
  static const cardCompact = EdgeInsets.all(Space.lg);

  /// Bottom sheet content padding.
  static const sheet = EdgeInsets.fromLTRB(Space.xxl, Space.sm, Space.xxl, Space.xxl);

  static const all4 = EdgeInsets.all(Space.xs);
  static const all8 = EdgeInsets.all(Space.sm);
  static const all12 = EdgeInsets.all(Space.md);
  static const all16 = EdgeInsets.all(Space.lg);
  static const all24 = EdgeInsets.all(Space.xxl);
}

/// Corner radii. Almanac corners are small and consistent: 6 to 8 px where a
/// container exists at all. [pill] is for dots and thin progress tracks only.
abstract final class Radii {
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double pill = 999;

  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Animation durations and curves. Almanac motion is slow and quiet.
///
/// Named `Motion` because Material already exports a `Durations` class.
abstract final class Motion {
  /// Press feedback and small state changes.
  static const fast = Duration(milliseconds: 150);

  /// Selection changes, cross-fades, and expanding content.
  static const medium = Duration(milliseconds: 300);

  /// Hero elements entering.
  static const slow = Duration(milliseconds: 600);

  /// The dial's arcs drawing in like ink.
  static const ink = Duration(milliseconds: 1400);

  /// Default curve for most motion.
  static const curve = Curves.easeOutCubic;

  /// Curve for elements entering the screen.
  static const emphasized = Curves.easeOutQuart;

  /// Kept for older code. Almanac doesn't overshoot, so it's a soft ease-out.
  static const spring = Curves.easeOutCubic;
}

/// Kept so older code compiles. Almanac has no shadows: every method returns
/// an empty list. Separate surfaces with [Hairline]s instead.
abstract final class BloomShadows {
  static List<BoxShadow> card(Brightness b) => const [];
  static List<BoxShadow> raised(Brightness b) => const [];
  static List<BoxShadow> glow(Color color) => const [];
}

/// Flat fills for inked emphasis blocks (`BloomCard.gradient`). Almanac has
/// no gradients, so each "gradient" is a single color: deep enough for paper
/// text on top in both modes.
abstract final class BloomGradients {
  static LinearGradient _flat(Color c) => LinearGradient(colors: [c, c]);

  /// Ink. `BloomCard.gradient` draws it as a dark ink block (light mode) or a
  /// raised walnut block (dark mode).
  static const brand = LinearGradient(colors: [BloomColors.ink, BloomColors.ink]);

  /// Oxblood.
  static const period = LinearGradient(colors: [BloomColors.period, BloomColors.period]);

  /// Deep ochre (readable with paper text).
  static const follicular = LinearGradient(colors: [Color(0xFF8C6A2C), Color(0xFF8C6A2C)]);

  /// Sage.
  static const fertile = LinearGradient(colors: [BloomColors.fertile, BloomColors.fertile]);

  /// Dusty plum.
  static const luteal = LinearGradient(colors: [BloomColors.luteal, BloomColors.luteal]);

  /// Amber ink.
  static const pregnancy = LinearGradient(colors: [BloomColors.pregnancy, BloomColors.pregnancy]);

  /// Neutral emphasis: plum.
  static const dusk = LinearGradient(colors: [BloomColors.luteal, BloomColors.luteal]);

  /// A flat fill of [color].
  static LinearGradient of(Color color) => _flat(color);

  /// A barely-there flat wash of [color].
  static LinearGradient wash(Color color, Brightness b) =>
      _flat(BloomColors.adapt(color, b).withValues(alpha: b == Brightness.dark ? 0.10 : 0.06));
}

/// Font families bundled under `assets/fonts` (works offline).
abstract final class BloomFonts {
  /// Display serif (variable: `wght` 300 to 600, `opsz` 9 to 144, `SOFT`
  /// fixed at 50). Use the [Almanac] helpers rather than this name.
  static const serif = 'Fraunces';

  /// Body and UI face.
  static const sans = 'Hanken Grotesk';

  /// Monospace for marginalia labels, dates, and times.
  static const mono = 'IBM Plex Mono';

  /// Bundled subset of Noto Color Emoji (OFL). Listed as a fallback on every
  /// text style so emoji render offline.
  static const emoji = 'BloomEmoji';

  /// Kept for older code: the display face.
  static const display = serif;

  /// Kept for older code: the body face.
  static const body = sans;

  static const fallback = [emoji];
}

/// Brightness-dependent design tokens, read with `BloomTokens.of(context)`.
@immutable
class BloomTokens extends ThemeExtension<BloomTokens> {
  const BloomTokens({
    required this.cardShadow,
    required this.raisedShadow,
    required this.border,
    required this.muted,
    required this.subtle,
    required this.heroWash,
  });

  /// Always empty in Almanac; kept for older code.
  final List<BoxShadow> cardShadow;

  /// Always empty in Almanac; kept for older code.
  final List<BoxShadow> raisedShadow;

  /// Hairline color for rules and outlines.
  final Color border;

  /// Secondary text and thin icon color (ink2).
  final Color muted;

  /// Subtle fill for inset areas (tracks, wells). A shade off the paper.
  final Color subtle;

  /// A flat, nearly transparent wash. Kept for older code.
  final LinearGradient heroWash;

  static BloomTokens of(BuildContext context) => Theme.of(context).extension<BloomTokens>()!;

  @override
  BloomTokens copyWith({
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? raisedShadow,
    Color? border,
    Color? muted,
    Color? subtle,
    LinearGradient? heroWash,
  }) =>
      BloomTokens(
        cardShadow: cardShadow ?? this.cardShadow,
        raisedShadow: raisedShadow ?? this.raisedShadow,
        border: border ?? this.border,
        muted: muted ?? this.muted,
        subtle: subtle ?? this.subtle,
        heroWash: heroWash ?? this.heroWash,
      );

  @override
  BloomTokens lerp(BloomTokens? other, double t) {
    if (other == null) return this;
    return BloomTokens(
      cardShadow: const [],
      raisedShadow: const [],
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      heroWash: LinearGradient.lerp(heroWash, other.heroWash, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

/// Almanac text styles beyond the Material text theme.
///
/// ```dart
/// Text('Cycle 07 · Wed 18 Nov'.toUpperCase(), style: Almanac.label(context));
/// Text('14', style: Almanac.numeral(context, size: 64));
/// Text('ovulation likely.', style: Almanac.italic(context, size: 22));
/// ```
abstract final class Almanac {
  /// Fraunces at [size] with the given weight. Sets the `wght` and `opsz`
  /// axes; `opsz` follows the size unless you pass one.
  static TextStyle serif({
    required double size,
    double weight = 350,
    bool italic = false,
    double? opsz,
    Color? color,
    double height = 1.15,
    double? letterSpacing,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: BloomFonts.serif,
        fontFamilyFallback: BloomFonts.fallback,
        fontSize: size,
        fontWeight: FontWeight(weight.round()),
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontVariations: [
          FontVariation('wght', weight.clamp(300, 600)),
          FontVariation('opsz', (opsz ?? size * 4).clamp(9, 144)),
        ],
        fontFeatures: tabular
            ? const [FontFeature.liningFigures(), FontFeature.tabularFigures()]
            : const [FontFeature.liningFigures()],
        letterSpacing: letterSpacing ?? (size >= 28 ? -size * 0.012 : 0),
        height: height,
        color: color,
      );

  /// Hanken Grotesk at [size].
  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: BloomFonts.sans,
        fontFamilyFallback: BloomFonts.fallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// IBM Plex Mono at [size], not uppercased. For dates, times, and data.
  static TextStyle mono({required double size, FontWeight weight = FontWeight.w400, Color? color, double letterSpacing = 0}) =>
      TextStyle(
        fontFamily: BloomFonts.mono,
        fontFamilyFallback: BloomFonts.fallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.35,
        letterSpacing: letterSpacing,
      );

  /// Marginalia: small tracked mono in ink2. Uppercase the string yourself
  /// (or use the `MonoLabel` widget, which does it for you).
  static TextStyle label(BuildContext context, {Color? color, double size = 10.5}) =>
      mono(size: size, color: color ?? BloomColors.of(context).ink2, letterSpacing: size * 0.09, weight: FontWeight.w500);

  /// A serif numeral: light Fraunces with tabular lining figures. The hero
  /// numeral on a screen is about 64; inline figures 20 to 28.
  static TextStyle numeral(BuildContext context, {double size = 64, Color? color, double weight = 300}) =>
      serif(size: size, weight: weight, color: color ?? BloomColors.of(context).ink, height: 1.0, tabular: true);

  /// Serif italic for phase names and accents ("*Follicular*").
  static TextStyle italic(BuildContext context, {double size = 17, Color? color, double weight = 300}) =>
      serif(size: size, weight: weight, italic: true, color: color ?? BloomColors.of(context).ink, height: 1.25);

  /// Alias of [italic], matching the design brief's name.
  static TextStyle italicAccent(BuildContext context, {double size = 17, Color? color}) =>
      italic(context, size: size, color: color);

  /// Small mono data text (dates, times, values) in ink2.
  static TextStyle data(BuildContext context, {Color? color, double size = 12.5}) =>
      mono(size: size, color: color ?? BloomColors.of(context).ink2);

  /// Spells out 0 to 99 in words ("fourteen"), for editorial headlines such
  /// as "Day fourteen". Larger numbers come back as digits.
  static String spell(int n) {
    const ones = [
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', //
      'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
    ];
    const tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
    if (n < 0 || n > 99) return '$n';
    if (n < 20) return ones[n];
    return n % 10 == 0 ? tens[n ~/ 10] : '${tens[n ~/ 10]}-${ones[n % 10]}';
  }

  /// A light selection haptic for toggles, day picks, and saves. Does nothing
  /// on the web.
  static void tick() => HapticFeedback.selectionClick();
}

/// Weight changes for Almanac text styles.
///
/// Fraunces is a variable font whose weight is set through its `wght` axis.
/// `copyWith(fontWeight: ...)` alone doesn't move that axis (Android then
/// fakes a bold, the web ignores it), so use [weight] instead:
///
/// ```dart
/// theme.textTheme.headlineSmall!.weight(450)
/// ```
extension AlmanacTextStyle on TextStyle {
  /// This style at weight [w] (300 to 600 for Fraunces, 400 to 700 for the
  /// sans). Keeps the other axes, such as `opsz`.
  TextStyle weight(double w) {
    final axes = [
      for (final v in fontVariations ?? const <FontVariation>[])
        if (v.axis != 'wght') v,
    ];
    final serif = fontFamily == BloomFonts.serif;
    return copyWith(
      fontWeight: FontWeight(w.round().clamp(1, 1000)),
      fontVariations: serif ? [FontVariation('wght', w.clamp(300, 600)), ...axes] : fontVariations,
    );
  }
}

TextTheme _textTheme(BloomPalette p) {
  TextStyle serif(double size, double w, {double height = 1.15, double? opsz}) =>
      Almanac.serif(size: size, weight: w, height: height, opsz: opsz, color: p.ink);
  TextStyle sans(double size, FontWeight w, {double height = 1.5, Color? color, double spacing = 0}) =>
      Almanac.sans(size: size, weight: w, height: height, color: color ?? p.ink, letterSpacing: spacing);
  return TextTheme(
    displayLarge: serif(64, 300, height: 1.0),
    displayMedium: serif(52, 300, height: 1.02),
    displaySmall: serif(40, 320, height: 1.05),
    headlineLarge: serif(34, 350, height: 1.08),
    headlineMedium: serif(28, 350, height: 1.12),
    headlineSmall: serif(23, 380, height: 1.18),
    titleLarge: serif(20, 400, height: 1.25, opsz: 72),
    titleMedium: sans(16, FontWeight.w600, height: 1.35),
    titleSmall: sans(14, FontWeight.w600, height: 1.35),
    bodyLarge: sans(16, FontWeight.w400, height: 1.55),
    bodyMedium: sans(14.5, FontWeight.w400, height: 1.55),
    bodySmall: sans(12.5, FontWeight.w400, height: 1.45, color: p.ink2),
    labelLarge: sans(14.5, FontWeight.w600, height: 1.25, spacing: 0.1),
    labelMedium: sans(12.5, FontWeight.w500, height: 1.25, spacing: 0.2),
    labelSmall: sans(11, FontWeight.w600, height: 1.2, spacing: 0.5),
  );
}

// ---------------------------------------------------------------------------
// Page transitions and scrolling
// ---------------------------------------------------------------------------

/// A short fade with a small horizontal slide: the new page settles in from
/// the right while the old one drifts a little to the left.
class AlmanacPageTransitionsBuilder extends PageTransitionsBuilder {
  const AlmanacPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final under = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.025, 0)).animate(under),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

/// Bouncing scroll physics everywhere and no Android glow or stretch.
class AlmanacScrollBehavior extends MaterialScrollBehavior {
  const AlmanacScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

ColorScheme _scheme(Brightness b, BloomPalette p) {
  final light = b == Brightness.light;
  return ColorScheme(
    brightness: b,
    primary: p.ink,
    onPrimary: p.paper,
    primaryContainer: light ? const Color(0xFFECE4D5) : const Color(0xFF2E2924),
    onPrimaryContainer: p.ink,
    primaryFixed: light ? const Color(0xFFECE4D5) : const Color(0xFF2E2924),
    secondary: p.period,
    onSecondary: light ? p.raised : p.paper,
    secondaryContainer: p.periodSoft,
    onSecondaryContainer: light ? p.brandDeep : p.ink,
    tertiary: p.fertile,
    onTertiary: light ? p.raised : p.paper,
    tertiaryContainer: p.fertileSoft,
    onTertiaryContainer: light ? p.ovulation : p.ink,
    error: p.error,
    onError: light ? p.raised : p.paper,
    errorContainer: light ? const Color(0xFFF0D5CF) : const Color(0xFF45231F),
    onErrorContainer: light ? const Color(0xFF5E1712) : const Color(0xFFF7D2CB),
    surface: p.paper,
    onSurface: p.ink,
    onSurfaceVariant: p.ink2,
    surfaceDim: light ? const Color(0xFFEDE6D8) : const Color(0xFF151210),
    surfaceBright: p.raised,
    surfaceContainerLowest: p.raised,
    surfaceContainerLow: light ? const Color(0xFFF3EDE2) : const Color(0xFF1F1B18),
    surfaceContainer: light ? const Color(0xFFF0E9DC) : p.raised,
    surfaceContainerHigh: light ? const Color(0xFFECE4D5) : const Color(0xFF2A2621),
    surfaceContainerHighest: light ? const Color(0xFFE7DECD) : const Color(0xFF322D27),
    outline: light ? const Color(0xFFB3A693) : const Color(0xFF6B6157),
    outlineVariant: p.hairline,
    shadow: const Color(0x00000000),
    scrim: const Color(0xFF000000),
    inverseSurface: p.ink,
    onInverseSurface: p.paper,
    inversePrimary: p.paper,
    surfaceTint: const Color(0x00000000),
  );
}

/// Builds Bloom's complete theme for [brightness]: paper, ink, hairlines,
/// no ripples, no elevation, no tonal tints.
ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final p = light ? BloomPalette.light : BloomPalette.dark;
  final s = _scheme(brightness, p);
  final text = _textTheme(p);
  final subtle = light ? const Color(0xFFEFE8DB) : const Color(0xFF26221E);
  final tokens = BloomTokens(
    cardShadow: const [],
    raisedShadow: const [],
    border: p.hairline,
    muted: p.ink2,
    subtle: subtle,
    heroWash: LinearGradient(colors: [p.paper, p.paper]),
  );
  final hair = BorderSide(color: p.hairline);
  final inkSide = BorderSide(color: p.ink);
  const shape = RoundedRectangleBorder(borderRadius: Radii.mdAll);
  const buttonPadding = EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md);
  const buttonSize = Size(64, 48);
  final buttonText = Almanac.sans(size: 15, weight: FontWeight.w600, height: 1.2, letterSpacing: 0.1);
  final none = WidgetStateProperty.all<Color?>(Colors.transparent);

  // Press feedback without ripples: a faint ink (or paper, on ink) veil.
  WidgetStateProperty<Color?> veil(Color c) => WidgetStateProperty.resolveWith((st) {
        if (st.contains(WidgetState.pressed)) return c.withValues(alpha: 0.12);
        if (st.contains(WidgetState.hovered)) return c.withValues(alpha: 0.05);
        if (st.contains(WidgetState.focused)) return c.withValues(alpha: 0.10);
        return null;
      });

  const transitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: AlmanacPageTransitionsBuilder(),
    TargetPlatform.iOS: AlmanacPageTransitionsBuilder(),
    TargetPlatform.macOS: AlmanacPageTransitionsBuilder(),
    TargetPlatform.windows: AlmanacPageTransitionsBuilder(),
    TargetPlatform.linux: AlmanacPageTransitionsBuilder(),
    TargetPlatform.fuchsia: AlmanacPageTransitionsBuilder(),
  });

  UnderlineInputBorder line(Color c, [double w = 1]) =>
      UnderlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: w));

  final disabledFg = p.ink.withValues(alpha: 0.38);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: s,
    textTheme: text,
    primaryTextTheme: text,
    fontFamily: BloomFonts.sans,
    fontFamilyFallback: BloomFonts.fallback,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.paper,
    cardColor: p.raised,
    dividerColor: p.hairline,
    disabledColor: disabledFg,
    // No ink ripples, no highlights. Widgets give their own quiet feedback.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: p.ink.withValues(alpha: 0.03),
    focusColor: p.ink.withValues(alpha: 0.08),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: transitions,
    extensions: [tokens, p],
    iconTheme: IconThemeData(color: p.ink, size: 22),
    primaryIconTheme: IconThemeData(color: p.ink, size: 22),
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: p.ink,
      iconTheme: IconThemeData(color: p.ink, size: 22),
      titleSpacing: Space.gutter,
      titleTextStyle: text.titleLarge,
      toolbarHeight: 60,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: Radii.lgAll, side: hair),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.xs),
      minVerticalPadding: Space.md,
      horizontalTitleGap: Space.md,
      shape: const RoundedRectangleBorder(),
      iconColor: p.ink2,
      textColor: p.ink,
      selectedColor: p.ink,
      selectedTileColor: Colors.transparent,
      titleTextStyle: text.bodyLarge!.copyWith(fontWeight: FontWeight.w500),
      subtitleTextStyle: text.bodyMedium!.copyWith(color: p.ink2),
      leadingAndTrailingTextStyle: Almanac.mono(size: 12.5, color: p.ink2),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: Radii.smAll, side: hair),
      side: hair,
      backgroundColor: Colors.transparent,
      selectedColor: p.ink,
      disabledColor: Colors.transparent,
      checkmarkColor: p.paper,
      deleteIconColor: p.ink2,
      labelStyle: WidgetStateTextStyle.resolveWith(
        (st) => text.labelMedium!.copyWith(
          fontSize: 13.5,
          color: st.contains(WidgetState.selected) ? p.paper : p.ink,
        ),
      ),
      secondaryLabelStyle: text.labelMedium!.copyWith(fontSize: 13.5, color: p.paper),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs + 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: Space.xs),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
      iconTheme: IconThemeData(color: p.ink2, size: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(buttonText),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled) ? p.ink.withValues(alpha: 0.12) : p.ink,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled) ? disabledFg : p.paper,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled) ? disabledFg : p.paper,
        ),
        overlayColor: veil(p.paper),
        iconSize: const WidgetStatePropertyAll(18),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.mdAll, side: hair)),
        textStyle: WidgetStatePropertyAll(buttonText),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: none,
        surfaceTintColor: none,
        backgroundColor: WidgetStatePropertyAll(p.raised),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.disabled) ? disabledFg : p.ink),
        overlayColor: veil(p.ink),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(buttonText),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: none,
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.disabled) ? disabledFg : p.ink),
        iconColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.disabled) ? disabledFg : p.ink),
        side: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled) ? hair : inkSide,
        ),
        overlayColor: veil(p.ink),
        iconSize: const WidgetStatePropertyAll(18),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm)),
        shape: const WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(
          buttonText.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationThickness: 1,
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.disabled) ? disabledFg : p.ink),
        iconColor: WidgetStatePropertyAll(p.ink2),
        backgroundColor: none,
        overlayColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.pressed) ? p.ink.withValues(alpha: 0.06) : null,
        ),
        iconSize: const WidgetStatePropertyAll(18),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        foregroundColor: WidgetStateProperty.resolveWith((st) {
          if (st.contains(WidgetState.disabled)) return disabledFg;
          return st.contains(WidgetState.selected) ? p.ink : p.ink;
        }),
        overlayColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.pressed) || st.contains(WidgetState.focused)
              ? p.ink.withValues(alpha: 0.07)
              : null,
        ),
        shape: const WidgetStatePropertyAll(shape),
        iconSize: const WidgetStatePropertyAll(22),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.ink,
      foregroundColor: p.paper,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      splashColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      extendedTextStyle: buttonText,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 42)),
        textStyle: WidgetStatePropertyAll(text.labelLarge!.copyWith(fontWeight: FontWeight.w500, fontSize: 14)),
        side: WidgetStatePropertyAll(BorderSide(color: light ? const Color(0xFFCFC4B1) : const Color(0xFF4A433A))),
        backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((st) {
          if (st.contains(WidgetState.disabled)) return disabledFg;
          return st.contains(WidgetState.selected) ? p.paper : p.ink;
        }),
        iconColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.paper : p.ink2),
        overlayColor: veil(p.ink),
        shape: const WidgetStatePropertyAll(shape),
        elevation: const WidgetStatePropertyAll(0),
      ),
      selectedIcon: Icon(Icons.check, size: 16, color: p.paper),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      borderRadius: Radii.mdAll,
      color: p.ink,
      selectedColor: p.paper,
      fillColor: p.ink,
      borderColor: p.hairline,
      selectedBorderColor: p.ink,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: false,
      isDense: false,
      contentPadding: const EdgeInsets.fromLTRB(0, Space.md, 0, Space.md),
      border: line(p.hairline),
      enabledBorder: line(light ? const Color(0xFFCFC4B1) : const Color(0xFF4A433A)),
      focusedBorder: line(p.ink, 1.5),
      errorBorder: line(p.error),
      focusedErrorBorder: line(p.error, 1.5),
      disabledBorder: line(p.hairline),
      labelStyle: text.bodyLarge!.copyWith(color: p.ink2),
      floatingLabelStyle: Almanac.mono(size: 13, color: p.ink2, letterSpacing: 0.6),
      hintStyle: text.bodyLarge!.copyWith(color: p.ink2.withValues(alpha: 0.75)),
      helperStyle: text.bodySmall,
      errorStyle: text.bodySmall!.copyWith(color: p.error),
      prefixIconColor: p.ink2,
      suffixIconColor: p.ink2,
      iconColor: p.ink2,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.ink,
      selectionColor: p.period.withValues(alpha: 0.22),
      selectionHandleColor: p.period,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((st) {
        if (st.contains(WidgetState.disabled)) return p.ink2.withValues(alpha: 0.4);
        return st.contains(WidgetState.selected) ? p.paper : p.ink2;
      }),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? p.ink : Colors.transparent,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? p.ink : (light ? const Color(0xFFB3A693) : const Color(0xFF6B6157)),
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(1),
      thumbIcon: const WidgetStatePropertyAll(null),
      overlayColor: none,
      splashRadius: 0,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(borderRadius: Radii.xsAll),
      side: WidgetStateBorderSide.resolveWith(
        (st) => BorderSide(color: st.contains(WidgetState.selected) ? p.ink : p.ink2, width: 1.2),
      ),
      fillColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : Colors.transparent),
      checkColor: WidgetStatePropertyAll(p.paper),
      overlayColor: none,
      splashRadius: 0,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : p.ink2),
      overlayColor: none,
      splashRadius: 0,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 1.5,
      activeTrackColor: p.ink,
      inactiveTrackColor: light ? const Color(0xFFCFC4B1) : const Color(0xFF4A433A),
      disabledActiveTrackColor: p.ink2.withValues(alpha: 0.4),
      disabledInactiveTrackColor: p.hairline,
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      thumbColor: p.ink,
      overlayColor: Colors.transparent,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 0, pressedElevation: 0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      trackShape: const RectangularSliderTrackShape(),
      valueIndicatorColor: p.ink,
      valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
      valueIndicatorTextStyle: Almanac.mono(size: 12.5, color: p.paper),
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.ink,
      linearTrackColor: p.hairline,
      circularTrackColor: Colors.transparent,
      linearMinHeight: 2,
      borderRadius: BorderRadius.zero,
      strokeCap: StrokeCap.butt,
      refreshBackgroundColor: p.raised,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.paper,
      elevation: 0,
      modalElevation: 0,
      shadowColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: light ? const Color(0xFFCFC4B1) : const Color(0xFF4A433A),
      dragHandleSize: const Size(36, 3),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        side: hair,
      ),
      constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
      clipBehavior: Clip.antiAlias,
      modalBarrierColor: (light ? const Color(0xFF2A2420) : Colors.black).withValues(alpha: light ? 0.28 : 0.55),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: Radii.lgAll, side: hair),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyLarge!.copyWith(color: p.ink2),
      insetPadding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xxl),
      barrierColor: (light ? const Color(0xFF2A2420) : Colors.black).withValues(alpha: light ? 0.28 : 0.55),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: Radii.lgAll, side: hair),
      headerBackgroundColor: p.paper,
      headerForegroundColor: p.ink,
      headerHeadlineStyle: text.headlineMedium,
      headerHelpStyle: Almanac.mono(size: 11, color: p.ink2, letterSpacing: 1),
      weekdayStyle: Almanac.mono(size: 12, color: p.ink2),
      dayStyle: text.bodyMedium,
      dividerColor: p.hairline,
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
      dayForegroundColor: WidgetStateProperty.resolveWith((st) {
        if (st.contains(WidgetState.disabled)) return disabledFg;
        return st.contains(WidgetState.selected) ? p.paper : p.ink;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : null),
      dayOverlayColor: none,
      todayForegroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.paper : p.period),
      todayBackgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : null),
      todayBorder: BorderSide(color: p.period),
      yearForegroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.paper : p.ink),
      yearBackgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : null),
      yearOverlayColor: none,
      rangeSelectionBackgroundColor: p.periodSoft,
      cancelButtonStyle: ButtonStyle(foregroundColor: WidgetStatePropertyAll(p.ink2)),
      confirmButtonStyle: ButtonStyle(foregroundColor: WidgetStatePropertyAll(p.ink)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: p.paper,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: Radii.lgAll, side: hair),
      dialBackgroundColor: p.raised,
      dialHandColor: p.ink,
      dialTextColor: WidgetStateColor.resolveWith((st) => st.contains(WidgetState.selected) ? p.paper : p.ink),
      hourMinuteShape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      hourMinuteColor: WidgetStateColor.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : p.raised),
      hourMinuteTextColor: WidgetStateColor.resolveWith((st) => st.contains(WidgetState.selected) ? p.paper : p.ink),
      dayPeriodShape: RoundedRectangleBorder(borderRadius: Radii.mdAll, side: hair),
      dayPeriodColor: WidgetStateColor.resolveWith((st) => st.contains(WidgetState.selected) ? p.ink : Colors.transparent),
      dayPeriodTextColor: WidgetStateColor.resolveWith((st) => st.contains(WidgetState.selected) ? p.paper : p.ink),
      dayPeriodBorderSide: hair,
      entryModeIconColor: p.ink2,
      helpTextStyle: Almanac.mono(size: 11, color: p.ink2, letterSpacing: 1),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: p.paper),
      actionTextColor: light ? const Color(0xFFE0BE7A) : BloomColors.period,
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      width: null,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.ink, borderRadius: Radii.smAll),
      textStyle: Almanac.sans(size: 12.5, color: p.paper, height: 1.3),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: Space.xs + 2),
      waitDuration: const Duration(milliseconds: 400),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.raised,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: Radii.mdAll, side: hair),
      textStyle: text.bodyLarge,
      labelTextStyle: WidgetStatePropertyAll(text.bodyLarge),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.raised),
        surfaceTintColor: none,
        shadowColor: none,
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.mdAll, side: hair)),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: text.bodyLarge,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.raised),
        surfaceTintColor: none,
        shadowColor: none,
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.mdAll, side: hair)),
      ),
    ),
    // The shell no longer uses NavigationBar or NavigationRail; these keep
    // any stray use flat and quiet.
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => text.labelMedium!.copyWith(color: st.contains(WidgetState.selected) ? p.ink : p.ink2),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (st) => IconThemeData(size: 22, color: st.contains(WidgetState.selected) ? p.ink : p.ink2),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      selectedIconTheme: IconThemeData(color: p.ink, size: 22),
      unselectedIconTheme: IconThemeData(color: p.ink2, size: 22),
      selectedLabelTextStyle: text.labelLarge!.copyWith(color: p.ink),
      unselectedLabelTextStyle: text.labelLarge!.copyWith(color: p.ink2, fontWeight: FontWeight.w500),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.ink,
      unselectedLabelColor: p.ink2,
      labelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
      indicator: UnderlineTabIndicator(borderSide: BorderSide(color: p.ink, width: 1.5)),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: p.hairline,
      dividerHeight: 1,
      overlayColor: none,
      splashFactory: NoSplash.splashFactory,
      labelPadding: const EdgeInsets.symmetric(horizontal: Space.md),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: p.period,
      textColor: light ? p.raised : p.paper,
      textStyle: Almanac.mono(size: 10, weight: FontWeight.w500),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: p.ink,
      collapsedIconColor: p.ink2,
      textColor: p.ink,
      collapsedTextColor: p.ink,
      tilePadding: const EdgeInsets.symmetric(horizontal: Space.xs),
      childrenPadding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.md),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(p.raised),
      surfaceTintColor: none,
      shadowColor: none,
      overlayColor: none,
      side: WidgetStatePropertyAll(hair),
      shape: const WidgetStatePropertyAll(shape),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.md)),
      textStyle: WidgetStatePropertyAll(text.bodyLarge),
      hintStyle: WidgetStatePropertyAll(text.bodyLarge!.copyWith(color: p.ink2)),
      constraints: const BoxConstraints(minHeight: 46),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(p.ink2.withValues(alpha: 0.3)),
      radius: Radius.zero,
      thickness: const WidgetStatePropertyAll(3),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: p.paper,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    ),
  );
}

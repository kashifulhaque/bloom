/// Bloom's design system: colors, tokens, and the Material theme.
///
/// Read `bloom_docs/DESIGN.md` for how to use these tokens. In short:
///
/// * Semantic colors live in [BloomColors]; everything else comes from
///   `Theme.of(context).colorScheme`.
/// * Spacing comes from [Space] (numbers), [Gap] (fixed-size boxes), and
///   [Insets] (padding).
/// * Corner radii come from [Radii], motion from [Motion], shadows from
///   [BloomShadows], and gradients from [BloomGradients].
/// * Brightness-dependent tokens (card shadow, hairline border, muted text)
///   come from `BloomTokens.of(context)`.
library;

import 'package:material_ui/material_ui.dart';

import '../core/engine.dart';

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

/// Semantic colors used across the app (calendar, rings, charts).
///
/// These are the same in light and dark mode. For text on top of these colors,
/// use [onColor].
abstract final class BloomColors {
  /// Logged period days.
  static const period = Color(0xFFF0507A);

  /// Light period tint, for backgrounds behind period content.
  static const periodSoft = Color(0xFFFFD9E3);

  /// Predicted (not yet logged) period days.
  static const predicted = Color(0xFFF7A1B8);

  /// Fertile window.
  static const fertile = Color(0xFF2FB8A6);

  /// Light fertile tint.
  static const fertileSoft = Color(0xFFCDF1EB);

  /// Ovulation day: a deeper teal than [fertile].
  static const ovulation = Color(0xFF138F80);

  /// Luteal phase.
  static const luteal = Color(0xFF9B87F5);

  /// Light luteal tint.
  static const lutealSoft = Color(0xFFE6E0FD);

  /// Follicular phase: a soft peach that sits between period and fertile.
  static const follicular = Color(0xFFF59E7A);

  /// Pregnancy mode.
  static const pregnancy = Color(0xFFF4B740);

  /// Light pregnancy tint.
  static const pregnancySoft = Color(0xFFFDEDC8);

  /// Brand rose, for decoration (gradients, illustrations, the logo).
  static const brand = Color(0xFFE8457A);

  /// Deep brand rose, for gradient ends and emphasis.
  static const brandDeep = Color(0xFFB8235A);

  /// Brand coral, the warm end of the brand gradient.
  static const coral = Color(0xFFFF8A73);

  /// Positive state (on track, saved).
  static const success = Color(0xFF2E9E6B);

  /// Caution state (late, check in).
  static const warning = Color(0xFFE59A1F);

  /// Info state.
  static const info = Color(0xFF5B7FE8);

  /// Returns black or white, whichever reads better on [background].
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.45 ? const Color(0xFF2A1F2D) : Colors.white;
}

/// The color that represents [phase] in rings, chips, and charts.
Color phaseColor(Phase phase) => switch (phase) {
      Phase.menstrual => BloomColors.period,
      Phase.follicular => BloomColors.follicular,
      Phase.ovulation => BloomColors.ovulation,
      Phase.luteal => BloomColors.luteal,
    };

/// The hero gradient for [phase], for example behind the Today header.
LinearGradient phaseGradient(Phase phase) => switch (phase) {
      Phase.menstrual => BloomGradients.period,
      Phase.follicular => BloomGradients.follicular,
      Phase.ovulation => BloomGradients.fertile,
      Phase.luteal => BloomGradients.luteal,
    };

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

/// Spacing scale on a 4-pt grid. Use these for every margin and padding.
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

  /// Horizontal page gutter on phones.
  static const double gutter = 20;

  /// Maximum width of page content on wide screens.
  static const double maxContentWidth = 640;

  /// Bottom padding that keeps scrolled content clear of the navigation bar.
  static const double navClearance = 24;
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
  /// Page content padding (horizontal gutter, small top).
  static const page = EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl);

  /// Horizontal page gutter only.
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

/// Corner radii. Cards use [lg]; pills and buttons use [pill].
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Animation durations and curves.
///
/// Named `Motion` because Material already exports a `Durations` class.
abstract final class Motion {
  /// Hover, press, and small state changes.
  static const fast = Duration(milliseconds: 150);

  /// Selection changes, cross-fades, and expanding content.
  static const medium = Duration(milliseconds: 260);

  /// Hero elements and rings animating in.
  static const slow = Duration(milliseconds: 600);

  /// Default curve for most motion.
  static const curve = Curves.easeOutCubic;

  /// Curve for elements entering the screen.
  static const emphasized = Curves.easeOutQuart;

  /// Slight overshoot, for playful selection feedback.
  static const spring = Curves.easeOutBack;
}

/// Layered shadows. Light mode uses soft, warm shadows; dark mode uses none
/// (cards get a hairline border instead, see [BloomTokens.border]).
abstract final class BloomShadows {
  /// Resting card shadow.
  static List<BoxShadow> card(Brightness b) => b == Brightness.dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0F7A2E4A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x147A2E4A), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -4),
        ];

  /// Raised elements: floating buttons, active hero cards.
  static List<BoxShadow> raised(Brightness b) => b == Brightness.dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -6)]
      : const [
          BoxShadow(color: Color(0x147A2E4A), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x267A2E4A), blurRadius: 32, offset: Offset(0, 14), spreadRadius: -8),
        ];

  /// A colored glow under gradient buttons and hero elements.
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -6),
      ];
}

/// Gradients for hero elements. Use at most one or two per screen.
abstract final class BloomGradients {
  static const _begin = Alignment.topLeft;
  static const _end = Alignment.bottomRight;

  /// Brand rose to coral: primary hero and call-to-action.
  static const brand = LinearGradient(begin: _begin, end: _end, colors: [Color(0xFFE23D74), Color(0xFFFF8A73)]);

  /// Period: rose to soft pink.
  static const period = LinearGradient(begin: _begin, end: _end, colors: [Color(0xFFE8396E), Color(0xFFFF7E9D)]);

  /// Follicular: peach to coral.
  static const follicular = LinearGradient(begin: _begin, end: _end, colors: [Color(0xFFF07A62), Color(0xFFFBB38A)]);

  /// Fertile window and ovulation: deep teal to mint.
  static const fertile = LinearGradient(begin: _begin, end: _end, colors: [Color(0xFF0F8A7C), Color(0xFF3CC7B2)]);

  /// Luteal: violet to lavender.
  static const luteal = LinearGradient(begin: _begin, end: _end, colors: [Color(0xFF7A62E6), Color(0xFFAE9BFA)]);

  /// Pregnancy: amber to honey.
  static const pregnancy = LinearGradient(begin: _begin, end: _end, colors: [Color(0xFFE79A1C), Color(0xFFF8C866)]);

  /// Calm dusk, for neutral hero areas (insights, assistant).
  static const dusk = LinearGradient(begin: _begin, end: _end, colors: [Color(0xFF8E6BE8), Color(0xFFE8457A)]);

  /// A two-stop gradient from [color] to a lighter version of it.
  static LinearGradient of(Color color) => LinearGradient(
        begin: _begin,
        end: _end,
        colors: [color, Color.lerp(color, Colors.white, 0.3)!],
      );

  /// A barely-there wash of [color], for tinted hero backgrounds.
  static LinearGradient wash(Color color, Brightness b) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: b == Brightness.dark ? 0.22 : 0.16),
          color.withValues(alpha: b == Brightness.dark ? 0.06 : 0.04),
        ],
      );
}

/// Font families bundled under `assets/fonts` (works offline).
abstract final class BloomFonts {
  /// Display and heading face: geometric and friendly.
  static const display = 'Outfit';

  /// Body and UI face: rounded and highly legible.
  static const body = 'Nunito';

  /// Bundled subset of Noto Color Emoji (OFL). Listed as a fallback on every
  /// text style so emoji render offline and without a first-frame "tofu" box.
  static const emoji = 'BloomEmoji';

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

  /// Shadow for resting cards (empty in dark mode).
  final List<BoxShadow> cardShadow;

  /// Shadow for raised and floating elements.
  final List<BoxShadow> raisedShadow;

  /// Hairline border color for cards and dividers.
  final Color border;

  /// Muted text and icon color (captions, disclaimers).
  final Color muted;

  /// Subtle fill for inset areas (inputs, tracks, chip backgrounds).
  final Color subtle;

  /// Background gradient for the top of hero pages.
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
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? other.cardShadow,
      raisedShadow: BoxShadow.lerpList(raisedShadow, other.raisedShadow, t) ?? other.raisedShadow,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      heroWash: LinearGradient.lerp(heroWash, other.heroWash, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

ColorScheme _scheme(Brightness b) {
  final light = b == Brightness.light;
  final seed = ColorScheme.fromSeed(seedColor: BloomColors.brand, brightness: b);
  return light
      ? seed.copyWith(
          primary: const Color(0xFFD6336C),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFDCE6),
          onPrimaryContainer: const Color(0xFF5C0F2E),
          secondary: const Color(0xFF8A4F67),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFF9DCE6),
          onSecondaryContainer: const Color(0xFF4A1830),
          tertiary: const Color(0xFF6F58D9),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFE6E0FD),
          onTertiaryContainer: const Color(0xFF2A1A73),
          error: const Color(0xFFC62F3B),
          errorContainer: const Color(0xFFFFDAD9),
          onErrorContainer: const Color(0xFF5F0A12),
          surface: const Color(0xFFFFF8F9),
          onSurface: const Color(0xFF2A1F2D),
          onSurfaceVariant: const Color(0xFF6E5F70),
          surfaceDim: const Color(0xFFF3E4E8),
          surfaceBright: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFFFF1F4),
          surfaceContainer: const Color(0xFFFCEBEF),
          surfaceContainerHigh: const Color(0xFFF8E4E9),
          surfaceContainerHighest: const Color(0xFFF2DDE3),
          outline: const Color(0xFFB9A6B0),
          outlineVariant: const Color(0xFFEBD9DF),
          inverseSurface: const Color(0xFF342937),
          onInverseSurface: const Color(0xFFFBEEF2),
          inversePrimary: const Color(0xFFFF8FB1),
          shadow: const Color(0xFF7A2E4A),
          surfaceTint: Colors.transparent,
        )
      : seed.copyWith(
          primary: const Color(0xFFFF8FB1),
          onPrimary: const Color(0xFF4A0E26),
          primaryContainer: const Color(0xFF6E1E3E),
          onPrimaryContainer: const Color(0xFFFFD9E3),
          secondary: const Color(0xFFEDB8CB),
          onSecondary: const Color(0xFF4A1830),
          secondaryContainer: const Color(0xFF4F2A3B),
          onSecondaryContainer: const Color(0xFFFFD9E3),
          tertiary: const Color(0xFFC3B5FF),
          onTertiary: const Color(0xFF2A1A73),
          tertiaryContainer: const Color(0xFF433384),
          onTertiaryContainer: const Color(0xFFE6E0FD),
          error: const Color(0xFFFFB4AE),
          errorContainer: const Color(0xFF7C1A22),
          onErrorContainer: const Color(0xFFFFDAD7),
          surface: const Color(0xFF17111A),
          onSurface: const Color(0xFFF4ECF5),
          onSurfaceVariant: const Color(0xFFC0B2C3),
          surfaceDim: const Color(0xFF17111A),
          surfaceBright: const Color(0xFF3A2F3E),
          surfaceContainerLowest: const Color(0xFF120D15),
          surfaceContainerLow: const Color(0xFF1E1722),
          surfaceContainer: const Color(0xFF231B27),
          surfaceContainerHigh: const Color(0xFF2B2230),
          surfaceContainerHighest: const Color(0xFF352B3A),
          outline: const Color(0xFF7D6E80),
          outlineVariant: const Color(0xFF3A2F3F),
          inverseSurface: const Color(0xFFF4ECF5),
          onInverseSurface: const Color(0xFF2A1F2D),
          inversePrimary: const Color(0xFFD6336C),
          shadow: Colors.black,
          surfaceTint: Colors.transparent,
        );
}

TextTheme _textTheme(ColorScheme s) {
  TextStyle display(double size, FontWeight w, {double spacing = -0.4, double height = 1.15}) => TextStyle(
        fontFamily: BloomFonts.display,
        fontFamilyFallback: BloomFonts.fallback,
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing,
        height: height,
        color: s.onSurface,
      );
  TextStyle body(double size, FontWeight w, {double spacing = 0, double height = 1.45, Color? color}) => TextStyle(
        fontFamily: BloomFonts.body,
        fontFamilyFallback: BloomFonts.fallback,
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing,
        height: height,
        color: color ?? s.onSurface,
      );
  return TextTheme(
    displayLarge: display(52, FontWeight.w600, spacing: -1.2, height: 1.05),
    displayMedium: display(42, FontWeight.w600, spacing: -1, height: 1.08),
    displaySmall: display(34, FontWeight.w600, spacing: -0.8, height: 1.1),
    headlineLarge: display(30, FontWeight.w600, spacing: -0.6),
    headlineMedium: display(26, FontWeight.w600, spacing: -0.5),
    headlineSmall: display(22, FontWeight.w600, spacing: -0.3, height: 1.2),
    titleLarge: display(20, FontWeight.w600, spacing: -0.2, height: 1.25),
    titleMedium: body(16, FontWeight.w700, height: 1.35),
    titleSmall: body(14, FontWeight.w700, height: 1.35),
    bodyLarge: body(16, FontWeight.w400, height: 1.5),
    bodyMedium: body(14.5, FontWeight.w400, height: 1.45),
    bodySmall: body(12.5, FontWeight.w400, height: 1.4, color: s.onSurfaceVariant),
    labelLarge: body(14.5, FontWeight.w700, spacing: 0.1, height: 1.25),
    labelMedium: body(12.5, FontWeight.w700, spacing: 0.2, height: 1.25),
    labelSmall: body(11, FontWeight.w700, spacing: 0.4, height: 1.2),
  );
}

/// Builds Bloom's complete Material 3 theme for [brightness].
ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final s = _scheme(brightness);
  final text = _textTheme(s);
  final tokens = BloomTokens(
    cardShadow: BloomShadows.card(brightness),
    raisedShadow: BloomShadows.raised(brightness),
    border: light ? const Color(0xFFF1E1E6) : const Color(0xFF342A39),
    muted: s.onSurfaceVariant,
    subtle: light ? const Color(0xFFFBEDF1) : const Color(0xFF2A2130),
    heroWash: BloomGradients.wash(BloomColors.brand, brightness),
  );
  final cardColor = light ? Colors.white : s.surfaceContainer;
  const pill = StadiumBorder();
  const buttonPadding = EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.md);
  const buttonSize = Size(64, 52);
  final buttonText = text.labelLarge!.copyWith(fontSize: 15.5, color: null);
  const transitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
  });

  OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: s,
    textTheme: text,
    primaryTextTheme: text,
    fontFamily: BloomFonts.body,
    fontFamilyFallback: BloomFonts.fallback,
    scaffoldBackgroundColor: s.surface,
    canvasColor: s.surface,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: transitions,
    extensions: [tokens],
    iconTheme: IconThemeData(color: s.onSurface, size: 24),
    dividerTheme: DividerThemeData(color: tokens.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: s.onSurface,
      titleSpacing: Space.gutter,
      titleTextStyle: text.titleLarge,
      toolbarHeight: 60,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: tokens.border),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xxs),
      minVerticalPadding: Space.md,
      horizontalTitleGap: Space.md,
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      iconColor: s.onSurfaceVariant,
      titleTextStyle: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
      subtitleTextStyle: text.bodyMedium!.copyWith(color: s.onSurfaceVariant),
      leadingAndTrailingTextStyle: text.labelLarge!.copyWith(color: s.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: tokens.border),
      backgroundColor: cardColor,
      selectedColor: s.primaryContainer,
      checkmarkColor: s.onPrimaryContainer,
      labelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      secondaryLabelStyle: text.labelLarge!.copyWith(color: s.onPrimaryContainer),
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      labelPadding: const EdgeInsets.symmetric(horizontal: Space.xs),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: pill,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: pill,
        textStyle: buttonText,
        backgroundColor: cardColor,
        foregroundColor: s.primary,
        elevation: light ? 1 : 0,
        shadowColor: s.shadow.withValues(alpha: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: pill,
        textStyle: buttonText,
        foregroundColor: s.primary,
        side: BorderSide(color: light ? const Color(0xFFEBC6D2) : s.outline, width: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        shape: pill,
        textStyle: buttonText.copyWith(fontSize: 14.5),
        foregroundColor: s.primary,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: s.onSurface),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primary,
      foregroundColor: s.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: const StadiumBorder(),
      extendedTextStyle: buttonText,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, 46),
        textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w700),
        side: BorderSide(color: tokens.border, width: 1.2),
        selectedBackgroundColor: s.primaryContainer,
        selectedForegroundColor: s.onPrimaryContainer,
        backgroundColor: cardColor,
        foregroundColor: s.onSurfaceVariant,
        shape: pill,
      ),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      borderRadius: Radii.mdAll,
      selectedColor: s.onPrimaryContainer,
      fillColor: s.primaryContainer,
      borderColor: tokens.border,
      selectedBorderColor: tokens.border,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: tokens.subtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.lg),
      border: inputBorder(Colors.transparent),
      enabledBorder: inputBorder(Colors.transparent),
      focusedBorder: inputBorder(s.primary, 1.6),
      errorBorder: inputBorder(s.error),
      focusedErrorBorder: inputBorder(s.error, 1.6),
      disabledBorder: inputBorder(Colors.transparent),
      labelStyle: text.bodyLarge!.copyWith(color: s.onSurfaceVariant),
      floatingLabelStyle: text.bodyMedium!.copyWith(color: s.primary, fontWeight: FontWeight.w700),
      hintStyle: text.bodyLarge!.copyWith(color: s.onSurfaceVariant.withValues(alpha: 0.7)),
      helperStyle: text.bodySmall,
      prefixIconColor: s.onSurfaceVariant,
      suffixIconColor: s.onSurfaceVariant,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: s.primary,
      selectionColor: s.primary.withValues(alpha: 0.25),
      selectionHandleColor: s.primary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.onPrimary : (light ? Colors.white : s.outline),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.primary : tokens.subtle,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? Colors.transparent : (light ? const Color(0xFFE4CCD4) : s.outline),
      ),
      thumbIcon: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? Icon(Icons.check_rounded, size: 16, color: s.primary) : null,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: s.outline, width: 1.6),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? s.primary : s.outline),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      activeTrackColor: s.primary,
      inactiveTrackColor: tokens.subtle,
      thumbColor: s.primary,
      overlayColor: s.primary.withValues(alpha: 0.12),
      valueIndicatorColor: s.inverseSurface,
      valueIndicatorTextStyle: text.labelLarge!.copyWith(color: s.onInverseSurface),
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: s.primary,
      linearTrackColor: tokens.subtle,
      circularTrackColor: tokens.subtle,
      linearMinHeight: 8,
      borderRadius: Radii.pillAll,
      strokeCap: StrokeCap.round,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: light ? Colors.white : s.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: light ? Colors.white : s.surfaceContainerLow,
      showDragHandle: true,
      dragHandleColor: s.outline.withValues(alpha: 0.5),
      dragHandleSize: const Size(40, 5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
      clipBehavior: Clip.antiAlias,
      modalBarrierColor: Colors.black.withValues(alpha: light ? 0.32 : 0.55),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: light ? Colors.white : s.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyLarge!.copyWith(color: s.onSurfaceVariant),
      insetPadding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xxl),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: light ? Colors.white : s.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      headerHeadlineStyle: text.headlineMedium,
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: light ? Colors.white : s.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.inverseSurface,
      contentTextStyle: text.bodyMedium!.copyWith(color: s.onInverseSurface, fontWeight: FontWeight.w600),
      actionTextColor: s.inversePrimary,
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      width: null,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: s.inverseSurface, borderRadius: Radii.smAll),
      textStyle: text.labelMedium!.copyWith(color: s.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: light ? Colors.white : s.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: s.shadow.withValues(alpha: 0.25),
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      textStyle: text.bodyLarge,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(light ? Colors.white : s.surfaceContainerHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.mdAll)),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: text.bodyLarge,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(light ? Colors.white : s.surfaceContainerHigh),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.mdAll)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: light ? Colors.white : s.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: s.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => text.labelMedium!.copyWith(
          color: st.contains(WidgetState.selected) ? s.onSurface : s.onSurfaceVariant,
          fontWeight: st.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (st) => IconThemeData(
          size: 24,
          color: st.contains(WidgetState.selected) ? s.onPrimaryContainer : s.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: s.primaryContainer,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: s.onPrimaryContainer, size: 24),
      unselectedIconTheme: IconThemeData(color: s.onSurfaceVariant, size: 24),
      selectedLabelTextStyle: text.labelLarge!.copyWith(color: s.onSurface, fontWeight: FontWeight.w800),
      unselectedLabelTextStyle: text.labelLarge!.copyWith(color: s.onSurfaceVariant, fontWeight: FontWeight.w600),
      labelType: NavigationRailLabelType.all,
      minWidth: 88,
      groupAlignment: -0.6,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: s.onPrimaryContainer,
      unselectedLabelColor: s.onSurfaceVariant,
      labelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w800),
      unselectedLabelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      indicator: BoxDecoration(color: s.primaryContainer, borderRadius: Radii.pillAll),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      overlayColor: WidgetStatePropertyAll(s.primary.withValues(alpha: 0.06)),
      splashBorderRadius: Radii.pillAll,
      tabAlignment: TabAlignment.center,
      labelPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: s.primary, textColor: s.onPrimary),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      collapsedShape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      iconColor: s.primary,
      collapsedIconColor: s.onSurfaceVariant,
      tilePadding: const EdgeInsets.symmetric(horizontal: Space.lg),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(tokens.subtle),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.lg)),
      textStyle: WidgetStatePropertyAll(text.bodyLarge),
      hintStyle: WidgetStatePropertyAll(text.bodyLarge!.copyWith(color: s.onSurfaceVariant)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(s.onSurfaceVariant.withValues(alpha: 0.35)),
      radius: const Radius.circular(Radii.pill),
      thickness: const WidgetStatePropertyAll(6),
    ),
  );
}

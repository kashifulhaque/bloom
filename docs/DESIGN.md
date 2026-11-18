# Bloom design guide: Almanac

This guide is for the agents restyling Bloom's screens. Bloom's visual direction is
**Almanac**: ink on warm paper, an editorial serif, hairlines instead of cards, and color
only where it carries meaning. It should feel like a personal notebook, a printed almanac,
or a botanical field guide: literary, calm, and private. It must not look like a stock
Material app.

To get every token and widget, import one file:

```dart
import '../../widgets/widgets.dart'; // also re-exports theme/app_theme.dart
```

The approved mockup is sample 1 in `docs/design_research/samples.html`. The
background research is "Direction 1: Almanac" in `docs/design_research/RESEARCH.md`.

## Principles

1. **One editorial column.** Content is left-aligned in a single column with a 24-px side
   margin (`Space.gutter`), capped at 640 px. Don't center body text. Don't build grids of
   boxes.
2. **Hairlines, not cards.** Separate sections with 1-px rules and vertical space (24 to
   48 px between sections). `BloomCard()` is a ruled section, not a box. Use a box
   (`BloomCard.outlined`) only for something the user can pick up or tap as a unit.
3. **One serif hero per screen.** Each screen has one large Fraunces moment: the page
   title, a `PhaseTitle`, a hero numeral, or the dial. Everything else is quieter.
4. **Mono marginalia.** Small uppercase IBM Plex Mono labels (`MonoLabel`, `Marginalia`,
   `SectionHeader(label:)`, `BloomPage(eyebrow:)`) carry dates, categories, and metadata.
5. **Italic phase names.** Phase names and short accents are Fraunces italic
   ("*Follicular*", "*ovulation likely.*").
6. **Color only for meaning.** Ink and paper do almost all the work. Oxblood means period,
   sage means fertile, ochre means follicular, and plum means luteal. Don't use phase
   colors for decoration, buttons, or headings that aren't about that phase.
7. **No gradients, shadows, ripples, or pills.** The theme already removes ripples,
   elevation, and tonal tints. Don't add them back. Corners are 6 to 8 px where a container
   exists.
8. **Emoji are de-emphasized.** For app-defined options, use a text tag with a small
   colored dot, a `BotanicalGlyph`, or a thin icon. Keep emoji only where the user chose
   them (a mood they picked, a note they wrote) or inside article and story content.
9. **Quiet motion.** Cross-fades of 250 to 350 ms with ease-out curves. Press feedback is a
   dim, not a ripple. No bounces or overshoot.

## Fonts

All fonts are bundled under `bloom/assets/fonts`, so the app works offline. All are SIL
Open Font License 1.1; the license texts are in `assets/fonts/OFL-*.txt`. Each is subset
to Latin and Latin Extended-A. The fonts total about 480 KB, plus the 430 KB emoji
subset.

| Family | Files | Role |
|---|---|---|
| **Fraunces** | `Fraunces-VF.ttf`, `Fraunces-Italic-VF.ttf` (variable) | Display, headlines, `titleLarge`, numerals, italic accents |
| **Hanken Grotesk** | static 400, 500, 600, and 700 | Body text and UI |
| **IBM Plex Mono** | static 400 and 500 | Marginalia labels, dates, times, and data |
| **BloomEmoji** | `BloomEmoji.ttf` | Emoji fallback on every style |

Fraunces is variable: `wght` 300 to 600 and `opsz` 9 to 144. The `SOFT` axis is fixed at
50 and `WONK` is off in the file itself, so you never set them. Both `wght` and `opsz`
render on Flutter web and on Android.

**Don't change a Fraunces weight with `copyWith(fontWeight: ...)`.** The weight comes
from the `wght` axis, so on Android a `fontWeight` change produces a fake bold, and on the
web it does nothing. Use the `weight()` extension or `Almanac.serif(weight:)` instead:

```dart
theme.textTheme.headlineSmall!.weight(450)
Almanac.serif(size: 28, weight: 300, italic: true)
```

Don't set `fontFamily` yourself, and don't import `google_fonts`.

### Text styles

The following table lists the text theme roles:

| Style | Face | Use for |
|---|---|---|
| `displayLarge` (64) / `displayMedium` (52) | Fraunces 300 | The one hero numeral |
| `displaySmall` (40) | Fraunces 320 | Large secondary numerals |
| `headlineLarge` (34) | Fraunces 350 | Page titles (`BloomPage` uses it) |
| `headlineMedium` (28) / `headlineSmall` (23) | Fraunces 350 to 380 | Sheet and dialog titles, block headings |
| `titleLarge` (20) | Fraunces 400 | Section titles (`SectionHeader` uses 22) |
| `titleMedium` / `titleSmall` | Hanken 600 | Row titles, small headings |
| `bodyLarge` / `bodyMedium` | Hanken 400 | Paragraphs |
| `bodySmall` | Hanken 400, ink2 | Captions |
| `labelLarge` / `labelMedium` | Hanken 600 / 500 | Buttons, tags |

The `Almanac` class adds the styles that the Material roles don't cover:

| Helper | Result |
|---|---|
| `Almanac.label(context)` | 10.5-px Plex Mono 500, tracked, ink2. Uppercase the string yourself, or use `MonoLabel`. |
| `Almanac.numeral(context, size: 64)` | Light Fraunces with tabular lining figures |
| `Almanac.italic(context, size: 17)` | Fraunces italic 300 (alias: `italicAccent`) |
| `Almanac.data(context)` | 12.5-px Plex Mono, ink2, not uppercased: times, values |
| `Almanac.serif(...)`, `Almanac.sans(...)`, `Almanac.mono(...)` | Raw builders |
| `Almanac.spell(14)` | `'fourteen'`, for headlines like "Day fourteen," |
| `Almanac.tick()` | A selection haptic; it does nothing on the web |

### Emoji font

Flutter web (CanvasKit) can't use system emoji, so Bloom bundles a subset of Noto Color
Emoji as `BloomEmoji` and lists it as the fallback on every text style. An emoji outside
the subset renders only when the device is online. For more information, see
[Rebuild the emoji font](#rebuild-the-emoji-font).

## Tokens

All tokens are in `lib/theme/app_theme.dart`.

### Colors

The following table lists the palette. Light mode is **paper**; dark mode is
**lamplight**.

| Token | Paper | Lamplight | Meaning |
|---|---|---|---|
| `paper` | `#F6F1E7` | `#1A1714` | Page background |
| `raised` | `#FBF8F2` | `#23201C` | Sheets, menus, inputs |
| `hairline` | `#E2D9C8` | `#3A342D` | Rules and outlines |
| `ink` | `#2A2420` | `#EFE7DA` | Text, primary buttons, selected states |
| `ink2` | `#6E645A` | `#A79C8D` | Secondary text, labels, thin icons |
| `period`, `brand` | `#A23B2A` oxblood | `#E07A63` | Logged period, the brand accent |
| `predicted` | `#C48476` | `#A55C4B` | Predicted period (also draw it dotted) |
| `fertile` | `#4F6B5A` sage | `#8DB09A` | Fertile window |
| `ovulation` | `#3C5446` | `#A9CBB5` | Ovulation day |
| `follicular` | `#C7A15A` ochre | `#E0BE7A` | Follicular phase |
| `luteal` | `#7A5C7E` plum | `#B79BBB` | Luteal phase |
| `pregnancy` | `#946426` | `#E0B074` | Pregnancy mode |
| `periodSoft`, `fertileSoft`, `lutealSoft`, `pregnancySoft` | | | Faint washes |
| `success`, `warning`, `info`, `error` | | | Status tones |

`BloomColors` follows these rules for brightness:

- The static constants, such as `BloomColors.period`, are the **paper** values. They stay
  `const`, so older code compiles.
- `BloomColors.of(context)` returns a `BloomPalette` for the current brightness. Use it
  for any color you draw yourself: `BloomColors.of(context).period`,
  `.ink2`, `.hairline`, `.phase(phase)`.
- `BloomColors.resolve(context, c)` maps a paper constant to its lamplight equivalent in
  dark mode. Unknown colors pass through unchanged.
- Every shared widget resolves the colors you pass it. `PillChip(color:
  BloomColors.period)` is correct in both modes without extra work.
- `readableTint(c, brightness)` returns a version of `c` that reads as text. Use it for
  ochre, which is too light for text on paper.
- `BloomColors.onColor(c)` returns paper or ink, whichever has more contrast on `c`.

The color scheme is defined by hand: `primary` is ink, `secondary` is oxblood,
`tertiary` is sage, `surface` is paper, and `outlineVariant` is the hairline.
`BloomTokens.of(context)` still provides `border` (hairline), `muted` (ink2), and
`subtle` (a shade off the paper for tracks). Its shadow fields are always empty.

### Spacing, radii, and motion

- `Space.xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 20, `xxl` 24, `xxxl` 32, `huge` 48.
  `Space.gutter` is 24 and `Space.margin` (the marginalia column) is 64.
- `Gap.v4` through `Gap.v48`, `Gap.h4` through `Gap.h24`, and `Insets.*` are unchanged.
- `Radii.xs` 2, `sm` 4 (tags), `md` 6 (buttons, inputs), `lg` 8 (boxes), `xl` 12 (sheet
  tops). `Radii.pill` is only for dots and thin tracks.
- `Motion.fast` 150 ms, `medium` 300 ms, `slow` 600 ms, and `ink` 1400 ms (the dial).
  `Motion.spring` is a plain ease-out: Almanac doesn't overshoot.
- `BloomShadows.*` return empty lists. `BloomGradients.*` are flat single-color fills used
  only by `BloomCard.gradient`. Don't build new gradients.

## Widgets

All widgets are in `lib/widgets/` and have doc comments with examples.

### Page structure

| Widget | When to use it |
|---|---|
| `BloomPage` | The body of every screen: safe area, 640-px column, an `eyebrow` (mono), a serif `title`, a `subtitle`, `actions`, an automatic back arrow on pushed routes, and `slivers` for lazy lists. Pass `header:` to replace the title block, for example with a `PhaseTitle`. `heroColor` is ignored. |
| `SectionHeader` | A section opener: an optional mono `label`, a serif title, a subtitle, and an underlined "See all →" link. |
| `Hairline` | A 1-px rule. `Hairline(vertical: true)` for columns, `spacing:` for space around it. |
| `Marginalia` | A two-column row: a mono label in the left margin, content on the right. Use it for notes, definitions, and small facts. |
| `MonoLabel` | Uppercase mono metadata text. |
| `PhaseTitle` | The large serif title of a day: a roman `lead` and an italic phrase, for example "Day fourteen," / "*ovulation likely.*" |
| `PaperBackground` | Paper plus grain. The app already wraps every route, sheet, and dialog in one, so screens don't add it. |

### Sections and data

| Widget | When to use it |
|---|---|
| `BloomCard()` | A ruled section: a hairline on top and vertical padding only, no box. Pass `rule: false` to drop the rule. |
| `BloomCard.outlined()` | A 1-px hairline box with 8-px corners, for a tappable unit. |
| `BloomCard.tinted(color:)` | A very faint wash of a phase color. Use it rarely. |
| `BloomCard.gradient(gradient:)` | An *inked* block: a flat fill (ink, oxblood, sage, plum, deep ochre) with paper text. At most one per screen. The name is historical. |
| `StatTile` | A metric: a mono label with a dot or thin icon, a large serif numeral, and an italic unit. Put two or three in a `Row` of `Expanded`. |
| `Ledger` | A strip of days: mono weekday letters and serif numerals colored by meaning, an ink underline on today, a box on the selected day, and dotted rules for predictions. You supply `days`, `styleFor`, and `onTap`. |
| `CycleRing` | The Almanac dial: a hairline circle with a tick per day, a thick oxblood period arc, a sage fertile arc with the ovulation day, a dotted plum luteal arc, predictions dotted, and an ink dot for today. The arcs draw in like ink. Use `CycleRing.fromEngine(store.engine, child: ...)` and put a serif numeral and an italic caption in the child. |
| `ProgressRing` | A hairline ring with a thin ink (or colored) progress arc. |
| `BotanicalGlyph` | A small original line drawing: `Botanical.bud` (menstrual), `sprout` (follicular), `flower` (ovulation), `seedHead` (luteal), and `sprig` (neutral). `BotanicalGlyph.phase(phase)` picks the drawing and colors its head. Use it beside phase names, in empty states, and in place of decorative emoji. |

### Controls and messages

| Widget | When to use it |
|---|---|
| `InkButton` | The primary action: an ink-filled rectangle with 6-px corners. `InkButton.outlined` is the secondary style. Pass `color:` only when the action is about a meaning, such as "Log period" in oxblood. |
| `GradientButton` | Kept for older code; it renders an `InkButton`. Its `gradient` is ignored. |
| `InkLink` | An underlined text link with an optional `→`. Use it for "See all," "Edit," and inline actions. |
| `Pressable` | Quiet press feedback (the child dims) with focus, keyboard, and semantics. Use it instead of `InkWell` or `GestureDetector` for custom tappables. |
| `InkSwitch` | A small hairline toggle. `MenuTile.toggle` uses it. |
| `SelectChip` | A selectable tag: hairline outline, ink fill when selected, a dot for the category color, and a small check. Use it in a `Wrap(spacing: Space.sm, runSpacing: Space.sm)`. |
| `PillChip` | A static tag: a hairline outline and a colored dot. `solid: true` fills it, for use on inked blocks. |
| `MenuSection` and `MenuTile` | Settings-style lists: a mono label, rows separated by hairlines, an optional thin icon, a mono `value`, and an arrow. Don't pass `color:` to rows unless the color means something. |
| `EmptyState` | No data yet: a botanical drawing (`glyph:`), a serif title, a muted body, and an ink button. `emoji` is no longer drawn. |
| `InfoBanner` | An inline note with a 2-px colored rule on the left and an underlined action. |
| `Disclaimer` | A "not medical advice" note with a mono **Note** label in the margin. |
| `showAppBottomSheet` and `AppBottomSheet` | Every modal sheet: paper, a thin handle, a hairline top edge, a mono `eyebrow`, a serif title, and pinned actions. |
| `IconBadge` | A thin-outline circle with an icon. Most rows need no badge; prefer a bare thin icon. |
| `BloomLogo` | The line-drawn flower mark, with an optional Fraunces wordmark. |

The theme also restyles the stock widgets: `FilledButton` (ink), `OutlinedButton` (1-px
ink outline), `TextButton` (underlined), `SegmentedButton` (hairline, ink when selected),
`TextField` (underline only), `Switch`, `Checkbox`, `Slider` (1.5-px track), `Chip`,
`TabBar` (ink underline), `ListTile`, dialogs, date and time pickers, popup menus, snack
bars (ink), and tooltips. Prefer the Almanac widgets in new code; the stock ones are a
safety net.

## The app shell

The shell is in `lib/app.dart`. On phones, the navigation is a paper bar with a top
hairline and five text labels: **Today**, **Calendar**, **Library**, **Ask**, and
**You**. The active label is ink with an underline. At 900 px and wider, a left editorial
column shows the mark, "Bloom" in Fraunces, and numbered vertical links. The tab order and
the `HomeShell.goTo(context, index)` indices are unchanged: 0 Today, 1 Calendar,
2 Library (insights), 3 Ask (assistant), 4 You (profile).

Name your screen's title to match its tab where it makes sense. For example, the profile
screen can keep "Me" as a page title, but "You" or the user's name reads more naturally
with the tab label.

Pushed routes fade in with a small horizontal slide. Scrolling bounces everywhere, with no
Android glow.

## Screen recipe

The following code sample shows the standard structure of a tab screen:

```dart
@override
Widget build(BuildContext context) {
  final store = context.watch<AppStore>();
  final palette = BloomColors.of(context);
  final info = store.engine.info(today());
  return Scaffold(
    body: BloomPage(
      eyebrow: 'Cycle 07 · ${fmtLong(today())}',
      header: PhaseTitle(
        lead: 'Day ${Almanac.spell(info.cycleDay ?? 1)},',
        italic: 'ovulation likely.',
        color: BloomColors.ovulation,
      ),
      children: [
        Center(child: CycleRing.fromEngine(store.engine, size: 260, child: _DialCenter())),
        Ledger(
          days: [for (var i = -3; i <= 3; i++) addDays(today(), i)],
          styleFor: (d) => store.isPeriodDay(d)
              ? const LedgerDay(color: BloomColors.period)
              : LedgerDay.plain,
          onTap: _openDay,
        ),
        const Hairline(),
        Marginalia(
          label: 'Note',
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Ovulatory. ', style: Almanac.italic(context)),
            const TextSpan(text: 'Energy and confidence often peak now.'),
          ])),
        ),
        Row(children: [InkButton(label: 'Log today', icon: Icons.add, onPressed: _log)]),
        const SectionHeader('Your cycle', label: 'Ledger', actionLabel: 'See all'),
        const Row(children: [
          Expanded(child: StatTile(value: '28', unit: 'days', label: 'Average cycle')),
          Gap.h16,
          Expanded(child: StatTile(value: '5', unit: 'days', label: 'Average period',
              color: BloomColors.period)),
        ]),
        const Disclaimer(),
      ],
    ),
  );
}
```

Follow these rules for structure:

1. Make `BloomPage` the `Scaffold.body`. Don't add an `AppBar` to tab screens.
2. Open with a mono eyebrow and one serif hero (a title, a `PhaseTitle`, a numeral, or the
   dial).
3. Group the rest into ruled sections: `SectionHeader`, then plain `BloomCard`s,
   `Marginalia` rows, or lists. `BloomPage` spaces children 16 px apart.
4. Use one primary `InkButton` per screen. Secondary actions are `InkButton.outlined` or
   `InkLink`.
5. End health content with `Disclaimer`.
6. For a long list, pass `slivers: [SliverList.builder(...)]` instead of `children`.
7. For a `TabBar` inside a page, use `TabBar(isScrollable: true, tabAlignment:
   TabAlignment.start, padding: Insets.pageH)` so the tabs start at the page margin.

## Do and don't

Do:

- Use `Space`, `Gap`, `Insets`, and `Radii` for every number.
- Use thin icons: `Icons.*_outlined` or plain `Icons.*` at 18 to 20 px in ink2.
  `CupertinoIcons` are allowed where you need a finer stroke. Keep one family per screen.
- Use `BloomColors.of(context)` for colors you draw, and `readableTint` for colored text.
- Pair every color with a label, a dot legend, or a pattern (solid versus dotted).
- Animate state changes with `AnimatedSwitcher`, `AnimatedOpacity`, or `AnimatedSize`
  and `Motion.medium`.
- Keep touch targets at 44 px or larger.
- Check every screen in light and dark mode, at 360 px and at desktop width.

Don't:

- Don't use gradients, `BoxShadow`, `elevation`, or `Material` surfaces with a tint.
- Don't use `InkWell` ripples or `Card`. Use `Pressable` and `BloomCard`.
- Don't use pill or stadium shapes for buttons, chips, or tabs.
- Don't put a filled, colored circle or square behind an icon.
- Don't use emoji as decoration for app-defined options, headings, or empty states.
- Don't hard-code hex colors, `Colors.white`, or `Colors.grey`.
- Don't use `copyWith(fontWeight: ...)` on a Fraunces style. Use `.weight(...)`.
- Don't center long text or nest boxes inside boxes.

## Screenshots

To check a screen without a browser, use `test/support/screenshot.dart`. It loads the
bundled fonts, wraps the screen in `PaperBackground` with the app's scroll behavior, and
writes a PNG. The following code sample shows a screenshot test in `test/shots/`:

```dart
testWidgets('today', (t) async {
  final store = AppStore.memory();
  loadDemoData(store, seed: 1);
  await shoot(t, 'today_light', store: store, child: const TodayScreen());
  await shoot(t, 'today_dark', store: store, child: const TodayScreen(), dark: true);
});
```

Run `flutter test test/shots/<file> --update-goldens`, then open
`test/shots/goldens/<name>.png`. Don't keep screenshot files in the repository.

## Rebuild the fonts

To rebuild the Latin font subsets, do the following:

1. Download the font files from the `google/fonts` repository (`ofl/fraunces`,
   `ofl/hankengrotesk`, and `ofl/ibmplexmono`) into an empty folder.
2. Pin the Fraunces axes with `fonttools varLib.instancer FILE wght=300:600 opsz=9:144
   SOFT=50 WONK=0`.
3. Make static Hanken Grotesk instances with `fonttools varLib.instancer FILE wght=WEIGHT
   --static`.
4. Subset each file with `pyftsubset` to `U+0000-017F` plus general punctuation, arrows,
   `U+2212`, `U+2248`, and `U+2264-2265`, and drop hinting.
5. Rebuild the two static Fraunces cuts that the doctor report PDF uses, because the
   `pdf` package can't set variable-font axes. From the subset variable files, run
   the following commands:

   ```bash
   fonttools varLib.instancer assets/fonts/Fraunces-VF.ttf wght=350 opsz=72 -o assets/pdf/Fraunces-Light.ttf
   ```

   ```bash
   fonttools varLib.instancer assets/fonts/Fraunces-Italic-VF.ttf wght=320 opsz=72 -o assets/pdf/Fraunces-LightItalic.ttf
   ```

   These files are listed under `assets:` in `pubspec.yaml`, not as a font family, so
   the app keeps using the variable font.

## Rebuild the emoji font

To add emoji to the bundled subset, do the following:

1. Download `NotoColorEmoji-Regular.ttf` from the `google/fonts` repository
   (`ofl/notocoloremoji`).
2. Collect the code points from `lib/` and the extra emoji you need into a comma-separated
   `U+XXXX` list, and include `U+200D`, `U+FE0F`, and `U+20E3`.
3. Run `fontTools.subset` with that list, `--layout-features='*'`, and
   `--drop-tables+=SVG`, and write the result to `assets/fonts/BloomEmoji.ttf`.

# Bloom design research: beyond stock Material

This document collects research on what makes the best-designed health, wellness,
cycle-tracking, and journaling apps look distinctive. It then distills six design
directions for Bloom, an offline period and cycle tracker built in Flutter for web and
Android, whose current UI reads as generic Material 3.

## How to read this document

- Part 1 profiles reference apps, grouped by what they teach.
- Part 2 lists the recurring patterns that separate premium apps from stock Material.
- Part 3 describes six named design directions, each with fonts, palettes, rules, and
  risks.
- Part 4 covers techniques to remove the Material feel from a Flutter app, without code.
- Part 5 lists sources.

> **About accuracy.** Public design write-ups rarely name exact typefaces, hex values, or
> corner radii. Where a source states a detail, this document cites it. Other visual
> descriptions come from general familiarity with each app's public screenshots as of
> mid-2026. Treat those as directional, and check current App Store or Play Store
> screenshots, or Mobbin, before you copy a specific value.

---

## Part 1: Reference apps

### Cycle and women's health

#### Clue

- **Typography:** Clean geometric-humanist sans, sentence case, modest weight contrast.
  No serif. Large numerals for "day X of cycle."
- **Color:** White or very light backgrounds. The signature is a muted brick red for
  period, with secondary tints for fertile window and PMS. It deliberately avoids
  candy pink and reads as scientific and gender-neutral.
- **Shape:** Soft but restrained; small radii, flat surfaces, few shadows.
- **Data visualization:** Historically the cycle wheel: a ring of dots, one per day, with
  period days filled red and predictions shown as outlined or hatched dots. This ring is
  the brand's most recognizable artifact. Later versions moved toward a calendar and
  day-detail view.
- **Iconography:** A custom set of small, two-tone symptom icons grouped by category,
  each category with its own color.
- **Navigation:** Standard bottom tab bar.
- **What makes it distinctive:** Scientific tone, a non-pink palette, and the dot ring.
  Third-party case studies list a dated UI and scattered symptom logging as common
  user complaints, so the ring alone is not enough.

#### Stardust

- **Typography:** Light, airy sans with generous tracking for labels.
- **Color:** Dark and cosmic: deep indigo-to-black backgrounds, star fields, soft
  gradients, and moon-phase glyphs. Reviewers note it escapes the all-pink look of
  clinical trackers.
- **Data visualization:** The home screen shows the cycle as a circle mapped to moon
  phases, with a scrubber you drag around the circle to explore each day. The calendar
  uses moon phases in place of a plain date grid.
- **Motion:** Animated constellations in the zodiac picker during onboarding; animated
  Mind and Body sections.
- **What makes it distinctive:** It commits fully to a theme. Standard components are
  restyled to fit the cosmic world, so nothing looks borrowed from a UI kit.
- **Caution:** Privacy criticism (a Mozilla review flagged data sharing with Facebook)
  shows that aesthetic trust and data trust are separate. Bloom's offline model is an
  advantage worth surfacing in the design.

#### Natural Cycles

- **Color:** A plum and purple brand, with a traffic-light day status: a red day means
  "use protection" and a green day means "not fertile." The status lives in a large
  circle on the home screen.
- **Typography:** Bold, friendly sans for the status word; very large and very simple.
- **Data visualization:** A horizontal scrollable strip of day circles, each colored by
  status, with temperature charts as thin line graphs.
- **What makes it distinctive:** Radical single-answer clarity. The home screen answers
  one question in one word. Reviewers describe it as sleek and minimal.

#### Apple Health cycle tracking

- **Typography:** SF Pro, with bold large titles and tight hierarchy.
- **Color:** Grouped light-gray backgrounds with white inset panels. Period days are a
  saturated pink-red, the fertile window is light blue, and predictions use dashed or
  lighter fills.
- **Data visualization:** A horizontal timeline of day ovals across the top: filled ovals
  for logged period days, outlined ovals for predictions, a light band for fertility.
  Scroll horizontally to move through time.
- **What makes it distinctive:** It is rigorous and quiet. It proves that a cycle can
  read as a linear timeline, not only a circle.

#### Oura (relevant for its cycle insights and wellness data)

- **Typography:** Large, light-weight numerals for scores, small uppercase labels. Third
  party token extractions suggest an Inter-like sans; Oura does not publish its app
  typeface.
- **Color:** Dark by default, near-black and deep navy. Scores sit in thin colored rings.
  Earlier versions used full-bleed sky photography that shifted with the time of day.
- **Layout:** The October 2025 redesign kept the Today, Vitals, and My Health tabs but
  dropped the card-style layout for a more open one. Coverage also described a palette
  that adapts to each member's biometrics.
- **Data visualization:** Thin rings, slim line charts, hypnogram-style sleep bars.
- **What makes it distinctive:** The "jewelry" register: dark, precise, thin strokes,
  lots of negative space. User reaction to the 2025 redesign was mixed, which shows the
  risk of removing containers without strong typographic hierarchy.

#### Bearable

- **Style:** Dense, utilitarian, data-first. Correlation charts, many toggles, a long
  scrolling log.
- **Lesson:** Power users value correlations ("sleep vs. cramps"), but the visual
  language is close to stock components. Bloom should borrow the insight model, not the
  look.

### Mood, journaling, and self-care

#### How We Feel

- **Shape language:** Emotions are abstract geometric shapes. The designers describe
  sharp, jagged edges for high-energy, stormy emotions and smooth curves for calm ones.
  They built the shapes as simple vectors so they could add more over time.
- **Color:** A four-quadrant color system based on Marc Brackett's Mood Meter: red for
  high energy and unpleasant, yellow for high energy and pleasant, blue for low energy
  and unpleasant, green for low energy and pleasant. The check-in screen starts with a
  2x2 grid of large color fields.
- **Background:** Mostly dark, so the color shapes glow.
- **Motion and haptics:** A draggable, interactive meter with haptic feedback; floating,
  drifting shapes.
- **Recognition:** 2024 Apple Design Award finalist.
- **What makes it distinctive:** Color and shape carry meaning, not decoration.
  For Bloom, cycle phases could get the same treatment.

#### Daylio

- **Style:** Five colored mood faces, an icon grid for activities, and the "Year in
  Pixels" grid where each day is a colored square.
- **Lesson:** The year-in-pixels grid is a powerful, compact visualization that Bloom
  could adapt to a year of cycles. The rest of the UI is close to stock Material, which
  is what Bloom wants to avoid.

#### Finch

- **Illustration:** A cartoon bird pet that grows as you complete self-care tasks. Reviews
  call the art cartoonish and adorable without being childish.
- **Interface:** A design critique describes it as skeuomorphic, with visible
  affordances and strong feedback. Splash screens are plain white with one centered
  character.
- **Risk:** Critiques also call it busy and say it skips progressive disclosure.
- **Lesson:** A companion character creates warmth and habit. It needs strict restraint
  elsewhere in the UI.

#### Bears Gratitude (2024 Apple Design Award winner, Delight and Fun)

- **Style:** A gratitude journal built around cute illustrated bears, warm paper-like
  backgrounds, and small celebratory animations when you write an entry.
- **Lesson:** A journaling app can win on delight alone if each entry feels rewarded.

#### grug (2026 Apple Design Award winner, Delight and Fun)

- Apple describes it as a playful way to discover daily wisdom, with illustrated,
  minimal screens and short prompts for reflection. Again: one character, few elements,
  lots of air.

#### Headspace

- **Typography:** A custom version of Colophon's Aperçu, chosen because it can move from
  playful to clinical. One sans family only.
- **Color:** Signature orange plus a warm, saturated secondary palette on off-white.
- **Illustration:** Blobby, faceless or simple-faced characters made by an in-house team
  with strict rules so thousands of assets stay consistent.
- **Rebrand (2024):** Italic Studio worked with the in-house team to make the brand more
  credible as a mental-health service while keeping the friendliness.
- **Lesson:** An illustration system with rules beats one-off illustrations.

#### Calm

- **Style:** Full-bleed nature imagery and video backgrounds, white text over deep blue
  gradients, very little chrome. Content sits on translucent overlays.
- **Lesson:** Atmosphere can come from the background layer alone.

### Fitness, sleep, and focus

#### Gentler Streak (2024 Apple Design Award winner, Social Impact)

- **Illustration:** Yorhart, an illustrated character designed to suit any age, gender,
  race, or body shape. It sits at the top of the Streak tab with the daily status.
- **Data visualization:** The Activity Path: a soft band that shows your recommended
  activity range, with your actual activity drawn through it. Stats become plain-language
  summaries, not raw metrics.
- **Tone:** Apple's citation praises a subtle, consistently pleasing design language. The
  team says they blend familiar iOS patterns with their own visual layer and add playful
  touches sparingly.
- **Lesson:** "A range, not a target" fits cycles well: predictions are ranges, and Bloom
  can draw them as soft bands.

#### Rise Science

- **Data visualization:** The Energy Schedule: a smooth wave of predicted energy peaks and
  dips across the day, with the current time marked. Sleep debt changes how intense the
  curve is, not when peaks happen.
- **Color:** Deep navy and dark backgrounds with warm gradient fills under the curve.
- **Tone:** Guidance, not scolding. The home screen is sparse on purpose: last night,
  sleep debt, today's curve.
- **Lesson:** A cycle is also a wave. Hormone or energy curves across 28 days can be a
  hero visualization.

#### Opal (2025 Apple Design Award finalist, Social Impact)

- **Style:** Black backgrounds, rendered 3D gems that grow brighter and more intricate as
  focus improves. Opal's brand kit says gems appear on black only.
- **Lesson:** A single precious 3D object as a progress metaphor feels premium. A "bloom"
  that opens across the cycle could do the same job.

#### Structured (2026 Apple Design Award finalist, Inclusivity)

- **Style:** A vertical timeline with a thin connecting line and pill-shaped, color-filled
  capsules for each task, each with an icon. Tall capsules represent long tasks.
- **Lesson:** Pills on a spine is a strong, non-Material pattern for a day log.

### Productivity and craft benchmarks

#### Things 3

- **Typography:** System sans with careful weight contrast and generous line height.
- **Color:** Almost entirely white or near-black, with one blue accent and small colored
  icons.
- **Navigation:** No tab bar. A list-of-lists home and a floating "Magic Plus" button you
  can drag to the spot where you want to insert an item.
- **Motion:** Precise, spring-based transitions; satisfying checkbox animations.
- **Lesson:** Restraint plus one tactile signature interaction is enough to feel premium.

#### Arc (browser and Arc Search)

- **Style:** Vivid gradient themes the user can pick, playful sounds, and a bottom bar
  that merges the address field with actions.
- **Lesson:** Letting the user choose a color mood creates ownership.

#### (Not Boring) apps by Andy Works

- **Style:** Chunky 3D graphics, a striking monochrome palette per app, sound effects,
  and haptics on nearly every interaction. Paid "skins" (Opal, Cedar, Chroma, Monsters)
  re-theme the whole app.
- **Recognition:** Weather was an Apple Design Award finalist; (Not Boring) Camera was a
  2026 Visuals and Graphics finalist.
- **Lesson:** Commit to one material and one color per screen. Treat sound and haptics as
  part of the visual design.

#### Airbnb 2025 redesign

- **Style:** A dimensional system with 3D-rendered icons (a house, a hot-air balloon, a
  service bell) for the Homes, Experiences, and Services tabs, plus an animated
  interface. Bloomberg framed it as part of a broader return from flat design, alongside
  Apple's Liquid Glass.
- **Typography:** Airbnb Cereal, its in-house rounded sans.
- **Lesson:** Small 3D objects as navigation anchors make an app feel warm and current,
  but they need a consistent render style and lighting.

### Recent Apple Design Award signals (2023 to 2026)

| Year | App | Category | Relevance to Bloom |
|---|---|---|---|
| 2023 | Flighty | Interaction | Dense data made calm through hierarchy and live updates |
| 2023 | Any Distance | Visuals and Graphics | Fitness data as collectible, beautifully rendered artifacts |
| 2024 | Gentler Streak | Social Impact | Gentle, range-based health data and a mascot |
| 2024 | Bears Gratitude | Delight and Fun | Journaling made rewarding through illustration |
| 2024 | Rooms | Visuals and Graphics | Tactile, toy-like 3D |
| 2024 | Crouton | Interaction | Fluid gestures in a utility app |
| 2024 | How We Feel | Finalist | Color and shape as meaning |
| 2025 | CapWords | Delight and Fun | Photos turned into stickers; sticker aesthetic |
| 2025 | Opal | Finalist, Social Impact | Single precious 3D object on black |
| 2025 | iA Writer, Mela | Finalists, Interaction | Typography-first restraint |
| 2026 | Moonlitt | Interaction | Moon phases, elegant, Liquid Glass, time travel through dates |
| 2026 | Tide Guide | Visuals and Graphics | Full-screen custom charts, sky-matched palette |
| 2026 | grug | Delight and Fun | Minimal illustrated reflection prompts |
| 2026 | Structured | Finalist, Inclusivity | Timeline of pills |

Moonlitt deserves special attention. Its team says they wanted the app to reflect the
elegance and quiet of the moon, and to let people interact with the data as naturally as
looking at the sky. It lets you scrub through time to see any date's phase, which is the
same mental model a cycle tracker needs.

---

## Part 2: What separates premium apps from stock Material

1. **One committed world, not a component kit.** Stardust, Opal, (Not Boring), and
   Calm each restyle every surface to one theme. Stock Material shows when cards,
   chips, and buttons look like they came from different places.
2. **A hero visualization that is the brand.** Clue's dot ring, Rise's energy wave,
   Natural Cycles' status circle, Gentler Streak's Activity Path, Opal's gem. Each app
   owns one custom drawing that you could recognize in a thumbnail.
3. **Typographic contrast instead of containers.** Premium apps use big size jumps
   (a 64 to 120 pt numeral above 13 pt labels), tight tracking at display sizes,
   tabular numerals, and often a serif or a very characterful display face. Oura's 2025
   redesign removed cards and relies on type and spacing alone.
4. **Color as meaning.** How We Feel's quadrants and Natural Cycles' red and green days
   use color to encode state. Decorative tonal palettes (the Material 3 default) read as
   generic.
5. **Background as atmosphere.** Gradients, grain, photography, or a warm paper tone
   replace flat `surface` colors. Pure white and Material's tinted surfaces are the most
   generic choice possible.
6. **Custom navigation.** Floating pill bars, a single draggable action button, a
   swipeable day strip, or no tab bar at all. The default bottom navigation bar with a
   pill indicator is the strongest Material tell.
7. **Physical feedback.** Haptics on every meaningful touch, springy press states,
   satisfying completion animations, occasionally sound. No ink ripples.
8. **Characters or objects with rules.** Yorhart, Finch's bird, Headspace's blobs,
   Airbnb's 3D icons. All follow a strict style guide.
9. **Kind language.** Rise and Gentler Streak turn data into plain-language guidance.
   Copy is part of the visual design.

---

## Part 3: Six design directions for Bloom

All fonts listed are on Google Fonts under the SIL Open Font License (OFL). Because Bloom
is offline, bundle the font files as app assets and do not fetch them at runtime.
Avoid popular look-alikes that are not on Google Fonts, such as Satoshi, General Sans,
and Cabinet Grotesk (Fontshare licenses), or GT and Söhne families (commercial).

Palettes list the core roles. "Period," "Fertile," "Luteal," and "Follicular" are the
cycle phase colors used in charts. Check text contrast against WCAG AA (4.5:1 for body
text) before shipping.

### Direction 1: Almanac (editorial serif and paper)

**Inspired by:** Moonlitt, iA Writer, Clue's scientific calm, printed almanacs and
botanical field guides, Things 3's restraint.

- **Mood:** literary, calm, trustworthy, timeless, private, a personal notebook.
- **Type pairing:**
  - Display: **Fraunces** (variable). Use weight 300 to 400 for headlines, the `opsz`
    axis at its maximum for large sizes, and `SOFT` at about 50 to round the serifs. Use
    italic 300 for phase names ("*Follicular*").
  - Body and UI: **Hanken Grotesk** 400, 500, and 600.
  - Numerals and data: Fraunces with tabular lining figures for the day count; **IBM
    Plex Mono** 400 for small metadata such as dates and times.
- **Palette, light ("paper"):**
  - Background `#F6F1E7`, raised surface `#FBF8F2`, hairline `#E2D9C8`
  - Ink (text) `#2A2420`, secondary text `#6E645A`
  - Accent and period `#A23B2A` (oxblood), fertile `#4F6B5A` (sage),
    follicular `#C7A15A` (ochre), luteal `#7A5C7E` (dusty plum)
- **Palette, dark ("lamplight"):**
  - Background `#1A1714`, raised surface `#23201C`, hairline `#3A342D`
  - Ink `#EFE7DA`, secondary text `#A79C8D`
  - Period `#E07A63`, fertile `#8DB09A`, follicular `#E0BE7A`, luteal `#B79BBB`
- **Shape and spacing:**
  - Almost no cards. Separate sections with 1 px hairlines and generous vertical rhythm
    (8 px base, 32 to 48 px between sections).
  - Corner radius small and consistent (6 to 8 px) where containers exist.
  - Left-aligned editorial column with a wide left margin (24 px) and a narrow right
    margin; occasional marginalia (small mono labels) on the left.
  - A subtle paper grain overlay at 3 to 5 percent opacity.
- **Cycle visualization:** A sundial or almanac dial. A thin hairline circle with 28 to
  35 tick marks; longer ticks every 7 days; day numbers set in tiny Plex Mono outside
  the ring. The period is a thicker oxblood ink arc, the fertile window a sage arc
  inside it, and today a small filled dot with a serif numeral in the center
  ("Day **14**" with "*ovulation likely*" in italic below). Predictions are dotted
  strokes. Alternative: a horizontal "ledger" strip of days like Apple Health, with
  serif numerals.
- **Navigation:** No tab bar. A home "Today" page with a serif date as the title, and a
  small text-and-icon row at the bottom ("Today · Calendar · Journal · Settings") set in
  Hanken Grotesk 500 with an underline indicator. Or a single floating "Log" button.
- **Motion:** Slow and quiet. Cross-fades of 250 to 350 ms with gentle ease-out curves;
  the dial draws its arcs like ink being laid down on first load; page turns as a short
  horizontal slide with parallax on the title.
- **Signature details:** Drop caps or a large italic phase name at the top of the day;
  journal entries styled like dated diary pages; a "pressed flower" small botanical line
  illustration per phase; an ex libris style "Your data stays on this device" note.
- **Risks:** Serif body text at small sizes on low-DPI Android screens; can feel cold or
  "too literary"; paper texture can look muddy in dark mode (lower its opacity there).
- **Best for:** Users who want privacy, journaling, and a grown-up tone.

### Direction 2: Bloom Field (soft organic shapes and grain gradients)

**Inspired by:** How We Feel's meaningful shapes and colors, Headspace's blobs, Calm's
atmospheric backgrounds, Gentler Streak's soft ranges, the 2025 to 2026 return of
texture.

- **Mood:** warm, embodied, fluid, gentle, sensual without being pink.
- **Type pairing:**
  - Display: **Bricolage Grotesque** 600 to 700, with the optical size axis at the
    largest setting for headings. Its slightly ink-trapped forms feel organic.
  - Body: **Figtree** 400, 500, and 600.
  - Numerals: Bricolage Grotesque 800 at 72 to 96 pt for the day number.
- **Palette, light:**
  - Background `#FBF4EE` (warm blush cream), surface `#FFFFFF` at 70 percent with blur
  - Text `#2B1E24`, secondary `#7B6670`
  - Phase gradients:
    - Menstrual: `#E2574C` to `#F29C8B` (coral to peach)
    - Follicular: `#F4C77B` to `#FBE3B0` (honey)
    - Ovulation and fertile: `#6FB8A6` to `#BFE3D6` (sea glass)
    - Luteal: `#9D7BC7` to `#D9C6EE` (lavender)
  - Grain: monochrome noise at 6 to 8 percent, multiply blend.
- **Palette, dark:**
  - Background `#16110F` (warm near-black), surface `#221A18`
  - Text `#F5ECE6`, secondary `#B5A39C`
  - Phase gradients, slightly deeper and more saturated:
    menstrual `#D9473F` to `#7A2430`, follicular `#E6B35C` to `#6B4A1F`,
    fertile `#4FA591` to `#1F4A44`, luteal `#8A66BC` to `#33254A`
  - Grain: 4 percent, screen blend.
- **Shape and spacing:**
  - No rectangles with uniform radius. Use blobs (organic closed curves) for the hero and
    large pills (fully rounded) for controls.
  - Squircle-style continuous corners (superellipse) with large radii (24 to 32 px) for
    the few surfaces that exist.
  - Lots of overlap: shapes bleed off the screen edge; text sits on top of color fields.
- **Cycle visualization:** A living blob in the center of the home screen that morphs
  shape and gradient through the cycle: tight and deep coral during the period, expanding
  and honey-toned in the follicular phase, round and luminous at ovulation, softer and
  lavender in the luteal phase. A thin orbit ring around it carries day dots, and the
  blob's position on the orbit marks today. Fertile and predicted ranges show as soft,
  blurred bands (like Gentler Streak's Activity Path) rather than hard arcs.
- **Navigation:** A floating, frosted pill bar with three to four icons, detached 16 px
  from the bottom edge. The active icon sits inside a small blob that morphs between
  positions.
- **Motion:** Slow ambient drift of background gradients (very low frequency, 10 to 20 s
  loops); spring physics on blob morphs; logging a symptom releases a small burst of
  petals or bubbles. Respect reduced-motion settings by freezing the drift.
- **Signature details:** Symptom icons as small pebble shapes; the app icon and splash
  share the same blob; each phase has a short body-positive one-line affirmation.
- **Risks:** Gradients and grain can band or look muddy on cheap Android screens; blur
  and shaders cost battery and can hurt web performance (CanvasKit); low contrast text
  on gradients; "wellness app sameness" if the blobs are not distinctive.
- **Best for:** The most emotionally warm and distinctive option; strongest link to the
  name "Bloom."

### Direction 3: Bento Bold (bold grid with oversized numerals)

**Inspired by:** Apple's bento-style feature grids, Oura's big scores, Natural Cycles'
one-word answer, Any Distance's data artifacts, Daylio's year-in-pixels grid.

- **Mood:** confident, informative, modern, sporty, data-literate.
- **Type pairing:**
  - Display and numerals: **Archivo** (variable width and weight). Use width 112 to 125
    (expanded) at weight 800 to 900 for numerals and big labels.
  - Body: **Geist** 400, 500, and 600.
  - Data labels: **Geist Mono** 500 in uppercase at 11 to 12 pt with wide tracking.
- **Palette, light:**
  - Background `#EFEDE8` (warm gray), tile `#FFFFFF`, tile alt `#E4E1DA`
  - Text `#111111`, secondary `#5F5B55`
  - Period `#FF4D3D` (signal red), fertile `#2F6BFF` (cobalt), follicular `#FFC53D`
    (sun), luteal `#8E6BFF` (violet), positive `#1FA971`
  - One tile per screen may be fully filled with the phase color.
- **Palette, dark:**
  - Background `#0B0B0C`, tile `#18181A`, tile alt `#222226`
  - Text `#F4F4F2`, secondary `#9A9A9F`
  - Period `#FF5A4A`, fertile `#5B8CFF`, follicular `#FFD25C`, luteal `#A68BFF`,
    positive `#3CCB8B`
- **Shape and spacing:**
  - A strict 2-column (phone) and 4-column (web) bento grid with 8 to 12 px gutters.
  - Tiles span 1x1, 2x1, or 2x2; corner radius 20 to 24 px, continuous corners.
  - No shadows. Tiles separate by color only.
  - Oversized numerals may crop at the tile edge on purpose.
- **Cycle visualization:** The hero tile is a 2x2 with "Day **14**" at 120 pt and a
  segmented ring: one thick segment per day, with gaps, colored by phase. Today's segment
  is raised and longer. Other tiles: "Period in **5** days," a 7-day mini strip, a
  "cycle length **29**" stat with a sparkline, and a Daylio-style year-of-cycles pixel
  grid (one row per cycle, one square per day).
- **Navigation:** A compact floating bar with text labels only, or a segmented control at
  the top ("Today | Calendar | Insights"). Logging opens a full-height sheet.
- **Motion:** Snappy (150 to 250 ms). Numbers count up or roll like an odometer; tiles
  stagger in by 30 ms each; tapping a tile expands it into a full screen with a shared
  element transition.
- **Signature details:** Mono "data labels" (`CYCLE 07 · DAY 14`), crop-off-the-edge
  numerals, a single color-flooded tile per screen, a shareable "cycle card" export.
- **Risks:** Can feel clinical or like a fitness dashboard; dense grids overwhelm
  irregular-cycle users with prediction confidence they do not have; bento is itself
  becoming a cliche.
- **Best for:** Users who want insights and numbers at a glance.

### Direction 4: Quiet Mono (calm monochrome with a single accent)

**Inspired by:** Things 3, Oura's 2025 open layout, Apple Health's discipline, Opal's
black backgrounds, Moonlitt's restraint.

- **Mood:** minimal, precise, discreet, serene, "nobody needs to know what this app is."
- **Type pairing:**
  - Everything: **Inter** (variable). Display 300 at 48 to 72 pt with -2 to -3 percent
    tracking; UI 400 and 500; tabular figures on.
  - Accent moments: **Instrument Serif** italic (one weight, 400) for the occasional
    phase name or quote.
- **Palette, light:**
  - Background `#FAFAF9`, surface `#F2F2F0`, hairline `#E4E4E1`
  - Text `#18181B`, secondary `#71717A`, tertiary `#A1A1AA`
  - Single accent (period and active state) `#C8102E`. All other phases use grays
    (fertile `#3F3F46` filled, predicted `#A1A1AA` outlined, luteal `#D4D4D8`).
- **Palette, dark:**
  - Background `#09090B`, surface `#141416`, hairline `#26262A`
  - Text `#FAFAFA`, secondary `#A1A1AA`, tertiary `#52525B`
  - Accent `#FF4655`
- **Shape and spacing:**
  - Few containers; content groups by spacing alone (8 px grid, 40 px between groups).
  - Radius 12 px for the few surfaces, 999 px for buttons.
  - Thin 1 px strokes, never shadows.
- **Cycle visualization:** A thin 2 px ring, gray, with only the period arc in the accent
  color. A tiny dot marks today. Fertile days are a slightly thicker dark gray arc;
  predictions are dashed. Inside: a large light-weight numeral. The calendar is a
  borderless grid where period days are accent-filled circles and everything else is
  plain numerals.
- **Navigation:** No visible tab bar on the home screen. Swipe horizontally between
  Today, Calendar, and Journal with a tiny three-dot page indicator, or use one floating
  "+" button (like Things 3's Magic Plus) for logging.
- **Motion:** Precise, physical springs (short duration, no bounce overshoot); the ring
  rotates subtly to bring today to the top; checkmarks draw themselves.
- **Signature details:** Discreet mode (the app icon and home look neutral); one accent
  color that the user can change; perfect alignment and tabular numerals everywhere.
- **Risks:** Can feel cold or unbranded; red-only accent is hard for some color-vision
  deficiencies, so pair it with shape (filled versus outlined); easy to execute
  poorly, because the quality comes entirely from spacing and type details.
- **Best for:** Privacy-minded users and the lowest implementation risk.

### Direction 5: Nocturne (dark cosmic glass)

**Inspired by:** Stardust, Moonlitt and Liquid Glass, Rise's dark navy wave, Oura's dark
mode, Calm's atmosphere, Tide Guide's sky-matched palettes.

- **Mood:** dreamy, lunar, intimate, nighttime, a little mystical but grounded.
- **Type pairing:**
  - Display: **Sora** 300 for large numerals and 600 for headings.
  - Body: **Manrope** 400, 500, and 600.
  - Accent: **Cormorant Garamond** italic 500 for phase names and moon-like moments.
- **Palette, dark (primary):**
  - Background gradient `#0B0D1F` (top) to `#1C1433` (bottom), with a faint radial glow
    behind the hero `#3A2A5C` at 40 percent
  - Glass surface: white at 6 to 10 percent with 20 to 30 px background blur, 1 px
    border of white at 12 percent
  - Text `#F2EEFA`, secondary `#A9A2C2`
  - Period `#FF7A8A` (rose glow), fertile `#7FD8E8` (moonlight cyan), follicular
    `#F6D58E` (starlight), luteal `#B69CFF` (twilight violet)
- **Palette, light ("dawn"):**
  - Background gradient `#F4EFFA` to `#FBEDEB`
  - Glass surface: white at 60 percent with blur, border white at 80 percent
  - Text `#1E1A2E`, secondary `#6A6380`
  - Period `#D9455C`, fertile `#2A93A8`, follicular `#C79A2E`, luteal `#7C5CD6`
- **Shape and spacing:**
  - Glass panels with 24 to 28 px continuous corners; floating, not edge-to-edge.
  - Circles and arcs dominate; star-dust particles at very low density.
  - Wide margins (20 to 24 px) so the background shows around every panel.
- **Cycle visualization:** The cycle as a lunar orbit. A large circle where each day is a
  small moon glyph whose fill shows progress through the cycle (new moon on day 1, full
  around ovulation, waning in the luteal phase). Drag a scrubber around the orbit
  (like Stardust and Moonlitt's time travel) to see any day. The period arc glows rose,
  the fertile window glows cyan, and predictions twinkle faintly.
- **Navigation:** A floating glass capsule tab bar centered at the bottom, with icons
  only and a glowing dot under the active one.
- **Motion:** Slow parallax of the star field on scroll and device tilt; glow pulses on
  today; panels rise and blur in; the orbit scrubber has detent haptics on each day.
- **Signature details:** Night mode as the default; a "tonight" greeting; moon-phase
  icons in the calendar; an ambient lock-screen-style widget.
- **Risks:** Astrology associations can undermine credibility (keep it lunar, not
  zodiac); glass blur is expensive on low-end Android and on Flutter web; low-contrast
  text on glass; dark-only apps can be hard to read in daylight.
- **Best for:** Users who track at night and want a soothing, private ritual.

### Direction 6: Toybox (playful tactile and 3D)

**Inspired by:** Finch, Bears Gratitude, grug, (Not Boring) apps, Airbnb's 2025 3D
icons, Duolingo, Rooms, CapWords' stickers.

- **Mood:** joyful, chunky, friendly, rewarding, de-stigmatizing.
- **Type pairing:**
  - Display: **Gabarito** 800 to 900 for headings and numerals.
  - Body: **DM Sans** 400, 500, and 700.
  - Stickers and badges: **Gabarito** 700 in all caps with tight tracking.
- **Palette, light:**
  - Background `#FFF6EC` (cream), surface `#FFFFFF`, edge shadow `#E8D9C6`
  - Text `#2D1B14`, secondary `#7A6458`
  - Period `#FF5C5C` (tomato), fertile `#2EC4A6` (mint), follicular `#FFB830`
    (marigold), luteal `#8C6CF0` (grape), accent `#FF8FB1` (bubblegum, used sparingly)
- **Palette, dark:**
  - Background `#1E1612`, surface `#2A201B`, edge shadow `#120D0A`
  - Text `#FFF1E6`, secondary `#C2AA9C`
  - Period `#FF6B6B`, fertile `#3DD6B6`, follicular `#FFC24D`, luteal `#A08BFF`
- **Shape and spacing:**
  - Chunky, pressable elements: 20 to 28 px radius plus a solid 4 to 6 px bottom
    "edge" in a darker shade, which collapses when pressed (the button sinks).
  - Thick 2 px outlines in the text color on illustrations and stickers.
  - Generous padding (16 to 24 px inside controls).
- **Cycle visualization:** A "flower clock": each day is a petal around a center, and
  petals fill with color as days are logged. Period petals are tomato, fertile petals
  mint. Today's petal is lifted with a shadow. Completing a cycle produces a collectible
  pressed-flower sticker for a "garden" history screen. Optional mascot: a small seed or
  bud character that grows through the cycle.
- **Navigation:** A chunky floating tab bar with 3D-style icons (a flower, a calendar, a
  journal) and a large central "log" button that bounces.
- **Motion:** Bouncy springs with overshoot; squash and stretch on presses; confetti or
  petal bursts on logging; haptics on every press; optional soft sounds.
- **Signature details:** Sticker-style symptom icons; a "garden" of past cycles; badges
  for logging streaks (gentle, never punishing missed days); Airbnb-style 3D object
  icons rendered once as PNG or Lottie assets.
- **Risks:** Can feel childish for a health topic, especially for users dealing with
  infertility, pregnancy loss, or pain; streak mechanics can create guilt; 3D assets need
  a consistent render pipeline and add app size; harder to make accessible.
- **Best for:** Teens and younger users, and making logging habitual.

### Comparison

| Direction | Feel | Build effort in Flutter | Distinctiveness | Main risk |
|---|---|---|---|---|
| Almanac | Literary, private | Low to medium | High | Small serif legibility |
| Bloom Field | Warm, organic | High (shaders, blobs) | Very high | Performance, muddy gradients |
| Bento Bold | Data-forward | Medium | Medium | Clinical, cliche |
| Quiet Mono | Minimal, discreet | Low | Medium | Cold, needs perfect detailing |
| Nocturne | Lunar, dreamy | Medium to high (blur) | High | Astrology vibe, blur cost |
| Toybox | Joyful, tactile | High (assets) | High | Childish for serious moments |

Hybrids work well. For example, Almanac typography with a Bloom Field hero blob, or
Quiet Mono structure with a Nocturne dark theme.

---

## Part 4: Removing the Material feel from a Flutter app

These are techniques, not code. Each one removes a recognizable Material tell.

### Touch feedback

- Turn off ink ripples and splashes globally: set the theme's splash factory to "no
  splash" and make highlight, hover, and focus overlay colors transparent.
- Replace them with your own press states: scale the pressed element down to about 96 to
  97 percent with a spring, dim it slightly, or sink a chunky button's bottom edge.
- Add light haptics (selection click or light impact) on toggles, day selection,
  scrubbers, and saves. Haptics do nothing on web, so make sure the visual feedback is
  enough alone.

### Surfaces and elevation

- Material 3 tints elevated surfaces with the primary color. Turn surface tint off for
  cards, sheets, app bars, and dialogs.
- Replace elevation shadows with either no shadow, a 1 px hairline, or a custom, very
  soft, large-blur shadow tinted with the background hue.
- Use continuous (superellipse or squircle) corners instead of circular ones for large
  surfaces. Flutter's continuous rectangle border approximates this; community squircle
  packages are closer to Apple's shape.

### Color

- Do not generate the palette from a seed color. Seed-generated tonal palettes are the
  strongest Material 3 signature. Define every role by hand.
- Use phase colors semantically and a neutral or textured background instead of tinted
  `surface` containers.
- Add background atmosphere: a gradient, a grain image overlay, or a fragment shader for
  mesh gradients and noise. Test shaders on Flutter web, where renderer support differs.

### Typography

- Replace the default Material type scale. Define your own roles (for example: hero
  numeral, display, title, body, label, data) rather than display/headline/title large,
  medium, and small.
- Use larger jumps between levels, tight negative letter spacing at display sizes,
  slightly positive tracking on small uppercase labels, and tabular figures for numbers
  that change.
- Bundle font files as assets. If you use the `google_fonts` package, disable runtime
  fetching, because Bloom is offline.
- Check variable font axes (such as Fraunces `opsz` and `SOFT`, Archivo `wdth`) on both
  Android and web, because axis support varies by renderer.

### Navigation

- Replace the Material navigation bar with a custom floating bar built in a stack over
  the content: a pill or capsule detached from the bottom edge, with your own indicator
  animation. Pad scrollable content so the last item is not hidden behind it.
- Consider fewer destinations. Many premium apps use one home screen, a single floating
  action, and sheets, with no tab bar.
- Replace the Material app bar with large custom titles that collapse on scroll, built
  from slivers, or with no app bar at all.

### Page transitions

- The default Android transition (zoom or fade-up) marks an app as Material. Set a custom
  page transitions theme for every platform: a horizontal slide with parallax (iOS
  style), a fade-through, or a shared-axis transition with your own timing.
- Use hero (shared element) transitions from a tile or day to its detail screen.
- Present logging and detail views as custom bottom sheets with a grab handle, rounded
  top corners, and a spring, rather than full-screen Material routes or dialogs.

### Scrolling

- Use bouncing scroll physics everywhere through a custom scroll behavior, and remove the
  Android glow or stretch overscroll indicator.
- Use snapping physics for day strips and carousels, so the selected day always lands
  centered.

### Components

- Rebuild chips as pills or pebbles with your own selected state (fill change plus a
  small check or dot), not tonal Material chips.
- Rebuild buttons with your own shapes, padding, and press states. Avoid the stock
  filled, tonal, and outlined button set.
- Replace switches, checkboxes, and sliders with custom ones; these are highly
  recognizable Material widgets. Cupertino versions are a quick interim step.
- Replace snackbars with small floating toasts and dialogs with sheets.
- Replace Material Icons with a different icon family that matches the direction (for
  example Phosphor or Lucide for line icons, or custom drawn icons), and keep one
  stroke weight.

### Motion

- Use spring simulations instead of fixed-curve tweens for interactive elements.
- Stagger list and tile entrances slightly (20 to 40 ms per item).
- Honor the platform's reduced-motion setting and disable ambient animation when it is
  on.

### Verification

- Check every direction against WCAG AA contrast, large font sizes, and a screen reader.
- Test on a low-end Android device and on Flutter web, because blur, shaders, and large
  variable fonts are the usual performance problems.

---

## Part 5: Sources

- [Apple Newsroom: 2026 Apple Design Award winners and finalists](https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/)
- [Apple Developer: ADA Q&A with Moonlitt](https://developer.apple.com/news/?id=v1nphz91)
- [Apple Newsroom: 2025 Apple Design Award winners and finalists](https://www.apple.com/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards/)
- [9to5Mac: 2025 Apple Design Award winners](https://9to5mac.com/2025/06/03/apple-announces-2025-apple-design-award-winners/)
- [Apple Newsroom: 2024 Apple Design Award winners](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards)
- [Sketch blog: Gentler Streak](https://sketch.com/blog/gentler-streak)
- [How We Feel Substack: design of the Mood Meter](https://howwefeel.substack.com/p/we-feelgrateful)
- [Apple App Store story: How We Feel](https://apps.apple.com/story/id1638393948)
- [Screens Design: Stardust showcase](https://screensdesign.com/showcase/stardust-period-pregnancy)
- [The C-Word: Stardust review](https://www.thecwordmag.co.uk/c-word-loves/stardust-app-review-the-period-tracking-app-for-modern-witches)
- [Mozilla Foundation: Stardust privacy review](https://www.mozillafoundation.org/fy-NL/nothing-personal/stardust-privacy-review/)
- [Behance: Clue UI/UX case study](https://www.behance.net/gallery/114333427/Clue-UI-UX-case-study/report)
- [Android Developers Blog: Clue rebuilt with Jetpack Compose](https://android-developers.googleblog.com/2023/04/clues-development-speed-improves-after-rebuilding-with-jetpack-compose.html)
- [9to5Google: Oura app redesign (October 2025)](https://9to5google.com/2025/10/20/oura-app-redesign/)
- [Instrument: Oura app case study](https://instrument.com/work/oura-app)
- [It's Nice That: Headspace visual identity by Italic Studio](https://itsnicethat.com/articles/italic-studio-headspace-graphic-design-project-250424)
- [Design Compass: Headspace rebranding](https://designcompass.org/en/2024/04/30/headspace/)
- [It's Nice That: Airbnb app redesign](https://www.itsnicethat.com/articles/airbnb-app-redesign-140525)
- [Bloomberg: Big Tech and the end of flat design](https://www.bloomberg.com/news/articles/2025-06-13/apple-airbnb-ditch-flat-app-icons-for-new-3d-ui-design)
- [Design Compass: Airbnb's new design system](https://designcompass.org/en/2025/07/04/airbnb-new-design-system/)
- [Opal: Apple Design Award finalist](https://opalapp.com/blog/apple-design-award-finalist)
- [Opal: The milestone reveal moment](https://opal.so/blog/the-milestone-reveal-moment)
- [Opal partner brand kit](https://brandkit.opal.so)
- [Rise help center: Energy Schedule](https://help.risescience.com/hc/en-us/articles/6654243671191-What-is-my-Daily-Energy-Energy-Schedule)
- [TapSmart: (Not Boring) Habits review](https://www.tapsmart.com/apps/review-not-boring-habits/)
- [Apple App Store: Behind the Design, (Not Boring) Habits](https://apps.apple.com/us/story/id1556321408)
- [Pratt IxD: Finch design critique](https://ixd.prattsi.org/2024/09/design-critique-finch-ios-app)
- [Pixelfield: UI design trends 2025 to 2026](https://pixelfield.co.uk/blog/ui-design-trends-2025-26/)
- [Google Fonts](https://fonts.google.com) for font availability and licenses

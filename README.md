# Bloom

Bloom is a free, open-source period, fertility, and pregnancy tracker for the web and
Android, built with Flutter. It works fully offline. There's no account, and your data
stays on your device.

Bloom covers the features of the popular commercial trackers, including the ones they
put behind a subscription. For the full feature inventory, see
[`bloom_docs/FLO_FEATURES.md`](../bloom_docs/FLO_FEATURES.md).

## Features

- **Cycle tracking:** period and ovulation predictions, a fertile window, chance of
  pregnancy, detection from LH tests and basal body temperature, and a regularity check
  based on ACOG ranges.
- **Daily logging:** 125 options across 16 categories, plus water, sleep,
  weight, basal temperature, steps, energy, and notes. You can show, hide, and reorder
  categories.
- **Calendar:** month and year views, a day detail panel, and a screen for editing
  period dates.
- **Graphs and reports:** cycle history, charts, symptom statistics by phase, pattern
  detection, and a PDF report for a doctor.
- **Life stages:** pregnancy mode (week by week, kick counter, contraction timer, weight,
  checklist), after-birth mode (recovery timeline, feeding log), and perimenopause mode
  (symptom score, stage estimate, relief options).
- **Insights:** 36 original articles, 11 quizzes, daily insight stories, a well-being
  score, and a private journal.
- **Assistant:** an offline, scripted assistant that uses your data, and educational
  symptom checkers for PCOS, endometriosis, and fibroids.
- **Reminders:** period, fertility, birth control, and wellness reminders. They appear as
  system notifications on Android and as an in-app banner on the web.
- **Privacy:** a PIN app lock, JSON backup, export and import, CSV export, and an option
  to delete all data.
- **Partner sharing:** a read-only snapshot that you share as a code or QR code.

Bloom isn't a medical device or a method of birth control.

## Run the app

Before you begin, set up the toolchain. The Flutter SDK, JDK, and Android SDK live in
`../.tooling/`. To use them, run the following command from this folder:

```bash
source ../.tooling/env.sh
```

To run the web version in Chrome, run the following command:

```bash
flutter run -d chrome
```

To try the app with sample data, on the welcome screen, click **Load demo data**.

To build a release web bundle into `build/web`, run the following command:

```bash
flutter build web --release
```

To build an Android APK, run the following command:

```bash
flutter build apk --release
```

## Test

To run the static analysis and the test suite, run the following commands:

```bash
flutter analyze
```

```bash
flutter test
```

## Project layout

The code is organized as follows:

- `lib/core/`: models, the logging catalog, the cycle prediction engine, and the
  persisted store.
- `lib/theme/` and `lib/widgets/`: the design system. For more information, see
  [`bloom_docs/DESIGN.md`](../bloom_docs/DESIGN.md).
- `lib/features/`: one folder for each feature area.
- `test/`: unit and widget tests. `test/support/screenshot.dart` renders screens to PNG
  files for visual review.

## License

The code is available under the MIT License. The bundled fonts (Outfit, Nunito, and a
subset of Noto Color Emoji) use the SIL Open Font License 1.1. Their license texts are in
`assets/fonts/`.

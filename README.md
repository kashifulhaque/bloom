# Bloom

Bloom is a free, open-source period, fertility, and pregnancy tracker for the web and
Android, built with Flutter. It works fully offline. There's no account, and your data
stays on your device. The only exception is the optional AI answers in **Ask**, which are
off until you turn them on.

Bloom covers the features of the popular commercial trackers, including the ones they
put behind a subscription. For the full feature inventory, see
[`docs/FLO_FEATURES.md`](docs/FLO_FEATURES.md).

Try it at https://bloom.ifkash.dev. The web app's **You > Get the app** page has the
Android APK and an unsigned iOS build.

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
- **Assistant:** an offline, scripted assistant that uses your data, educational
  symptom checkers for PCOS, endometriosis, and fibroids, and optional AI answers from
  free models.
- **Reminders:** period, fertility, birth control, and wellness reminders. They appear as
  system notifications on Android and as an in-app banner on the web.
- **Privacy:** a PIN app lock, JSON backup, export and import, CSV export, and an option
  to delete all data.
- **Partner sharing:** a read-only snapshot that you share as a code or QR code.

Bloom isn't a medical device or a method of birth control.

## Run the app

Before you begin, install Flutter 3.50 from the stable channel. To build for Android,
also install JDK 17 and the Android SDK; `flutter doctor` reports anything missing.

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

## AI answers

The **Ask** tab can answer typed questions with a free AI model through
[OpenRouter](https://openrouter.ai). AI answers are optional and off by default. The
scripted topics, the symptom checkers, and the urgent and crisis answers always stay
offline.

### Choose where answers come from

Bloom picks the first of the following sources that's set up:

1. **A key that you enter in the app.** Bloom sends questions straight to OpenRouter.
1. **A key compiled in at build time** (`OPENROUTER_API_KEY`). Bloom sends questions
   straight to OpenRouter. Use this only for local development.
1. **Bloom's hosted proxy** (`BLOOM_AI_PROXY`). Bloom sends questions to the proxy
   without a key. The proxy adds its own OpenRouter key and forwards the request
   unchanged.

If none of these is set up, AI answers aren't available, and **Ask** answers offline. The
**AI answers** page names the source in use.

### Use the hosted proxy

The proxy keeps the OpenRouter key on the server, so the key never ships in the app. The
public build at https://bloom.ifkash.dev serves the proxy at `POST /api/ai/chat`. The
proxy limits how many requests each IP address can send, and Bloom shows a "busy" message
when it reaches that limit.

To point a build at the proxy, set `BLOOM_AI_PROXY` with the `--dart-define` flag:

- For the web build that the proxy's host serves, use a path. Bloom resolves it against
  the page's own origin:

  ```bash
  flutter build web --release --dart-define=BLOOM_AI_PROXY=/api/ai/chat
  ```

- For Android and iOS builds, use the full HTTPS URL:

  ```bash
  flutter build apk --release --dart-define=BLOOM_AI_PROXY=https://bloom.ifkash.dev/api/ai/chat
  ```

A key that the user enters in the app still takes priority over the proxy.

### Add an OpenRouter key

To enter a key in the app, in **Ask**, click **More > AI answers**, paste the key in the
**OpenRouter key** field, and then click **Save key**. To check the key, click
**Test connection**. The same page is in **You > AI answers in Ask**.

To compile a key into the app, do the following:

1. In this folder, copy `.env.example` to `.env`. Git ignores `.env`.
1. In `.env`, set `OPENROUTER_API_KEY` to your key.
1. Run the app or build it with the `--dart-define-from-file` flag:

   ```bash
   flutter run -d chrome --dart-define-from-file=.env
   ```

   ```bash
   flutter build web --release --dart-define-from-file=.env
   ```

**Caution:** Anyone who has the built app can extract a compiled-in key. Use a build-time
key only for local development. For builds that you share, leave the key out and use
`BLOOM_AI_PROXY`, or let each person enter their own key in the app.

### Free models only

Bloom asks for larger free models only, whichever source it uses. The list is `kAiModels`
in `lib/features/assistant/ai/openrouter_client.dart`, in order of preference:

1. `google/gemma-4-31b-it:free`
1. `nvidia/nemotron-3-ultra-550b-a55b:free`
1. `google/gemma-4-26b-a4b-it:free`
1. `nvidia/nemotron-3.5-super-vl:free`

Bloom doesn't use the `openrouter/free` router, because it can pick very small models that
get health facts wrong. Each request names the first three models, and OpenRouter answers
with the first one that's available. Bloom asks a second time, at most, in two cases:

- OpenRouter rejects a model ID that it no longer lists. Bloom drops that ID.
- None of the three models can answer. Bloom tries the fourth.

The app has no setting to change the models, and the client rejects any model ID that
doesn't end in `:free`. For extra protection, we recommend that you also restrict your
OpenRouter key to free models. Free models change over time, so check the list against
https://openrouter.ai/api/v1/models and update it when a model is retired.

Free models have rate limits: about 20 requests a minute and a daily cap. If a request
returns a "no endpoints" error, in your OpenRouter privacy settings, allow the free model
providers. If the error mentions a guardrail, the key's restrictions block the model; in
the key's settings, allow free models.

These free models reason before they answer, which spends part of the answer budget on
hidden reasoning. Bloom asks for up to 900 tokens. If a model runs out before it writes an
answer, Bloom shows **Try again**.

### Privacy

The first time that you turn on AI answers, Bloom explains what leaves the device and asks
for your consent. Each request sends the following to OpenRouter and to the model
provider that answers. With the proxy, the request goes to `bloom.ifkash.dev` first, which
also sees your IP address:

- Instructions that describe the assistant's role and limits.
- Your last few typed questions and the AI answers to them.
- Optional: a short cycle summary, only when **Include my cycle summary** is on. The
  summary contains your goal, cycle day and phase, average cycle and period length,
  regularity, days late, pregnancy week, your most-logged symptoms and moods from the last
  30 days, and a five-year age bracket. To see the exact text, go to the **What's shared**
  section of the AI answers page.

Bloom never sends your name, notes, journal, birth year, or any dates. Free model providers
might log prompts or use them for training. AI answers can be wrong and aren't medical
advice.

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
  [`docs/DESIGN.md`](docs/DESIGN.md).
- `lib/features/`: one folder for each feature area.
- `test/`: unit and widget tests. `test/support/screenshot.dart` renders screens to PNG
  files for visual review.

## Deploy

The **Build and deploy** workflow (`.github/workflows/deploy.yml`) runs on every push to
`main`. It tests the app, builds a signed Android APK and an unsigned iOS app, builds the
web app, and packages all three into a container image. Then it deploys the image to
https://bloom.ifkash.dev.

The site serves the builds at the following paths:

- `/downloads/bloom.apk`: the signed Android release build.
- `/downloads/bloom-unsigned.ipa`: the iOS build. You must sign it to install it.
- `/downloads/manifest.json`: the version, file sizes, SHA-256 checksums, and the
  SHA-256 fingerprint of the Android signing certificate.

The same files are attached to the `latest` release on GitHub.

### Sign Android release builds

Release builds read the signing key from a `key.properties` file with the following
keys: `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. A relative
`storeFile` path resolves against the folder that holds `key.properties`.

To build a signed APK, point `BLOOM_KEY_PROPERTIES` at the file:

```bash
BLOOM_KEY_PROPERTIES=PATH_TO_KEY_PROPERTIES flutter build apk --release
```

Replace `PATH_TO_KEY_PROPERTIES` with the path to your `key.properties` file. Keep the
file and the keystore outside the repository. If `BLOOM_KEY_PROPERTIES` isn't set, the
build reads `android/key.properties`, which Git ignores. If neither file exists, the
build signs with the debug key and prints a warning. Don't distribute that APK.

To check the signature, run the following command:

```bash
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The SHA-256 digest of the signer certificate must match the one in
`/downloads/manifest.json`.

### Configure the repository

The workflow needs the following repository secrets:

- `ANDROID_KEYSTORE_BASE64`: the release keystore, encoded with `base64`.
- `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD`: the keystore and key
  passwords. The key alias is `bloom`.
- `VM_SSH_KEY`: the private SSH key that the workflow uses to deploy.
- `VM_KNOWN_HOSTS`: the VM's host keys, as `ssh-keyscan` prints them.
- `VM_HOST` and `VM_USER`: the VM's host name and the account that runs Docker.

You can also set the following repository variables:

- `ANDROID_CERT_SHA256`: the expected certificate fingerprint. The workflow has a
  built-in default.
- `IMAGE_PLATFORMS`: the image platforms. The default is `linux/amd64`.

### Run the container

The image (`ghcr.io/kashifulhaque/bloom`) runs nginx as an unprivileged user on port
`8080`. It only packages files that CI builds, so the build context must contain
`build/web/` and `downloads/`. The container works with a read-only root file system
when `/tmp` is a tmpfs.

The container serves the following:

- The web app, with every other path falling back to `index.html`.
- `/healthz`, which returns `200`.
- `/api/ai/chat`, a proxy to OpenRouter that adds the server's key. Set the key in
  the `OPENROUTER_API_KEY` environment variable. Without a key, the proxy returns `503`.
  It accepts only `POST` requests of up to 32 KB, and it allows each client address 6
  requests a minute, with a burst of 4.

To set up the VM, do the following:

1. Copy `deploy/compose.yaml` and `deploy/deploy.sh` to `~/docs/apps/bloom/`.
1. In the same folder, create a `.env` file that contains
   `OPENROUTER_API_KEY=YOUR_KEY`, and run `chmod 600 .env`.
1. In `~/.ssh/authorized_keys`, restrict the deploy key to the deploy script:

   ```none
   command="/home/ifkash/docs/apps/bloom/deploy.sh",restrict ssh-ed25519 PUBLIC_KEY bloom-ci
   ```

1. Add the block in `deploy/caddy.snippet` to the Caddyfile, and reload Caddy.

Replace the following:

- `YOUR_KEY`: the OpenRouter API key.
- `PUBLIC_KEY`: the public half of `VM_SSH_KEY`.

The workflow sends a short-lived registry token to `deploy.sh`, which pulls the image and
restarts the container. Then the workflow checks that the site serves the new version.

## License

The code is available under the MIT License. The bundled fonts (Outfit, Nunito, and a
subset of Noto Color Emoji) use the SIL Open Font License 1.1. Their license texts are in
`assets/fonts/`.

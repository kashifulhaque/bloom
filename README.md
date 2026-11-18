# Bloom

Bloom is a free, open-source period, fertility, and pregnancy tracker for the web and
Android, built with Flutter. It works fully offline. You don't need an account, and your
data stays on your device. The exceptions are the optional AI answers in **Ask**,
optional end-to-end encrypted sync, and end-to-end encrypted report links that you
choose to share. All three are off until you use them.

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
- **Privacy:** a PIN app lock, JSON backup, export and import, CSV export, import from
  Flo, Clue, Apple Health, and other apps, and an
  option to delete all data.
- **Sync:** optional, end-to-end encrypted sync between your phone and the web, unlocked
  with a 12-word recovery phrase.
- **Partner sharing:** a read-only snapshot that you share as a code or QR code.
- **Report for a doctor:** a PDF to print or share, or an end-to-end encrypted link that
  expires after 1, 7, or 30 days and that you can turn off at any time. For more
  information, see [`docs/REPORT_SHARING.md`](docs/REPORT_SHARING.md).

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

## Import from another app

Bloom can import your history from another period tracker. To start, go to **You > My
data > Import from another app**, or on the welcome page, tap **Coming from another
app?** Bloom shows how to export from each app, previews what it found, and then asks
whether to add the import to your data or replace your data with it.

Bloom reads the following exports:

- **Apple Health:** `export.zip` from **Export All Health Data**. Bloom streams the file,
  so exports of several gigabytes work.
- **Clue:** the password-protected ZIP from **Download my data**, or the
  `measurements.json` file inside it. Older `.cluedata` backups also work.
- **Flo:** the JSON export that Flo's support team sends on request, with or without its
  password-protected ZIP. Flo's export has no flow levels, so periods arrive without one.
- **drip:** the CSV export.
- **Mensinator:** the JSON export.
- **Any other app:** a CSV file with a date column. Bloom asks which column holds the
  date, flow, temperature, and notes.

Bloom detects the format from the file's contents. It reads the file on the device and
never uploads it. When sync is on, imported days sync like days that you log by hand. The
preview lists everything that Bloom can't map, so nothing is left out without a count.
Bloom can't read Android Health Connect exports, because their format isn't documented.

For the formats, the mappings, and their sources, see
[`docs/IMPORT_FORMATS.md`](docs/IMPORT_FORMATS.md).

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

Bloom doesn't use the `openrouter/free` router by default, because it can pick very small
models that get health facts wrong. Each request names the first three models, and OpenRouter answers
with the first one that's available. Bloom asks again only in the following cases:

- OpenRouter rejects a model ID that it no longer lists. Bloom drops that ID and asks the
  remaining models. If OpenRouter no longer lists any of them, Bloom asks the
  `openrouter/free` router once as a last resort, so an outdated list doesn't turn AI
  answers off.
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

## Sync

Sync keeps Bloom the same on Android, iOS, and the web. It's optional and off by default,
and a build without sync settings works exactly as before. To turn it on, in the app, go
to **You > Sync**, sign in with a 6-digit code that Bloom emails you, and save your
recovery phrase.

To set up a new device from an account that already has sync on, tap **Already have an
account?** on the welcome page. Sign in with the emailed code and enter your recovery
phrase. Bloom restores your synced data, skips the setup questions, and keeps sync on. The
welcome page shows this option only in builds that have sync.

### What's encrypted

Bloom encrypts every record on the device before upload, so the server stores only
ciphertext:

- **Records.** Each day log, the profile, each feature (such as the journal or pregnancy
  settings), and each month of period days is one record, encrypted with
  XChaCha20-Poly1305 under a random 256-bit data key. The associated data binds each
  ciphertext to its row, so the server can't swap rows or replay old content.
- **Record IDs.** A record's ID is an HMAC-SHA256 of its plaintext key, such as a date, so
  the server can't see which days have logs.
- **The data key.** Argon2id derives a key from the 12-word recovery phrase and a random
  salt, and that key wraps the data key. Only the wrapped key, the salt, and the Argon2id
  parameters go to the server.

The server can see your email address, how many records you have, when they change, their
sizes, and your IP address. Your app-lock PIN, your OpenRouter key, and the AI answers
settings stay on each device.

On Android and iOS, the unwrapped data key is in the Keystore or Keychain. On the web, a
non-extractable WebCrypto AES-GCM key in IndexedDB wraps it. Signing out removes the key
from the device.

If you lose the recovery phrase and every device that has sync on, nobody can recover
the synced data. Bloom says so before you turn sync on.

For the design, see [`docs/SYNC_PLAN.md`](docs/SYNC_PLAN.md).

### Configure a build

A build has sync when it has both of the following values. Neither one is secret: the
publishable key identifies the project, and row-level security protects the data.

- `SUPABASE_URL`: the project URL, such as `https://PROJECT_REF.supabase.co`.
- `SUPABASE_PUBLISHABLE_KEY`: the project's publishable key (`sb_publishable_...`).

Add them to `.env`, and then pass the file to the build:

```bash
flutter build web --release --dart-define-from-file=.env
```

Replace `PROJECT_REF` with the project reference. Never put the secret key or the service
role key in `.env` or in the app.

The web build loads `web/sodium.js` (libsodium.js, ISC License) the first time it derives
a key. The Content-Security-Policy must allow the project URL in `connect-src`. The
policy in `deploy/nginx/templates/bloom.conf.template` already does.

### Run the local stack

The Supabase CLI is a development dependency in `package.json`. To work against a local
stack, do the following:

1. Start Docker, and then start the stack:

   ```bash
   npm install
   npx supabase start
   ```

   The command applies the migrations in `supabase/migrations/` and prints the local URL
   and keys.

1. Run the database tests and the advisors:

   ```bash
   npx supabase test db
   npx supabase db advisors --type all --level info
   ```

1. Run the integration test. It reads the local URL and publishable key from
   `npx supabase status`, serves the Edge Functions, reads sign-in codes from the local
   Mailpit inbox, and refuses to run against anything but `127.0.0.1` or `localhost`:

   ```bash
   tool/sync_integration_test.sh
   ```

1. Optional: run the app against the local stack:

   ```bash
   flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=LOCAL_PUBLISHABLE_KEY
   ```

   Replace `LOCAL_PUBLISHABLE_KEY` with the publishable key that `npx supabase status`
   prints. Sign-in emails appear in Mailpit at http://127.0.0.1:54324.

1. When you're done, stop the stack:

   ```bash
   npx supabase stop
   ```

### Deploy sync

To deploy sync to the hosted project, do the following:

1. Push the migration to the linked project. If this folder isn't linked yet, first run
   `npx supabase link --project-ref PROJECT_REF`. `db push` prompts for the database
   password, or reads `SUPABASE_DB_PASSWORD`:

   ```bash
   npx supabase db push --dry-run
   npx supabase db push
   ```

1. Run the advisors against the project:

   ```bash
   npx supabase db advisors --remote --type all --level info
   ```

1. Deploy the Edge Function:

   ```bash
   npx supabase functions deploy delete-account
   ```

   The function reads the project URL, its keys, and the signing keys from the hosted
   environment. It needs no secrets of its own.

1. In the dashboard, under **Authentication**, set the following:

   - **Sign In / Providers > Email**: turn on **Email**, set **Email OTP Length** to 6
     and **Email OTP Expiration** to 600 seconds.
   - **Emails > Templates > Magic Link**: include `{{ .Token }}`, as in
     `supabase/templates/otp_code.html`. Without it, the email has a link but no code.
     Do the same for **Confirm signup** if email confirmations are on. New free-plan
     projects can only edit templates after you set up custom SMTP.
   - **Sessions**: set the access token (JWT) expiry to 900 seconds.
   - **URL Configuration**: set **Site URL** to `https://bloom.ifkash.dev`. Bloom signs in
     with a typed code, so it doesn't need redirect URLs.

   Don't use `npx supabase config push` for these settings: `config.toml` holds local
   values, such as the local site URL, that would replace the project's.

1. Add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` to the build: in `.env` for local
   builds, and as `--dart-define` values in the workflow's web, Android, and iOS build
   steps.

## Updates

Bloom isn't in an app store, so it checks its own website for new versions. A check is
one `GET` request for `https://bloom.ifkash.dev/downloads/manifest.json`, the release
manifest that CI builds. The request carries no account, device ID, or notebook data.
Checks run in the background after launch and when the app resumes, and a failed check
stays silent.

Bloom compares the manifest's build number with its own. The running build number comes
from `--build-number`, which Flutter compiles into the app as `appBuildNumber`, so every
CI build, including the web build, must pass `--build-number=${{ github.run_number }}`.

When a newer build is available, **Today** shows a short note. What the note offers
depends on the platform:

- **Android:** at most one check a day. **Download update** opens the APK in the browser.
  When you open the downloaded file, Android asks whether to install an update to the
  existing app; if the browser doesn't have the **Install unknown apps** permission,
  Android asks for it first. Every release is signed with the same key, so the APK
  installs over the old one and keeps your data. **Not now** hides that version for 7
  days.
- **iPhone:** at most one check a week. The unsigned IPA can't update itself, so the note
  links to the web app and its **Get the app** page (`/#/get-app`). **Not now** hides
  that version for 30 days.
- **Web:** at most one check every 6 hours while a tab is open. **Reload** loads the
  newest deployment. nginx serves the entry files, `version.json`, and everything under
  `/downloads/` with `Cache-Control: no-cache`, so a reload and a check never read a
  stale copy.

If the manifest has a `notes` field, the note shows it. CI sets `notes` to the subject
line of the commit that it built.

To see the version, check for updates, or turn automatic checks off, go to **You >
Settings > Updates**. The same controls are on the **About & privacy** page.

## Test

To run the static analysis and the test suite, run the following commands:

```bash
flutter analyze
```

```bash
flutter test
```

The sync crypto and engine tests also run in Chrome, which checks that the web build
produces the same bytes:

```bash
flutter test --platform chrome test/sync_crypto_test.dart test/sync_engine_test.dart
```

The integration test in `test/integration/` is skipped unless you run it with
`tool/sync_integration_test.sh`. For more information, see [Run the local
stack](#run-the-local-stack).

## Project layout

The code is organized as follows:

- `lib/core/`: models, the logging catalog, the cycle prediction engine, and the
  persisted store.
- `lib/theme/` and `lib/widgets/`: the design system. For more information, see
  [`docs/DESIGN.md`](docs/DESIGN.md).
- `lib/core/sync/`: sync without UI code: encryption, the record codec, the hybrid
  logical clock, the sync engine, and the Supabase client.
- `lib/features/`: one folder for each feature area. The Sync screens are in
  `lib/features/sync/`.
- `supabase/`: the database migration, its pgTAP tests, the `delete-account` Edge
  Function, and the local stack's settings.
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
- `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`: the Supabase project for sync. Both are
  public by design, because row-level security protects the data. Without them, the
  builds show that sync isn't configured.

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
- `/api/share`, a proxy to the `report-share` Edge Function for report links, and
  `/r/ID`, the page that opens them. Set `BLOOM_SHARE_UPSTREAM` and
  `BLOOM_SHARE_PROXY_SECRET`. Without both, `/api/share` returns `503`. For more
  information, see [`docs/REPORT_SHARING.md`](docs/REPORT_SHARING.md).

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
`assets/fonts/`. `web/sodium.js` is libsodium.js under the ISC License
(`web/sodium.LICENSE.txt`), and the recovery phrase uses the BIP-39 English wordlist
under the MIT License (`lib/core/sync/crypto/bip39_english.dart`).

# Flo feature inventory (free and premium)

This document inventories the features of the Flo period and ovulation tracker by Flo
Health, as of 2025-2026, and splits them into free and premium (Flo Premium) tiers. It
ends with a recommended scope for an offline, open-source Flutter clone.

All descriptions are summarized in our own words. Flo, Flo Premium, Flo for Partners,
Secret Chats, Flori, and related names are trademarks of Flo Health; a clone must use
its own names, colors, icons, and copy.

## How to read this document

Each feature has a tier tag:

- **FREE**: available without a subscription.
- **PREMIUM**: requires Flo Premium (paywalled, usually offered with a free trial).
- **MIXED**: a free base with premium extensions.
- **UNCLEAR**: sources conflict or don't state the tier.

Each option list also has a confidence marker:

- **[V]** Verified: stated in a Flo help article, a Flo store listing, or a
  peer-reviewed paper that used Flo data.
- **[R]** Reported: stated by a reputable third-party review, or partially confirmed.
- **[U]** Unverified: based on observed app versions and common knowledge of the app,
  not confirmed by a source found during this research. Confirm in the live app before
  relying on the exact label.

Flo changes paywalls often. Its App Store listing states that some features moved from
free to premium, and reviewers complain about this. Treat tiers as a snapshot.

## Pricing and subscription model

- The app is free to download. Cycle tracking and prediction stay free. **[V]**
- Flo Premium is sold as monthly and annual subscriptions with free trials. Reported
  US prices are about USD 39.99 per year and USD 11.49 per month; App Store in-app
  purchases range from USD 1.99 to USD 59.99. **[R]**
- The App Store lists goal-themed subscription products: Menstrual Cycle Tracker,
  Pregnancy Tracker, Ovulation & Health Tracker, Birth Control Reminder, and Women's
  Health & Wellbeing. These appear to be the same Premium entitlement sold under
  different paywall names. **[V]** (names) **[R]** (same entitlement)
- In the US, Flo Premium is listed as HSA and FSA eligible. **[V]**
- Tapping any locked feature opens a paywall with a trial offer. **[R]**

## Onboarding and goals

| Feature | Tier | Notes |
|---|---|---|
| Goal selection | FREE | **[V]** Goals: **Track cycle**, **Get pregnant** (trying to conceive), **Track pregnancy**. Perimenopause support is added as a goal or mode from July 2025. Change later in **Menu (avatar) > My goal**. Each goal changes trackers, content, and daily stories. |
| Last period start date | FREE | **[V]** Required for the first prediction. |
| Typical period length and cycle length | FREE | **[R]** Asked during onboarding, with an "I don't know" option that falls back to defaults (5-day period, 28-day cycle). **[U]** for defaults. |
| Year of birth and age gate | FREE | **[R]** Age affects content; some features (partner sharing, contraception logging) require age 18 or older (20 in South Korea for partners). **[V]** |
| Cycle regularity and health questions | FREE | **[U]** Questions about regular or irregular cycles, birth control use, known conditions (PCOS, endometriosis), and symptoms you want to manage. |
| Account creation or Anonymous Mode | FREE | **[V]** Email, Apple, or Google sign-in; Anonymous Mode as an alternative. |
| Personalized paywall at end of onboarding | n/a | **[R]** Trial offer shown after the questionnaire. |

## Cycle and period prediction

| Feature | Tier | Notes |
|---|---|---|
| Log period start and end | FREE | **[V]** **Log Period** button on the main screen; edit via **Calendar > Edit period dates**. |
| Next period prediction | FREE | **[V]** Shown as red dotted circles in the calendar. |
| Cycle day counter | FREE | **[V]** Shown on the main screen with days until the next period. |
| Late period and delay handling | FREE | **[V]** Health Assistant dialogs cover delays; base delay counter is free. |
| Predictions adapt to logged symptoms | FREE | **[V]** Logging some symptoms can shift predictions. |
| Irregular cycle support | FREE | **[V]** |
| Remove a large gap between cycles | FREE | **[V]** Help article on removing long gaps that skew averages. |
| "My cycles" block: normal and regular assessment | FREE | **[V]** Uses ACOG ranges: cycle 21-35 days, period 2-7 days, regular when the longest and shortest cycles differ by 7 days or less. Needs several logged cycles. |
| Cycle history list | FREE | **[V]** Past cycle and period lengths. |
| Birth control adjusts predictions | FREE | **[V]** Enabling a contraception reminder tells the app you use hormonal birth control; predictions and content change. |

## Fertile window and ovulation

| Feature | Tier | Notes |
|---|---|---|
| Fertile window prediction | FREE | **[V]** Teal days in the calendar. |
| Predicted ovulation day | FREE | **[V]** Day inside the teal dotted circle. |
| Chance of pregnancy indicator | FREE | **[V]** Shown on the main screen for the current day (low, medium, high). Levels **[U]**. |
| Ovulation test logging | FREE | **[V]** See the ovulation test option list. |
| Basal body temperature logging | FREE | **[V]** Hidden while tracking a pregnancy. |
| Fertility insights for trying to conceive | PREMIUM | **[V]** Personalized fertility analysis and content. |
| Detailed fertile-sign analysis | PREMIUM | **[R]** Reviewers report detailed fertility analysis moved behind the paywall. |

Flo states that it is not a method of birth control or a conception aid. **[V]**

## Daily logging

Open logging with **+** on the main screen (**Log your symptoms** card). **[V]** Facts
that apply to all trackers:

- Flo describes 16 trackers with more than 50 symptoms and events in one help article,
  and more than 80 in another; the store listing says more than 70. A 2021 study counts
  84 items on the symptom panel. **[V]**
- Each symptom can be logged once per day, at any time of day. **[V]**
- Many trackers accept several selections; flow accepts one. **[V]**
- **Edit** next to **Categories**, or **More parameters**, lets you show, hide, and
  reorder trackers. **[V]**
- You can log past days and edit or delete entries. **[V]**
- Some trackers are mode-specific: flow appears only during a period; ovulation test
  and BBT are hidden in pregnancy mode. **[V]**

All core logging is **FREE**. **[V]**

### Category option lists

The following list gives each category and its options. Categories named in the
peer-reviewed papers are: sex and sex drive, mood, symptoms, vaginal discharge, physical
activity, menstrual products, and other. **[V]**

**Menstrual flow** (single choice; visible only during a period) **[V]**

- Light
- Medium
- Heavy
- Blood clots

**Sex and sex drive** (multi-select)

- **[V]** Unprotected sex, High sex drive.
- **[U]** Didn't have sex, Protected sex, Oral sex, Anal sex, Masturbation, Sensual
  touch, Sex toys, Orgasm, Neutral sex drive, Low sex drive.

**Mood** (multi-select) **[V]** (full list from a 2023 study using Flo data)

- Calm
- Happy
- Energetic
- Frisky
- Mood swings
- Irritated
- Sad
- Anxious
- Depressed
- Feeling guilty
- Obsessive thoughts
- Apathetic
- Confused
- Very self-critical

**Symptoms** (multi-select) **[V]** (physiological list from the same study)

- Cramps
- Headache
- Abdominal pain
- Perineum pain
- Backache
- Tender breasts
- Swelling
- Fatigue
- Acne
- Bloating
- Cravings
- Nausea
- Diarrhea
- Insomnia
- Disease or injury

**[U]** Also seen in app versions: Everything is fine, Joint pain, Constipation
(sometimes under a separate digestion group).

**Vaginal discharge** (multi-select)

- **[V]** Creamy, Watery, Sticky, Spotting.
- **[U]** No discharge, Egg white, Unusual, Clumpy white, Gray.

**Digestion and stool** **[U]**

- Nausea, Bloating, Constipation, Diarrhea. Some versions place these under
  **Symptoms** instead of a separate tracker.

**Pregnancy test** **[R]** (category confirmed by reviews)

- **[U]** Didn't take tests, Positive, Negative, Faint line.

**Ovulation test** **[V]**

- Android: Didn't take tests, Test: positive, Test: negative, Ovulation: my method.
- iOS: log strip or digital tests, each with a tutorial. Log only a peak result as
  positive; peak, high, and negative results are distinguished for digital tests.

**Physical activity** (category confirmed **[V]**)

- **[U]** Didn't exercise, Yoga, Gym, Aerobics and dancing, Swimming, Team sports,
  Running, Cycling, Walking.
- Steps can be tracked from the phone's health data (help article on step data). **[V]**

**Oral contraceptives (pills)** **[V]**

- Taken on time is the documented status. You can log yesterday's pill.
- **[U]** Additional statuses: Missed, Taken late, Double dose.
- Emergency contraception can't be logged. **[V]**

**Menstrual products** (category confirmed **[V]**)

- **[U]** Pad, Tampon, Menstrual cup, Period underwear, Liner.

**Other** **[V]** Travel, Stress, Alcohol. **[U]** Also Meditation, Disease or injury
(duplicated in some versions).

**Measurements and numeric trackers**

| Tracker | Notes |
|---|---|
| Basal body temperature | **[V]** Picker value in °C or °F. |
| Weight | **[R]** Logged in kg or lb; also edited in pregnancy settings. |
| Water | **[R]** Water-intake logging with a reminder; glass count or volume **[U]**. |
| Sleep | **[R]** Sleep tracking listed in perimenopause and Flori features; hours or quality **[U]**. |
| Steps | **[V]** Read from Apple Health or Google Fit. |
| Notes | **[U]** Free-text note per day. |

## Calendar views

| Feature | Tier | Notes |
|---|---|---|
| Month calendar with color key | FREE | **[V]** Logged period days, predicted period (red dotted), fertile days (teal), ovulation day (teal dotted circle), post-ovulation days, pregnancy days (yellow). |
| Tap a day to view logs | FREE | **[V]** |
| Edit period dates mode | FREE | **[V]** Multi-select days to mark or unmark. |
| Year view and horizontal day strip | FREE | **[U]** |

## Today screen and daily content

| Feature | Tier | Notes |
|---|---|---|
| Main screen: cycle day, pregnancy chance, today's logs | FREE | **[V]** |
| Daily stories ("daily plans") | MIXED | **[V]** Story-format cards tailored to cycle day and goal; personalized daily insights are listed as premium. |
| Insights tab: articles, videos, courses | MIXED | **[V]** Some articles and videos moved to premium. |
| Expert-led video courses | PREMIUM | **[V]** |
| Quizzes | MIXED | **[R]** Short quizzes inside stories; a couples quiz in Flo for Partners **[V]**. |
| Flori well-being "battery" | PREMIUM | **[V]** Daily snapshot of how sleep, cycle, activity, and symptoms might affect your energy. Rolled out to eligible new members in version 10.1. |
| Weekly health insights | PREMIUM | **[V]** |

## Health Assistant, Symptom Checker, and reports

| Feature | Tier | Notes |
|---|---|---|
| Health Assistant (chat-style dialogs) | PREMIUM | **[V]** Scripted, medically reviewed dialogs about your logged data and cycle events (period, ovulation, delays). Listed as a 24/7 virtual assistant. Some event dialogs might be free **[U]**. |
| Extended cycle report via Health Assistant | PREMIUM | **[V]** |
| Symptom Checker | PREMIUM | **[V]** Educational questionnaires about PCOS, endometriosis, and uterine fibroids. Not offered in the UK, EU, EEA, or Switzerland. |
| Report for a doctor (PDF) | PREMIUM | **[V]** iOS. **Menu > Report for a doctor**. PDF of the last 6 cycles (including the current one), period lengths, detected patterns, and the top 5 symptoms. Share by email or print. Not available in pregnancy mode. |
| Graphs & reports | MIXED | **[V]** **Menu > Graphs & reports** shows logged data across cycles (cycle length, period length, symptoms). Basic charts free; deeper analysis premium **[R]**. |
| Cycle and symptom pattern detection | PREMIUM | **[R]** |

## Reminders and notifications

Configure reminders in **Menu (avatar) > Reminders**. **[V]** Reminder types:

| Reminder | Tier | Notes |
|---|---|---|
| Period start and end | FREE | **[V]** |
| Fertile window and ovulation | FREE | **[V]** |
| Medication and contraception | FREE | **[V]** Methods: oral contraceptives, vaginal ring, patch, injection, IUD, implant. Set intake start date, time, and pill pack settings (pill break or continuous). |
| Water intake | FREE | **[V]** |
| Sleep | FREE | **[V]** |
| Log symptoms or daily check-in | FREE | **[U]** |
| Weight, meditation, steps | FREE | **[U]** |
| Secret Chats and special offers | FREE | **[R]** Marketing-type notifications you can turn off. |
| Notification privacy | FREE | **[V]** Choose detailed, minimal, or private notification text (also through device settings). |

## Pregnancy mode

Turn it on in **Menu > My goal > Track pregnancy > Log pregnancy > Activate**. **[V]**

| Feature | Tier | Notes |
|---|---|---|
| Gestational age (weeks and days) on main screen | FREE | **[V]** Counted from the first day of the last period. |
| Due date | FREE | **[V]** Editable. |
| Pregnancy settings | FREE | **[V]** Edit gestational age, number of babies, and due date. |
| Week-by-week information | MIXED | **[V]** **Details** on the main screen; basic weekly updates free, in-depth content premium. |
| Baby development and size visuals | MIXED | **[R]** Weekly visuals of development; fruit-size comparison **[U]**. |
| Daily pregnancy stories from week 4 | MIXED | **[V]** |
| Pregnancy checklists and expert guidance | PREMIUM | **[V]** "In-depth pregnancy features" are premium. |
| Pregnancy symptom logging | FREE | **[V]** Ovulation test and BBT hidden. |
| Kick counter | UNCLEAR | **[U]** No source confirmed a kick counter in Flo during this research. |
| Contraction timer | UNCLEAR | **[U]** One low-quality aggregator claims a premium contraction timer; not confirmed. |
| Pregnancy weight tracking | UNCLEAR | **[U]** |
| End pregnancy: "A baby is born!" | FREE | **[V]** Pregnancy mode stays active for up to 43 weeks so you can log the birth later. |
| End pregnancy: pregnancy loss | FREE | **[R]** Flo has a pregnancy-loss policy and content; reviews say loss can be logged from day 29. |
| Partner sees pregnancy progress | FREE | **[V]** See Flo for Partners. |

## Postpartum (after birth) mode

| Feature | Tier | Notes |
|---|---|---|
| Postpartum mode after logging a birth | FREE | **[V]** Flo recommends switching to it after the birth. |
| Recovery content and cycle-return tracking | MIXED | **[U]** Postpartum content, period-return logging, and breastfeeding-related content. |

## Perimenopause

Flo for Perimenopause launched for all users on July 21, 2025, and Flo added further
perimenopause features for premium members in May 2026. **[V]**

| Feature | Tier | Notes |
|---|---|---|
| Perimenopause goal and mode | FREE | **[V]** |
| Symptom tracking (hot flashes, night sweats, sleep, energy, mood, well-being) | FREE | **[V]** for sleep, energy, mood, well-being; **[U]** for hot flashes and night sweats labels. |
| Perimenopause Score | MIXED | **[V]** Validated assessment of how much symptoms affect you, tracked over time. Developed with Flo's scientific advisory board. |
| Menopause Timeline | MIXED | **[V]** Estimates your transition stage and what comes next; educational, not diagnostic. |
| Relief Options | PREMIUM | **[R]** Comparison of treatments, from medication to lifestyle changes, matched to symptoms. |

## Privacy and security

| Feature | Tier | Notes |
|---|---|---|
| Anonymous Mode | FREE | **[V]** **Avatar > Profile > Switch to Anonymous Mode**. Removes name, email, and technical identifiers from health data. Switching triggers deletion of the original account. The access code can't be reset; losing it means starting a new account. Exporting data requires leaving Anonymous Mode and contacting support. |
| App lock (PIN or access code) | FREE | **[V]** Passcode protection; Face ID or Touch ID on iOS **[U]**. Reset flow exists for non-anonymous accounts. |
| Request my data (export) | FREE | **[V]** **My Data > Request My Data** produces a password-protected file with logs, account info, and usage history. |
| Delete account | FREE | **[V]** In **Settings** or by email to support; permanent. |
| Notification privacy levels | FREE | **[V]** |
| Apple Health integration | FREE | **[V]** Writes Flo activities to Health and reads menstrual cycle data. |
| Google Fit and Health Connect | FREE | **[R]** Step data. |
| Apple Watch app | FREE | **[V]** |

## Social features

| Feature | Tier | Notes |
|---|---|---|
| Flo for Partners | UNCLEAR | **[V]** Help center says it's available to all mobile users; Healthline lists it as premium. Set up from the **Partner** tab: share a code; the partner installs Flo and enters it. Partner sees a read-only cycle calendar, phase-based daily insights and tips, pregnancy updates (weekly changes, common symptoms, baby milestones), and mode-switch notifications. Personal symptom logs aren't shared in pregnancy mode. **Stop sharing** revokes access. Couples quiz with skippable questions. |
| Secret Chats (anonymous community) | UNCLEAR | **[V]** Anonymous topic-based discussion groups. Older reviews list it as free; the 2026 App Store listing lists it among premium features. Read access might be free with posting gated **[U]**. |

## Settings and personalization

| Feature | Tier | Notes |
|---|---|---|
| Units: temperature (°C or °F), weight (kg or lb) | FREE | **[R]** |
| Cycle and period length overrides | FREE | **[V]** **Menu > Cycle and ovulation**. |
| Tracker visibility and order | FREE | **[V]** |
| Language selection (20+ languages) | FREE | **[R]** |
| Themes and dark mode | UNCLEAR | **[U]** Follows system dark mode; no custom theme picker confirmed. |
| Help center and contact support | FREE | **[V]** |

## Recommended scope for an offline, open-source Flutter clone

The following recommendations assume local-only storage (for example, SQLite through
`drift` or `sqflite`, or `isar`), no accounts, and no network. Every feature is free in
the clone; the premium column in this document only shows what Flo charges for.

### Build in version 1 (fully offline)

- **Onboarding**: goal choice (track cycle, get pregnant, track pregnancy,
  perimenopause), last period date, average period and cycle length with defaults,
  birth year, and optional birth control method.
- **Prediction engine**: rolling weighted average of the last 3-6 cycles; ovulation at
  next period minus 14 days; fertile window from ovulation minus 5 days to ovulation
  plus 1 day; refine with BBT shift (three-over-six rule) and positive ovulation tests.
  Show a pregnancy-chance level per day. Exclude outlier gaps on request.
- **Cycle health assessment**: ACOG ranges (cycle 21-35 days, period 2-7 days, variation
  of 7 days or less).
- **Daily logging**: every category in this document, as data-driven option lists in a
  JSON or Dart config, so labels stay editable. Include numeric trackers (BBT, weight,
  water, sleep, steps entered manually) and a free-text note. Support tracker
  show, hide, and reorder.
- **Calendar**: month view with logged, predicted, fertile, ovulation, and pregnancy
  styling; day detail sheet; edit-period-dates mode.
- **Charts**: cycle-length and period-length history, symptom frequency by cycle phase,
  BBT chart with cover line, weight and sleep trends (for example, with `fl_chart`).
- **Doctor report PDF**: last 6 cycles, period lengths, detected patterns, and top 5
  symptoms, generated on-device with the `pdf` and `printing` packages and shared through
  the system share sheet.
- **Rule-based insights**: local cards such as "period likely in 3 days," "cycle longer
  than your average," or "headache logged 3 cycles in a row before your period."
  Write your own content; don't copy Flo's.
- **Scripted assistant**: an offline decision-tree "assistant" that walks through
  late period, spotting, or symptom questions using the user's local data. Add an
  optional on-device LLM later if you want free-form chat.
- **Symptom questionnaires**: self-assessment questionnaires for PCOS or endometriosis
  signs that end with "talk to a clinician" guidance. Write them with medical review and
  label them educational.
- **Reminders**: local notifications (`flutter_local_notifications`) for period,
  fertile window, ovulation, pill, ring, patch, injection, water, sleep, and daily
  logging, with a private-notification-text option.
- **Contraception**: pill pack model (21+7, 24+4, continuous), daily pill status
  logging, and refill reminders.
- **Pregnancy mode**: gestational age from last period or due date, multiples count,
  week-by-week cards with your own content and size comparisons, kick counter, and
  contraction timer (both straightforward local tools), pregnancy weight log, and
  "baby born" or "pregnancy loss" exits handled with care.
- **Postpartum mode**: recovery checklist, bleeding (lochia) log, and period-return
  tracking that switches back to cycle mode.
- **Perimenopause mode**: symptom trackers (hot flashes, night sweats, sleep, brain fog,
  joint pain), a score built on a published, freely usable scale such as the
  Menopause Rating Scale (check its license first), and an educational stage estimate
  based on STRAW+10 criteria.
- **Privacy**: app lock with PIN and biometrics (`local_auth`), encrypted database
  (`sqlcipher_flutter_libs` or similar), no analytics, "delete all data" with
  confirmation, and JSON or CSV export plus encrypted backup file import and export.
- **Settings**: units, language (`intl`), light, dark, and system themes, first day of
  week, and tracker customization.
- **Health platform sync (optional)**: read steps and write cycle data through the
  `health` package (Apple Health and Health Connect). This stays local to the device.

### Simulate locally or through export

- **Partner sharing**: generate a read-only snapshot (calendar, predictions, phase
  tips) as a PDF, image, or encrypted file, or as a QR code the partner's copy of the
  app imports. There's no live sync without a backend.
- **Couples quiz**: run on one device in pass-the-phone mode.
- **Community (Secret Chats)**: leave out, or link to external communities. A local
  "journal" with prompts can stand in.
- **Articles, videos, and courses**: bundle a small, original, openly licensed article
  set in the app (Markdown assets). Skip video, or link out.

### Out of scope without a backend

- Accounts, cloud sync, and multi-device sync (offer manual backup files instead).
- Live partner sync and server-side community.
- Subscriptions and paywalls.
- Server-side personalization and remote content updates.
- Anonymous Mode as Flo defines it. A local-only app with no account is anonymous by
  design.

## Sources

- Flo on the App Store: https://apps.apple.com/us/app/flo-period-pregnancy-tracker/id1038369065
- Flo help center: https://help.flo.health/hc/en-us
- Logging your symptoms: https://help.flo.health/hc/en-us/articles/4406826542740-Logging-your-symptoms
- How do I use the app: https://help.flo.health/hc/en-us/articles/360014347632-How-do-I-use-the-app
- How do I log my menstrual flow: https://help.flo.health/hc/en-us/articles/360054540452-How-do-I-log-my-menstrual-flow
- How do I log my basal temperature or ovulation test results: https://help.flo.health/hc/en-us/articles/360015318231-How-do-I-log-my-basal-temperature-or-ovulation-test-results
- What can I find on the main screen: https://help.flo.health/hc/en-us/articles/4401756146452-What-can-I-find-on-the-main-screen
- How do I log my birth control method: https://help.flo.health/hc/en-us/articles/360015106292-How-do-I-log-my-birth-control-method
- What is Pregnancy mode: https://help.flo.health/hc/en-us/articles/360054523711-What-is-Pregnancy-mode-and-how-do-I-activate-it
- Report for a doctor: https://help.flo.health/hc/en-us/articles/51631220426900-I-want-to-generate-a-report-for-my-doctor
- What data will be shared with my partner: https://help.flo.health/hc/en-us/articles/19872048333972-What-data-will-be-shared-with-my-partner
- Export data in Anonymous Mode: https://help.flo.health/hc/en-us/articles/8467664174612-How-do-I-export-my-data-in-Anonymous-mode
- Anonymous Mode FAQ: https://flo.health/privacy-portal/anonymous-mode-faq
- Flo for Perimenopause launch: https://flo.health/newsroom/flo-for-perimenopause-is-launching-to-empower-the-1-billion-women-who-experience-perimenopause-without-the-support-they-deserve
- Healthline review of Flo: https://www.healthline.com/health/flo-period-tracker
- Stress and pain in Flo users (npj Mental Health Research, 2023), source of the mood and symptom lists: https://www.nature.com/articles/s44184-023-00043-w
- PCOS among Flo users (Reproductive Biology and Endocrinology, 2021), source of the 84-item panel and category names: https://link.springer.com/article/10.1186/s12958-021-00719-y

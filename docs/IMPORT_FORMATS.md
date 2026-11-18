# Import formats

This document describes the export formats of other period trackers that Bloom's
**Import from another app** flow reads, what Bloom maps from each one, and how sure we
are of each format. The parsers are in `lib/features/import/`, and the synthetic test
fixtures are in `test/import/fixtures/`.

None of these vendors publishes a schema for its export. Each section labels its claims
as follows:

- **Verified:** seen in vendor documentation, platform SDK headers, open-source code that
  reads the files, or a real export file.
- **Partly verified:** one source, or sources that disagree.
- **Unverified:** inferred, with no source that shows the file itself.

Every parser counts what it can't map and lists it in the preview, so a format detail that
we got wrong shows up as a skipped item instead of disappearing.

## Summary

The following table lists each source and its status in Bloom:

| Source | File | Status in Bloom | Confidence |
|---|---|---|---|
| Apple Health | `export.zip` with `apple_health_export/export.xml` | Supported, streamed | Verified, except iOS 18 value names |
| Clue | Password-protected ZIP with `measurements.json` | Supported, with the password | Verified |
| Clue (older Android backup) | `.cluedata` JSON | Supported, best effort | Partly verified |
| Flo | Password-protected ZIP with a JSON file, sent by support | Supported for periods and tests | Partly verified |
| drip | One CSV file | Supported | Verified |
| Mensinator | One JSON file | Supported | Verified for the structure |
| Health Connect | `Health Connect.zip` with a SQLite database | Not supported | Undocumented |
| Any other app | CSV with a date column | Supported, with a column-mapping step | Not applicable |

Bloom detects the format from the file's contents, not its name or the app that the user
picked.

## Apple Health

**How the user gets it:** in the Health app, tap the profile picture, then **Export All
Health Data**. The result is `export.zip`.

**Container:** a ZIP that holds `apple_health_export/export.xml`, `export_cda.xml`, and
folders such as `workout-routes/`. Bloom reads only `export.xml`. Exports can reach
hundreds of megabytes compressed and several gigabytes uncompressed, so the ZIP can use
ZIP64 fields.

**Structure (verified):** an inline DTD, then `<HealthData locale="...">` with
`<ExportDate>`, `<Me>`, and many `<Record>` elements. Each record has `type`,
`sourceName`, `unit`, `creationDate`, `startDate`, `endDate`, and `value` attributes, and
can have `<MetadataEntry key="..." value="..."/>` children. Dates look like
`2024-09-27 12:00:00 +0300`. Category values are written as enum names, such as
`HKCategoryValueMenstrualFlowMedium`, not as integers.

The following table lists how Bloom maps cycle-tracking records:

| Record type | Values | Bloom |
|---|---|---|
| `HKCategoryTypeIdentifierMenstrualFlow` | `Light`, `Medium`, `Heavy` | Flow level and a period day |
| | `Unspecified` | Period day without a level |
| | `None` | Skipped and counted |
| `HKCategoryTypeIdentifierIntermenstrualBleeding` | `NotApplicable` | Spotting |
| `HKCategoryTypeIdentifierOvulationTestResult` | `LuteinizingHormoneSurge` (old name `Positive`), `Negative` | Ovulation test |
| | `EstrogenSurge`, `Indeterminate` | Skipped and counted |
| `HKCategoryTypeIdentifierPregnancyTestResult` | `Positive`, `Negative` | Pregnancy test |
| `HKCategoryTypeIdentifierSexualActivity` | Metadata `HKSexualActivityProtectionUsed` `1` or `0` | Protected or unprotected sex |
| | No protection metadata | Skipped and counted |
| `HKQuantityTypeIdentifierBasalBodyTemperature` | `degC` or `degF` | Basal temperature in °C, earliest reading of the day |
| `HKCategoryTypeIdentifierCervicalMucusQuality` | `Dry`, `Sticky`, `Creamy`, `Watery`, `EggWhite` | Discharge |
| Symptom types, such as `AbdominalCramps`, `Headache`, `Bloating`, `MoodChanges` | `HKCategoryValueSeverity*` or `HKCategoryValuePresence*` | Matching Bloom symptom, unless the value is `NotPresent` |

Cycle-related types without a Bloom option, such as `AppetiteChanges` and
`SleepChanges`, are skipped and counted by name. Every other record type, such as steps
and heart rate, is counted as one "other data" line.

The day of a record is the date part of `startDate`, which is the local date when the
entry was made.

**Unverified:** iOS 18 renamed `HKCategoryValueMenstrualFlow` to
`HKCategoryValueVaginalBleeding`, with the same raw values. We found no iOS 18 export
that shows which name `export.xml` uses, so Bloom accepts both prefixes. The `degC` and
`degF` unit strings come from HealthKit's unit syntax, not from a real temperature
record.

**Sources:**

- [`HKCategoryValueVaginalBleeding`](https://developer.apple.com/documentation/healthkit/hkcategoryvaluevaginalbleeding)
  and the [Apple Developer Forums thread about the rename](https://developer.apple.com/forums/thread/771074).
- The raw enum values in
  [`HKDefines.h` from the iOS 16.5 SDK](https://github.com/theos/sdks/blob/master/iPhoneOS16.5.sdk/System/Library/Frameworks/HealthKit.framework/Headers/HKDefines.h).
- A [real iOS 17.6.1 cycle-tracking export](https://github.com/ipekaksoy/DSA210_project_ipek/blob/main/data/mensturalcycledata.xml)
  that shows enum-name values and the `HKMenstrualCycleStart` metadata key.
- [A fixture with the export DTD](https://github.com/sanguity/sanguity/blob/main/tests/fixtures/apple_health/apple_health_export/export.xml).

### Large files

Bloom never loads the whole export. It reads the ZIP's central directory from the end of
the file, then streams `export.xml` through an inflater and a scanner that looks only for
`<Record` tags:

- **Android and iOS:** the import runs in a background isolate. It reads the file by path
  with `dart:io` and inflates it with `ZLibDecoder`. Memory use stays flat whatever the
  file size.
- **Web:** the picked file stays a browser `Blob`. Bloom reads slices of it and inflates
  `export.xml` with the browser's native `DecompressionStream('deflate-raw')`. The scanner
  runs on the main thread and pauses between chunks, so the page keeps drawing.

In tests, the scanner itself processes several hundred megabytes of skipped records a
second on both the Dart VM and in Chrome. Reading and inflating take most of the time.
On the web, a multi-gigabyte export can take several minutes, and the tab must stay open.
`DecompressionStream` with `deflate-raw` requires Chrome 80, Safari 16.4, Firefox 113, or
later. We haven't tested a real multi-gigabyte export in each browser.

## Clue

**How the user gets it (verified):** in Clue, go to **More > Settings > Download my
data**, and tap **Request data**. Clue shows a one-time password on screen and emails a
download link that expires after 72 hours. The download is a password-protected ZIP that
holds `measurements.json`.

**Structure (verified from four independent parsers):** a JSON array of entries such as
`{"date": "2024-02-01", "type": "period", "value": {"option": "medium"}}`. The `value`
field takes the following shapes:

- `{"option": "..."}` for single-choice categories, such as `period` and
  `birth_control_pill`.
- A list of `{"option": "..."}` objects for multi-select categories, such as `pain` and
  `feelings`.
- `{"celsius": 36.5, "excluded": false}` for `bbt`.

One parser reads `discharge` as a list and another as a single value, so Bloom accepts
both. Option keys are English `snake_case` in every app language.

The following table lists the categories that Bloom maps:

| Clue `type` | Bloom |
|---|---|
| `period` (`light`, `medium`, `heavy`, `very_heavy`) | Flow. `very_heavy` becomes heavy and is listed as adjusted. |
| `spotting` | Spotting |
| `pain` (`period_cramps`, `lower_back`, `breast_tenderness`, `headache`, `migraine`) | Symptoms |
| `feelings` (`happy`, `sad`, `angry`, `anxious`, `indifferent`) | Mood |
| `energy` (`energetic`, `tired`, `exhausted`) | Mood or fatigue |
| `sex_life` (`protected`, `unprotected`, `no_sex_today`, `masturbation`, `high_sex_drive`, `low_sex_drive`) | Sex |
| `discharge` (`none`, `sticky`, `creamy`, `egg_white`, `atypical`) | Discharge |
| `digestion` (`nauseous`, `bloated`, `gassy`) | Digestion |
| `skin` (`acne`) | Acne |
| `tests` (`ovulation_positive`, and the `_negative` and pregnancy forms) | Tests |
| `bbt` | Basal temperature, unless `excluded` is true |
| `birth_control_pill` (`taken`) | Pill |

Every other category and option, including custom `tags`, is skipped and counted with its
name. The pregnancy-test and negative ovulation-test option names are unverified guesses;
if they're wrong, they appear in the skipped list.

**Encryption:** Bloom decrypts the ZIP on the device with `package:archive`, which
supports both ZipCrypto and WinZip AES. Decryption needs the whole archive in memory, so
Bloom limits encrypted files to 150 MB. Clue and Flo exports are far smaller. The user
can also unzip the file and pick `measurements.json`.

**Older format (partly verified):** older Android backups (`.cluedata`) are a JSON object
with a `data` array of day objects. One converter confirms the `data` array. A second
source, without a sample file, shows `day` as the date, `period` as a plain string, and
list values for other categories. Bloom reads that shape and counts anything else.

**Sources:**

- [Clue Help Center: How do I get a copy of my Clue data?](https://support.helloclue.com/hc/en-us/articles/17320910724125-How-do-I-get-a-copy-of-my-Clue-data)
- [fabfabretti/clue-to-drip `script.js`](https://github.com/fabfabretti/clue-to-drip/blob/main/script.js)
  and its [conversion rules](https://github.com/fabfabretti/clue-to-drip/blob/main/conversionrules.md).
- [forcegk/clue2drip](https://github.com/forcegk/clue2drip/blob/main/clue2drip_convert.py).
- [Mensinator `ClueImport.kt`](https://github.com/EmmaTellblom/Mensinator/blob/main/app/src/main/java/com/mensinator/app/business/ClueImport.kt).
- [Nodea `import-clue.ts`](https://github.com/aliceout/Nodea/blob/main/packages/web/src/app/flow/Cycle/lib/import-clue.ts).
- [Clue-Period-Tracker-Backup-Converter](https://github.com/isosphere/Clue-Period-Tracker-Backup-Converter/blob/master/clue-to-excel.py)
  for the older format.

## Flo

**How the user gets it (verified):** Flo has no export button. In Flo, the user taps the
profile picture, then **Help > Contact us**, and asks for a copy of their data. Flo offers
TXT and JSON. Anonymous Mode users must create an account first.

**Container (partly verified):** a password-protected file, with the password in a
separate email. Flo's privacy page says delivery can take up to a month. We couldn't open
that page directly, and one guide that describes unzipping the file returned an error, so
the ZIP container is likely but not confirmed first-hand. Bloom accepts the ZIP, with its
password, or the JSON file on its own.

**Structure (verified from two parsers):**

- `operationalData.cycles[]`: objects with `period_start_date` and `period_end_date` as
  `yyyy-MM-dd` strings. Bloom marks every day in each range as a period day. It keeps only
  the start day when the end is missing, and caps a range at 15 days.
- `operationalData.point_events_manual_v2[]`: objects with `category`, `subcategory`, and
  `date`. Only `OvulationTest`/`Positive` and `Ovulation`/`OtherMethods` are confirmed.
  Bloom maps those to ovulation tests. It also maps guessed `OvulationTest`/`Negative` and
  `PregnancyTest` pairs. Every other pair is skipped and counted by name.

**What isn't covered:** neither parser that we found reads a flow level or symptoms, so
Bloom imports Flo periods without a flow level. If Flo's JSON holds symptoms in another
field, Bloom doesn't read them yet. The preview's skipped list shows the
`category: subcategory` pairs that it found, which is the information needed to extend
the parser from a real export.

**Other routes:**

- On iPhone, Flo's help says that periods logged in Flo aren't sent to the Health app, so
  an Apple Health export doesn't help Flo users.
- On Android, Flo can pair with Health Connect. A third-party discussion says Flo writes
  menstruation records there, but Flo doesn't say so, and Bloom can't read Health Connect
  exports.

**Sources:**

- [Flo Help Center: How do I export my data?](https://help.flo.health/hc/en-us/articles/360054973811-How-do-I-export-my-data)
- [Flo: Your data and privacy](https://flo.health/your-data-and-privacy).
- [Flo Help Center: How to import data from the Health app to Flo](https://help.flo.health/hc/en-us/articles/34890229122068-How-to-import-data-from-the-Health-app-to-Flo-iOS).
- [Mensinator `FloImport.kt`](https://github.com/EmmaTellblom/Mensinator/blob/main/app/src/main/java/com/mensinator/app/business/FloImport.kt).
- [SaraVieira/flo-to-drip `formatjson.js`](https://github.com/SaraVieira/flo-to-drip/blob/main/src/formatjson.js).

## drip

**How the user gets it (verified):** in drip, go to **Settings > Data** and export. The
result is one CSV file.

**Structure (verified from drip's source):** a header of `date` and `group.field`
columns, built from drip's database schema. drip's own import rejects unknown headers.
Bloom recognizes the file by `date`, `bleeding.value`, and `temperature.value`.

The following list describes the columns and how Bloom maps them:

- `date`: `yyyy-MM-dd`.
- `bleeding.value`: `0` spotting, `1` light, `2` medium, `3` heavy. When
  `bleeding.exclude` is `true`, drip doesn't count the bleeding as a period, so Bloom saves
  it as spotting and lists it as adjusted.
- `temperature.value`: °C. Excluded temperatures are skipped and counted.
  `temperature.note` goes into the day's note.
- `mucus.texture`: `0` nothing, `1` creamy, `2` egg white. Bloom maps these to discharge.
  `mucus.feeling` and the `cervix.*` columns are skipped and counted.
- `desire.value`: `0` low, `1` medium, `2` high. Bloom maps these to sex drive.
- `sex.solo` becomes masturbation. `sex.partner` becomes protected sex when any
  contraceptive column is `true`, or unprotected sex when `sex.none` is `true`.
  Otherwise it's skipped and counted.
- `pain.*` and `mood.*` are `true` or `false` flags. Most map to Bloom symptoms and moods.
  `pain.ovulationPain`, `mood.fine`, and the `other` flags are skipped and counted.
- `note.value` and the other `*.note` columns become the day's note.

**Sources:** `src/lib/import-export/` and `src/db/schemas/` in
[drip's repository](https://gitlab.com/bloodyhealth/drip), and
[drip's sample CSV](https://dripapp.org/assets/more-cycle-data.csv).

## Mensinator

Mensinator is an open-source Android tracker.

**Structure (verified from Mensinator's source):** a JSON file with the top-level keys
`periods`, `symptoms`, `symptom_date`, `ovulations`, and `app_settings`. Each is a dump
of a database table with every value as a string. Bloom reads the following:

- `periods[].date` as period days.
- `symptom_date[]` (`symptom_date`, `symptom_id`), joined with `symptoms[]` (`id`,
  `symptom_name`). Mensinator's built-in `Heavy_Flow`, `Medium_Flow`, `Light_Flow`, and
  `Spotting` symptoms become flow levels. Other names match Bloom's option labels, and
  unmatched names are skipped and counted.
- `ovulations[].date` as "ovulation: my method." We didn't confirm the `ovulations`
  columns.

The menu path to Mensinator's export in the in-app guide is unverified.

**Source:** [Mensinator `MensinatorExportImport.kt`](https://github.com/EmmaTellblom/Mensinator/blob/main/app/src/main/java/com/mensinator/app/business/MensinatorExportImport.kt).

## Android Health Connect

**Not supported.** Health Connect on Android 14 and later can export to a cloud-storage
app through **Manage data > Backup and restore**. The default file is
`Health Connect.zip`. Community reports say it holds `health_connect_export.db`, an
unencrypted SQLite database with Android's internal table layout, such as
`menstruation_flow_record_table`. Google doesn't document that layout, and it can change
between Android releases.

Reading it would also need a SQLite engine on every platform, including the web. Bloom
detects these files and explains that it can't read them. The supported route is reading
records in-app through the Health Connect API, which Bloom doesn't do.

**Sources:**

- [Android Help: Back up and restore Health Connect data](https://support.google.com/android/answer/15323271).
- The [`MenstruationFlowRecord` reference](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/MenstruationFlowRecord)
  and related record classes.

## Generic CSV

For any other app, Bloom reads a CSV file with a header row and asks which column holds
what. It guesses the mapping from the header names.

The mapping step has the following fields:

- **Date** (required): `yyyy-MM-dd`, `dd/MM/yyyy`, or `MM/dd/yyyy`, also with dots or
  hyphens and two-digit years. Bloom guesses the order from the values and lets the user
  change it.
- **Period end** (optional): for files with one row per period. Each row then marks every
  day from the start to the end, up to 15 days.
- **Flow or bleeding** (optional): words (`spotting`, `light`, `medium`, `heavy`), numbers
  from `1` to `3` (`4` reads as heavy), or yes and no marks.
- **Basal temperature** (optional): values above 50 are read as °F.
- **Notes** (optional).

The separator can be a comma, a semicolon, or a tab, and the file can start with a UTF-8
byte order mark. Unrecognized flow values and unreadable dates are skipped and counted.

## Merge rules

After the preview, the user chooses one of the following:

- **Add to my data:** a day that already has a period mark or a non-empty log in Bloom
  keeps Bloom's entry, and the imported entry for that day is left out. The preview says
  how many days overlap.
- **Replace everything:** Bloom removes every period day and daily log, then writes the
  import. The profile, settings, reminders, journal, and other features stay. The user must
  type `REPLACE` to confirm.

Both write through `AppStore.applyImport`, which reports each changed day and period
month to sync. When sync is on, imported days upload like days logged by hand, and days
removed by **Replace everything** are deleted from the synced copy.

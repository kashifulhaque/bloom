# Plan: encrypted sync with Supabase

This plan adds optional sync between Bloom on Android, iOS, and the web. Supabase stores
only ciphertext: Bloom encrypts all data on the device before upload, so neither
Supabase nor anyone with database access can read a user's health data.

## Goals

- Sync is optional and off by default. Bloom keeps working with no account.
- The server never sees plaintext health data, names, or notes.
- Signing in on a new device and entering the recovery phrase restores everything.
- Conflicting edits from two devices merge without losing a day's log.

## Non-goals

- Sharing data between different people. Partner sharing keeps its own snapshot code.
- Server-side features that need plaintext, such as server-generated insights.

## Architecture

| Part | Choice |
|---|---|
| Project | Supabase project `bloom` in the `bloom-app` organization, region `eu-central-1` (Frankfurt), near `vm.ifkash.dev` |
| Sign-in | Supabase Auth with email one-time codes (OTP) first; passkeys later. No Google or Apple sign-in. |
| Storage | One Postgres table of encrypted records, with row-level security (RLS) |
| Client | `supabase_flutter`, publishable key only. The secret key never ships. |
| Encryption | XChaCha20-Poly1305 with a random 256-bit data key, wrapped by a key derived from a recovery phrase with Argon2id |

## Data model

Bloom syncs at the level of one record per item, so edits on two devices merge per day
instead of one device overwriting the whole store.

```sql
create table public.sync_records (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  kind        text not null,          -- 'day', 'profile', 'feature', 'periods'
  record_id   text not null,          -- for example a day key or a feature key, hashed
  version     bigint not null,        -- hybrid logical clock from the device
  deleted     boolean not null default false,
  ciphertext  bytea not null,         -- nonce plus encrypted JSON
  updated_at  timestamptz not null default now(),
  primary key (user_id, kind, record_id)
);
alter table public.sync_records enable row level security;
```

- `record_id` is an HMAC of the plaintext key, so the server can't see which dates have logs.
- RLS policies give each user select, insert, update, and delete on their own rows only,
  using `to authenticated` with `(select auth.uid()) = user_id`. The update policy has
  both `using` and `with check`.
- An index on `(user_id, updated_at)` serves "everything changed since" pulls.
- A second table, `sync_keys`, stores each user's wrapped data key (ciphertext only)
  and the Argon2id salt and parameters, under the same RLS rules.
- The tables are granted only to `authenticated`. The `anon` role has no access.

## Encryption

1. On first sync, the device creates a random data key and a 12-word recovery phrase.
2. Argon2id turns the phrase and a random salt into a key-encryption key, which wraps
   the data key. Only the wrapped key and the salt go to `sync_keys`.
3. Each record is encrypted with the data key and a fresh nonce.
4. A new device signs in, downloads the wrapped key, and asks for the recovery phrase.
5. The unwrapped data key is kept in secure storage: Android Keystore, iOS Keychain, and
   on the web, a non-extractable WebCrypto key in IndexedDB.

If a user loses the recovery phrase and every device, the data can't be recovered. The
app says so clearly before sync is turned on.

## Sync algorithm

- Each local change bumps that record's version with a hybrid logical clock and marks it
  dirty.
- **Push:** upsert dirty records. The server keeps a record only if the incoming version
  is newer, which a `before update` trigger enforces.
- **Pull:** fetch rows with `updated_at` later than the last pull, decrypt, and apply
  the newer version per record. Deletes are tombstones (`deleted = true`).
- Sync runs on launch, on resume, after edits (debounced by 5 seconds), and from a
  **Sync now** button. Realtime subscriptions can come later.
- Period days sync as one record per month, so marking a period doesn't rewrite the
  whole history.

## App changes

- `lib/core/sync/`: crypto, the record codec, the hybrid logical clock, and the sync
  engine, with no Flutter UI code, so it's unit-testable.
- `AppStore`: record-level change tracking and an `applyRemote` method.
- **You > Sync**: sign in with an email code, show the recovery phrase once with a
  confirmation step, show the last sync time, offer **Sync now**, sign out, and
  **Delete synced data**, which deletes the account and its rows.
- Settings copy and the About page are updated so the privacy promise stays accurate.

## Configuration

- `supabase/migrations/`: the tables, RLS policies, the version trigger, and indexes.
- Auth: email OTP turned on, Supabase's own email sender for now, rate limits left at
  their defaults, and a short JWT expiry.
- The Supabase URL and publishable key go in `.env` as `SUPABASE_URL` and
  `SUPABASE_PUBLISHABLE_KEY`, passed in with `--dart-define-from-file`. Neither is
  secret, but both stay out of git like the other keys.
- CI deploys migrations with a scoped personal access token, never the browser-login token.

## Testing

- Unit tests: encryption round trips, wrong-phrase failure, clock ordering, merge
  rules, and tombstones.
- Integration tests against the local stack (`npx supabase start`): RLS denies access to
  another user's rows, and the version trigger rejects stale writes.
- Run `supabase db advisors` before each migration is committed.
- A manual check: sign in on the web and on Android with the same account and confirm a
  log made on one appears on the other.

## Steps

1. Create the `bloom` project in `bloom-app` and link it with `supabase link`.
2. Write the migration and test RLS on the local stack.
3. Build the crypto and sync engine with unit tests.
4. Build the Sync screens.
5. Push the migration, add the keys to `.env` and CI, and test across two devices.

## Implementation notes

This section lists the decisions that differ from, or extend, the plan.

### Server

- **Stale writes are skipped, not rejected.** The `before update` trigger on
  `sync_records` returns `NULL` when the incoming `version` isn't greater than the stored
  one, so the row stays unchanged and is missing from the upsert's `RETURNING` rows. One
  stale row never fails a whole batch. The client compares the returned rows with the
  rows it sent, fetches the missing ones, and merges the server's copy. An equal version
  is also skipped, which makes a retried push harmless.
- **Concurrent first inserts** use `insert ... on conflict (user_id, kind, record_id) do
  update`, so the second insert becomes an update and goes through the same version rule.
- **The server sets `updated_at`.** Triggers set it to `clock_timestamp()` on every insert
  and accepted update, so clients can't choose it. The trigger also refuses changes to
  `user_id`, `kind`, or `record_id` (error `42501`).
- **The pull index** is `(user_id, updated_at, record_id)`, one column more than the plan,
  so keyset pages by `(updated_at, record_id)` use it.
- **Check constraints** limit `kind` to the four kinds, `record_id` to 16-128 base64url
  characters, `version` to positive values, and `ciphertext` to 41 bytes-1 MiB.
  `sync_keys` checks the wrapped-key length, the salt length, and the Argon2id ranges.
- **Grants.** Both tables revoke everything from `public`, `anon`, and `authenticated`,
  then grant `select, insert, update, delete` to `authenticated` only. The local
  `config.toml` sets `auto_expose_new_tables = false` to match the hosted default for new
  projects, so the explicit grants are tested. The trigger functions are `security
  invoker` in a `private` schema that the Data API doesn't expose.
- **`delete-account`** uses `@supabase/server` (`withSupabase({ auth: "user" })`), which
  verifies the caller's JWT and answers CORS preflight requests. It deletes the rows with
  the caller's own RLS-scoped client, revokes all refresh tokens, and then deletes the
  user with the admin client. No service-role grants on the tables are needed.
- **Email codes.** `signInWithOtp` sends the **Magic Link** template, so the template must
  contain `{{ .Token }}`. The local template is `supabase/templates/otp_code.html`. New
  free-plan projects can edit templates only with custom SMTP, which conflicts with "use
  Supabase's own email sender for now."

### Client

- **Packages.** `cryptography` (pure Dart) for XChaCha20-Poly1305, HKDF-SHA256, HMAC-SHA256,
  and Argon2id on Android and iOS, run in a background isolate. On the web, Argon2id runs
  in libsodium.js (`web/sodium.js`, the "sumo" browser build pinned by commit and SHA-512),
  loaded only the first time a key is derived; Dart Argon2id is the fallback. The `sodium`
  package was rejected because its build hook compiles libsodium from source for every
  platform and fails on machines without a full Xcode install.
- **Argon2id parameters:** 64 MiB, 2 passes, 1 lane (libsodium's "interactive" limits).
  They're stored per account in `sync_keys`.
- **The recovery phrase** is 128 bits of entropy in standard BIP-39 form (checksum
  included). The 16 entropy bytes, not the words, are the Argon2id input.
- **Subkeys.** HKDF-SHA256 derives a record-encryption key and a record-ID key from the
  data key. A record ID is base64url HMAC-SHA256 of `kind\nkey`.
- **Associated data** binds each ciphertext to its kind, record ID, version, and deleted
  flag. A downloaded row whose ID doesn't match the HMAC of the key inside it is
  rejected.
- **Versions** are hybrid logical clock values that stay below 2^53, so they're exact in
  JavaScript and JSON: milliseconds since 2025-01-01 times 4096, plus a 6-bit counter and
  a 6-bit device tag.
- **Pull** starts 2 minutes before the saved cursor, to catch writes that commit late with
  an earlier timestamp, and pages by `(updated_at, record_id)` with the server's own
  timestamp strings. Applying a row twice changes nothing.
- **A joining device adopts the account's data.** Until a device finishes its first full
  download, downloaded records replace local ones. Then local records that the account
  doesn't have are uploaded. Without this rule, the profile from a new device's
  onboarding would overwrite the account's profile.
- **The first download is staged.** A joining device fetches every page before it applies
  any record, then applies them all at once. A dropped connection part way through leaves
  the device's data and the pull cursor unchanged.
- **Restoring from onboarding.** **Already have an account?** on the welcome page signs
  in and unlocks with the same `SyncController` steps as **You > Sync**, but calls
  `restore()` instead of `unlock()`. `restore()` waits for the first download and reports
  a failure to the user. Until the download finishes, it saves nothing: on failure it
  removes the key, so the device is still on the welcome page, unchanged. It always starts
  from a new sync state, so a state left over from an earlier sign-out can't mark the
  account's records as deleted. The restored profile sets `onboarded`, which moves the app
  to **Today**, or to the lock screen when the device has an app-lock PIN. An account
  without a `sync_keys` row isn't given a key: the user chooses between setting up Bloom
  as new, which opens sync setup with a new phrase after the questions, and going back.
- **Change tracking.** `AppStore` reports exactly which records each method changes. A
  plain `commit()` (used by code that edits the store directly) triggers a full rescan.
  Profile and feature records are rescanned before every sync, and every record is
  rescanned once per launch. A fingerprint keeps unchanged records from being uploaded.
- **Device-only data.** The app-lock PIN, the `assistant_ai` feature (which can hold the
  user's OpenRouter key), and `notifications_log` aren't synced.
- **Erasing all data** on a device turns sync off on that device first, so the erase
  doesn't spread to other devices. **Delete synced data** is the way to delete the
  account copy.
- **Signing out** removes the data key and the session from the device and keeps the
  per-record state, so signing back in to the same account resumes. Signing in to a
  different account starts over.
- **Erasing while signed out forgets the kept state.** `AppStore.deleteAll()` calls
  `onErase` even when sync is off, and `SyncController` clears the saved sync state there.
  Otherwise, unlocking again would read every record in that state as deleted on this
  device and push deletes that win on every device. After an erase, the next unlock
  joins as a new device and adopts the account's copy.
- **Session storage.** On Android and iOS, the Supabase session is in
  `flutter_secure_storage` instead of shared preferences. On the web, it's in
  `localStorage`.
- **Supabase starts lazily.** The client initializes only when the device has a sync key
  or the user opens **You > Sync**, so the offline app makes no Supabase requests.
- **`supabase_flutter` 2.18.3** is used, with `publishableKey`. Version 3 was still a
  prerelease on pub.dev.
- **Realtime** isn't used.

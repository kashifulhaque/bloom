# Report share links

**Report for a doctor** can make a link to the report that anyone can open in a browser,
such as a clinician who doesn't use Bloom. The report is end-to-end encrypted: Bloom's
server stores only ciphertext and never receives the key.

## How it works

When you tap **Share link**, the following happens:

1. The app renders the same PDF that **Print or save PDF** makes.
1. The app makes a random 32-byte key for this link only, and seals the PDF with
   XChaCha20-Poly1305. The box format is the same as sync records: a format byte
   (`0x01`), a 24-byte nonce, the ciphertext, and a 16-byte tag. The associated data is
   `bloom/v1/report-share`, so a sync record can't be passed off as a report.
1. The app sends only the box to `POST /api/share?days=DAYS` on bloom.ifkash.dev. The
   server returns a random `id`, a `revokeToken`, and `expiresAt`.
1. The app builds the link `https://bloom.ifkash.dev/r/ID#KEY`, where `KEY` is the key in
   base64url without padding. Browsers never send the part after `#` to a server.
1. The app saves the link, the revoke token, and the expiry in the `report_shares`
   feature key. If sync is on, the list syncs end-to-end encrypted like other features,
   so another device can turn the link off.

When someone opens the link, the static page in `web/r/` loads, fetches
`GET /api/share/ID`, decrypts the box in the browser with the self-hosted `/sodium.js`,
checks that the result starts with `%PDF-`, and offers it as a PDF to download or open.
The page doesn't load the Flutter app.

To turn a link off, the app sends `DELETE /api/share/ID` with the
`X-Bloom-Revoke-Token` header. The server deletes the row at once.

## Backend

The following components serve the links:

- **nginx** in the web container proxies `/api/share` to the Edge Function. It applies
  per-address rate limits and adds two headers: `X-Bloom-Proxy-Secret` and
  `X-Bloom-Client-Ip`. Because the proxy is on the same origin as the viewer, the viewer
  needs no CORS and no new Content-Security-Policy source.
- **The `report-share` Edge Function** (`supabase/functions/report-share/`) refuses any
  request without the proxy secret, so nobody can skip the nginx limits by calling
  Supabase directly. It runs with `verify_jwt = false`.
- **Postgres** stores each box as `bytea` in `public.report_shares`. Row-level security
  is on with no policies, and only `service_role` can run the `report_share_*` functions,
  so the Data API can't read the table. A `pg_cron` job deletes expired rows every hour.
  An expired link returns `404` immediately, even before the job runs.

A Postgres table fits better than a Storage bucket here: turning a link off and expiring
it are each one `DELETE`, with no separate object to clean up. Reports are small, about
100-300 KB.

## Limits

Sharing doesn't need an account. The following limits protect the service from abuse:

| Limit | Where | Value |
|---|---|---|
| Uploads per address | nginx | 2 a minute, burst of 5 |
| Fetches and revokes per address | nginx | 30 a minute, burst of 20 |
| Upload size | nginx and the function | 2 MiB of report |
| Uploads per address per day | Postgres | 20 |
| Uploads per day, all users | Postgres | 1,000 |
| Total stored | Postgres | 500 MB |
| Link lifetime | The function and a table constraint | 1, 7, or 30 days |

For the daily per-address limit, the function stores an HMAC-SHA256 of the uploader's IP
address under the proxy secret, and deletes it after 24 hours. The viewer shows the
decrypted file only as `application/pdf`, and only if it's a PDF, so the service can't
host web pages.

## What the server can see

The server can see the following:

- The ciphertext and its size.
- When the link was made and when it expires.
- The random `id` and a SHA-256 hash of the revoke token.
- For 24 hours, a keyed hash of the uploader's IP address.
- In nginx and Supabase logs, IP addresses and the `/r/ID` path.

The server can't see the report, the key, or who the report is about.

## Configure a build

A build shows **Share link** when it has `BLOOM_SHARE_API`. On the web, use the relative
path `/api/share`. On Android and iOS, use the full URL. The following commands show
both:

```bash
flutter build web --dart-define=BLOOM_SHARE_API=/api/share
```

```bash
flutter build apk --dart-define=BLOOM_SHARE_API=https://bloom.ifkash.dev/api/share
```

The container reads the following environment variables:

- `BLOOM_SHARE_UPSTREAM`: the function URL, for example
  `https://PROJECT_REF.supabase.co/functions/v1/report-share`.
- `BLOOM_SHARE_PROXY_SECRET`: a random value that matches the function's secret of the
  same name. If either variable is empty, `/api/share` returns `503`.

## Deploy

To deploy share links to the hosted project and the VM, do the following:

1. Push the migration to the linked project:

   ```bash
   npx supabase db push --dry-run
   npx supabase db push
   ```

1. Make a secret and set it on the function. Keep it out of your shell history and the
   repository:

   ```bash
   openssl rand -base64 32 | tr -d '\n' > /tmp/bloom-share-secret
   npx supabase secrets set BLOOM_SHARE_PROXY_SECRET="$(cat /tmp/bloom-share-secret)"
   ```

1. Deploy the function:

   ```bash
   npx supabase functions deploy report-share --no-verify-jwt
   ```

1. On the VM, add the two variables to `~/docs/apps/bloom/.env`, then delete the local
   secret file:

   ```
   BLOOM_SHARE_UPSTREAM=https://PROJECT_REF.supabase.co/functions/v1/report-share
   BLOOM_SHARE_PROXY_SECRET=SECRET
   ```

1. Deploy the web container as usual. CI builds the app with `BLOOM_SHARE_API`.

## Test locally

To test with the local stack, do the following:

1. Start Supabase and apply the migrations:

   ```bash
   npx supabase start
   npx supabase migration up
   ```

1. Serve the function with a local secret file that holds
   `BLOOM_SHARE_PROXY_SECRET=SECRET`:

   ```bash
   npx supabase functions serve report-share --env-file PATH_TO_ENV_FILE
   ```

1. Build the web app with `--dart-define=BLOOM_SHARE_API=/api/share`, and run the
   container with `BLOOM_SHARE_UPSTREAM=http://host.docker.internal:54321/functions/v1/report-share`
   and the same secret.

The viewer's decryption test runs with Node.js:

```bash
npm run test:viewer
```

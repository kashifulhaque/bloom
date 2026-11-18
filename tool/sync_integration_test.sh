#!/usr/bin/env bash
# Runs test/integration/sync_local_stack_test.dart against the LOCAL Supabase
# stack. It never contacts the linked project: it reads the local URL and the
# local publishable key from `supabase status` and refuses any other host.
#
# Before you run it, start the stack from this folder with `npx supabase start`.
# The script serves Edge Functions locally while the test runs.
set -euo pipefail
cd "$(dirname "$0")/.."

status=$(npx supabase status -o env 2>/dev/null)
get() { sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" <<<"$status"; }
api_url=$(get API_URL)
publishable_key=$(get PUBLISHABLE_KEY)
mailpit_url=$(get MAILPIT_URL)

case "$api_url" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "sync_integration_test: $api_url isn't a local stack; start it with 'npx supabase start'." >&2; exit 1 ;;
esac

# Serve Edge Functions (delete-account) unless they're already served.
served_here=""
code=$(curl -s -o /dev/null -w '%{http_code}' -X OPTIONS "$api_url/functions/v1/delete-account" || true)
if [[ "$code" != "200" ]]; then
  npx supabase functions serve >/dev/null 2>&1 &
  served_here=$!
  trap 'kill "$served_here" 2>/dev/null || true' EXIT
  for _ in $(seq 1 60); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -X OPTIONS "$api_url/functions/v1/delete-account" || true)
    [[ "$code" == "200" ]] && break
    sleep 1
  done
fi

SUPABASE_LOCAL_URL="$api_url" \
SUPABASE_LOCAL_PUBLISHABLE_KEY="$publishable_key" \
SUPABASE_LOCAL_MAILPIT_URL="$mailpit_url" \
  flutter test test/integration/sync_local_stack_test.dart "$@"

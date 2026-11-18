-- Share links for the doctor report.
--
-- The app encrypts the report PDF on the device with a fresh random key and
-- uploads only the ciphertext. The key travels in the link's URL fragment
-- (https://bloom.ifkash.dev/r/<id>#<key>), which browsers never send to a
-- server, so nothing here can decrypt a report.
--
-- Nobody reaches these tables through the Data API: RLS is on with no
-- policies, and the functions below run only as service_role. The
-- report-share Edge Function calls them, behind the nginx proxy on
-- bloom.ifkash.dev, which applies per-address rate limits. See
-- docs/REPORT_SHARING.md.

create extension if not exists pg_cron with schema pg_catalog;

-- ---------------------------------------------------------------- tables

create table public.report_shares (
  -- 16 random bytes, base64url without padding.
  id           text primary key,
  -- SHA-256 of the revoke token. The token itself stays on the device.
  revoke_hash  bytea not null,
  ciphertext   bytea not null,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null,
  constraint report_shares_id_check check (id ~ '^[A-Za-z0-9_-]{22}$'),
  constraint report_shares_revoke_hash_check check (octet_length(revoke_hash) = 32),
  -- A box is a format byte, a 24-byte nonce, the ciphertext, and a 16-byte
  -- tag. 2 MiB of PDF is far more than a six-cycle report needs.
  constraint report_shares_ciphertext_check check (octet_length(ciphertext) between 1024 and 2097193),
  constraint report_shares_expiry_check check (
    expires_at > created_at and expires_at <= created_at + interval '30 days 1 minute'
  )
);

comment on table public.report_shares is
  'Bloom doctor-report share links: end-to-end encrypted PDFs that expire. The key is never sent here.';

create index report_shares_expires_idx on public.report_shares (expires_at);

-- One row per upload, for the per-client daily limit. client_hash is an
-- HMAC of the uploader's IP address under a server secret; rows are deleted
-- after 24 hours.
create table public.report_share_uploads (
  client_hash  bytea not null,
  created_at   timestamptz not null default now(),
  constraint report_share_uploads_hash_check check (octet_length(client_hash) = 32)
);

create index report_share_uploads_client_idx on public.report_share_uploads (client_hash, created_at);
create index report_share_uploads_created_idx on public.report_share_uploads (created_at);

alter table public.report_shares enable row level security;
alter table public.report_share_uploads enable row level security;

revoke all on table public.report_shares from public, anon, authenticated;
revoke all on table public.report_share_uploads from public, anon, authenticated;

-- ---------------------------------------------------------------- functions

-- Stores a new share. Raises 'rate_limited' (P0001 with that message) when the
-- client has made 20 uploads in 24 hours, and 'busy' when the service-wide
-- daily limit (1,000 uploads) or storage limit is reached. The storage limit is
-- 100 MiB, well under the free plan's 500 MB database, which turns read-only
-- when full and would also stop sync.
create or replace function public.report_share_create(
  p_id          text,
  p_revoke_hash bytea,
  p_ciphertext  bytea,
  p_days        integer,
  p_client_hash bytea
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  expires timestamptz;
begin
  if p_days not in (1, 7, 30) then
    raise exception 'bad_days' using errcode = '22023';
  end if;

  -- Serialize uploads so the limits below can't be raced.
  perform pg_advisory_xact_lock(hashtext('report_share_create'));

  if (select count(*) from public.report_share_uploads
      where client_hash = p_client_hash and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'rate_limited';
  end if;
  if (select count(*) from public.report_share_uploads
      where created_at > now() - interval '24 hours') >= 1000 then
    raise exception 'busy';
  end if;
  if (select coalesce(sum(octet_length(ciphertext)), 0) from public.report_shares)
      + octet_length(p_ciphertext) > 100 * 1024 * 1024 then
    raise exception 'busy';
  end if;

  expires := now() + make_interval(days => p_days);
  insert into public.report_share_uploads (client_hash) values (p_client_hash);
  insert into public.report_shares (id, revoke_hash, ciphertext, expires_at)
    values (p_id, p_revoke_hash, p_ciphertext, expires);
  return expires;
end;
$$;

-- Returns the ciphertext and expiry of a live share, or no row.
create or replace function public.report_share_get(p_id text)
returns table (ciphertext bytea, expires_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select s.ciphertext, s.expires_at
  from public.report_shares s
  where s.id = p_id and s.expires_at > now();
$$;

-- Deletes a share when the revoke token's hash matches. Returns whether a row
-- was deleted.
create or replace function public.report_share_revoke(p_id text, p_revoke_hash bytea)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with gone as (
    delete from public.report_shares
    where id = p_id and revoke_hash = p_revoke_hash
    returning 1
  )
  select exists (select 1 from gone);
$$;

-- Deletes expired shares and upload counts older than 24 hours.
create or replace function public.report_share_cleanup()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.report_shares where expires_at <= now();
  delete from public.report_share_uploads where created_at <= now() - interval '24 hours';
$$;

revoke all on function public.report_share_create(text, bytea, bytea, integer, bytea) from public, anon, authenticated;
revoke all on function public.report_share_get(text) from public, anon, authenticated;
revoke all on function public.report_share_revoke(text, bytea) from public, anon, authenticated;
revoke all on function public.report_share_cleanup() from public, anon, authenticated;

grant execute on function public.report_share_create(text, bytea, bytea, integer, bytea) to service_role;
grant execute on function public.report_share_get(text) to service_role;
grant execute on function public.report_share_revoke(text, bytea) to service_role;
grant execute on function public.report_share_cleanup() to service_role;

-- ---------------------------------------------------------------- cleanup

-- Expired shares already return nothing; this job frees the space.
select cron.schedule('report-share-cleanup', '17 * * * *', 'select public.report_share_cleanup()');

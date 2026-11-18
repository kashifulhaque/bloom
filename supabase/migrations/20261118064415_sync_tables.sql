-- Encrypted, optional sync for Bloom.
--
-- The server stores only ciphertext. Bloom encrypts every record on the
-- device with XChaCha20-Poly1305 before upload, and `record_id` is an HMAC of
-- the record's plaintext key, so the server can't tell which dates have logs.
-- See docs/SYNC_PLAN.md.
--
-- Version rule: an update is kept only when the incoming `version` is greater
-- than the stored one. A stale or equal version is SKIPPED, not raised: the
-- trigger returns NULL, so the row is left unchanged and isn't part of the
-- statement's RETURNING output. A batch upsert therefore never fails because
-- of one stale row. The client compares the returned rows with the rows it
-- sent and pulls the server's newer copy of any row that is missing.

-- ---------------------------------------------------------------- schema

-- Trigger functions live in a schema that the Data API doesn't expose.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------- sync_records

create table public.sync_records (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind        text not null,
  record_id   text not null,
  version     bigint not null,
  deleted     boolean not null default false,
  ciphertext  bytea not null,
  updated_at  timestamptz not null default now(),
  primary key (user_id, kind, record_id),
  constraint sync_records_kind_check check (kind in ('day', 'profile', 'feature', 'periods')),
  -- Base64url HMAC-SHA256 (43 characters). Allows a little room for change.
  constraint sync_records_record_id_check check (record_id ~ '^[A-Za-z0-9_-]{16,128}$'),
  constraint sync_records_version_check check (version > 0),
  -- 1 MiB per record is far more than any day log or feature needs.
  constraint sync_records_ciphertext_check check (octet_length(ciphertext) between 41 and 1048576)
);

comment on table public.sync_records is
  'Bloom sync: one end-to-end encrypted record per day log, profile, feature key, or month of period days.';
comment on column public.sync_records.record_id is
  'Base64url HMAC-SHA256 of kind and plaintext key, under a subkey of the user''s data key.';
comment on column public.sync_records.version is
  'Hybrid logical clock from the writing device. Updates with a version that isn''t greater are skipped.';
comment on column public.sync_records.ciphertext is
  'Format byte, 24-byte nonce, XChaCha20-Poly1305 ciphertext and tag.';
comment on column public.sync_records.updated_at is
  'Server time of the last accepted write. Set by a trigger; clients can''t choose it.';

-- "Everything changed since" pulls, ordered by (updated_at, record_id) for
-- keyset pagination. The primary key already covers lookups by user and id.
create index sync_records_user_updated_idx
  on public.sync_records (user_id, updated_at, record_id);

alter table public.sync_records enable row level security;

-- ---------------------------------------------------------------- sync_keys

create table public.sync_keys (
  user_id          uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  -- Format byte, 24-byte nonce, XChaCha20-Poly1305 of the 32-byte data key.
  wrapped_key      bytea not null,
  kdf_alg          text not null default 'argon2id13',
  kdf_salt         bytea not null,
  kdf_mem_kib      integer not null,
  kdf_iterations   integer not null,
  kdf_parallelism  integer not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint sync_keys_wrapped_key_check check (octet_length(wrapped_key) = 73),
  constraint sync_keys_kdf_alg_check check (kdf_alg = 'argon2id13'),
  constraint sync_keys_kdf_salt_check check (octet_length(kdf_salt) = 16),
  constraint sync_keys_kdf_mem_check check (kdf_mem_kib between 8192 and 1048576),
  constraint sync_keys_kdf_iterations_check check (kdf_iterations between 1 and 16),
  constraint sync_keys_kdf_parallelism_check check (kdf_parallelism = 1)
);

comment on table public.sync_keys is
  'Bloom sync: each user''s data key, wrapped with a key derived from the recovery phrase. Ciphertext only.';

alter table public.sync_keys enable row level security;

-- ---------------------------------------------------------------- triggers

-- Sets the server timestamp on every write. clock_timestamp() rather than
-- now(), so rows written later in a long transaction still sort later.
create or replace function private.sync_touch()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

-- Enforces the version rule and keeps a row's identity fixed.
create or replace function private.sync_records_before_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id
     or new.kind is distinct from old.kind
     or new.record_id is distinct from old.record_id then
    raise exception 'sync_records: user_id, kind, and record_id can''t change'
      using errcode = '42501';
  end if;

  -- Stale or duplicate write: keep the stored row and skip this one.
  if new.version <= old.version then
    return null;
  end if;

  new.updated_at := clock_timestamp();
  return new;
end;
$$;

create or replace function private.sync_keys_before_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'sync_keys: user_id can''t change' using errcode = '42501';
  end if;
  new.created_at := old.created_at;
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

revoke all on function private.sync_touch() from public, anon, authenticated;
revoke all on function private.sync_records_before_update() from public, anon, authenticated;
revoke all on function private.sync_keys_before_update() from public, anon, authenticated;

create trigger sync_records_before_insert
  before insert on public.sync_records
  for each row execute function private.sync_touch();

create trigger sync_records_before_update
  before update on public.sync_records
  for each row execute function private.sync_records_before_update();

create trigger sync_keys_before_insert
  before insert on public.sync_keys
  for each row execute function private.sync_touch();

create trigger sync_keys_before_update
  before update on public.sync_keys
  for each row execute function private.sync_keys_before_update();

-- ---------------------------------------------------------------- policies

create policy "sync_records: owner can select"
  on public.sync_records for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "sync_records: owner can insert"
  on public.sync_records for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "sync_records: owner can update"
  on public.sync_records for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "sync_records: owner can delete"
  on public.sync_records for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "sync_keys: owner can select"
  on public.sync_keys for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "sync_keys: owner can insert"
  on public.sync_keys for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "sync_keys: owner can update"
  on public.sync_keys for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "sync_keys: owner can delete"
  on public.sync_keys for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------- grants

-- Only signed-in users reach these tables through the Data API. Revoke first,
-- because projects that still auto-expose new tables grant them to anon too.
revoke all on table public.sync_records from public, anon, authenticated;
revoke all on table public.sync_keys from public, anon, authenticated;

grant select, insert, update, delete on table public.sync_records to authenticated;
grant select, insert, update, delete on table public.sync_keys to authenticated;

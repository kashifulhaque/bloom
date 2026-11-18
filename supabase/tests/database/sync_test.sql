-- pgTAP tests for the sync tables: row-level security, grants, and the
-- version trigger. Run with `npx supabase test db` against the local stack.
begin;
create extension if not exists pgtap with schema extensions;

select plan(36);

-- Two users, A and B.
insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'a@example.test'),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'b@example.test');

-- 41 bytes is the smallest valid ciphertext: format byte, nonce, and tag.
create temporary table fixture as
select
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid as a,
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid as b,
  decode(repeat('01', 41), 'hex') as c1,
  decode(repeat('02', 41), 'hex') as c2,
  decode(repeat('03', 41), 'hex') as c3,
  decode(repeat('04', 73), 'hex') as wrapped,
  decode(repeat('05', 16), 'hex') as salt;
grant select on fixture to authenticated, anon;

-- ---------------------------------------------------------------- structure

select ok((select relrowsecurity from pg_class where oid = 'public.sync_records'::regclass), 'sync_records has RLS on');
select ok((select relrowsecurity from pg_class where oid = 'public.sync_keys'::regclass), 'sync_keys has RLS on');
select ok(not has_table_privilege('anon', 'public.sync_records', 'select'), 'anon has no select on sync_records');
select ok(not has_table_privilege('anon', 'public.sync_records', 'insert'), 'anon has no insert on sync_records');
select ok(not has_table_privilege('anon', 'public.sync_keys', 'select'), 'anon has no select on sync_keys');
select ok(has_table_privilege('authenticated', 'public.sync_records', 'select, insert, update, delete'), 'authenticated has CRUD on sync_records');
select ok(not has_table_privilege('authenticated', 'public.sync_records', 'truncate'), 'authenticated can''t truncate');
select ok(not has_schema_privilege('authenticated', 'private', 'usage'), 'private schema is not usable by authenticated');
select has_index('public', 'sync_records', 'sync_records_user_updated_idx', array['user_id', 'updated_at', 'record_id'], 'pull index exists');

-- ---------------------------------------------------------------- user A writes

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);

select lives_ok(
  $$ insert into public.sync_records (kind, record_id, version, ciphertext, updated_at)
     select 'day', 'recordAAAAAAAAAAAAAAAA', 100, c1, '2000-01-01' from fixture $$,
  'A inserts a record; user_id defaults to auth.uid()');

select is((select user_id from public.sync_records where record_id = 'recordAAAAAAAAAAAAAAAA'),
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid, 'user_id came from the JWT');

select ok((select updated_at > '2020-01-01' from public.sync_records where record_id = 'recordAAAAAAAAAAAAAAAA'),
  'the client can''t choose updated_at');

select throws_ok(
  $$ insert into public.sync_records (user_id, kind, record_id, version, ciphertext)
     select b, 'day', 'recordForgedForBBBBBBBB', 1, c1 from fixture $$,
  '42501', null, 'A can''t insert a row for B');

select throws_ok(
  $$ insert into public.sync_records (kind, record_id, version, ciphertext)
     select 'secrets', 'recordAAAAAAAAAAAAAAAB', 1, c1 from fixture $$,
  '23514', null, 'unknown kinds are rejected');

select throws_ok(
  $$ insert into public.sync_records (kind, record_id, version, ciphertext)
     values ('day', 'recordAAAAAAAAAAAAAAAC', 1, '\x00') $$,
  '23514', null, 'ciphertext shorter than nonce plus tag is rejected');

select lives_ok(
  $$ insert into public.sync_keys (wrapped_key, kdf_salt, kdf_mem_kib, kdf_iterations)
     select wrapped, salt, 65536, 2 from fixture $$,
  'A stores a wrapped key');

-- ---------------------------------------------------------------- version rule

select is_empty(
  $$ insert into public.sync_records (kind, record_id, version, ciphertext)
     select 'day', 'recordAAAAAAAAAAAAAAAA', 99, c2 from fixture
     on conflict (user_id, kind, record_id) do update
       set version = excluded.version, ciphertext = excluded.ciphertext
     returning record_id $$,
  'a stale upsert returns no row');

select is((select version from public.sync_records where record_id = 'recordAAAAAAAAAAAAAAAA'), 100::bigint,
  'a stale upsert leaves the version unchanged');

select is_empty(
  $$ update public.sync_records set ciphertext = (select c2 from fixture)
     where record_id = 'recordAAAAAAAAAAAAAAAA' returning 1 $$,
  'an update with the same version is skipped');

select is((select ciphertext from public.sync_records where record_id = 'recordAAAAAAAAAAAAAAAA'),
  (select c1 from fixture), 'a skipped update leaves the ciphertext unchanged');

select isnt_empty(
  $$ insert into public.sync_records (kind, record_id, version, ciphertext)
     select 'day', 'recordAAAAAAAAAAAAAAAA', 101, c2 from fixture
     on conflict (user_id, kind, record_id) do update
       set version = excluded.version, ciphertext = excluded.ciphertext
     returning record_id $$,
  'a newer upsert returns the row');

select is((select ciphertext from public.sync_records where record_id = 'recordAAAAAAAAAAAAAAAA'),
  (select c2 from fixture), 'a newer upsert replaces the ciphertext');

select throws_ok(
  $$ update public.sync_records set user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', version = 200
     where record_id = 'recordAAAAAAAAAAAAAAAA' $$,
  '42501', null, 'A can''t reassign a row to B');

select throws_ok(
  $$ update public.sync_records set record_id = 'recordRenamedAAAAAAAAA', version = 200
     where record_id = 'recordAAAAAAAAAAAAAAAA' $$,
  '42501', null, 'a row''s record_id can''t change');

-- ---------------------------------------------------------------- user B

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);

select is_empty($$ select 1 from public.sync_records $$, 'B can''t read A''s records');
select is_empty($$ select 1 from public.sync_keys $$, 'B can''t read A''s key');

select is_empty(
  $$ update public.sync_records set version = 999, ciphertext = (select c3 from fixture)
     where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' returning 1 $$,
  'B can''t update A''s records');

select is_empty(
  $$ delete from public.sync_records where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' returning 1 $$,
  'B can''t delete A''s records');

select is_empty(
  $$ delete from public.sync_keys where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' returning 1 $$,
  'B can''t delete A''s key');

select throws_ok(
  $$ insert into public.sync_records (user_id, kind, record_id, version, ciphertext)
     select a, 'day', 'recordAAAAAAAAAAAAAAAA', 999, c3 from fixture
     on conflict (user_id, kind, record_id) do update set version = excluded.version $$,
  '42501', null, 'B can''t overwrite A''s record through an upsert with A''s user_id');

-- The same record_id under B is a separate row, not a conflict with A.
select lives_ok(
  $$ insert into public.sync_records (kind, record_id, version, ciphertext)
     select 'day', 'recordAAAAAAAAAAAAAAAA', 1, c3 from fixture $$,
  'B''s rows are separate from A''s');

-- ---------------------------------------------------------------- anon

reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok($$ select 1 from public.sync_records $$, '42501', null, 'anon can''t select sync_records');
select throws_ok($$ select 1 from public.sync_keys $$, '42501', null, 'anon can''t select sync_keys');
select throws_ok(
  $$ insert into public.sync_records (user_id, kind, record_id, version, ciphertext)
     select a, 'day', 'recordAnonAAAAAAAAAAAA', 1, c1 from fixture $$,
  '42501', null, 'anon can''t insert');

-- ---------------------------------------------------------------- final state

reset role;

select is((select version from public.sync_records
           where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and record_id = 'recordAAAAAAAAAAAAAAAA'),
  101::bigint, 'A''s record kept the newest version through B''s attempts');

select is((select count(*)::int from public.sync_keys where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1, 'A''s key survived B''s attempts');

select * from finish();
rollback;

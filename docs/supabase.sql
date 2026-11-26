-- 볼링 연습일지 — Supabase 표·보호 규칙(RLS)·초대 코드·사진 버킷
-- 쓰는 법: Supabase 화면 > SQL Editor > New query 에 이 파일 전체를 붙여 넣고 Run.
-- 여러 번 실행해도 괜찮게 만들었다 (이미 있는 것은 건너뛰거나 다시 만든다).
-- 설계: docs/supabase.md
--
-- 규칙 요약
--  * 기록 표(profiles·balls·days)와 사진은 "내 것" + "초대 코드를 넣은 사람"일 때만 읽고 쓴다.
--  * 초대 코드 목록(invite_codes)은 앱에서 읽을 수 없다. 코드 확인은 서버 함수 join_with_code 만 한다.
--  * 지우기는 deleted = true 로 표시 (진짜 삭제 권한은 주지 않음).
--  * updated_at 은 서버 시각으로 자동 기록 (휴대폰 시계가 틀려도 동기화가 꼬이지 않게).

-- ───────────────────────── 1. 초대 코드와 회원 ─────────────────────────
create table if not exists public.invite_codes (
  code       text primary key,
  max_uses   int  not null default 30,         -- 이 코드로 가입할 수 있는 사람 수
  used       int  not null default 0,
  expires_at timestamptz,                      -- 비워 두면 기한 없음
  note       text,                             -- 예: '수요일 모임'
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  user_id   uuid primary key references auth.users on delete cascade,
  code      text not null,
  joined_at timestamptz not null default now()
);

-- 코드 맞히기 시도를 막으려고 틀린 기록을 남긴다 (1시간에 10번 틀리면 잠시 막힘)
create table if not exists public.invite_fails (
  user_id uuid not null references auth.users on delete cascade,
  at      timestamptz not null default now()
);
create index if not exists invite_fails_user_at on public.invite_fails (user_id, at);

alter table public.invite_codes enable row level security;   -- 규칙 없음 = 앱에서 아무도 못 읽음
alter table public.invite_fails enable row level security;   -- 규칙 없음 = 앱에서 아무도 못 읽음
alter table public.members      enable row level security;

drop policy if exists "see own membership" on public.members;
create policy "see own membership" on public.members
  for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.invite_codes, public.invite_fails, public.members from anon, authenticated;
grant select on public.members to authenticated;

-- 지금 로그인한 사람이 회원(초대 코드 넣은 사람)인가?
create or replace function public.is_member()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.members where user_id = (select auth.uid()));
$$;

-- 초대 코드 넣기. 돌려주는 값: ok / already / bad / expired / full / too_many / not_signed_in
create or replace function public.join_with_code(p_code text)
returns text
language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  c   public.invite_codes%rowtype;
begin
  if uid is null then return 'not_signed_in'; end if;
  if exists (select 1 from public.members where user_id = uid) then return 'already'; end if;
  if (select count(*) from public.invite_fails
        where user_id = uid and at > now() - interval '1 hour') >= 10 then
    return 'too_many';
  end if;

  select * into c from public.invite_codes
    where code = upper(trim(coalesce(p_code, ''))) for update;
  if not found then
    insert into public.invite_fails (user_id) values (uid);
    return 'bad';
  end if;
  if c.expires_at is not null and c.expires_at < now() then return 'expired'; end if;
  if c.used >= c.max_uses then return 'full'; end if;

  update public.invite_codes set used = used + 1 where code = c.code;
  insert into public.members (user_id, code) values (uid, c.code);
  return 'ok';
end;
$$;

revoke all on function public.is_member()            from public, anon;
revoke all on function public.join_with_code(text)   from public, anon;
grant execute on function public.is_member()          to authenticated;
grant execute on function public.join_with_code(text) to authenticated;

-- ───────────────────────── 2. 기록 표 ─────────────────────────
-- 사람(프로필): 계정 1개에 여러 사람 (지금 앱의 "사용자1~6")
create table if not exists public.profiles (
  id         text primary key,                 -- 앱의 newId() 값 그대로
  owner      uuid not null default auth.uid() references auth.users on delete cascade,
  name       text not null,
  ord        int  default 0,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false
);

create table if not exists public.balls (
  id         text primary key,
  owner      uuid not null default auth.uid() references auth.users on delete cascade,
  pid        text not null references public.profiles(id),
  name       text,
  weight     numeric,
  hand       text,
  memo       text,
  active     boolean default true,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false
);

create table if not exists public.days (
  id         text primary key,
  owner      uuid not null default auth.uid() references auth.users on delete cascade,
  pid        text not null references public.profiles(id),
  date       date not null,
  place      text,
  lane       text,
  ball_id    text,
  memo       text,
  games      jsonb not null default '[]',      -- [{mode, rolls, score, strike, split, open, ballId, memo, photoId, cumFix}]
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false
);

-- (3단계 추가) 앱의 만든 시각(ms) — 볼 목록 순서에 쓴다
alter table public.balls add column if not exists created bigint;
alter table public.days  add column if not exists created bigint;
-- (v0.7 추가) 일지 종류(대회/개인연습/단체연습/기타)·대회 이름, 사람별 볼링장 목록 [{name, memo}]
alter table public.days     add column if not exists kind   text;
alter table public.days     add column if not exists match  text;
alter table public.profiles add column if not exists places jsonb not null default '[]';

create index if not exists profiles_owner_upd on public.profiles (owner, updated_at);
create index if not exists balls_owner_upd    on public.balls    (owner, updated_at);
create index if not exists days_owner_upd     on public.days     (owner, updated_at);

-- updated_at 은 서버 시각으로
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at := now(); return new; end; $$;

drop trigger if exists touch on public.profiles;
drop trigger if exists touch on public.balls;
drop trigger if exists touch on public.days;
create trigger touch before insert or update on public.profiles for each row execute function public.touch_updated_at();
create trigger touch before insert or update on public.balls    for each row execute function public.touch_updated_at();
create trigger touch before insert or update on public.days     for each row execute function public.touch_updated_at();

-- 보호 규칙: 내 것 + 회원일 때만 (세 표 모두 같음)
alter table public.profiles enable row level security;
alter table public.balls    enable row level security;
alter table public.days     enable row level security;

drop policy if exists "own rows, members only" on public.profiles;
drop policy if exists "own rows, members only" on public.balls;
drop policy if exists "own rows, members only" on public.days;
create policy "own rows, members only" on public.profiles for all to authenticated
  using      (owner = (select auth.uid()) and (select public.is_member()))
  with check (owner = (select auth.uid()) and (select public.is_member()));
create policy "own rows, members only" on public.balls for all to authenticated
  using      (owner = (select auth.uid()) and (select public.is_member()))
  with check (owner = (select auth.uid()) and (select public.is_member()));
create policy "own rows, members only" on public.days for all to authenticated
  using      (owner = (select auth.uid()) and (select public.is_member()))
  with check (owner = (select auth.uid()) and (select public.is_member()));

-- 로그인 안 한 사람(anon)은 아무것도 못 함. 로그인한 사람은 읽기·넣기·고치기만 (지우기는 deleted 표시)
revoke all on public.profiles, public.balls, public.days from anon, authenticated;
grant select, insert, update on public.profiles, public.balls, public.days to authenticated;

-- ───────────────────────── 3. 사진 버킷 (비공개) ─────────────────────────
-- 경로: {내 uid}/{photoId}.jpg   · 1장 최대 2MB · JPEG 만
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 2097152, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "photos: own folder read"   on storage.objects;
drop policy if exists "photos: own folder insert" on storage.objects;
drop policy if exists "photos: own folder update" on storage.objects;
drop policy if exists "photos: own folder delete" on storage.objects;
create policy "photos: own folder read" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member()));
create policy "photos: own folder insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member()));
create policy "photos: own folder update" on storage.objects for update to authenticated
  using      (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member()))
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member()));
create policy "photos: own folder delete" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member()));

-- ───────────────────────── 4. 확인 ─────────────────────────
-- 아래 결과에서 rls_on 이 모두 true 여야 한다.
select c.relname as table_name, c.relrowsecurity as rls_on
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by 1;

-- ───────────────────────── (따로) 초대 코드 만들기 ─────────────────────────
-- 코드는 이 파일(공개 보관함)에 적지 않는다. 필요할 때 SQL Editor 에서 아래만 따로 실행하면
-- 무작위 코드가 만들어지고 화면에 나온다. 그 코드를 모임 사람들에게 알려 준다.
--
--   insert into public.invite_codes (code, max_uses, note)
--   values (upper(substr(md5(random()::text), 1, 8)), 30, '볼링 모임')
--   returning code, max_uses;
--
-- 코드 목록·사용 수 보기:   select * from public.invite_codes;
-- 코드 막기(더 못 쓰게):    update public.invite_codes set max_uses = used where code = 'ABCD1234';

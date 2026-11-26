# 서버 방식 설계 (Supabase) — 초안

> 상태: **만드는 중 — 1·2단계 끝 (v0.5 로그인·초대 코드 가입 실제 성공)**. 다음은 3단계 동기화.
> 목표 인원: 20~30명. 비용: Supabase 무료 요금제 안에서.

## 0. 프로젝트 (2026-11-26 사용자가 만듦, 지역 서울)
- 주소: `https://gxwquxyymjfgtimzlglr.supabase.co`
- 공개 키(publishable, 예전 이름 anon): `sb_publishable_hs6lOQupvkCSs0KMotr89g_hm_v8pV0` — 앱에 넣어도 되는 키
- **secret / service_role 키와 DB 비밀번호는 여기·앱·대화 어디에도 적지 않는다.**
- 표·규칙 SQL: [`supabase.sql`](supabase.sql) — SQL Editor 에 붙여 넣고 Run

## 1. 왜 바꾸나 (지금의 한계)
| 지금 (v0.4) | 바꾸면 |
|---|---|
| 기록이 **그 휴대폰 브라우저에만** 있다 | 서버에 있어서 휴대폰을 바꾸거나 인터넷 기록을 지워도 남는다 |
| 백업 파일을 손으로 저장·불러오기 | 저장하면 자동으로 서버에도 올라간다 |
| 주소가 바뀌면 기록이 안 보인다 (주소별 저장) | 어느 주소·어느 기기든 로그인하면 보인다 |
| 다른 사람 기록은 볼 수 없다 | (원하면) 모임 사람끼리 평균·순위 보기 가능 |

## 2. 큰 틀
```
휴대폰 (index.html)
  ├─ IndexedDB  ← 지금처럼 먼저 여기에 저장 (인터넷 없어도 됨)
  └─ 동기화      ← 인터넷 되면 서버와 주고받기
          │
Supabase (서버)
  ├─ 로그인 (Auth)
  ├─ 표 (Postgres): profiles, balls, days
  └─ 사진 보관 (Storage): photos/{사용자}/{사진id}.jpg  ← 비공개
```
- **빌드 없는 정적 앱은 그대로.** GitHub Pages 주소도 그대로. `supabase-js` 를 jsdelivr ESM 으로 버전 고정해 불러온다 (지금 Claude SDK 와 같은 방식).
- **오프라인 먼저**: 볼링장 와이파이가 약해도 기록이 막히지 않게, 저장은 늘 IndexedDB 에 먼저 하고 서버는 뒤에서 맞춘다.
- AI 키는 지금처럼 그 휴대폰에만 둔다 (서버에 안 올림).

## 3. 공개 보관함과 키
- 앱에 넣는 것은 **anon(공개) 키**와 프로젝트 주소뿐. 이 키는 공개돼도 되는 키이고, 실제 보호는 아래 **RLS(행 보호 규칙)** 가 한다.
- **service_role 키는 절대 보관함·앱에 넣지 않는다.** (모든 규칙을 건너뛰는 관리자 키)
- RLS 를 켜지 않은 표가 하나라도 있으면 누구나 읽고 쓸 수 있다 → 표를 만들 때마다 RLS 확인을 시험 항목에 넣는다.

## 4. 표 설계
지금 IndexedDB 의 모양을 거의 그대로 옮긴다. 게임 목록은 지금처럼 `days.games` 안에 JSON 으로 둔다 (점수 계산 `BW` 를 안 고쳐도 됨).

```sql
-- 사람(프로필): 로그인 계정 1개 안에 여러 사람을 둘 수 있게 (한 휴대폰을 가족이 같이 쓰는 경우)
create table profiles (
  id         text primary key,          -- 지금의 newId() 값 그대로
  owner      uuid not null default auth.uid() references auth.users,
  name       text not null,
  ord        int  default 0,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false
);

create table balls (
  id text primary key, owner uuid not null default auth.uid() references auth.users,
  pid text not null references profiles(id),
  name text, weight numeric, hand text, memo text, active boolean default true,
  updated_at timestamptz not null default now(), deleted boolean not null default false
);

create table days (
  id text primary key, owner uuid not null default auth.uid() references auth.users,
  pid text not null references profiles(id),
  date date not null, place text, lane text, ball_id text, memo text,
  games jsonb not null default '[]',      -- [{mode, rolls, score, strike, split, open, ballId, memo, photoId, cumFix}]
  updated_at timestamptz not null default now(), deleted boolean not null default false
);
create index on days (owner, updated_at);

-- 행 보호: 내 것만 읽고 쓴다 (세 표 모두 같은 규칙)
alter table days enable row level security;
create policy "own rows" on days for all
  using (owner = auth.uid()) with check (owner = auth.uid());
```
- 사진: Storage 버킷 `photos` (비공개). 경로 `{auth.uid()}/{photoId}.jpg`, 규칙은 "경로 첫 칸이 내 uid 일 때만". 지금처럼 1600px·JPEG 82% 로 줄여서 올린다 (장당 약 200~400KB).
- 지우기는 바로 지우지 않고 `deleted = true` 로 표시 → 다른 기기에도 "지워졌다"가 전해진다.

## 5. 동기화 방식 (간단하게)
1. 저장/지우기 → IndexedDB 에 쓰고 `updated` 시각을 넣고 "올릴 목록"에 추가.
2. 인터넷 되면 올릴 목록을 서버에 `upsert` (사진은 먼저 Storage 에 올림).
3. 앱을 열 때·화면에 돌아올 때 `updated_at > 마지막으로 받은 시각` 인 것만 받아서 IndexedDB 에 덮어쓴다.
4. 같은 일지를 두 기기에서 동시에 고친 경우 **나중에 저장한 쪽이 이긴다**. (혼자 쓰는 일지라 드문 경우 — 이 정도로 충분하다고 본다)

## 6. 지금 쓰는 사람들 옮기기
- 처음 로그인하면 "이 휴대폰에 있는 기록 N일치를 서버로 올릴까요?" → 한 번에 올린다. id 가 같아서 두 번 올려도 겹치지 않는다.
- 로그인 안 하고 지금처럼 **휴대폰에만 저장**하는 방식도 남겨 둔다 (설정에서 고름).
- 백업 파일 기능도 남긴다.

## 7. 무료 요금제 확인 (만들기 전에 Supabase 사이트에서 다시 확인)
- DB 500MB, 사진 보관 1GB, 월 사용자 5만 명 → 30명 기준 DB 는 충분. **사진이 관건**: 1장 300KB 로 치면 약 3,000장. 1인당 하루 1~2장이면 몇 달~1년쯤에 꽉 찬다 → 사진을 더 작게(1200px) 하거나, 오래된 사진은 휴대폰에만 두는 방법을 나중에 정한다.
- **무료 프로젝트는 1주일 동안 아무도 안 쓰면 잠든다.** 사이트에서 다시 깨우면 되고 기록은 안 사라진다. 매주 누가 쓰면 문제없다.

## 8. 만드는 순서
| 단계 | 할 일 | 누가 |
|---|---|---|
| 0 | Supabase 가입·프로젝트 만들기(지역: 서울), 주소·anon 키 받기 | 사용자 (계정 만들기라 직접) |
| 1 | 표·RLS·사진 버킷 SQL 만들기 (`docs/supabase.sql`), 다른 계정으로 남의 기록이 안 보이는지 시험 | Claude |
| 2 | 로그인 화면 + 초대 코드 (v0.5, 설정에서 버전 글자 5번 눌러야 보임). "저장 방식" 고르기는 3단계로 미룸 | Claude |
| 3 | 동기화 (올릴 목록, 받기, 사진) + 휴대폰 기록 옮기기 | Claude |
| 4 | 두 기기로 시험: 오프라인 저장 → 다시 연결, 지우기 전파, 사진 | 같이 |
| 5 | (선택) 모임 기능: 서로 평균·순위 보기 | 나중에 |

`sw.js` 는 Supabase 요청을 캐시하지 않게 해야 한다 (고치면 캐시 이름 v3).

### 1단계에서 정한 것 (supabase.sql)
- 초대 코드: `invite_codes`(앱에서 못 읽음) · `members`(코드를 넣은 사람) · 서버 함수 `join_with_code(code)` → `ok/already/bad/expired/full/too_many`. 1시간에 10번 틀리면 잠시 막음.
- 기록 표 규칙: `owner = 내 uid` **그리고** `is_member()`. 로그인만 하고 코드를 안 넣으면 읽기·쓰기 모두 막힌다.
- 로그인 안 한 사람(anon)은 표에 아무 권한 없음. 로그인한 사람도 진짜 삭제(DELETE) 권한은 없음 → `deleted = true`.
- `updated_at` 은 서버가 트리거로 넣는다 (휴대폰 시계 무관).
- 사진 버킷 `photos`: 비공개, 1장 최대 2MB, JPEG 만, `{uid}/…` 폴더만.
- 초대 코드 자체는 공개 보관함에 적지 않는다 (supabase.sql 맨 아래 방법으로 SQL Editor 에서 만든다).
- 동기화 순서 주의: `balls`·`days` 는 `profiles` 를 참조하므로 profiles 를 먼저 올린다.

### 2단계 전에 Supabase 화면에서 할 설정
- **메일 서버: Gmail SMTP 로 정함 (2026-11-26).** Supabase 는 SMTP 를 직접 연결해야 메일 내용을 고칠 수 있고, 기본 메일은 시간당 몇 통뿐이라 30명에 부족.
  - Gmail(2단계 인증 + 앱 비밀번호) → Authentication → Emails → SMTP Settings: 호스트 `smtp.gmail.com`, 포트 `465`. 앱 비밀번호는 Supabase 화면에만 넣는다 (보관함·대화 금지).
  - Rate Limits 의 메일 수 한도를 시간당 100 정도로 올린다.
- 그다음 메일 내용("Magic link or OTP", "Confirm signup")에 `{{ .Token }}` (6자리 번호)를 넣는다.
- 메일 내용은 **두 곳 모두** 바꾼다: "Confirm sign up"(처음 가입하는 사람) · "Magic link or OTP"(두 번째부터). 저장 후 1~2분 지나야 적용.
- 번호 길이: Sign In / Providers → Email → Email OTP Length (이 프로젝트 기본 8 → 6 으로). 앱은 6~10자리 받음.
- 메일 속 **링크** 로그인은 쓰지 않는다: 홈 화면 앱과 브라우저는 저장 공간이 달라(특히 아이폰) 엉뚱한 곳에 로그인된다.

## 9. 정한 것 (사용자 결정 2026-11-26, 회사 서브컴)
1. 로그인 방법 → **이메일로 받은 6자리 번호** (비밀번호 없음)
2. 계정과 사람 → **계정 1개에 여러 사람** (지금 "사용자1~6" 그대로)
3. 가입 범위 → **초대 코드가 있어야 가입** (추천안과 다름 — 처음부터 모임 사람만)
   - 만들 때: 이메일 번호로 로그인은 되더라도, 초대 코드를 넣기 전에는 기록 표에 쓰지 못하게 RLS 로 막는다
     (코드 확인은 서버 함수에서. 코드 목록은 앱에서 읽을 수 없게)
4. 모임 사람끼리 기록 보기 → **처음엔 내 것만**, 나중에 단계 5로

### (처음 안 — 참고)
1. **로그인 방법** — 추천: *이메일로 받은 6자리 번호* (비밀번호 없음, 무료). 다른 안: 이메일+비밀번호 / 카카오 로그인(카카오 개발자 등록 필요, 가장 편하지만 준비가 많음).
2. **계정과 사람** — 추천: 계정 1개에 여러 사람 가능(지금 "사용자1~6" 그대로). 다른 안: 계정 1개 = 1명.
3. **아무나 가입?** — 추천: 아무나 가입 가능하게 두고, 나중에 필요하면 "초대 코드"를 넣는다.
4. **모임 사람끼리 기록 보기** — 처음엔 안 넣고(내 것만), 나중에 단계 5로.

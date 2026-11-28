# CLAUDE.md — 볼링 연습일지

휴대폰용 볼링 연습 기록 앱. 파일만 있으면 도는 정적 웹앱(빌드 없음, 서버 저장 없음).
**ERP 프로젝트와 별개다.** ERP 저장소(`C:\workspace\erp`)에 볼링 파일을 넣지 않는다.

## 시작할 때 / 끝낼 때
- 시작: `git pull` → `HANDOFF.md` 읽고 `상태: 진행중` 항목이 있으면 이어서 할지 묻는다.
- 끝: `HANDOFF.md` 맨 위 항목 갱신 → 저장 기록 남기기 → 보관함에 올리기(push). 올리지 않으면 다른 컴퓨터에서 안 보인다.
- **"볼링 (프로그램) 이어서 하자"** 라고 하면: 묻지 말고 `git pull` → `HANDOFF.md` 맨 위 `진행중` 항목을 3~4줄로 요약 → 그 항목의 "남은 일" 1번부터 바로 이어 간다. 사용자가 정해야 하는 일이면 그 결정부터 묻는다.
- 새 컴퓨터 처음 한 번: `git clone https://github.com/sunboys20/bowling-diary C:\workspace\bowling-diary` → `powershell -ExecutionPolicy Bypass -File C:\workspace\bowling-diary\tools\setup_claude.ps1` (저장 기록 이메일 + 어느 폴더에서든 "볼링 이어서"가 통하게 `~/.claude/CLAUDE.md` 에 안내 추가)
- 사용자는 git 초보에 가깝다. 설명은 쉬운 우리말로 한다 (ERP 쪽 소통 규칙과 같음).

## ⚠️ 공개 보관함
- `github.com/sunboys20/bowling-diary` 는 **공개**다 (GitHub Pages 무료 사용 때문).
- 새 컴퓨터에서 받은 뒤 저장 기록 이메일을 꼭 GitHub 대체 주소로 맞춘다:
  ```
  git -C C:\workspace\bowling-diary config user.email 273581171+sunboys20@users.noreply.github.com
  ```
- 개인 정보·ERP 내용·API 키·백업 파일(`볼링일지_백업_*.json`)을 올리지 않는다.

## 구조
| 파일 | 하는 일 |
|---|---|
| `index.html` | 앱 전체 (화면·점수 계산 `BW`·IndexedDB 저장·인쇄·AI 사진 읽기). 버전 `APP_VER` |
| `manifest.webmanifest`, `icons/` | 홈 화면 이름·아이콘 |
| `help.html`, `help/*.png` | 사용 설명서. 사진은 체험 모드 화면을 375px 로 찍은 것 — 화면이 바뀌면 다시 찍는다: 로컬 서버를 켜고 `node tools/shots.mjs http://localhost:8153 [이름…]` (tools/_shot.html 화면을 크롬으로 찍음, 이름 없으면 전부). 가입 설명서 `signup.html` 사진은 `help/signup-*.png` |
| `sw.js` | 오프라인 열기 (https 에서만 등록). 캐시 이름 `bowling-diary-v5` — 고치면 숫자를 올린다. 글꼴(Pretendard)·아이콘(Tabler) CDN 도 저장 |
| `docs/server2.md`, `tools/setup_server2.ps1` | server2 예비 주소(8892) |
| `docs/supabase.md` | 서버 방식(Supabase) 설계 초안 — 아직 앱에 반영 안 됨 |

- 주소: https://sunboys20.github.io/bowling-diary/ — main 에 push 하면 1분쯤 뒤 반영.
- 설치 링크: 주소 뒤 `?install=1` — 첫 화면에서 설치 단추·안내가 바로 뜬다 (읽은 뒤 주소에서 지움). index.html `INST`·`instMode()`: 안드로이드 `beforeinstallprompt` → [설치] 단추(`prompt()`), 아이폰 사파리 → [공유]→[홈 화면에 추가] 안내(아래 화살표), 카톡 등 앱 안 브라우저 → 크롬(`intent://`)/사파리(`kakaotalk://web/openExternal`)로 열기. 띠는 기록·볼러 고르기 화면 위(`.inst-slot`), 설정 카드. 설치되어 연 경우(standalone)·체험 모드는 안 띄움. 닫으면 7일 안 뜸(localStorage `bowling-diary-inst-hide`)
- 체험 모드: 주소 뒤 `?demo` — 따로 저장 공간 `bowling-diary-demo` 에 예시 기록(`seedDemo`)을 만든다. 서버·진짜 기록과 안 섞임.
- 기록은 각 휴대폰 브라우저(IndexedDB)에만 있다. 주소가 바뀌면 기록이 안 보인다(주소별 저장).
- AI 자동 입력: 브라우저에서 Claude API 직접 호출. SDK `@anthropic-ai/sdk@1.6.0` (jsdelivr ESM), 기본 모델 `claude-haiku-5-5`(`AI_DEFAULT`, 싸고 빠름 — 설정에서 Opus 5.5 로 바꿀 수 있음), 키는 사용자가 [설정]에 넣는다.

## 디자인
- 글꼴 Pretendard, 아이콘 Tabler webfont (jsdelivr, 버전 고정). 색은 `:root` 변수 — 어두운 모드 두 곳(`@media`, `[data-theme=dark]`)도 같이 고친다. 사용자가 설정 [화면]에서 자동/밝게/어둡게를 고르면 `<head>` 의 `applyTheme` 가 `data-theme` 를 붙인다(localStorage `bowling-diary-theme`, help·signup 도 같은 줄).
- v0.7 디자인: 연한 파랑(시안 C). 화면 점수판은 `gridHTML`(5프레임×2줄, 누적 점수는 약하게), A4 인쇄 기록지는 예전 `boardHTML`(한 줄 10칸).
- 볼링 그림(핀·공)은 index.html 맨 위 `<symbol>` + `PINS_SVG`·`ballSVG`.
- 일지 `kind`(대회/개인연습/단체연습/기타)·`match`(대회 이름), 사람 `places`([{name, memo}]), 메인 점수판 선택은 meta `homeBoards`(이 기기만).
- 중간 점수 고치기: 게임에 `cumFix: {프레임번호(0~9): 누적점수}`. 계산은 `BW.cumFixed`·`BW.scoreOf`.

## 시험
- 로컬: 폴더에서 `php -S localhost:8920` 또는 `npx serve` 후 브라우저 375px 폭으로 본다.
- 점수 계산을 고치면 300점·90점(전부 9-)·150점(전부 5/5) 과 실제 점수판 사진 예시로 다시 확인한다.
- server2 설정(Apache·포트·방화벽)은 **server2 에서만** 한다.

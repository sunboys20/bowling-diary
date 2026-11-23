# CLAUDE.md — 볼링 연습일지

휴대폰용 볼링 연습 기록 앱. 파일만 있으면 도는 정적 웹앱(빌드 없음, 서버 저장 없음).
**ERP 프로젝트와 별개다.** ERP 저장소(`C:\workspace\erp`)에 볼링 파일을 넣지 않는다.

## 시작할 때 / 끝낼 때
- 시작: `git pull` → `HANDOFF.md` 읽고 `상태: 진행중` 항목이 있으면 이어서 할지 묻는다.
- 끝: `HANDOFF.md` 맨 위 항목 갱신 → 저장 기록 남기기 → 보관함에 올리기(push). 올리지 않으면 다른 컴퓨터에서 안 보인다.
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
| `sw.js` | 오프라인 열기 (https 에서만 등록). 캐시 이름 `bowling-diary-v1` |
| `docs/server2.md`, `tools/setup_server2.ps1` | server2 예비 주소(8892) |

- 주소: https://sunboys20.github.io/bowling-diary/ — main 에 push 하면 1분쯤 뒤 반영.
- 기록은 각 휴대폰 브라우저(IndexedDB)에만 있다. 주소가 바뀌면 기록이 안 보인다(주소별 저장).
- AI 자동 입력: 브라우저에서 Claude API 직접 호출. SDK `@anthropic-ai/sdk@1.6.0` (jsdelivr ESM), 기본 모델 `claude-opus-5-5`, 키는 사용자가 [설정]에 넣는다.

## 시험
- 로컬: 폴더에서 `php -S localhost:8920` 또는 `npx serve` 후 브라우저 375px 폭으로 본다.
- 점수 계산을 고치면 300점·90점(전부 9-)·150점(전부 5/5) 과 실제 점수판 사진 예시로 다시 확인한다.
- server2 설정(Apache·포트·방화벽)은 **server2 에서만** 한다.

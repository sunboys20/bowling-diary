
<!-- bowling-diary:start -->
# 볼링 연습일지 (개인 앱 — ERP 와 별개)
- 사용자가 "볼링 이어서", "볼링 프로그램 이어서하자"처럼 말하면 저장소 `C:\workspace\bowling-diary` 에서 이어서 한다.
  - 지금 세션 폴더가 거기가 아니면(예: ERP 폴더) 이 세션에서 볼링 파일을 고치지 않는다. 데스크톱 앱이면 그 폴더(`cwd`)로 새 세션을 열어 넘기고, 아니면 그 폴더에서 Claude 를 열어 달라고 쉬운 말로 안내한다.
  - 폴더가 없으면 먼저 받는다: `git clone https://github.com/sunboys20/bowling-diary C:\workspace\bowling-diary` → `powershell -ExecutionPolicy Bypass -File C:\workspace\bowling-diary\tools\setup_claude.ps1`
  - 그다음은 저장소 `CLAUDE.md` 의 "이어서 하자" 순서를 따른다.
<!-- bowling-diary:end -->

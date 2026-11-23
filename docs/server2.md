# server2에 올리기 (8892)

GitHub 페이지(https://sunboys20.github.io/bowling-diary/)가 **기본 주소**예요. server2는 사무실 안에서 쓰거나, GitHub가 안 될 때 쓰는 **예비 주소**예요.

- 앱은 파일만 있으면 돼요 (PHP·DB 없음). 기록은 각자 휴대폰에 저장되고 server2에는 저장되지 않아요.
- ERP(8888·8889)와 섞지 않으려고 **따로 폴더 + 따로 포트(8892)**를 써요.
- 서버 설정은 **회사 서버컴(server2)에서만** 해요 (ERP 프로젝트 규칙과 같음).

## 처음 한 번 (server2에서, 관리자 PowerShell)

```powershell
git clone https://github.com/sunboys20/bowling-diary.git C:\workspace\bowling-diary
powershell -ExecutionPolicy Bypass -File C:\workspace\bowling-diary\tools\setup_server2.ps1
```
위 명령은 할 일만 보여 줘요. 확인한 뒤 `-Apply`를 붙여 다시 실행하고, 화면에 나오는 1~6번을 따라 해요.
- Apache 다시 시작
- 방화벽 열기
- 바깥에서도 쓰려면 iptime 포트포워딩

## 주소
| 어디서 | 주소 |
|---|---|
| server2 자신 | http://localhost:8892/ |
| 사무실 PC·휴대폰(사무실 와이파이) | http://192.168.0.15:8892/ |
| 바깥 (포트포워딩 했을 때만) | http://sunboy.iptime.org:8892/ |

server2 주소는 `https`가 아니라서, 인터넷이 약할 때 열리게 하는 기능(sw.js)은 꺼져요. 그 밖의 기능은 똑같아요.
주소마다 저장 공간이 따로라서, GitHub 주소에서 쓴 기록은 server2 주소에서 보이지 않아요. 한 사람은 한 주소만 쓰고, 옮길 때는 백업 파일로 옮겨요.

## 새 버전 반영
```powershell
git -C C:\workspace\bowling-diary pull
```
Apache는 다시 시작하지 않아도 돼요.

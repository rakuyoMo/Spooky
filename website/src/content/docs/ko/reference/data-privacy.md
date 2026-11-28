---
title: "데이터와 개인정보 보호"
description: "Spooky가 무엇을 어디에 저장하는지, 어떤 네트워크 주소에 연결하는지, 충돌 보고서와 진단 보고서에 무엇이 들어가는지 알아봅니다."
---

Spooky에는 계정이 없으며, Spooky는 사용 데이터를 수집하지 않습니다. 이 페이지에는 Spooky가 무엇을 저장하고, 어디에 저장하며, 어떤 주소에 연결하는지 나와 있습니다.

## Mac에 저장되는 것 {#mac}

| 무엇을 | 어디에 |
|---|---|
| 설정, 저장소 목록, 사용자 프로필, 호스팅 계정 목록, 서버 저장소의 이 Mac의 위치, 도구 막대 버튼과 그 스크립트 | Spooky의 환경설정 `com.rakuyo.spooky` |
| 테마. 테마마다 `.spookytheme` 파일 하나 | `~/Library/Application Support/Spooky/Themes/` |
| 서버 저장소가 최근 문서에 나타나게 해 주는 작은 `.spookyrepo` 폴더 | `~/Library/Application Support/Spooky/Locations/` |
| :ui[activity.title]에 있는 가져오기, 풀, 푸시 같은 원격 작업의 기록. 7일 동안 보관됩니다 | `~/Library/Application Support/Spooky/Activity/` |
| :ui[activity.title]이 변경 사항을 셀 때 비교하는 기준. 저장소마다 파일 하나 | `~/Library/Application Support/Spooky/Baselines/` |
| 서버의 Git용으로 저장한 사용자 이름과 암호 | 키체인. `com.rakuyo.spooky.remote.<host alias>`라는 이름의 항목 |
| 호스팅 계정의 토큰 | 키체인. `com.rakuyo.spooky.hosting.<address>`라는 이름의 항목 |
| macOS가 Spooky의 네트워크 요청용으로 보관하는 캐시와 쿠키 | `~/Library/Caches/com.rakuyo.spooky/`, 그리고 `~/Library/HTTPStorages/`에서 이름이 `com.rakuyo.spooky`로 시작하는 항목 |
| 서버 저장소의 연결 파일 | `/tmp/spooky-*` 폴더. 연결이 닫히면 제거됩니다 |
| 훑어보기나 다른 앱에서 연 파일의 사본 | 임시 `spooky-files-*` 폴더. 저장소가 닫히면 제거됩니다 |

자체 관리형 GitLab에 사용자 이름과 암호로 로그인하면 Spooky는 그 대가로 받은 토큰을 보관합니다. 암호는 보관하지 않습니다.

이 모두를 제거하려면 [제거](/guide/start/install/#uninstall)를 참고하세요.

:ui[app.name > settings.title] › :ui[settings.sshHosts]에서 추가한 호스트 별칭은 SSH가 직접 읽는 파일인 `~/.ssh/config`에 저장됩니다. 이 파일은 Spooky의 것이 아니므로, Spooky를 제거해도 그대로 남습니다. [호스트 별칭 추가하기](/guide/server/prepare-ssh/#alias)를 참고하세요.

## 서버에 저장되는 것 {#servers}

저장소 자체 말고도 Spooky는 서버의 두 곳에 씁니다.

- 홈 폴더의 `~/.spooky/bin/`: Spooky가 SSH로 실행하는 작은 스크립트와, 입력 요청과 서명에 쓰이는 그 스크립트의 링크입니다. 다음 연결을 위해 그대로 남습니다. Spooky는 설치할 때마다 30일 동안 쓰이지 않은 이전 버전을 삭제합니다. 없애려면 폴더를 삭제합니다.
- `/tmp/spooky-*`: 현재 연결에 쓰는 파일입니다. 연결이 닫히면 제거됩니다.

Spooky가 저장소의 [이 Mac의 위치](/guide/server/local-location/#automatic)를 찾을 때는 저장소의 Git 폴더에 빈 파일을 잠깐 넣습니다. 확인이 끝나면 곧바로 파일을 삭제합니다.

서버의 Git이 암호를 요구하면 Spooky가 Mac에서 SSH 연결을 통해, 요청한 Git 명령에만 답을 보냅니다. Spooky가 자신의 명령에서는 Git의 자격 증명 헬퍼를 끄기 때문에 서버의 Git은 암호를 저장하지 않습니다.

## 저장소에 저장되는 것 {#repositories}

Spooky는 몇 가지를 저장소 자체의 Git 구성에 `branch.<name>.spooky-*` 항목으로 저장합니다.

- 어떤 브랜치가 고정되거나 보관되었는지
- 각 브랜치의 부모 브랜치
- 자동 보관에 쓰이는 표시

이 항목들은 브랜치의 이름을 변경하면 브랜치와 함께 옮겨지고, 브랜치를 삭제하면 사라집니다. 저장소의 :ui[repositorySettings.title]에서 바꾸는 서명 같은 Git 설정도 같은 구성에 들어갑니다. [저장소 설정](/guide/settings/identity/#repository)을 참고하세요.

Git 구성은 푸시되지 않으므로 이 중 어느 것도 원격에 전달되지 않습니다. 서버 저장소라면 서버에 저장됩니다.

## 네트워크 연결 {#network}

| Spooky가 연결하는 곳 | 연결하는 때 |
|---|---|
| SSH를 통한 사용자의 서버 | 서버 저장소가 열려 있는 동안. Spooky는 `~/.ssh/config`의 호스트 별칭을 사용합니다. SMB 마운트는 서버의 파일 공유에도 연결합니다. |
| 사용자의 Git 원격 | 가져오기, 풀, 푸시, 복제를 할 때와 자동 가져오기 중에. 서버 저장소에서는 Git이 Mac이 아니라 서버에서 연결합니다. |
| `github.com`과 `api.github.com`, 또는 사용자의 GitLab 주소 | 호스팅 계정을 추가하거나 다시 인증할 때, 그리고 계정이 필요한 기능을 쓸 때. 풀 리퀘스트와 머지 리퀘스트, 이슈 번호 자동 완성, 브랜치 검토의 상태, 저장소 게시가 여기에 해당합니다. 이런 요청은 Mac에서 나갑니다. [요청이 가는 곳](/guide/hosting/accounts/#network)을 참고하세요. |
| `gravatar.com` | 커밋 작성자의 사진을 표시할 때 |
| Spooky의 릴리스가 있는 `github.com` | 업데이트를 확인할 때 |

자동 가져오기는 기본적으로 30분마다 실행됩니다. 바꾸려면 :ui[app.name > settings.title]을 열고 :ui[settings.general]을 클릭한 다음 :ui[settings.autoFetch] 옆에서 옵션을 고릅니다. 요청할 때만 가져오려면 :ui[settings.autoFetch.never]을 선택합니다. [작업](/guide/settings/general/#operations)을 참고하세요.

커밋 작성자의 사진을 가져올 때 Gravatar는 작성자의 이메일 주소 자체가 아니라 그 해시를 받습니다. 다운로드한 사진은 메모리에만 있고 Spooky를 종료하면 사라집니다. GitHub와 GitLab 사용자의 사진은 그 서비스들에서 가져옵니다. 사진을 끄는 설정은 없습니다.

Spooky는 기본적으로 하루에 한 번 업데이트를 확인합니다. 멈추려면 :ui[app.name > settings.title] › :ui[settings.updates]에서 :ui[updates.automaticChecks]을 끕니다. [Spooky를 최신 상태로 유지하기](/guide/start/install/#updates)를 참고하세요.

:ui[help.help]과 :ui[help.support] 같은 :ui[menu.help] 메뉴의 항목은 브라우저에서 웹 페이지를 엽니다.

## 충돌 보고서 {#crash-reports}

Spooky가 지난번에 예기치 않게 종료되었다면 macOS가 Mac에 저장한 충돌 보고서를 읽습니다. 다음에 실행할 때 :ui[crash.title]이라고 물어봅니다.

- :ui[crash.report]를 클릭하면 브라우저에서 GitHub의 새 이슈 페이지가 열리고, 충돌 요약이 채워져 있습니다.
- :ui[crash.dontReport]을 클릭하면 건너뜁니다. Spooky는 그 충돌에 대해 다시 묻지 않습니다.

요약에는 Spooky 버전과 빌드, macOS 버전, 충돌 유형, 충돌한 스레드의 호출 스택 최대 30줄이 들어 있습니다. Mac을 떠나기 전에 Spooky가 홈 폴더, 사용자 이름, 이메일 주소, IP 주소, 토큰, 웹 주소 안의 암호를 자리 표시자로 바꿉니다.

요약은 페이지의 웹 주소에 포함됩니다. 페이지가 열리는 즉시 GitHub가 요약을 받습니다. 이슈는 브라우저에서 제출해야만 만들어집니다. 먼저 텍스트를 편집하거나 페이지를 닫을 수 있습니다.

다음부터 질문을 건너뛰려면 대화상자에서 :ui[settings.crashReports.always]를 선택합니다. 그러면 Spooky가 이슈 페이지를 곧바로 엽니다. 같은 옵션이 :ui[app.name > settings.title] › :ui[settings.integration]에도 있습니다.

## 진단 보고서 {#diagnostic-reports}

문제를 보고할 때 진단 보고서가 있으면 무슨 일이 있었는지 알리는 데 도움이 됩니다. :ui[menu.help > help.diagnosticReport]을 선택하고 저장할 곳을 고릅니다. Spooky가 텍스트 파일을 저장하고 Finder에서 보여 줍니다. 보고서를 어디로도 보내지 않습니다.

보고서에는 다음이 들어 있습니다.

- Spooky 버전과 빌드, macOS 버전, 선호하는 언어 중 처음 세 개
- 이 Mac의 Git 프로그램과 그 버전
- 모양, 업데이트 채널, 터미널 앱, 비교 도구와 병합 도구, SSH 에이전트, Git 프로그램, 로그인 셸에서 환경 변수를 읽을지 여부처럼 Spooky의 실행 방식에 영향을 주는 설정
- 로컬 저장소와 서버 저장소의 개수
- 최근 작업 20개의 이름, 시간, 결과
- 현재 실행 중 마지막 한 시간 동안의 Spooky 로그 최대 500줄

저장소 경로, 호스트 별칭, 암호, 환경 변수의 값은 들어 있지 않습니다. Spooky는 충돌 보고서와 같은 방식으로 홈 폴더, 사용자 이름, 이메일 주소, IP 주소, 토큰을 자리 표시자로 바꿉니다. 공유하기 전에 파일을 열어 읽어 봅니다.

Spooky의 로그에는 연결 변화와 작업의 시작, 완료, 실패가 기록됩니다. 명령의 인수나 출력, 커밋 메시지, 암호, 토큰은 기록되지 않습니다.

## 함께 보기

- [Spooky 설치하기](/guide/start/install/)
- [서버 저장소의 동작 방식](/guide/server/overview/)
- [호스팅 계정](/guide/hosting/accounts/)
- [시스템 요구 사항](/reference/requirements/)

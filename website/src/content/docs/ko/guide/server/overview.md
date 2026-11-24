---
title: "서버 저장소의 동작 방식"
description: "서버에서 일어나는 일과 Mac에서 일어나는 일, Spooky가 서버에 남기는 것, 서버 저장소가 로컬 저장소와 다른 점을 알아봅니다."
---

서버 저장소는 다른 컴퓨터에 있고 Spooky가 SSH로 여는 Git 저장소입니다. 파일은 서버에 그대로 있고, Git도 서버에서 실행됩니다. 먼저 Mac에 복제하지 않습니다. 이 페이지는 양쪽이 각각 하는 일, Spooky가 서버에 남기는 것, Mac에 있는 저장소와 다르게 동작하는 부분을 설명합니다.

서버 저장소를 준비하려면 [SSH 준비하기](/guide/server/prepare-ssh/)부터 읽고, 이어서 [서버 저장소 추가](/guide/server/add/)를 읽습니다.

## 어디에서 무슨 일이 일어나는가 {#where}

Spooky는 macOS에 포함된 SSH로 연결합니다. `~/.ssh/config` 파일의 호스트 별칭을 사용하므로, 터미널의 `ssh` 명령과 같은 방식으로 서버에 로그인합니다.

서버에서 일어나는 일:

- 모든 명령은 서버의 Git이 서버의 환경에서 실행합니다.
- Spooky는 SSH 연결로 파일을 읽고 씁니다. 큰 파일은 SSH의 파일 전송 기능인 SFTP로 가져옵니다.
- 삭제한 파일과 버린 새 파일은 서버에 휴지통이 있으면 거기로 갑니다.
- 가져오기, 풀, 푸시는 서버에서 GitHub 같은 원격에 접속합니다. 서버의 네트워크와 서버의 SSH 키를 사용합니다.

Mac에서 일어나는 일:

- 작업할 때 보는 윈도우, 목록, Diff.
- 서버로 가는 SSH 연결. Spooky는 열려 있는 저장소마다 연결을 하나씩 유지하고, 모든 명령을 그 연결로 보냅니다.
- 암호나 키 암호문처럼 서버의 Git이 묻는 질문. [암호와 암호문 입력 요청](/guide/server/connection/#prompts)을 참고하세요.
- 계정 로그인이나 풀 리퀘스트 불러오기 같은 GitHub와 GitLab으로의 요청.
- 훑어보기나 다른 앱에서 여는 파일의 사본.

:::note
SSH로 접속하는 원격은 서버가 그 원격의 호스트 키를 이미 알고 있어야 합니다. 모른다면 서버에 로그인해서 거기에서 원격에 한 번 연결합니다.
:::

## Spooky가 서버에 남기는 것 {#on-server}

Spooky는 관리자 권한이 필요 없고, 서비스도 설치하지 않습니다. 서버에 남기는 것은 두 가지입니다.

- **`~/.spooky/bin/`의 도우미 스크립트.** 서버의 홈 폴더에 있습니다. Git의 질문을 Mac으로 전달합니다. Spooky는 연결할 때 이 스크립트를 두고, 다음 연결을 위해 남겨 둡니다. Spooky는 설치할 때마다 30일 동안 쓰이지 않은 이전 버전을 삭제합니다. 그 폴더에서 이름이 `-askpass`, `-gpg` 등으로 끝나는 다른 항목은 같은 파일을 가리키는 링크입니다.
- **`/tmp/spooky-*`의 임시 파일.** 저장소가 열려 있는 동안 있습니다. 저장소를 닫으면 Spooky가 지웁니다.

도우미는 `/usr/bin/perl`로 실행됩니다. 대부분의 macOS 및 Linux 서버에 이미 있습니다. 전체 목록은 [시스템 요구 사항](/reference/requirements/#servers)을 참고하세요.

`~/.spooky`는 언제든 삭제해도 됩니다. Spooky가 다음에 연결할 때 도우미를 다시 설치합니다.

## 서버 저장소가 다른 점 {#differences}

서버 저장소는 Mac에 있는 저장소와 같은 종류의 윈도우에서 열립니다. 대부분의 보기와 명령은 똑같이 동작합니다. 저장소가 서버에 있다는 것은 다음 표시로 알 수 있습니다.

::screenshot[서버 저장소의 윈도우. 제목은 spooky-test:driftwood이고 그 아래에 현재 보기와 브랜치가 표시됩니다. 도구 막대에는 호스트 별칭 spooky-test가 보입니다. 가운데 열 맨 위의 띠에는 spooky-test: 연결됨이라고 적혀 있습니다. 그 아래에 커밋 영역과 변경된 파일 목록이 있습니다. 오른쪽 열에는 선택한 파일의 변경 사항이 표시됩니다.]{name="hero" frame="window" markers="45.8,3.3 64.4,7.2 40,8.9"}

1. 윈도우 제목이 `driftwood-server:driftwood`처럼 호스트 별칭으로 시작합니다. 저장소 윈도우에서도 이름이 같은 방식으로 표시됩니다.
2. 도구 막대의 :ui[toolbar.host] 항목에 호스트 별칭이 표시됩니다.
3. 작업 사본, 기록 등의 목록 맨 위에 연결 상태가 표시됩니다. [연결 상태와 다시 연결](/guide/server/connection/)을 참고하세요.

다르게 동작하는 부분도 있습니다.

| 항목 | 서버 저장소에서 |
|---|---|
| 서버에서 생긴 변경 | 저장소의 윈도우가 맨 앞에 있는 동안에는 2초마다, 그렇지 않으면 10초마다 Spooky가 서버의 변경을 확인합니다. 서버의 응답이 느리면 덜 자주 확인합니다. |
| 연결이 끊겼을 때 | Spooky가 마지막으로 읽은 내용은 계속 볼 수 있지만, 다시 연결될 때까지 아무것도 바꿀 수 없습니다. |
| :ui[action.revealFinder] | Finder에는 서버의 파일을 보여 주는 Mac의 폴더가 필요합니다. [이 Mac의 위치](/guide/server/local-location/)를 참고하세요. |
| :ui[action.openTerminal] | 터미널이 `ssh`로 서버에 로그인해 저장소 폴더로 이동합니다. |
| :ui[action.copyPath] | 복사한 경로가 `driftwood-server:/srv/git/driftwood`처럼 호스트 별칭으로 시작합니다. |
| 다른 앱에서 파일 열기 | 대부분의 앱은 파일의 사본을 받습니다. 저장하면 Spooky가 변경 내용을 서버에 다시 씁니다. [터미널과 다른 앱](/guide/server/local-location/#terminal)을 참고하세요. |
| 파일 버리기 또는 삭제 | 변경 사항을 버리면 서버의 파일을 덮어쓰기 때문에 Spooky가 먼저 묻습니다. 삭제한 파일과 버린 새 파일은 서버의 휴지통으로 갑니다. 서버에 휴지통이 없으면 Spooky가 먼저 물은 다음 완전히 삭제합니다. |
| :ui[settings.environment] 설정 | Mac의 Git에만 적용됩니다. 서버의 Git은 서버의 환경을 사용합니다. [환경](/guide/settings/general/#environment)을 참고하세요. |

변경 사항 버리기, 파일 완전 삭제, 파일 복원을 확인하는 대화상자는 :ui[app.name > settings.title] › :ui[settings.general]에서 끌 수 있습니다. [확인 대화상자](/guide/settings/general/#confirmations)를 참고하세요.

## 함께 보기

- [SSH 준비하기](/guide/server/prepare-ssh/)
- [서버 저장소 추가](/guide/server/add/)
- [시스템 요구 사항](/reference/requirements/)

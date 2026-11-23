---
title: "서버 저장소 추가"
description: "서버 저장소 추가 대화상자를 채우고, 연결 확인 결과를 읽고, 서버에서 저장소를 복제하거나 찾는 방법을 알아봅니다."
---

서버 저장소를 추가하면 저장소 목록에 들어가고 바로 열립니다. Spooky가 먼저 연결을 확인합니다. 부족한 것이 있으면 대화상자가 무엇을 고쳐야 하는지 알려 줍니다.

시작하기 전에 터미널이 아무것도 묻지 않고 서버에 연결하는지 확인합니다. [SSH 준비하기](/guide/server/prepare-ssh/)를 참고하세요.

대화상자를 열려면 :ui[menu.file] 메뉴 또는 저장소 윈도우의 추가 버튼 메뉴에서 :ui[action.addRemote]를 선택합니다.

## 대화상자 채우기 {#dialog}

::screenshot[서버 저장소 추가 대화상자. 호스트 별칭은 spooky-test입니다. 저장소 경로는 /srv/git/driftwood이고 옆에 탐색 버튼이 있습니다. 이 Mac에 마운트는 마운트 안 함으로 설정되어 있습니다. 버튼은 취소와 열기입니다.]{name="add-server" frame="dialog"}

| 필드 | 입력할 내용 |
|---|---|
| :ui[remote.host] | `~/.ssh/config`의 `Host` 이름. 예: `driftwood-server`. 사용자 이름이나 포트 없이 별칭만 입력합니다. 별칭이 아직 없으면 [호스트 별칭 추가하기](/guide/server/prepare-ssh/#alias)를 참고하세요. |
| :ui[remote.path] | 서버에 있는 저장소의 전체 경로. `/`로 시작합니다. 예: `/srv/git/driftwood` |
| :ui[remote.mount] | 선택 사항. 저장소의 폴더를 이 Mac에서 쓸 수 있게 해서 Finder에 표시되게 합니다. [추가하면서 마운트하기](/guide/server/local-location/#when-adding)를 참고하세요. |

경로를 모르면 호스트 별칭을 입력한 다음 :ui[clone.browse]을 클릭합니다. Spooky가 입력한 경로 또는 서버의 홈 폴더부터 서버의 폴더를 나열합니다. Git 저장소에는 :ui[browse.repository] 표시가 붙습니다. 읽을 수 없는 폴더는 흐리게 표시됩니다. 폴더를 이중 클릭해 안으로 들어간 다음 :ui[bookmarks.create.choosePrompt]을 클릭합니다.

저장소 안의 폴더를 골라도 됩니다. Spooky는 그 폴더가 속한 저장소를 엽니다.

:ui[action.open]는 호스트 별칭을 입력하고 경로가 `/`로 시작하면 사용할 수 있습니다.

## 연결 확인 {#check}

:ui[action.open]를 클릭하면 Spooky가 대화상자 아래쪽에 :ui[remote.checking]을 표시하고 다음을 차례로 확인합니다.

1. SSH가 호스트 별칭으로 로그인합니다.
2. 서버에 Git이 있고, 버전이 2.41.0 이상입니다.
3. 폴더가 있고, 열어서 읽을 수 있습니다.
4. 폴더가 Git 저장소 안에 있고, Git이 그 상태를 읽을 수 있습니다.

확인하는 동안에는 필드가 잠깁니다. :ui[action.cancel]를 클릭하면 확인을 멈추고 대화상자를 닫습니다.

모두 통과하면 Spooky가 서버에 도우미를 준비하고, 저장소를 저장소 목록에 추가한 다음 엽니다.

## 확인이 실패했을 때 {#results}

대화상자는 열린 채로 있고 입력한 내용도 유지됩니다. 아래쪽에 무엇을 고쳐야 하는지 표시되고, 이어서 SSH나 Git의 원래 출력이 나옵니다. 문제를 고치고 :ui[action.open]를 다시 클릭합니다.

| 문제 | 할 일 |
|---|---|
| 호스트 별칭이 올바르지 않음 | `Host` 줄의 별칭만 입력합니다. 공백, `@`, `:`, `/`는 넣지 않습니다. |
| 서버의 지문을 알 수 없음 | 터미널에서 한 번 연결해 지문을 확인합니다. [한 번 연결하기](/guide/server/prepare-ssh/#fingerprint)를 참고하세요. Spooky는 지문을 대신 수락하지 않습니다. |
| 서버의 지문이 바뀜 | 아직 연결하지 않습니다. 먼저 서버 소유자에게 변경을 확인합니다. |
| SSH로 로그인할 수 없음 | 서버가 키를 받아들이지 않거나, Mac이 키의 잠금을 풀 수 없습니다. [Spooky가 연결하는 방식으로 테스트하기](/guide/server/prepare-ssh/#test)를 참고하세요. |
| 서버에 접근할 수 없음 | 호스트 별칭과 네트워크를 확인한 다음 다시 시도합니다. |
| Git을 찾을 수 없음 | 서버에 Git 2.41.0 이상을 설치합니다. 설치되어 있다면 SSH 로그인에서 Git을 찾지 못하는 것입니다. 출력에 서버가 사용하는 `PATH`가 나옵니다. 서버의 셸 시작 파일에서 Git의 폴더를 여기에 추가합니다. |
| Git이 너무 오래됨 | 서버의 Git을 2.41.0 이상으로 업데이트합니다. |
| 폴더가 없음 | 경로를 확인합니다. 거기에 새 저장소를 만들려면 :ui[bookmarks.noRepository.create]를 클릭합니다. |
| 폴더에 대한 권한이 없음 | 서버의 사용자에게 폴더를 열고 읽을 권한이 있어야 합니다. |
| 서버의 macOS가 폴더를 막음 | 서버가 Mac이고, 저장소가 문서 같은 보호된 폴더에 있습니다. [Mac을 서버로 사용하기](/guide/server/prepare-ssh/#mac-server)에 나온 대로 원격 사용자의 전체 디스크 접근을 켜거나 저장소를 옮깁니다. |
| 폴더가 Git 저장소가 아님 | 저장소의 폴더를 선택하거나, :ui[bookmarks.noRepository.create]를 클릭해 이 폴더를 저장소로 만듭니다. Git의 출력에 소유권이 언급되면 폴더가 서버의 다른 사용자 소유입니다. |
| Git이 상태를 읽을 수 없음 | 아래에 나오는 Git의 출력에 이유가 있습니다. |
| 서버 세션을 준비할 수 없음 | 서버의 SSH가 Unix 소켓 포워딩을 허용해야 합니다. 서버에 `/usr/bin/perl`도 있어야 하고, 서버의 `~/.spooky/bin`과 `/tmp`에 쓰기 권한이 있어야 합니다. [시스템 요구 사항](/reference/requirements/#servers)을 참고하세요. |

::screenshot[호스트 별칭 spooky-test와 경로 /srv/git/driftwood가 입력된 서버 저장소 추가 대화상자. 필드 아래에 선택한 서버에 절대 경로가 있는지 확인하라는 경고가 있고, 이어서 원래 출력 “Directory does not exist”가 나옵니다. 버튼은 취소, 저장소 만들기, 열기입니다.]{name="server-add-error" frame="dialog"}

:ui[bookmarks.noRepository.create]는 그 폴더에서 `git init`을 실행하고, 폴더가 없으면 먼저 만듭니다. 그런 다음 Spooky가 연결을 다시 확인하고 새 저장소를 엽니다.

저장소를 추가하지 않고 서버가 사용하는 `PATH`와 Git을 보려면 :ui[app.name > settings.title] › :ui[settings.environment]을 엽니다. 아래쪽에 호스트 별칭을 입력한 다음 :ui[settings.environment.server.check]을 클릭합니다. [서버 확인하기](/guide/settings/general/#server-check)를 참고하세요.

## 서버의 Git 환경 변수 {#environment}

확인이 끝난 뒤 Spooky가 :ui[remote.environment.title]을 표시할 수 있습니다. 서버의 비대화형 셸이 이름이 `GIT_`로 시작하는 변수를 설정하고 있다는 뜻입니다. 이런 변수는 Spooky가 서버에서 실행하는 모든 명령에서 Git이 저장소를 찾고 설정을 읽는 방식을 바꿉니다.

:ui[action.close]를 클릭하면 저장소가 열립니다. 그 저장소에서 Git이 예상과 다르게 동작하면 서버의 셸 시작 파일에서 그 변수를 제거합니다.

## 서버에서 복제하고 찾기 {#clone-scan}

서버 저장소를 목록에 넣는 방법이 두 가지 더 있습니다.

- **복제:** 복제 대화상자의 :ui[clone.to]에서 서버를 선택합니다. Git이 서버에서 저장소를 복제하고, Spooky가 서버 저장소로 추가합니다. [저장소 복제하기](/guide/repositories/manager/#clone)를 참고하세요.
- **찾기:** 추가 버튼의 메뉴에서 :ui[scan.menu]를 선택한 다음 :ui[scan.in]에서 서버를 선택합니다. Spooky가 서버의 폴더를 뒤져서 찾은 저장소를 나열합니다. [저장소 찾기](/guide/repositories/manager/#scan)를 참고하세요.

## 함께 보기

- [SSH 준비하기](/guide/server/prepare-ssh/)
- [연결 상태와 다시 연결](/guide/server/connection/)
- [이 Mac의 위치](/guide/server/local-location/)

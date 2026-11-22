---
title: "이 Mac의 위치"
description: "자동 찾기, SMB 또는 sshfs 마운트, 직접 지정한 폴더로 서버 저장소에 이 Mac의 위치를 정해 주면 Finder에서 보기, 터미널, 외부 편집기에서 열 수 있습니다."
---

Finder는 Mac에 있는 폴더만 보여 줄 수 있습니다. 서버 저장소의 파일은 서버에 있습니다. 이 파일을 Finder에 표시하려면 서버의 파일이 나타나는 이 Mac의 폴더가 필요합니다. 보통은 마운트한 네트워크 볼륨입니다. 그 폴더가 저장소의 이 Mac의 위치입니다.

이 페이지는 Spooky가 그 폴더를 찾거나 마운트하는 방법과, 터미널 및 다른 앱이 서버 저장소를 여는 방법을 다룹니다.

## Finder에서 보기 {#show-in-finder}

:ui[action.revealFinder]는 서버 저장소에서 항상 사용할 수 있습니다. 다음 위치에 있습니다.

- :ui[menu.file] 메뉴
- 도구 막대의 :ui[toolbar.finder]. 추가하려면 :ui[menu.view > menu.customizeToolbar]를 선택하고 도구 막대로 드래그합니다.
- 사이드바의 :ui[workspace.title] 행을 오른쪽 클릭했을 때
- [빠른 동작](/guide/repositories/navigation/#quick-actions)
- 저장소 윈도우에서 서버 저장소를 오른쪽 클릭했을 때
- 작업 사본의 파일을 오른쪽 클릭했을 때. Finder가 그 파일을 선택합니다.

위치를 알고 있고 폴더가 거기에 있으면 Finder가 바로 열립니다. 그렇지 않으면 Spooky가 시트를 표시하고 다음 단계를 진행합니다.

1. 저장소가 연결되어 있지 않으면 Spooky가 먼저 연결합니다.
2. 폴더를 찾고, 방법이 SMB나 sshfs이면 마운트합니다.
3. 그래도 폴더를 찾지 못하면 시트가 위치를 설정하는 양식으로 바뀌고 맨 위에 이유가 표시됩니다. [위치 설정하기](#set)를 참고하세요.

:ui[action.cancel]를 클릭하면 시트가 닫힙니다. 설정은 그대로 유지됩니다.

## 위치 설정하기 {#set}

1. 사이드바의 :ui[workspace.group] 아래에서 :ui[repositorySettings.title]을 클릭합니다.
2. :ui[repositorySettings.general] 페이지에서 :ui[repositorySettings.localLocation]를 찾습니다. 방법과 폴더가 표시되거나, :ui[localLocation.notMounted]처럼 폴더가 없는 이유가 표시됩니다.
3. 포인터를 그 행 위로 옮긴 다음 :ui[localLocation.change]이 나타나면 클릭합니다. 저장소가 연결되어 있어야 합니다.
4. :ui[localLocation.title]에서 :ui[localLocation.method] 옆의 방법을 선택합니다.
5. 마운트라면 :ui[localLocation.mount]를, 다른 방법이라면 :ui[localLocation.save]을 클릭합니다.

Spooky가 폴더를 마운트하거나 확인하는 동안에는 양식이 잠깁니다. 멈추려면 :ui[action.cancel]를 클릭합니다. 이전 설정이 유지됩니다.

위치는 서버 저장소별로 이 Mac에 저장됩니다. Spooky는 위치를 저장소나 서버에 쓰지 않습니다.

SMB 또는 sshfs 마운트가 추출되었으면 행에 :ui[localLocation.mountAgain]가 표시됩니다. 클릭하면 폴더를 다시 마운트합니다.

## 방법 {#methods}

:ui[localLocation.method] 메뉴에는 지금 쓸 수 있는 방법만 나옵니다. 현재 방법은 항상 나옵니다.

### 자동 찾기 {#automatic}

:ui[localLocation.method.automatic]가 기본값입니다. Spooky는 이 Mac에 이미 마운트된 네트워크 볼륨을 살펴봅니다. SMB, NFS, AFP, WebDAV, sshfs 볼륨 등입니다. 어느 앱이 마운트했는지는 상관없습니다. 볼륨의 서버 주소가 호스트 별칭의 주소와 같으면 대상이 됩니다.

그런 다음 Spooky는 볼륨 안에서 저장소 폴더를 찾습니다. 같은 저장소인지 확인하기 위해 Spooky는 서버에 있는 저장소의 Git 폴더에 빈 파일을 잠깐 넣고, 그 파일이 볼륨에 나타나는지 확인한 다음 삭제합니다.

### SMB 마운트 {#smb}

:ui[localLocation.method.smbMount]는 macOS가 사용하는 파일 공유 프로토콜인 SMB로 서버의 공유 폴더를 마운트합니다. 서버가 2초 안에 SMB 포트에서 응답하면 목록에 나옵니다.

1. :ui[localLocation.method.smbMount]를 선택한 다음 :ui[localLocation.mount]를 클릭합니다.
2. macOS가 서버의 공유 폴더를 보여 주거나 먼저 로그인하라고 요청합니다. 저장소가 들어 있는 공유를 선택합니다.

Spooky는 공유를 기억하고 다음에는 묻지 않고 다시 마운트합니다. 선택한 공유에 저장소가 없으면 양식에 다음 문구가 표시됩니다. :ui[localLocation.notInShare] 다른 공유를 선택하고 다시 시도합니다.

서버가 Mac이라면 그 Mac의 **Apple 메뉴 › 시스템 설정 › 일반 › 공유**에서 **파일 공유**를 켭니다.

### sshfs 마운트 {#sshfs}

:ui[localLocation.method.sshfsMount]는 Spooky가 쓰는 것과 같은 호스트 별칭으로 저장소 폴더를 SSH를 통해 마운트합니다. 이 Mac에 sshfs와 macFUSE 또는 FUSE-T가 있어야 합니다. Spooky는 `/opt/homebrew/bin`, `/usr/local/bin`, `PATH`에서 `sshfs`를 찾습니다. 설치되어 있지 않으면 이 방법은 목록에 나오지 않습니다.

1. :ui[localLocation.method.sshfsMount]를 선택합니다.
2. :ui[localLocation.mountAt] 옆의 :ui[localLocation.choose]을 클릭하고 이 Mac의 빈 폴더를 고릅니다. 서버의 파일이 거기에 나타납니다.
3. :ui[localLocation.mount]를 클릭합니다.

### 지정한 폴더 {#chosen-folder}

:ui[localLocation.method.chosenFolder]를 쓰면 폴더를 직접 고를 수 있습니다. 다른 방법으로 마운트해 둔 폴더가 그런 예입니다.

1. :ui[localLocation.method.chosenFolder]를 선택합니다.
2. :ui[localLocation.folder] 옆의 :ui[localLocation.choose]을 클릭하고 저장소 폴더를 고릅니다.
3. :ui[localLocation.save]을 클릭합니다. Spooky가 저장하기 전에 폴더를 확인합니다.

Spooky는 자신이 마운트한 볼륨을 추출하지 않습니다. 나중에 저장소를 다시 열면 Spooky가 아무것도 묻지 않고 백그라운드에서 다시 마운트합니다.

## 추가하면서 마운트하기 {#when-adding}

[서버 저장소를 추가](/guide/server/add/)할 때 :ui[remote.mount]로 같은 단계에서 위치를 설정합니다. 처음에는 :ui[remote.mount.none]으로 되어 있습니다. 호스트 별칭을 입력하면 메뉴에 :ui[remote.mount.smb]와 :ui[remote.mount.sshfs] 중 사용할 수 있는 것이 나옵니다. 둘 다 사용할 수 없으면 :ui[remote.mount.unavailable]이 표시됩니다.

- **SMB:** 저장소가 열린 뒤 macOS가 서버의 공유 폴더 또는 로그인 윈도우를 보여 줍니다. 취소해도 저장소는 열리고, 저장소 설정의 :ui[repositorySettings.localLocation]에 마운트되지 않은 이유가 표시됩니다.
- **sshfs:** :ui[localLocation.mountAt] 행이 추가로 나타납니다. 빈 폴더를 고릅니다. 저장소가 열린 뒤 Spooky가 거기에 저장소를 마운트합니다.

호스트 별칭을 바꾸면 메뉴가 :ui[remote.mount.none]으로 돌아갑니다.

## 터미널과 다른 앱 {#terminal}

다음 명령은 이 Mac의 위치가 없어도 서버 저장소에서 동작합니다.

- **:ui[action.openTerminal]**는 :ui[app.name > settings.title] › :ui[settings.general]에서 고른 터미널 앱을 열고, `ssh -t`와 호스트 별칭으로 로그인해 저장소 폴더로 이동합니다. 서버가 터미널을 허용하지 않으면 Spooky가 터미널 없이 다시 연결합니다. 명령은 여전히 동작하지만 줄 편집과 전체 화면 프로그램은 동작하지 않습니다. 이 명령은 :ui[menu.file] 메뉴, 도구 막대의 :ui[toolbar.terminal], 작업 사본이나 저장소 윈도우의 저장소를 오른쪽 클릭했을 때 나오는 메뉴에 있습니다. 터미널 앱을 고르는 방법은 [터미널](/guide/settings/integration/#terminal)을 참고하세요.
- **:ui[action.copyPath]**는 `driftwood-server:/srv/git/driftwood`처럼 앞에 호스트 별칭이 붙은 경로를 복사합니다.
- 작업 사본의 **:ui[files.open]와 :ui[files.openWith]**는 파일을 다른 앱에서 엽니다. Visual Studio Code, Visual Studio Code Insiders, Cursor는 Remote SSH 확장 프로그램이 설치되어 있으면 서버의 파일을 직접 엽니다. 다른 앱은 이 Mac에 있는 사본을 받습니다. 저장하면 Spooky가 사본을 서버에 다시 씁니다.

그사이에 서버의 파일이 바뀌었으면 Spooky가 쓰기 전에 :ui[externalTool.fileChanged]이라고 알리며 묻습니다. :ui[externalTool.overwrite]를 클릭하면 내 사본으로 대체합니다. 저장소를 닫으면 Spooky가 사본을 삭제합니다.

훑어보기와 외부 비교 및 병합 도구도 사본으로 동작합니다. 병합 도구가 끝나면 Spooky가 결과를 서버에 다시 쓰고 스테이지합니다.

## 함께 보기

- [서버 저장소의 동작 방식](/guide/server/overview/)
- [서버 저장소 추가](/guide/server/add/)
- [통합](/guide/settings/integration/)

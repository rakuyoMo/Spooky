---
title: "Spooky 둘러보기"
description: "저장소 윈도우와 개별 저장소 윈도우를 알아봅니다. 사이드바, 도구 막대, 세 개의 열, 빠른 동작을 소개합니다."
---

Spooky의 윈도우는 두 가지 중 하나를 보여 줍니다. 저장소 보기는 저장소의 목록입니다. 개별 저장소 윈도우는 실제 작업을 하는 곳입니다. 이 페이지는 두 윈도우의 각 부분에 이름을 붙입니다. 사용 설명서의 나머지 부분에서 이 이름을 사용합니다.

## 저장소 윈도우 {#repositories-window}

Spooky를 처음 열면 저장소 보기가 나타납니다. 사이드바의 :ui[repositories.title] 아래에 저장소가 나열됩니다. 저장소는 그룹으로 정리할 수 있습니다.

- 저장소를 선택하면 오른쪽에 세부사항이 나타납니다. 위치, 마지막으로 연 시점, 마지막 커밋, 현재 브랜치와 변경 사항, 원격을 볼 수 있습니다.
- 그룹을 선택하거나 아무것도 선택하지 않으면 :ui[bookmarks.dropZone.title]라고 적힌 영역과 :ui[bookmarks.dropZone.add], :ui[action.addRemote], :ui[bookmarks.dropZone.create], :ui[bookmarks.dropZone.clone] 버튼이 나타납니다.
- 사이드바 아래쪽의 추가 버튼으로 그룹과 저장소를 추가합니다.

저장소를 이중 클릭하면 열립니다. 같은 윈도우에서 저장소 보기 자리에 열립니다. 목록으로 돌아가려면 사이드바 위쪽의 :ui[toolbar.bookmarks]를 클릭합니다. 목록에 관한 자세한 내용은 [저장소 윈도우](/guide/repositories/manager/)에서 다룹니다.

## 개별 저장소 윈도우 {#repository-window}

저장소를 열면 윈도우 제목에 저장소의 이름이 표시됩니다. 이름 아래에는 현재 보기와 함께 브랜치, 변경된 파일 수 같은 짧은 요약이 표시됩니다.

::screenshot[개별 저장소 윈도우. 왼쪽의 사이드바에 저장소의 보기, 브랜치, 태그, 원격이 나열되어 있습니다. 위쪽에는 도구 막대가 가로로 놓여 있습니다. 가운데 열에는 커밋 영역과 그 아래의 변경된 파일 목록이, 오른쪽 열에는 선택한 파일의 변경 사항이 표시됩니다.]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. 사이드바
2. 도구 막대
3. 가운데 열: 현재 보기의 목록
4. 오른쪽 열: 가운데 열에서 선택한 항목의 세부사항

:::note[서버 저장소]
윈도우 제목은 `alias:name`처럼 호스트 별칭으로 시작합니다. 도구 막대의 :ui[toolbar.host] 항목에도 호스트 별칭이 표시됩니다. 연결이 끊겼을 때 윈도우에 무엇이 표시되는지는 [연결 상태와 다시 연결](/guide/server/connection/)에서 설명합니다.
:::

### 사이드바 {#sidebar}

맨 위의 :ui[workspace.group] 섹션에서 저장소의 보기를 전환합니다.

| 보기 | 보여 주는 것 |
|---|---|
| :ui[workspace.title] | 아직 커밋하지 않은 변경 사항. 옆의 숫자는 변경된 파일 수입니다. |
| :ui[history.title] | 커밋 |
| :ui[stash.title] | 따로 보관해 둔 변경 사항 |
| :ui[pr.title] | 호스팅 서비스의 풀 리퀘스트 또는 머지 리퀘스트 |
| :ui[review.title] | 내 브랜치. 정리해도 되는 브랜치를 찾을 수 있습니다. |
| :ui[reflog.title] | HEAD가 거쳐 온 위치. :ui[sidebar.viewSettings]에서 :ui[sidebar.showReflog]를 켜면 표시됩니다. |
| :ui[repositorySettings.title] | 이 저장소의 설정. [저장소 설정](/guide/settings/identity/#repository)을 참고하세요. |

그 아래에는 :ui[sidebar.pinned](브랜치를 고정하면 표시됨), :ui[branch.group], :ui[sidebar.archived], :ui[sidebar.tags], :ui[remote.group], :ui[submodule.group], :ui[worktree.group]가 차례로 나옵니다. :ui[branch.group]에서는 HEAD 배지가 현재 브랜치를 나타냅니다. ↑3처럼 숫자가 붙은 화살표는 아직 푸시하지 않은 커밋의 수입니다.

사이드바 아래쪽의 막대에는 :ui[sidebar.filter] 필드, 브랜치와 그 밖의 참조를 만드는 :ui[reference.addMenu] 버튼, 사이드바에 표시할 항목을 고르는 :ui[sidebar.viewSettings]이 있습니다.

### 도구 막대 {#toolbar}

도구 막대에는 왼쪽부터 다음 버튼이 있습니다.

- :ui[toolbar.bookmarks]: 저장소 보기로 돌아갑니다
- :ui[toolbar.previous]과 :ui[toolbar.next]: 방문한 보기 사이를 뒤로, 앞으로 이동합니다
- :ui[toolbar.finder]와 :ui[toolbar.terminal]: 저장소 폴더를 Finder에서 보거나 터미널에서 엽니다
- :ui[sync.fetch], :ui[sync.pull], :ui[sync.push]: 원격과 커밋을 주고받습니다
- :ui[toolbar.forcePush]: 커밋을 다시 쓴 뒤, 원격 브랜치를 내 브랜치로 바꿉니다
- :ui[toolbar.applyStash]과 :ui[toolbar.saveStash]: 보관해 둔 변경 사항을 되돌리거나, 현재 변경 사항을 따로 보관합니다
- :ui[toolbar.createBranch]: 새 브랜치를 만듭니다
- :ui[action.refresh]: 저장소를 다시 읽습니다
- :ui[action.search]: 현재 보기의 목록을 필터링합니다

<kbd>⌥</kbd>을 누르고 있으면 :ui[sync.fetch], :ui[sync.pull], :ui[sync.push]가 :ui[sync.quickPush] 같은 빠른 버전으로 바뀝니다. 빠른 버전은 대화상자를 열지 않고 추적 브랜치를 대상으로 바로 실행합니다.

:ui[toolbar.clone]는 최근에 복제한 항목이 있는 동안 나타납니다. [저장소 윈도우](/guide/repositories/manager/)를 참고하세요. 버튼을 추가하거나 제거하려면 :ui[menu.view > menu.customizeToolbar]를 선택합니다. 위의 버튼 외에 :ui[toolbar.quickActions], :ui[toolbar.synchronize], :ui[sync.merge]과 :ui[sync.rebaseHead], :ui[toolbar.pushTo]도 추가할 수 있습니다.

### 세 개의 열 {#columns}

왼쪽 열은 사이드바입니다. 가운데 열에는 선택한 보기의 목록이 표시됩니다. :ui[workspace.title]에서는 커밋 영역과 변경된 파일이고, :ui[history.title]에서는 커밋입니다.

오른쪽 열에는 가운데에서 선택한 항목의 세부사항이 표시됩니다. :ui[workspace.title]에서는 선택한 파일의 변경 사항입니다. 파일에 스테이지된 변경 사항과 스테이지되지 않은 변경 사항이 모두 있으면 위쪽의 :ui[working.staged]과 :ui[working.unstaged]으로 전환합니다. 아무것도 선택하지 않으면 이 열에 :ui[detail.empty.title]이 표시됩니다.

### 좁은 윈도우 {#narrow-window}

윈도우가 좁아져 세 개의 열이 들어가지 않으면 좁은 윈도우용 레이아웃으로 바뀝니다. 윈도우를 넓히면 세 개의 열이 원래 너비 그대로 돌아옵니다.

::screenshot[좁은 저장소 윈도우. 도구 막대 아래의 행에서 보기를 전환합니다. 커밋 영역과 변경된 파일 목록이 위에, 선택한 파일의 변경 사항이 아래에 표시됩니다.]{name="tour-narrow-window" frame="window" markers="75,9 75,40 75,84"}

1. 보기를 전환하는 행: 사이드바를 대신합니다
2. 현재 보기의 목록
3. 목록에서 선택한 항목의 세부사항

- 보기를 전환하는 행에는 :ui[workspace.title], :ui[history.title], :ui[stash.title] 항목이 있습니다. 브랜치, 태그, 원격, 그 밖의 보기를 쓰려면 행 맨 앞의 :ui[sidebar.menu] 버튼을 클릭합니다. 사이드바가 보기 위에 겹쳐서 열립니다. :ui[sidebar.menu] 버튼을 다시 클릭하거나 사이드바 바깥을 클릭하면 닫힙니다.
- 목록이 위에, 세부사항이 아래에 놓입니다. 둘 사이의 선을 드래그하면 각각의 높이를 조절할 수 있습니다.
- 도구 막대에 들어가지 않는 버튼은 끝에 있는 » 메뉴로 들어갑니다. :ui[sync.fetch], :ui[sync.pull], :ui[sync.push] 버튼은 도구 막대에 남습니다.

레이아웃이 바뀌어도 현재 보기, 선택한 항목, 쓰고 있던 커밋 메시지는 그대로입니다.

### 빠른 동작 {#quick-actions}

:ui[menu.file > quickActions.menu]을 선택하거나 <kbd>⇧⌘A</kbd>를 누르면 패널이 열립니다. 입력해서 보기, 브랜치, 파일, 커밋을 찾은 다음, 키보드에서 손을 떼지 않고 그 항목에 동작을 실행합니다. 무엇을 찾아 주고 어떤 키를 쓰는지는 [윈도우와 탐색](/guide/repositories/navigation/)에서 설명합니다.

## 함께 보기

- [첫 번째 저장소](/guide/start/first-repository/)
- [저장소 윈도우](/guide/repositories/manager/)
- [윈도우와 탐색](/guide/repositories/navigation/)

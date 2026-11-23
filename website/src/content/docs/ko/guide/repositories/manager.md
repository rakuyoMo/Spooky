---
title: "저장소 윈도우"
description: "저장소를 책갈피에 추가하고, 그룹으로 묶고, 열고, 복제하고, 만들고, 찾고, 제거하는 방법과 사라진 저장소를 찾는 방법을 알아봅니다."
---

저장소 윈도우에는 Mac과 서버에서 작업하는 저장소의 목록이 있습니다. 각 항목은 저장소를 가리키는 책갈피입니다. 책갈피를 제거해도 저장소 폴더는 그 자리에 남습니다. 폴더를 휴지통으로 옮기는 것은 따로 선택합니다. 이 페이지는 저장소를 추가하고, 정리하고, 열고, 제거하는 방법을 다룹니다.

저장소에서 목록으로 가려면 도구 막대의 :ui[toolbar.bookmarks]를 클릭하거나 :ui[menu.view > menu.showRepositories](<kbd>⌃⌘R</kbd>)를 선택합니다.

::screenshot[저장소 윈도우. 사이드바에 Driftwood Labs와 Notes 두 그룹이 있고 그 안에 저장소가 들어 있습니다. 그중 하나는 이름이 호스트 별칭으로 시작하는 서버 저장소입니다. 오른쪽에는 선택한 저장소 driftwood의 세부사항이 있습니다. 위치, 마지막으로 연 시점, 마지막 커밋, 설명, 커미터 정보, 현재 브랜치, 변경된 파일 수, 원격이 표시됩니다.]{name="repositories" frame="window"}

## 저장소 추가하기 {#add}

사이드바 아래쪽의 추가 버튼에는 목록에 항목을 추가하는 메뉴가 있습니다.

| 메뉴 항목 | 하는 일 |
|---|---|
| :ui[bookmarks.newGroup] | 선택한 항목 아래에 그룹을 추가합니다. 바로 이름을 입력할 수 있습니다. |
| :ui[bookmarks.add] | 이미 Mac에 있는 저장소를 추가합니다. 폴더를 여러 개 한꺼번에 선택할 수 있습니다. |
| :ui[action.addRemote] | 서버에 있는 저장소를 추가합니다. [서버 저장소 추가](/guide/server/add/)를 참고하세요. |
| :ui[bookmarks.create] | 빈 저장소를 만듭니다. [저장소 만들기](#create)를 참고하세요. |
| :ui[clone.menu] | 원격에서 저장소를 복사해 옵니다. [저장소 복제하기](#clone)를 참고하세요. |
| :ui[scan.menu] | 폴더 안에 있는 저장소를 찾습니다. [저장소 찾기](#scan)를 참고하세요. |

새 항목은 선택한 그룹에 들어갑니다. Finder에서 저장소 폴더를 목록으로 드래그해도 됩니다. :ui[menu.file > action.openLocal]로 연 저장소가 아직 목록에 없으면 목록 끝에 추가됩니다.

### 저장소 만들기 {#create}

1. 추가 버튼의 메뉴에서 :ui[bookmarks.create]를 선택합니다.
2. :ui[bookmarks.create.name]에 새 저장소의 이름을 입력합니다. 이 이름이 폴더 이름도 됩니다.
3. :ui[bookmarks.create.location] 옆의 :ui[bookmarks.create.choose]을 클릭해 저장소를 만들 폴더를 고릅니다. 처음에는 홈 폴더가 선택되어 있습니다.
4. :ui[bookmarks.create.submit]를 클릭합니다.

Spooky가 폴더를 만들고, 그 폴더를 빈 Git 저장소로 만들고, 선택한 그룹에 추가한 다음 엽니다.

### 저장소 복제하기 {#clone}

복제는 원격에 있는 저장소와 그 기록을 새 폴더로 복사합니다.

1. 추가 버튼의 메뉴에서 :ui[clone.menu]를 선택하거나 <kbd>⌃⌘C</kbd>를 누릅니다.
2. :ui[clone.url]에 저장소의 주소를 입력합니다. 예를 들어 `https://`나 `git@`로 시작하는 주소입니다.
3. :ui[clone.to]에서 :ui[clone.machine.local]이나 서버를 선택합니다. 이미 쓰고 있는 서버는 목록에 있습니다. 다른 서버를 쓰려면 :ui[clone.machine.other]를 선택하고 :ui[remote.host]을 입력합니다.
4. :ui[clone.directory]에서 복제할 폴더를 선택합니다. Spooky가 그 안에 저장소 이름으로 폴더를 만듭니다.
5. 저장소의 하위 모듈도 체크아웃하려면 :ui[clone.submodules]를 선택된 채로 둡니다. 저장소가 큰 파일을 Git LFS에 보관한다면 :ui[clone.lfs]를 선택합니다.
6. :ui[clone.submit]를 클릭합니다.

Spooky는 먼저 원격에 접근할 수 있는지 확인합니다. 접근할 수 없으면 대화상자가 열린 채로 이유를 보여 줍니다. 주소를 고치고 다시 시도합니다. 접근할 수 있으면 대화상자가 닫히고 복제가 백그라운드에서 진행됩니다. 진행 상황은 목록에서 그 저장소의 행에 표시됩니다. 복제가 끝나면 Spooky가 :ui[clone.notification.title] 알림을 보냅니다.

Mac에서는 폴더가 홈 폴더에서 시작하거나, :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory]에 설정한 폴더에서 시작합니다. [복제와 터미널](/guide/settings/general/#cloning)을 참고하세요.

최근에 복제한 항목이 있는 동안에는 도구 막대에 :ui[toolbar.clone]가 나타납니다. 클릭하면 :ui[clone.recent.title]가 보입니다. 여기에서 진행 중인 복제를 중단하거나, 실패했거나 취소된 복제를 :ui[clone.retry]으로 다시 시작하거나, :ui[clone.remove]로 목록에서 뺄 수 있습니다. 끝난 복제를 이중 클릭하면 열립니다. :ui[clone.recent.clear]는 목록을 비웁니다.

:::note[서버 저장소]
서버로 복제하면 Spooky가 연결을 확인하고 서버에서 복제를 실행합니다. 새 저장소는 서버 저장소로 추가됩니다. 폴더에는 서버의 절대 경로를 입력하거나, :ui[clone.browse]을 클릭해 고릅니다. Spooky는 서버마다 마지막으로 사용한 폴더를 기억합니다.
:::

저장소의 주소를 목록으로 드래그해서 복제를 시작할 수도 있습니다. 링크로도 시작할 수 있습니다. [윈도우와 탐색](/guide/repositories/navigation/)을 참고하세요.

### 저장소 찾기 {#scan}

1. 추가 버튼의 메뉴에서 :ui[scan.menu]를 선택합니다.
2. :ui[scan.in]에서 :ui[clone.machine.local]이나 서버를 선택한 다음, 찾을 폴더를 선택합니다.
3. :ui[scan.start]를 클릭합니다. Spooky가 저장소를 찾는 대로 목록에 나타납니다. 멈추려면 :ui[scan.stop]을 클릭합니다.
4. 찾은 저장소는 모두 선택되어 있습니다. 필요 없는 것은 선택을 해제한 다음 :ui[scan.add]를 클릭합니다.

이미 목록에 있는 저장소는 다시 표시되지 않습니다. 여러 폴더나 서버를 차례로 찾을 수 있습니다. 결과는 누적됩니다.

## 목록 정리하기 {#organize}

- 그룹을 추가하려면 추가 버튼의 메뉴에서 :ui[bookmarks.newGroup]을 선택한 다음 이름을 입력합니다.
- 항목의 순서를 바꾸거나 다른 그룹으로 옮기려면 드래그합니다.
- 항목의 이름을 바꾸려면 오른쪽 클릭하고 :ui[bookmarks.rename]을 선택합니다. 목록에서 저장소의 이름을 바꿔도 폴더 이름은 바뀌지 않습니다.
- 이름순으로 정렬하려면 오른쪽 클릭하고, 그룹 안의 항목을 정렬할 때는 :ui[bookmarks.sortChildren]을, 항목이 들어 있는 그룹을 정렬할 때는 :ui[bookmarks.sortParent]을 선택합니다.

:ui[app.name > settings.title] › :ui[settings.general]의 두 옵션으로 목록에 표시되는 내용을 바꿉니다.

- :ui[settings.showWorktreesInRepositoryList]: 다른 작업 트리가 있는 저장소를 펼쳐서 작업 트리를 볼 수 있습니다. 작업 트리는 저장소와 같은 방법으로 엽니다. 기본으로 꺼져 있습니다.
- :ui[settings.showHostAliasesInRepositoryList]: 서버 저장소의 이름이 호스트 별칭으로 시작합니다. 기본으로 켜져 있습니다.

[윈도우와 저장소 목록](/guide/settings/general/#windows)을 참고하세요.

## 저장소 열기 {#open}

저장소를 이중 클릭하거나, 선택하고 <kbd>↩</kbd>을 누릅니다. 같은 윈도우에서 목록 자리에 열립니다. 저장소가 이미 다른 윈도우에 열려 있으면 Spooky는 그 윈도우를 앞으로 가져옵니다.

저장소를 오른쪽 클릭하면 더 많은 선택지가 나옵니다.

- :ui[bookmarks.open]{1="driftwood"}와 :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder], :ui[action.copyPath], :ui[action.openTerminal]

오른쪽의 세부사항에도 :ui[action.open] 버튼과 :ui[bookmarks.multiple.delete] 버튼이 있습니다. 거기에서 :ui[bookmarks.detail.edit]을 클릭하면 :ui[bookmarks.detail.description]과 :ui[bookmarks.detail.identity]를 바꿀 수 있습니다. :ui[bookmarks.detail.unset]는 이 저장소에만 설정한 커미터 정보를 지웁니다. 각 원격 옆의 :ui[bookmarks.detail.viewInBrowser]는 그 원격의 웹 페이지를 엽니다. 설명과 커미터 정보는 [저장소 설정](/guide/settings/identity/#repository)에 나오는 것과 같습니다.

:::note[서버 저장소]
:ui[action.copyPath]는 `alias:/path/to/repository`처럼 앞에 호스트 별칭이 붙은 경로를 복사합니다. Spooky는 서버 저장소를 선택했을 때만 그 세부사항을 읽습니다. 서버 저장소를 선택하면 서버에 연결할 수 있습니다.
:::

## 사라진 저장소 {#missing}

저장소의 폴더를 옮기거나, 이름을 바꾸거나, 삭제하면 목록에서 그 이름이 회색으로 바뀌고 경고 표시가 붙습니다. 세부사항에는 다음과 같이 표시됩니다. :ui[bookmarks.detail.missing] Spooky는 목록이 나타날 때마다 Mac에 있는 저장소를 확인합니다.

사라진 저장소를 열면 윈도우에 :ui[missing.title]이 표시됩니다. 디스크를 다시 연결한 뒤처럼 다시 확인하고 싶을 때는 :ui[action.refresh]을 클릭합니다. 목록으로 돌아가려면 :ui[action.close]를 클릭합니다.

항목을 바로잡으려면 항목을 제거하고, 저장소가 지금 있는 위치에서 다시 추가합니다.

:::note[서버 저장소]
Spooky는 서버 저장소를 선택하거나 열 때만 확인합니다. 서버에 접근할 수 없으면 윈도우에 :ui[missing.unreachable.title]{1="alias"}이 표시되고 SSH가 보고한 내용이 함께 나옵니다. [연결 상태와 다시 연결](/guide/server/connection/)을 참고하세요.
:::

## 저장소 제거하기 {#delete}

항목을 하나 이상 선택한 다음, 다음 중 하나를 합니다.

- <kbd>⌫</kbd>를 누릅니다.
- 오른쪽 클릭하고 :ui[bookmarks.delete]{1="driftwood"}를 선택합니다. 그룹이면 :ui[bookmarks.deleteFolder], 항목이 여러 개면 :ui[bookmarks.deleteMultiple]{1="2"}를 선택합니다.
- 세부사항에서 :ui[bookmarks.multiple.delete]를 클릭합니다.

저장소 폴더가 아직 있으면 Spooky가 먼저 :ui[bookmarks.delete.title]{1="driftwood"}라고 묻습니다. 책갈피만 제거됩니다. 폴더는 그 자리에 남습니다. 폴더도 휴지통으로 옮기려면 :ui[bookmarks.delete.trash]을 선택합니다. :ui[bookmarks.delete.submit]를 클릭해 확인합니다.

빈 그룹과 폴더가 없어진 항목은 묻지 않고 바로 제거됩니다.

:::caution
휴지통으로 옮기면 커밋하지 않은 변경 사항을 포함해 저장소 폴더 전체가 옮겨집니다. 휴지통을 비우기 전까지는 되살릴 수 있습니다. 휴지통 체크상자는 대화상자가 열릴 때마다 선택 해제되어 있습니다.
:::

폴더를 옮길 수 없으면 Spooky가 :ui[bookmarks.trashFailed.title]을 표시하고 남은 폴더를 나열합니다. Spooky는 홈 폴더, 홈 폴더가 들어 있는 폴더, 디스크의 최상위는 절대 휴지통으로 옮기지 않습니다.

:::note[서버 저장소]
Spooky는 서버 저장소를 제거하기 전에 항상 묻습니다. 폴더는 Mac이 아니라 그 서버의 휴지통으로 갑니다.
:::

## 함께 보기

- [윈도우와 탐색](/guide/repositories/navigation/)
- [서버 저장소 추가](/guide/server/add/)
- [작업 트리](/guide/advanced/worktrees/)

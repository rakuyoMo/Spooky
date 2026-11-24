---
title: "브랜치"
description: "브랜치를 만들고, 체크아웃하고, 추적하고, 이름을 바꾸고, 삭제하고, 고정하고, 보관하고, 부모 브랜치를 설정하고, 사이드바에서 브랜치를 필터링하고 그룹으로 묶습니다."
---

로컬 브랜치는 사이드바의 :ui[branch.group] 아래에 나열됩니다. 브랜치로 하는 일은 대부분 여기에서 시작합니다. 브랜치를 오른쪽 클릭해 메뉴를 열거나, 다른 곳으로 드래그합니다.

::screenshot[사이드바의 아래쪽. 브랜치 아래에서 main에는 HEAD 배지와 ↑3이 있고, feature 폴더에는 dark-mode, station-map, units-toggle이 들어 있습니다. 보관된 브랜치는 비어 있습니다. 태그에는 v0.1.0부터 v0.4.0까지 나열되어 있습니다. 원격 아래의 origin에는 집 아이콘이 붙은 main과 접힌 feature 폴더가 있습니다. 맨 아래 막대의 왼쪽에는 필터 필드가, 오른쪽에는 추가 버튼과 보기 설정 버튼이 있습니다.]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. 현재 브랜치. HEAD 배지와 아직 푸시하지 않은 커밋 수가 표시됩니다
2. 이름이 `feature/`로 시작하는 브랜치를 담은 폴더
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. 추가 버튼과 보기 설정 버튼

## 사이드바에서 {#sidebar}

브랜치를 클릭하면 기록에 그 브랜치의 커밋이 표시됩니다. 이중 클릭하면 체크아웃합니다.

원격 브랜치를 추적하는 브랜치에는 둘이 얼마나 벌어져 있는지 표시됩니다. ↑는 아직 원격에 없는 내 커밋의 수입니다. ↓는 원격에는 있고 나에게는 없는 커밋의 수입니다. 브랜치 위에 포인터를 올려 두면 무엇을 추적하는지 볼 수 있습니다.

한동안 새 커밋이 없는 브랜치는 오래된 브랜치입니다. 이름이 흐리게 표시되고, 그 뒤에 시계와 지난 기간이 나옵니다. `main`, `master`, `trunk`, `dev`, `develop`, `next`, 그리고 다른 브랜치의 부모인 브랜치는 오래된 브랜치가 되지 않습니다.

:ui[remote.group] 아래에서는 집 아이콘이 각 원격의 기본 브랜치를 나타냅니다.

## 브랜치 만들기 {#create}

1. 도구 막대에서 :ui[toolbar.createBranch]를 클릭하거나 :ui[menu.repository > branch.createMenu](<kbd>⌘B</kbd>)를 선택합니다. 사이드바 맨 아래의 추가 버튼을 클릭하거나 :ui[branch.group]를 오른쪽 클릭하고 메뉴에서 선택해도 됩니다.
2. :ui[reference.name]에 이름을 입력합니다.
3. :ui[branch.start]에서 브랜치가 시작할 곳을 고릅니다. 처음에는 현재 브랜치이거나, 여기로 오려고 오른쪽 클릭한 항목입니다.
4. 옵션을 설정합니다.
   - :ui[branch.trackStart]은 새 브랜치가 시작점을 추적하게 합니다. 시작점이 브랜치일 때만 사용할 수 있습니다.
   - :ui[branch.pin]은 새 브랜치를 :ui[sidebar.pinned] 아래에 둡니다.
   - :ui[branch.checkoutCreated]은 곧바로 새 브랜치로 전환합니다. Spooky는 이 선택을 기억합니다.
   - :ui[branch.parentOption]는 시작점을 새 브랜치의 [부모](#parent)로 설정합니다.
5. :ui[branch.create]를 클릭합니다.

특정 브랜치, 태그, 커밋에서 브랜치를 시작하려면 그 항목을 오른쪽 클릭하고 메뉴에서 :ui[branch.createFromMenu]{1="main"}를 선택합니다. :ui[branch.group] 위로 드래그해도 됩니다.

입력하는 동안 Spooky가 이름을 Git에 맞게 고칩니다. 공백과 Git이 허용하지 않는 문자는 `-`로 바뀌거나 빠집니다. 이름을 입력한 그대로 쓰려면 :ui[app.name > settings.title] › :ui[settings.general]에서 :ui[branch.cleanNames]을 끕니다. [작업](/guide/settings/general/#operations)을 참고하세요.

이름에 `/`가 있으면 브랜치가 폴더에 들어갑니다. 예를 들어 `feature/units-toggle`은 `feature`에 들어갑니다. 폴더를 오른쪽 클릭하고 메뉴에서 :ui[branch.createMenu]를 선택하면 이름이 그 폴더로 시작합니다.

## 브랜치 체크아웃하기 {#checkout}

브랜치를 이중 클릭하거나, 오른쪽 클릭하고 메뉴에서 :ui[branch.checkoutNamed]{1="feature/dark-mode"}을 선택합니다.

원격 브랜치도 이중 클릭할 수 있습니다.

- 이미 그 브랜치를 추적하는 로컬 브랜치가 있으면 Spooky가 그 브랜치를 체크아웃합니다.
- 이름은 같지만 그 브랜치를 추적하지 않는 로컬 브랜치가 있으면 Spooky가 먼저 :ui[branch.trackExisting.title]에서 물어봅니다. 그런 다음 그 브랜치를 체크아웃하고 원격 브랜치를 추적하게 합니다.
- 둘 다 아니면 Spooky가 원격 브랜치를 추적하는 같은 이름의 로컬 브랜치를 만듭니다. 그런 다음 그 브랜치를 체크아웃합니다.

추적 중인 파일에 변경 사항이 있으면 Spooky가 먼저 스태시할지 물어봅니다. [자동 스태시](/guide/work/stash/#auto-stash)를 참고하세요.

다른 작업 트리에서 체크아웃된 브랜치는 여기에서 체크아웃할 수 없습니다. 이중 클릭하면 Spooky가 그 작업 트리를 대신 엽니다. <kbd>⌘</kbd>를 누른 채 이중 클릭하면 새 탭에서 엽니다.

### 태그나 커밋 체크아웃하기 {#checkout-revision}

태그를 이중 클릭하면 태그의 커밋을 체크아웃합니다. 그 밖의 것을 체크아웃하려면 :ui[workspace.title > rewrite.checkout.menu](<kbd>⇧⌘B</kbd>)을 선택하고, 브랜치, 태그 또는 커밋을 고른 다음 :ui[rewrite.checkout.button]을 클릭합니다.

고른 것이 로컬 브랜치가 아니면 대화상자가 HEAD가 분리된다고 경고합니다. 분리된 HEAD는 브랜치가 아니라 커밋 위에 있다는 뜻입니다. 거기에서 만든 커밋을 남기려면 그 커밋에서 브랜치를 만듭니다.

## 원격 브랜치 추적하기 {#track}

로컬 브랜치는 원격의 브랜치를 추적할 수 있습니다. 이 원격 브랜치가 업스트림입니다. 다른 것을 고르지 않으면 풀과 푸시는 업스트림을 사용합니다. ↑와 ↓의 수도 업스트림과 비교한 값입니다.

원격 브랜치의 로컬 브랜치를 만들려면 다음과 같이 합니다.

1. 원격 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[branch.trackMenu]{1="origin/feature/station-map"}을 선택하거나, :ui[branch.group] 위로 드래그합니다.
2. :ui[branch.remoteField]에 원격 브랜치가 표시됩니다. 원하면 :ui[reference.name]에서 이름을 바꿉니다.
3. :ui[branch.track.checkout]은 매번 선택되어 있습니다. 현재 브랜치에 머무르려면 선택을 해제합니다.
4. :ui[branch.track.submit]를 클릭합니다.

기존 브랜치가 추적하는 대상을 바꾸려면 브랜치를 오른쪽 클릭하고 :ui[branch.tracking] 아래에서 브랜치를 선택합니다. :ui[branch.tracking.remove]는 추적을 멈춥니다. 현재 브랜치라면 <kbd>⌥</kbd>을 누른 채 원격 브랜치를 그 위로 드래그해도 됩니다.

현재 브랜치가 아닌 브랜치가 업스트림보다 뒤처져 있고 자체 커밋이 없으면 메뉴에 :ui[branch.fastForward]{1="main"}가 있습니다. 브랜치를 체크아웃하지 않고 업스트림 위치까지 옮깁니다.

## 브랜치 이름 변경하기 {#rename}

브랜치를 오른쪽 클릭하고 메뉴에서 :ui[reference.renameMenu]{1="feature/dark-mode"}을 선택합니다. 새 이름을 입력하고 :ui[reference.rename]을 클릭합니다.

고정, 보관, 부모 설정은 브랜치를 따라갑니다. 원격 브랜치의 이름을 변경하면 원격에서 이름이 바뀝니다.

브랜치를 폴더로 옮기려면 폴더 위로 드래그합니다. [드래그 앤 드롭](/guide/branches/merge-rebase/#drag-and-drop)을 참고하세요.

## 브랜치 삭제하기 {#delete}

브랜치를 오른쪽 클릭하고 메뉴에서 :ui[reference.deleteMenu]{1="feature/dark-mode"}를 선택합니다. 사이드바에 초점이 있을 때 브랜치를 하나 이상 선택하고 <kbd>⌘⌫</kbd>를 눌러도 됩니다.

Spooky는 항상 먼저 물어봅니다. 대화상자에는 옵션이 두 개 있습니다.

- :ui[branch.forceDelete]는 완전히 병합되지 않은 브랜치도 삭제합니다. 선택하지 않으면 Spooky가 완전히 병합되지 않은 브랜치를 나열하고 다시 물어봅니다.
- :ui[branch.deleteUpstream]는 브랜치가 추적하는 원격 브랜치도 삭제합니다. 원격 브랜치가 아직 남아 있는 브랜치 하나를 삭제할 때 나옵니다.

현재 브랜치는 삭제할 수 없습니다. 먼저 다른 브랜치를 체크아웃합니다.

원격 브랜치를 삭제하면 원격에서 삭제됩니다.

삭제한 로컬 브랜치를 되살리려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다. :ui[branch.deleteUpstream]를 선택했어도 됩니다. 원격 브랜치만 삭제한 경우에는 실행 취소할 수 없습니다. [실행 취소와 복구](/guide/work/undo/)를 참고하세요.

## 브랜치 고정하기 {#pin}

고정한 브랜치는 :ui[branch.group]에서 목록 맨 위의 :ui[sidebar.pinned]으로 옮겨집니다. 자주 돌아가는 브랜치에 사용합니다.

브랜치를 오른쪽 클릭하고 메뉴에서 :ui[branch.pinNamed]{1="feature/station-map"}을 선택하거나, :ui[sidebar.pinned] 위로 드래그합니다. 브랜치를 여러 개 선택하면 항목이 :ui[branch.pinMultiple]{1="2"}이 됩니다. 브랜치를 되돌리려면 :ui[branch.unpinNamed]{1="feature/station-map"}를 선택합니다.

## 브랜치 보관하기 {#archive}

보관하면 브랜치를 삭제하지 않고 눈에 띄지 않게 치워 둘 수 있습니다. 브랜치는 :ui[branch.group]에서 :ui[sidebar.archived]로 옮겨집니다. 전과 똑같이 사용할 수 있습니다.

브랜치를 오른쪽 클릭하고 메뉴에서 :ui[branch.archiveNamed]{1="feature/dark-mode"}을 선택하거나, :ui[sidebar.archived] 위로 드래그합니다. 다시 꺼내려면 :ui[branch.unarchiveNamed]{1="feature/dark-mode"}를 선택합니다.

Spooky가 보관할 만한 브랜치를 찾아서 대신 보관할 수도 있습니다. [브랜치 검토](/guide/branches/review/#archive-suggestions)를 참고하세요.

:::note[서버 저장소]
고정, 보관, 부모 브랜치는 저장소의 Git 구성에 저장됩니다. 서버 저장소라면 서버에 저장됩니다.
:::

## 부모 브랜치 {#parent}

부모 브랜치는 내 브랜치의 바탕이 되고 내 브랜치가 따라가야 하는 브랜치입니다. 예를 들어 `feature/units-toggle`의 부모는 `main`입니다.

설정하려면 브랜치를 오른쪽 클릭하고 :ui[branch.parent] 아래에서 제안된 브랜치를 선택합니다. 다른 브랜치로 하려면 :ui[branch.parent.setMenu]을 선택하고, :ui[branch.parent.field]에서 브랜치를 고른 다음 :ui[branch.parent.set]을 클릭합니다. 브랜치를 만들 때 설정할 수도 있습니다. :ui[branch.parent.remove]는 설정을 지웁니다.

브랜치에 부모가 있으면 다음과 같이 됩니다.

- 기록에서 브랜치를 비교할 때 부모부터 비교합니다. [다른 브랜치와 비교하기](/guide/history/browse/#compare-branches)를 참고하세요.
- 내 브랜치에 없는 커밋이 부모에 있으면 브랜치의 기록에 :ui[history.parentBanner.title]이 표시됩니다. 브랜치의 메뉴에 있는 :ui[branch.updateNamed]{1="feature/units-toggle"}로 그 커밋을 가져옵니다. [부모에서 브랜치 업데이트하기](/guide/branches/merge-rebase/#update)를 참고하세요.
- 현재 브랜치에서는 메뉴의 :ui[branch.mergeWith]{1="main"}과 :ui[branch.rebaseOn]{1="main"}가 부모를 고른 상태로 병합 대화상자와 리베이스 대화상자를 엽니다.
- 부모 자신은 오래된 브랜치가 되지 않습니다.

## 필터링과 그룹화 {#filter}

사이드바 맨 아래의 :ui[sidebar.filter]에 입력하면 일치하는 브랜치, 태그, 원격 브랜치, 하위 모듈, 작업 트리만 표시됩니다. 글자가 붙어 있지 않아도 됩니다. `stm`으로 `station-map`을 찾을 수 있습니다. 대소문자와 악센트는 구분하지 않습니다. 필터링하는 동안에는 폴더가 펼쳐지고, <kbd>Esc</kbd>를 누르면 필드가 지워집니다.

오른쪽 아래의 보기 설정 버튼을 클릭하거나 :ui[menu.view > sidebar.menu]를 선택해 사이드바에 표시할 내용을 설정합니다. 설정은 모든 윈도우에 적용됩니다.

- :ui[sidebar.groupRefs]는 `/`가 있는 이름을 폴더에 넣습니다. 처음에는 켜져 있습니다. :ui[sidebar.groupedRefsOnTop]는 폴더를 다른 브랜치보다 먼저 나열합니다.
- :ui[sidebar.showStaleInfo]는 어떤 브랜치가 오래되었는지 보여 줍니다. :ui[sidebar.staleInterval]은 브랜치에 커밋이 없어도 되는 기간을 정하며, 처음에는 6개월입니다.
- :ui[sidebar.remoteFilter]과 :ui[sidebar.tagsFilter]은 :ui[sidebar.showNewest] 아래에서 목록을 최신 몇 개로 제한합니다. 제한은 원격마다 따로 셉니다. 태그는 :ui[sidebar.sortBy] 아래에서 정렬할 수도 있습니다. 필터링하는 동안에는 일치하는 항목이 모두 표시됩니다.
- :ui[sidebar.autoArchive]은 [브랜치 검토](/guide/branches/review/#auto-archive)에서 설명합니다.

## 함께 보기

- [가져오기, 풀, 푸시](/guide/branches/sync/)
- [병합과 리베이스](/guide/branches/merge-rebase/)
- [브랜치 검토](/guide/branches/review/)
- [작업 트리](/guide/advanced/worktrees/)

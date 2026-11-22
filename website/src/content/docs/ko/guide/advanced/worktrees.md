---
title: "작업 트리"
description: "추가 작업 트리에서 브랜치를 체크아웃하고, 작업 트리를 열고, 이동하고, 복구하고, 제거합니다."
---

작업 트리는 같은 저장소에서 체크아웃한 또 다른 폴더입니다. 작업 트리마다 체크아웃된 브랜치와 작업 사본이 따로 있습니다. 저장소의 커밋과 브랜치는 모두가 함께 씁니다. 그래서 첫 번째 폴더에서 스태시하거나 전환하지 않고도 두 번째 브랜치에서 작업할 수 있습니다.

브랜치 하나는 한 번에 한 작업 트리에서만 체크아웃할 수 있습니다.

## 사이드바에서 {#sidebar}

작업 트리는 사이드바의 :ui[worktree.group] 아래에 이름순으로 나열됩니다. 이름은 작업 트리 경로의 마지막 부분입니다. 윈도우에 열려 있는 작업 트리는 나열되지 않습니다. 포인터를 올려 두면 체크아웃된 위치가 표시됩니다.

작업 트리를 클릭하면 이름, 경로, 현재 리비전, 브랜치가 표시됩니다. 이중 클릭하면 같은 윈도우에서 열립니다.

다른 작업 트리에 체크아웃된 브랜치는 아이콘에 작은 배지가 붙습니다. 오른쪽 클릭하면 메뉴에 어느 작업 트리에 있는지 나옵니다. 그 작업 트리를 열거나 제거하는 항목도 있습니다. [브랜치 체크아웃하기](/guide/branches/branches/#checkout)를 참고하세요.

저장소 윈도우에도 작업 트리를 나열하려면 [목록 정리하기](/guide/repositories/manager/#organize)를 참고하세요.

## 작업 트리 추가하기 {#add}

다음 방법 중 하나로 시작합니다.

- 메뉴 막대에서 :ui[menu.repository > menu.addWorktree]를 선택합니다.
- 사이드바 맨 아래의 추가 버튼을 클릭하거나 :ui[worktree.group]를 오른쪽 클릭하고 메뉴에서 :ui[worktree.add.menu]를 선택합니다.
- 로컬 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[worktree.checkoutBranch]{1="feature/units-toggle"}을 선택합니다.
- 로컬 브랜치를 :ui[worktree.group]로 드래그합니다.

대화상자에서:

1. :ui[worktree.revision] 옆에서 체크아웃할 브랜치나 리비전을 선택하거나 입력합니다. 브랜치에서 시작했으면 이미 채워져 있습니다.
2. :ui[worktree.destination] 옆에 새 폴더의 전체 경로를 입력합니다. :ui[submodule.path.select] 버튼은 저장소 폴더 옆에서 시작합니다. 저장소 이름과 리비전으로 만든 이름을 제안합니다. 폴더는 아직 없거나 비어 있어야 합니다.
3. 그 리비전에서 분리된 HEAD를 체크아웃하려면 :ui[worktree.detach]를 선택합니다. 그러면 작업 트리가 어떤 브랜치도 차지하지 않습니다.
4. :ui[worktree.add.submit]를 클릭합니다.

브랜치가 이미 다른 작업 트리에 체크아웃되어 있으면 대화상자가 그렇게 알립니다. 그래도 작업 트리를 만들려면 :ui[worktree.detach]를 선택하거나 :ui[dialog.options] 아래의 :ui[worktree.force]를 선택합니다.

저장소에 커밋이 적어도 하나 있어야 합니다. 작업 트리를 만든 뒤에도 윈도우는 열려 있던 저장소에 그대로 있습니다. 새 작업 트리는 사이드바에 나타납니다.

## 작업 트리 열기 {#open}

작업 트리는 다른 저장소와 똑같이 엽니다. 사이드바에서 오른쪽 클릭하고 메뉴에서 선택합니다.

- :ui[worktree.open.current], :ui[worktree.open.newTab], :ui[worktree.open.newWindow]
- :ui[worktree.reveal], :ui[action.copyPath], :ui[action.openTerminal]

## 작업 트리 이동하기 {#move}

작업 트리를 오른쪽 클릭하고 메뉴에서 :ui[worktree.move.menu]을 선택합니다. 새 경로를 입력하거나 :ui[submodule.path.select] 버튼을 클릭합니다. 작업 트리 안의 변경 사항도 함께 옮겨집니다.

## 작업 트리 제거하기 {#remove}

작업 트리를 오른쪽 클릭하고 메뉴에서 :ui[worktree.remove.menu]를 선택합니다. 작업 트리의 폴더가 삭제됩니다. 거기에 체크아웃되어 있던 브랜치는 저장소에 남습니다.

작업 트리에 변경 사항이나 추적되지 않는 파일이 있으면 Git이 제거를 거부합니다. 그것들까지 함께 삭제하려면 :ui[worktree.remove.force]를 선택합니다.

저장소의 주 작업 트리, 곧 `.git` 디렉터리가 들어 있는 폴더는 이동하거나 제거할 수 없습니다. 다른 작업 트리를 열어 두었을 때 목록에 나옵니다.

## 작업 트리 복구하기 {#repair}

작업 트리의 폴더를 Spooky 밖에서 옮기거나 삭제하면 작업 트리가 동작하지 않습니다. 사이드바에 경고 아이콘이 붙습니다. 열 수 없습니다. 세부사항에는 Git이 알려 준 이유와 함께 :ui[worktree.invalid]라고 표시되고, 버튼이 두 개 있습니다.

- :ui[worktree.invalid.repair]: 폴더를 옮겼다면 :ui[worktree.location] 메뉴에서 :ui[submodule.path.select]을 선택하고 폴더가 지금 있는 곳을 찾습니다. Spooky는 그 폴더가 이 저장소의 이 작업 트리인지 확인합니다. 그런 다음 :ui[worktree.relocate.submit]을 클릭합니다.
- :ui[worktree.invalid.remove]: 폴더가 없어졌다면 저장소에 남은 작업 트리의 흔적을 제거합니다.

둘 다 작업 트리의 오른쪽 클릭 메뉴에도 있습니다.

## 실행 취소 {#undo}

작업 트리 추가, 이동, 제거, 복구는 <kbd>⌘Z</kbd>로 실행 취소할 수 없습니다. 이 가운데 하나를 한 뒤에는 그 전의 작업도 더는 실행 취소할 수 없습니다. [실행 취소와 복구](/guide/work/undo/)를 참고하세요.

:::note[서버 저장소]
작업 트리는 서버에 만들어집니다. 경로는 서버의 경로입니다. :ui[submodule.path.select]은 서버의 폴더를 탐색합니다.

:ui[worktree.reveal]는 Spooky가 Mac에서 작업 트리의 폴더를 찾을 수 있을 때 쓸 수 있습니다. 작업 트리가 저장소 폴더 안에 있으면 Spooky는 저장소의 위치를 통해 찾습니다. 그렇지 않으면 Mac에 마운트된 볼륨 가운데에서 찾습니다. [이 Mac의 위치](/guide/server/local-location/)를 참고하세요.
:::

## 함께 보기

- [브랜치](/guide/branches/branches/)
- [하위 모듈](/guide/advanced/submodules/)
- [저장소 윈도우](/guide/repositories/manager/)

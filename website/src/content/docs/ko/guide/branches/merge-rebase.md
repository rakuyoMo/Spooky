---
title: "병합과 리베이스"
description: "브랜치를 병합하고 리베이스하고, 시작하기 전에 충돌을 미리 보고, 부모에서 브랜치를 업데이트하고, 사이드바에서 브랜치를 드래그 앤 드롭합니다."
---

병합과 리베이스는 둘 다 다른 브랜치의 커밋을 현재 브랜치로 가져옵니다.

- 병합은 두 기록을 합치며, 보통 병합 커밋이 생깁니다.
- 리베이스는 내 커밋을 다른 브랜치의 커밋 뒤로 옮깁니다. 기록은 한 줄로 이어지지만 내 커밋은 다시 쓰입니다.

도구 막대에 :ui[sync.merge]과 :ui[sync.rebaseHead]가 나란히 있습니다. 둘 다 :ui[workspace.title] 메뉴에서도 시작할 수 있습니다.

## 병합 {#merge}

1. 도구 막대에서 :ui[sync.merge]을 클릭하거나 :ui[workspace.title > sync.mergeMenu](<kbd>⇧⌘M</kbd>)을 선택합니다. 사이드바에서 현재 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[workspace.mergeMenu]을 선택하거나, 다른 브랜치를 그 위로 드래그해도 됩니다.
2. :ui[branch.target]에서 병합할 대상을 고릅니다. 로컬 브랜치, 원격 브랜치, 태그 중 하나입니다. 처음에는 현재 브랜치의 업스트림입니다.
3. 커밋하는 방법을 선택합니다.
   - :ui[merge.squash]는 병합 커밋 없이 모든 변경 사항을 스테이지해 직접 커밋 하나로 만들 수 있게 합니다.
   - :ui[merge.alwaysCommit]은 Git이 브랜치를 앞으로 옮기기만 해도 되는 경우에도 병합 커밋을 만듭니다.
   - :ui[merge.autoCommit]은 병합을 곧바로 커밋합니다. :ui[merge.alwaysCommit]이 선택되어 있을 때만 선택을 해제할 수 있습니다. 해제하면 병합된 변경 사항이 작업 사본에서 커밋을 기다립니다.
4. 병합에서 충돌이 생길 것 같으면 아래 줄에 표시됩니다. [충돌 미리 보기](#preview)를 참고하세요.
5. 옵션을 설정합니다.
   - :ui[merge.verify]은 병합할 커밋에 신뢰할 수 있는 서명이 없으면 병합을 멈춥니다.
   - :ui[sync.skipHooks]는 이번에만 저장소의 Git 훅을 건너뜁니다.
6. :ui[sync.merge]을 클릭합니다.

Spooky는 :ui[merge.alwaysCommit], :ui[merge.autoCommit], :ui[merge.verify]을 기억합니다.

병합이 충돌로 멈추면 Spooky가 작업 사본으로 전환하고 배너를 표시합니다. [충돌 해결하기](/guide/work/conflicts/#banner)를 참고하세요.

<kbd>⌘Z</kbd>로 병합을 실행 취소합니다. 병합이 충돌로 멈춘 상태에서 실행 취소하면 병합이 중단됩니다.

## 리베이스 {#rebase}

1. 도구 막대에서 :ui[sync.rebaseHead]를 클릭하거나 :ui[workspace.title > sync.rebaseMenu](<kbd>⇧⌘R</kbd>)를 선택합니다. 현재 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[workspace.rebaseMenu]를 선택해도 됩니다.
2. :ui[branch.target]에서 리베이스할 대상 브랜치를 고릅니다. 처음에는 현재 브랜치의 업스트림입니다.
3. 미리 보기를 확인하고, 필요하면 :ui[sync.skipHooks]를 선택합니다.
4. :ui[sync.rebaseHead]를 클릭합니다.

<kbd>⌘Z</kbd>로 끝난 리베이스를 실행 취소합니다. 충돌로 멈춘 리베이스는 실행 취소할 수 없습니다. 충돌을 해결하고 계속하거나, 배너에서 중단합니다.

커밋 일부만 다른 베이스로 옮기려면 [커밋을 다른 베이스로 리베이스하기](/guide/history/rewrite/#rebase-onto)를 참고하세요.

:::caution
리베이스는 커밋을 다시 씁니다. 이미 푸시한 커밋이라면 다음 푸시는 [강제 푸시](/guide/branches/sync/#force-push)여야 합니다.
:::

## 로컬 변경 사항 {#local-changes}

병합하려면 추적 중인 파일에 변경이 없어야 합니다. 새 파일은 병합이 덮어쓰게 될 때만 방해가 됩니다.

리베이스와 부모에서 브랜치 업데이트하기는 새 파일을 포함해 변경 사항이 전혀 없는 작업 사본이 필요합니다.

로컬 변경 사항 때문에 이런 작업을 할 수 없으면 Spooky가 변경 사항을 먼저 스태시하자고 제안합니다. [자동 스태시](/guide/work/stash/#auto-stash)를 참고하세요.

## 충돌 미리 보기 {#preview}

병합, 리베이스, 풀, 동기화 대화상자는 시작하기 전에 브랜치가 충돌하는지 확인하고 결과를 대화상자에 표시합니다.

- Spooky가 비교하는 동안에는 :ui[merge.checking].
- 충돌하는 파일의 수. 줄 위에 포인터를 올려 두면 어떤 파일인지 볼 수 있습니다.
- :ui[merge.clean] 또는 :ui[merge.unchanged].
- 확인하지 못했을 때는 :ui[merge.unavailable]. 줄 위에 포인터를 올려 두면 이유를 볼 수 있습니다.

병합 대화상자는 :ui[merge.clean]과 :ui[merge.unchanged]을 표시하지 않습니다. 나머지 대화상자는 모든 결과를 표시합니다.

## 빠른 버전 {#quick}

<kbd>⌥</kbd>을 누르고 있으면 도구 막대의 :ui[sync.merge]과 :ui[sync.rebaseHead]가 :ui[sync.quickMerge]과 :ui[sync.quickRebase]로 바뀝니다. 대화상자 없이 곧바로 실행됩니다.

- :ui[sync.quickMerge]은 현재 브랜치의 업스트림을 병합합니다.
- :ui[sync.quickRebase]는 현재 브랜치를 업스트림 위로 리베이스합니다.

빠른 병합은 병합 대화상자에서 마지막으로 선택한 커밋 옵션과 서명 옵션을 사용합니다. 둘 다 대화상자와 마찬가지로 로컬 변경 사항을 스태시하자고 제안합니다.

사이드바 메뉴의 항목도 같은 방식으로 바뀝니다. 예를 들어 :ui[workspace.mergeMenu]은 :ui[sync.quickMergeInto]{1="origin/main" 2="main"}이 됩니다.

## 부모에서 브랜치 업데이트하기 {#update}

브랜치에 [부모 브랜치](/guide/branches/branches/#parent)가 있으면 업데이트로 부모의 새 커밋을 가져옵니다.

1. 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[branch.updateNamed]{1="feature/units-toggle"}를 선택합니다. 브랜치의 기록을 보고 있고 부모에 새 커밋이 있으면 :ui[history.parentBanner.title] 배너에도 :ui[review.updateBranch.menu] 버튼이 있습니다.
2. :ui[review.update.branch]를 확인합니다. 아래 줄에 부모에서 커밋이 몇 개 들어오는지 나옵니다.
3. :ui[review.update.strategy]에서 :ui[review.update.merge] 또는 :ui[review.update.rebase]를 선택합니다. :ui[review.update.merge]을 선택하면 :ui[merge.alwaysCommit]도 선택할 수 있습니다.
4. 미리 보기를 확인합니다. :ui[review.update.conflicts], :ui[review.update.clean], :ui[review.update.noChanges] 중 하나입니다.
5. 옵션을 설정합니다. :ui[merge.verify](병합할 때만)과 :ui[sync.skipHooks]가 있습니다.
6. :ui[review.update.button]를 클릭합니다.

Spooky는 먼저 브랜치를 체크아웃한 다음 병합하거나 리베이스합니다. 업데이트는 브랜치에 없는 커밋이 부모에 있고 진행 중인 다른 작업이 없을 때만 사용할 수 있습니다.

현재 브랜치에서는 사이드바 메뉴의 :ui[branch.mergeWith]{1="main"}과 :ui[branch.rebaseOn]{1="main"}가 부모를 이미 고른 상태로 병합 대화상자와 리베이스 대화상자를 엽니다.

:::tip
메뉴가 열려 있을 때 <kbd>⌥</kbd>을 누르고 있으면 :ui[branch.updateNamed]{1="feature/units-toggle"}가 :ui[branch.quickUpdateNamed]{1="feature/units-toggle"}로 바뀝니다. 대화상자 없이 곧바로 부모를 병합합니다.
:::

## 드래그 앤 드롭 {#drag-and-drop}

브랜치 작업의 상당수는 사이드바에서 드래그해 시작합니다. 드래그하는 동안 포인터 옆의 레이블이 무슨 일이 일어날지 알려 줍니다. 접힌 폴더나 원격 위에 잠시 머무르면 펼쳐집니다.

| 드래그하는 항목 | 놓는 곳 | 일어나는 일 |
|---|---|---|
| 로컬 브랜치 | :ui[workspace.title] 또는 현재 브랜치 | 병합 대화상자. <kbd>⌥</kbd>을 누르고 있으면 리베이스 대화상자입니다. |
| 원격 브랜치 | :ui[workspace.title] 또는 현재 브랜치 | 풀 대화상자 |
| <kbd>⌥</kbd>을 누른 채 원격 브랜치 | 현재 브랜치 | 내 브랜치의 업스트림이 됩니다. |
| 로컬 브랜치, 태그 또는 커밋 | :ui[branch.group] | 거기에서 브랜치를 만드는 대화상자 |
| 원격 브랜치 | :ui[branch.group] | 그 브랜치를 추적하는 대화상자 |
| 로컬 브랜치 | 원격 | 게시 대화상자 |
| 로컬 브랜치 | 원격 브랜치 | :ui[sync.pushBranch] 대화상자 |
| 로컬 브랜치 또는 커밋 | :ui[sidebar.tags] 또는 태그 폴더 | 태그를 만드는 대화상자 |
| 태그 | 원격 | 태그를 게시하는 대화상자 |
| 로컬 브랜치 | :ui[sidebar.pinned] 또는 :ui[sidebar.archived] | 브랜치가 고정되거나 보관됩니다. |
| 로컬 브랜치 | :ui[worktree.group] | 그 브랜치의 작업 트리를 만드는 대화상자 |

브랜치를 폴더로 옮기려면 폴더 위로 드래그합니다. 브랜치 이름은 대화상자 없이 폴더에 이름의 마지막 부분을 붙인 것으로 바뀝니다. 원격 브랜치는 자기 원격의 폴더로만 옮길 수 있습니다. 브랜치를 폴더 밖으로 꺼내려면 목록의 위쪽이나 아래쪽 가장자리로 드래그합니다. 이름 변경은 <kbd>⌘Z</kbd>로 실행 취소할 수 있습니다.

기록에서 커밋을 :ui[workspace.title]이나 현재 브랜치 위로 드래그해 체리픽할 수도 있습니다. <kbd>⌥</kbd>을 누르고 있으면 대신 되돌립니다. [커밋 체리픽하기](/guide/history/rewrite/#cherry-pick)를 참고하세요. 커밋의 변경 세트에서 파일 하나를 거기로 드래그하면 그 파일의 변경 사항만 스테이지하지 않은 채 작업 사본에 적용됩니다.

## 함께 보기

- [충돌 해결하기](/guide/work/conflicts/)
- [기록 다시 쓰기](/guide/history/rewrite/)
- [가져오기, 풀, 푸시](/guide/branches/sync/)
- [브랜치](/guide/branches/branches/)

---
title: "키보드 단축키"
description: "Spooky의 모든 키보드 단축키를 찾아봅니다."
---

메뉴 항목 옆에는 단축키가 표시됩니다. 이 페이지에는 그 단축키를 모두 모으고, 커밋 영역, 목록, 대화상자처럼 특정한 곳에서 쓰는 키도 함께 정리했습니다. 기호는 [키보드 단축키](/guide/#shortcuts)에서 설명합니다.

단축키는 해당 메뉴 항목을 사용할 수 있을 때만 동작합니다. 항목이 흐리게 표시되어 있으면 단축키를 눌러도 아무 일도 일어나지 않습니다.

## 메뉴 {#menus}

### 앱과 윈도우 {#app-windows}

| 단축키 | 메뉴 항목 |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### 저장소 {#repositories}

| 단축키 | 메뉴 항목 |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### 보기 {#views}

| 단축키 | 메뉴 항목 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### 편집과 찾기 {#edit}

| 단축키 | 메뉴 항목 |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- :ui[menu.undo]로 무엇을 취소할 수 있는지는 [실행 취소와 실행 복귀](/guide/work/undo/#undo)를 참고하세요.
- :ui[menu.delete]는 일부 목록에서 선택한 항목도 삭제합니다. [목록](#lists)을 참고하세요.
- :ui[action.find]와 :ui[action.search]은 둘 다 도구 막대의 검색 필드에 커서를 둡니다. [검색하고 걸러 내기](/guide/history/browse/#search)와 [파일 찾기](/guide/work/working-copy/#search)를 참고하세요.
- :ui[commit.reformatParagraph]은 커밋 메시지에서 동작합니다. [메시지 쓰기](/guide/work/commit/#write)를 참고하세요.

### 브랜치와 동기화 {#sync}

| 단축키 | 메뉴 항목 |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

<kbd>⌥⇧⌘</kbd>가 붙은 항목은 빠른 버전입니다. 메뉴가 열려 있을 때 <kbd>⌥</kbd>을 누르고 있으면 바로 위 항목 자리에 나타납니다. 대화상자 없이 곧바로 실행됩니다. 단축키는 메뉴를 열지 않아도 동작합니다. [가져오기, 풀, 푸시](/guide/branches/sync/#quick)와 [병합과 리베이스](/guide/branches/merge-rebase/#quick)의 빠른 버전을 참고하세요.

### 변경 사항과 커밋 {#changes}

| 단축키 | 메뉴 항목 |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## Option 누르고 있기 {#option}

<kbd>⌥</kbd>을 누르고 있으면 일부 버튼과 메뉴가 바뀝니다. 손을 떼면 원래대로 돌아갑니다.

| 위치 | 바뀌는 것 |
|---|---|
| 도구 막대의 가져오기, 풀, 푸시, 동기화, 병합, 리베이스 버튼 | 빠른 버전으로 바뀝니다. [가져오기, 풀, 푸시](/guide/branches/sync/#quick)를 참고하세요. |
| 커밋 영역. 두 메시지 필드 모두 편집 중이 아닐 때 | 최근 커밋 수정으로 전환됩니다. [최근 커밋 수정하기](/guide/work/commit/#amend)를 참고하세요. |
| 파일 목록 위의 :ui[working.stageAll]. 변경 사항 일부만 스테이지되어 있을 때 | :ui[working.unstageAll]로 바뀝니다. [파일 전체 스테이지하기](/guide/work/diff/#stage-file)를 참고하세요. |
| 작업 사본의 파일 메뉴 | 스태시 항목이 빠른 버전으로 바뀝니다. [일부 파일만 스태시하기](/guide/work/stash/#partial)를 참고하세요. |
| 하위 모듈의 메뉴 | 가져오기와 업데이트가 빠른 버전으로 바뀝니다. [가져오기와 업데이트](/guide/advanced/submodules/#update)를 참고하세요. |
| 부모 브랜치가 있는 브랜치의 메뉴 | 부모에서 업데이트하기가 빠른 버전으로 바뀝니다. [부모에서 브랜치 업데이트하기](/guide/branches/merge-rebase/#update)를 참고하세요. |
| 커밋의 메뉴 | 패치 저장이 빠른 버전으로 바뀝니다. 커밋 두 개를 선택했다면 비교 방향이 반대가 됩니다. [패치 저장하기](/guide/history/commit-details/#patch)를 참고하세요. |
| 커밋 두 개를 선택했을 때의 :ui[compare.submit] | 반대 방향으로 비교합니다. [여러 커밋](/guide/history/commit-details/#multiple)을 참고하세요. |
| 드래그 | [Option을 누른 채 드래그하기](#drag)를 참고하세요. |

## 커밋 영역 {#commit-area}

| 키 | 하는 일 |
|---|---|
| 제목에서 <kbd>↩</kbd> 또는 <kbd>Tab</kbd> | 설명으로 이동합니다 |
| 설명에서 <kbd>Tab</kbd> | 파일 목록으로 이동합니다 |
| 설명에서 <kbd>⇧Tab</kbd> | 제목으로 돌아갑니다 |
| 메시지를 입력하는 중에 <kbd>⌘↩</kbd> | :ui[working.commit] 같은 커밋 영역의 주 버튼을 클릭합니다. 숫자 키패드의 <kbd>Enter</kbd>도 똑같이 동작합니다. |
| 두 메시지 필드 모두 편집 중이 아닐 때 <kbd>⌥⌘↩</kbd> | 최근 커밋을 수정합니다. [최근 커밋 수정하기](/guide/work/commit/#amend)를 참고하세요. |
| 자동 완성 목록에서 <kbd>↑</kbd> <kbd>↓</kbd>, <kbd>↩</kbd>, <kbd>Esc</kbd> | 일치 항목을 고르고, 삽입하고, 목록을 닫습니다 |

[변경 사항 커밋하기](/guide/work/commit/)를 참고하세요.

## 파일 목록 {#file-list}

다음 키는 작업 사본의 파일 목록에서 동작합니다.

| 키 | 하는 일 |
|---|---|
| <kbd>스페이스 바</kbd> | 선택한 파일을 스테이지하거나 스테이지 해제합니다. :ui[files.spacebar]를 :ui[files.spacebar.quickLook]로 설정했다면 대신 훑어보기로 보여 줍니다. [파일 목록](/guide/settings/general/#file-list)을 참고하세요. |
| <kbd>⌘⌫</kbd> | 선택한 파일을 휴지통으로 이동합니다 |
| <kbd>⇧Tab</kbd> | 커밋 메시지의 설명으로 돌아갑니다 |

## Diff의 줄 {#diff-lines}

작업 사본에서 블록의 줄 번호에 키보드 초점이 올 때까지 <kbd>Tab</kbd>을 누릅니다. 그런 다음 아래 키를 씁니다.

| 키 | 하는 일 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 선택할 수 있는 줄 사이를 이동합니다 |
| <kbd>스페이스 바</kbd> | 줄을 선택하거나 선택 해제합니다 |
| <kbd>Tab</kbd> 또는 <kbd>⇧Tab</kbd> | 줄 번호에서 벗어납니다 |

마우스로는 <kbd>⇧</kbd>를 누른 채 줄 번호를 클릭하면 그 사이의 모든 줄이 선택됩니다. [줄 스테이지하기](/guide/work/diff/#lines)를 참고하세요.

## 목록 {#lists}

| 위치 | 키 | 하는 일 |
|---|---|---|
| 기록의 커밋 목록 | <kbd>⌘C</kbd> | 선택한 커밋의 전체 해시를 복사합니다 |
| 커밋의 변경 세트 | <kbd>↑</kbd> <kbd>↓</kbd> | 선택을 이동합니다 |
| 전체 페이지 세부사항의 변경된 파일 | <kbd>↩</kbd> | 선택한 파일을 기본 앱에서 엽니다 |
| 커밋의 파일 트리 | <kbd>↩</kbd> | 선택한 폴더를 펼치거나 접습니다 |
| 파일 기록 | <kbd>↩</kbd> | 선택한 커밋을 전체 페이지 세부사항으로 엽니다 |
| 사이드바 | <kbd>⌘⌫</kbd> | 물어본 뒤 선택한 브랜치, 태그, 원격 또는 하위 모듈을 삭제합니다 |
| 사이드바의 필터 필드 | <kbd>Esc</kbd> | 필드를 지웁니다 |
| 스태시 | <kbd>⌘⌫</kbd> | 물어본 뒤 선택한 스태시를 삭제합니다 |
| 브랜치 검토 | <kbd>⌘⌫</kbd> | 물어본 뒤 선택한 브랜치를 삭제합니다 |
| 저장소 윈도우 | <kbd>↩</kbd> | 선택한 저장소를 엽니다 |
| 저장소 윈도우 | <kbd>⌫</kbd> 또는 <kbd>⌦</kbd> | 선택한 항목을 제거합니다. [저장소 제거하기](/guide/repositories/manager/#delete)를 참고하세요. |
| 실행할 때 표시되는 윈도우 | <kbd>↩</kbd> | 선택한 저장소를 엽니다. [하던 곳에서 이어 가기](/guide/repositories/navigation/#restore)를 참고하세요. |
| 풀 리퀘스트의 대화 | <kbd>↩</kbd> | 선택한 커밋을 엽니다 |
| 풀 리퀘스트의 대화 | <kbd>⌘S</kbd> | :ui[pullRequests.addComment]를 클릭합니다 |
| 설정의 :ui[settings.themes] | <kbd>↩</kbd> | 선택한 테마의 이름을 변경합니다 |
| 설정의 :ui[settings.appIcon.label] | 화살표 키, <kbd>스페이스 바</kbd> | 아이콘 사이를 이동하고, 현재 위치의 아이콘을 사용합니다 |

여러 항목을 선택할 수 있는 목록에서는 <kbd>⇧</kbd>-클릭으로 범위를 선택합니다. <kbd>⌘</kbd>-클릭은 항목 하나를 추가하거나 뺍니다. 사이드바에서 브랜치와 태그를 <kbd>⌘</kbd>-클릭하면 그 기록을 함께 볼 수 있습니다. [기록 열기](/guide/history/browse/#open)를 참고하세요.

다른 작업 트리에서 체크아웃된 브랜치를 <kbd>⌘</kbd>를 누른 채 이중 클릭합니다. 그 작업 트리가 새 탭에서 열립니다. [브랜치 체크아웃하기](/guide/branches/branches/#checkout)를 참고하세요.

## 빠른 동작 {#quick-actions}

다음 키는 [빠른 동작](/guide/repositories/navigation/#quick-actions) 패널에서 동작합니다.

| 키 | 하는 일 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 선택을 이동합니다 |
| <kbd>↩</kbd> | 선택한 항목의 기본 동작을 실행합니다 |
| <kbd>Tab</kbd>, 또는 텍스트 끝에서 <kbd>→</kbd> | 선택한 항목의 모든 동작을 나열합니다 |
| 텍스트가 없을 때 <kbd>←</kbd>, 또는 <kbd>⇧Tab</kbd> | 동작 목록에서 돌아갑니다 |
| <kbd>Esc</kbd> | 텍스트를 지웁니다. 텍스트가 없으면 동작 목록에서 돌아가거나 패널을 닫습니다. |

## 대화상자 {#dialogs}

대화상자에서 <kbd>↩</kbd>은 강조된 버튼을 클릭합니다. <kbd>Esc</kbd>는 취소하는 버튼을 클릭합니다. 대화상자에 그런 버튼이 없으면 <kbd>Esc</kbd>도 강조된 버튼을 클릭합니다.

## Option을 누른 채 드래그하기 {#drag}

놓을 때 <kbd>⌥</kbd>을 누르고 있으면 다른 동작을 합니다.

| 드래그하는 항목 | 놓는 곳 | <kbd>⌥</kbd> 없이 | <kbd>⌥</kbd>을 누른 채 |
|---|---|---|---|
| 로컬 브랜치 | :ui[workspace.title] 또는 현재 브랜치 | 병합 대화상자 | 리베이스 대화상자 |
| 원격 브랜치 | 현재 브랜치 | 풀 대화상자 | 내 브랜치의 업스트림이 됩니다. |
| 기록의 커밋 | :ui[workspace.title] 또는 현재 브랜치 | 체리픽합니다 | 되돌립니다 |
| 기록의 커밋 | 목록의 다른 커밋 | 그 커밋에 스쿼시합니다 | 대신 Fixup합니다 |

[드래그 앤 드롭](/guide/branches/merge-rebase/#drag-and-drop)과 [스쿼시, Fixup, 삭제, 이동](/guide/history/rewrite/#interactive)을 참고하세요.

## 함께 보기

- [윈도우와 탐색](/guide/repositories/navigation/)
- [변경 사항 커밋하기](/guide/work/commit/)
- [변경 사항 검토하고 스테이지하기](/guide/work/diff/)
- [병합과 리베이스](/guide/branches/merge-rebase/)

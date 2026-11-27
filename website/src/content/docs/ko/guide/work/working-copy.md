---
title: "작업 사본"
description: "변경된 파일의 상태를 읽고, 목록이나 트리로 보고, 정렬하고 검색하고, 추적되지 않는 파일과 무시된 파일을 다루고, 파일 동작과 훑어보기를 사용합니다."
---

작업 사본은 마지막 커밋 이후에 바뀐 내용을 보여 줍니다. 여기에서 다음 커밋에 넣을 변경 사항을 고르고, 파일을 살펴보고, Git이 추적하면 안 되는 파일을 Git에서 떼어 놓습니다.

작업 사본을 열려면 사이드바 맨 위의 :ui[workspace.title]을 클릭하거나 :ui[menu.view > menu.showWorkingCopy](<kbd>⌘1</kbd>)를 선택합니다. 가운데 열 맨 위에 커밋 영역이 있고, 그 아래에 변경된 파일이 나열됩니다. 커밋 영역은 [변경 사항 커밋하기](/guide/work/commit/)에서 설명합니다.

## 상태 읽기 {#status}

변경된 파일마다 한 행이 있고, 행에는 체크상자, 상태 배지 두 개, 파일 이름이 있습니다.

- 체크상자는 변경 사항이 스테이지되었는지 보여 줍니다. 대시는 파일의 일부만 스테이지되었다는 뜻입니다.
- 왼쪽 배지는 스테이지된 변경입니다. 오른쪽 배지는 아직 스테이지되지 않은 변경입니다.
- 글자는 Git의 상태 코드입니다. M은 수정됨, A는 추가됨, D는 삭제됨, R은 이름 변경됨입니다. Git이 아직 추적하지 않는 새 파일은 ?로, 무시된 파일은 !로 표시됩니다.
- 충돌한 파일은 U U처럼 충돌 코드 두 개로 표시됩니다. [충돌 해결하기](/guide/work/conflicts/)를 참고하세요.

배지 위에 포인터를 올려 두면 상태가 글로 표시됩니다.

목록 위의 줄에는 현재 브랜치가 나오고, 그 뒤에 이 브랜치가 추적하는 원격 브랜치가 나옵니다. 추적하는 브랜치가 없으면 :ui[branch.noTracking]이라고 표시됩니다.

파일이 바뀌면 Spooky가 목록을 알아서 업데이트합니다. 전부 다시 읽으려면 :ui[action.refresh]을 클릭하거나 <kbd>⌘R</kbd>을 누릅니다.

:::note[서버 저장소]
Spooky는 저장소의 윈도우가 맨 앞에 있는 동안에는 2초마다, 그렇지 않을 때는 10초마다 서버의 변경을 확인합니다. 서버의 응답이 느리면 확인 간격이 더 길어집니다. 서버에서 일어난 변경은 그만큼 늦게 나타날 수 있습니다. [서버 저장소가 다른 점](/guide/server/overview/#differences)을 참고하세요.
:::

## 목록 또는 트리로 보기 {#view}

:ui[menu.view > files.statusMenu] 메뉴에서 목록에 표시할 내용을 바꿉니다. 브랜치 줄 오른쪽 끝의 버튼에도 같은 항목이 있습니다.

| 항목 | 하는 일 |
|---|---|
| :ui[working.list] (<kbd>⌃⌘L</kbd>) | 파일마다 한 행씩, 전체 경로와 함께 표시합니다 |
| :ui[working.tree] (<kbd>⌃⌘T</kbd>) | 파일을 폴더별로 묶어 표시합니다. 폴더를 이중 클릭하면 펼치거나 접습니다. |
| :ui[files.showNonModified] (<kbd>⌃⌘M</kbd>) | 변경된 파일뿐 아니라 저장소의 모든 파일을 나열합니다. 트리에서 사용할 수 있습니다. |
| :ui[files.showIgnored] (<kbd>⌃⌘I</kbd>) | Git이 무시하는 파일을 나열합니다 |
| :ui[files.showAssumeUnchanged] | assume-unchanged로 표시한 파일을 나열합니다. [추적되지 않는 파일과 무시된 파일](#untracked-ignored)을 참고하세요. |

목록으로 볼지 트리로 볼지는 저장소마다 기억됩니다. 저장소는 처음에 목록으로 표시됩니다. 나머지 항목은 모든 저장소에 적용됩니다.

## 정렬하기 {#sort}

:ui[status.filename] 또는 :ui[status.column] 열 제목을 클릭하면 그 열을 기준으로 정렬됩니다. 다시 클릭하면 순서가 반대로 바뀝니다. 정렬 순서는 모든 저장소와 윈도우에서 같습니다.

:ui[status.column]를 처음 클릭하면 스테이지된 파일이 맨 앞에 옵니다. 그다음은 나머지 변경, 새 파일 순이고, 변경되지 않은 파일과 무시된 파일이 마지막입니다.

## 파일 찾기 {#search}

1. <kbd>⌘F</kbd>를 누르거나 도구 막대의 검색 필드를 클릭합니다. 검색 필드에는 :ui[history.search.forFile]이라고 적혀 있습니다.
2. 파일 경로의 일부를 입력합니다. Spooky가 그 글자들이 같은 순서로 들어 있는 파일을 제안합니다.
3. 파일을 선택하면 그 경로만 나열됩니다. 마지막 제안을 선택하면 입력한 내용이 경로에 들어 있는 모든 파일이 나열됩니다.

<kbd>Esc</kbd>를 누르면 검색 필드에서 빠져나옵니다. 목록은 필터링된 채로 남습니다. 모든 파일을 다시 보려면 검색 필드를 비웁니다.

## 추적되지 않는 파일과 무시된 파일 {#untracked-ignored}

새 파일은 스테이지하고 커밋하기 전까지 추적되지 않습니다. 추적되지 않는 파일은 ?로 표시되고 다른 변경과 함께 나열됩니다. 다음 커밋에 넣으려면 다른 변경과 똑같이 스테이지합니다.

빌드 결과물이나 개인 메모처럼 절대 커밋하면 안 되는 파일도 있습니다. Git이 이런 파일을 나열하지 않게 하려면 파일을 오른쪽 클릭하고 규칙을 선택합니다.

- :ui[files.ignore]는 저장소 루트의 `.gitignore` 파일에 규칙을 추가합니다. `.gitignore`를 커밋하면 이 저장소를 쓰는 모든 사람에게 규칙이 적용됩니다.
- :ui[files.exclude]는 Git 폴더의 `info/exclude`에 규칙을 추가합니다. 규칙은 이 저장소 사본에만 적용되고 커밋되지 않습니다.

두 하위 메뉴 모두 이 항목만, 이름이 같은 모든 항목, 확장자가 같은 모든 항목, 직접 입력한 패턴 가운데 하나를 골라 무시할 수 있습니다.

무시 규칙은 Git이 이미 추적하는 파일에는 적용되지 않습니다. 추적 중인 파일을 무시하면 Spooky가 추적도 중단할지 묻습니다. 추적을 중단하려면 :ui[files.untrack]을, 계속 추적하려면 :ui[files.untrackIgnored.skip]를 클릭합니다. 어느 쪽이든 파일은 폴더에 그대로 남습니다.

무시 규칙 없이 파일의 추적만 중단하려면 파일을 오른쪽 클릭하고 :ui[files.untrack]을 선택합니다. 다음 커밋에서 파일이 저장소에서 제거되고, 폴더에는 그대로 남습니다.

:ui[files.mark > files.assumeUnchanged.set]은 추적 중인 파일의 로컬 변경을 Git이 빼놓게 합니다. 이 Mac에서만 고쳐 쓰는 구성 파일이 그런 예입니다. 파일은 목록에서 사라집니다. 다시 보려면 :ui[files.showAssumeUnchanged]를 켠 다음 :ui[files.mark > files.assumeUnchanged.unset]를 선택합니다.

## 파일 동작 {#file-actions}

파일을 오른쪽 클릭하면 파일에 쓸 수 있는 동작이 나옵니다. 선택 영역 안의 행을 오른쪽 클릭하면 선택한 모든 파일에 동작이 적용됩니다. 선택 영역 밖에서는 클릭한 행에만 적용됩니다.

::screenshot[작업 사본에서 src/readings.ts의 단축 메뉴. 위에서 아래로 파일 열기와 경로 복사, 훑어보기, 스테이지와 휴지통으로 이동, 충돌, 버리기와 스태시, Blame과 파일 기록, 무시, 비교 항목이 있습니다.]{name="work-file-menu" frame="closeup"}

| 하려는 일 | 선택할 항목 |
|---|---|
| 파일 열기 | :ui[files.open] 또는 :ui[files.openWith]의 앱. 파일을 이중 클릭해도 됩니다. |
| 경로 복사 | :ui[workspace.copyPathMenu] 또는 :ui[working.copyRelative] |
| Finder나 터미널에서 보기 | :ui[action.revealFinder] 또는 :ui[action.openTerminal] |
| 이동하거나 이름 변경 | :ui[files.move.menu] |
| 휴지통으로 이동 | :ui[files.trash], 또는 <kbd>⌘⌫</kbd> 누르기 |
| 변경 사항 버리기 | :ui[working.discard.menu]([변경 사항 버리기](/guide/work/diff/#discard) 참고) |
| 스태시에 넣기 | [일부 파일만 스태시하기](/guide/work/stash/#partial)를 참고하세요. |
| 이전 버전으로 복원 | :ui[files.revert.menu] |
| 기록 살펴보기 | :ui[quickActions.showFileHistory] 또는 :ui[quickActions.showBlame]([파일 기록과 Blame](/guide/history/file-views/) 참고) |
| 다른 앱에서 비교 | :ui[externalTool.compare]([다른 앱에서 비교하기](/guide/work/diff/#external) 참고) |

:ui[files.trash]은 먼저 묻지 않습니다. 추적 중인 파일을 휴지통으로 옮기면 스테이지된 삭제로 나타납니다. 되살리려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다.

:::note[서버 저장소]
:ui[files.trash]은 파일을 서버의 휴지통으로 옮깁니다. 서버에 휴지통이 없으면 항목 이름이 :ui[files.delete]로 바뀌고, Spooky가 파일을 완전히 삭제하기 전에 묻습니다. 대부분의 앱은 파일의 사본을 받고, 저장하면 Spooky가 변경 내용을 서버에 다시 씁니다. [터미널과 다른 앱](/guide/server/local-location/#terminal)을 참고하세요.
:::

## 훑어보기 {#quick-look}

앱을 열지 않고 파일을 미리 보려면 파일을 오른쪽 클릭하고 :ui[files.quickLook.single]{1="README.md"}를 선택합니다.

훑어보기를 자주 쓴다면 스페이스 바로 열 수 있습니다. :ui[app.name > settings.title] › :ui[settings.general]을 선택하고 :ui[files.spacebar]를 :ui[files.spacebar.quickLook]로 설정합니다. 기본적으로 스페이스 바는 선택한 파일을 스테이지하거나 스테이지 해제합니다. [파일 목록](/guide/settings/general/#file-list)을 참고하세요.

:::note[서버 저장소]
Spooky는 먼저 파일을 이 Mac의 임시 폴더로 내려받습니다. 이 폴더는 저장소를 닫을 때 제거됩니다.
:::

## 파일 목록 설정 {#settings}

다음 설정은 :ui[app.name > settings.title] › :ui[settings.general]에 있습니다.

| 설정 | 선택 항목 |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile](기본값) 또는 :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging](기본값) 또는 :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] 또는 :ui[files.fontSize.medium](기본값) |
| :ui[files.truncation] | :ui[files.truncation.beginning](기본값) 또는 :ui[files.truncation.middle] |

[파일 목록](/guide/settings/general/#file-list)을 참고하세요.

## 함께 보기

- [변경 사항 검토하고 스테이지하기](/guide/work/diff/)
- [변경 사항 커밋하기](/guide/work/commit/)
- [파일 기록과 Blame](/guide/history/file-views/)

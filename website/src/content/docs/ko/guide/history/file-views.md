---
title: "파일 기록과 Blame"
description: "파일의 기록을 따라가고, Blame으로 줄마다 누가 바꿨는지 보고, 특정 리비전의 파일을 보고, 그 리비전에서 파일을 복원합니다."
---

이 보기들은 한 번에 파일 하나를 다룹니다. 파일을 바꾼 커밋, 줄마다 누가 썼는지, 과거 어느 시점에 어떤 내용이었는지를 봅니다.

## 파일 기록 {#file-history}

파일을 바꾼 모든 커밋을 보려면:

- 작업 사본에서 파일을 오른쪽 클릭하고 :ui[fileHistory.showHistoryOf]{1="units.ts"}를 선택합니다.
- 또는 오른쪽 열 맨 위의 파일 이름 위에 포인터를 올려 두고 :ui[fileHistory.title]을 클릭합니다.
- [커밋 세부사항](/guide/history/commit-details/#changeset)에서는 변경 세트나 파일 트리의 파일을 오른쪽 클릭하고 같은 항목을 선택합니다.

작업 사본에서는 폴더를 선택하고 오른쪽 열 맨 위의 :ui[fileHistory.title]을 클릭할 수도 있습니다. 이때 기록은 그 안의 모든 파일을 다룹니다.

왼쪽 열에는 커밋이 가장 새로운 것부터 월별로 묶여 나열됩니다. 맨 위에는 파일 이름과 커밋 개수가 있습니다. 파일 이름을 클릭하면 다른 파일로 바꿀 수 있습니다.

커밋을 선택하면 그 커밋이 파일에서 바꾼 내용이 오른쪽에 표시됩니다. :ui[showFile.raw]으로 바꾸면 그 커밋 시점의 파일 전체가 보이고, :ui[fileHistory.diff]로 돌아갈 수 있습니다. 맨 위의 짧은 해시 위에 포인터를 올려 두면 더 많은 버튼이 나옵니다.

- :ui[blame.title]은 그 커밋 시점에 줄마다 누가 썼는지 보여 줍니다. [Blame](#blame)을 참고하세요.
- :ui[fileHistory.showCommit]는 커밋을 [전체 페이지 세부사항](/guide/history/commit-details/#full-page)으로 엽니다.
- :ui[externalTool.action.diffTool]는 변경을 비교 도구에서 엽니다.

::screenshot[src/units.ts의 파일 기록. 왼쪽 열에 파일 이름과 커밋 개수가 있고, 이 파일을 바꾼 커밋이 월별로 묶여 있습니다. 오른쪽에는 선택한 커밋이 파일에서 바꾼 내용이 있습니다. 포인터는 짧은 해시 위에 있습니다. 오른쪽 위에 Blame, 커밋 보기, 비교 도구 버튼이 Diff와 원문 전환 버튼 옆에 보입니다.]{name="history-file-history" frame="window" markers="28.5,9 94.6,13.25 86,13.25"}

1. 파일 이름과 커밋 개수
2. :ui[fileHistory.diff]와 :ui[showFile.raw] 사이의 전환 버튼
3. 포인터가 짧은 해시 위에 있는 동안 보이는 버튼

커밋을 이중 클릭하거나 <kbd>Return</kbd>을 눌러도 전체 페이지 세부사항으로 열립니다. 커밋을 오른쪽 클릭하면 같은 동작이 나오고, 그 커밋 시점의 파일을 복원하거나 내보낼 수도 있습니다.

### 파일 기록 검색하기 {#file-history-search}

도구 막대의 검색 필드에 입력하면 목록이 좁혀집니다. 필드의 돋보기를 클릭해 검색할 대상을 고릅니다. :ui[fileHistory.scope.message], :ui[fileHistory.scope.hash], :ui[fileHistory.scope.author], :ui[fileHistory.scope.committer] 가운데 하나입니다.

- 메시지, 작성자, 커미터는 입력한 텍스트와 대소문자 구분 없이 일치시킵니다. 작성자와 커미터는 이름이나 이메일로 일치시킵니다.
- 커밋 해시, 브랜치, 태그는 그 지점까지에서 파일을 바꾼 가장 최근 커밋을 보여 줍니다.

## Blame {#blame}

Blame은 파일 전체를 보여 주고, 오른쪽 열에 줄 블록마다 마지막으로 바꾼 커밋을 표시합니다. 블록마다 작성자의 아바타, 커밋 메시지의 첫 줄, 작성자, 얼마나 전인지가 나옵니다.

- 작업 사본에서 파일을 오른쪽 클릭하고 :ui[blame.show]{1="units.ts"}를 선택합니다. 또는 오른쪽 열 맨 위의 파일 이름 위에 포인터를 올려 두고 :ui[blame.title]을 클릭합니다.
- 커밋의 변경 세트나 파일 트리에서는 :ui[fileHistory.blameAt]{1="units.ts" 2="e2dda2bc"}를 선택해 그때의 파일을 봅니다.

::screenshot[src/units.ts의 Blame. 왼쪽에 파일이 있습니다. 오른쪽 열에는 블록마다 마지막으로 바꾼 커밋의 아바타, 메시지, 작성자, 지난 시간이 표시됩니다. Drop trailing zeros from temperatures의 블록들이 강조되어 있습니다.]{name="history-blame" frame="window" markers="84,22 84,82.5"}

1. 블록마다 마지막으로 바꾼 커밋을 보여 주는 열
2. 클릭한 커밋의 블록들이 강조된 모습

블록을 클릭하면 그 커밋의 요약이 표시됩니다. 그 커밋의 모든 블록이 강조됩니다. 블록을 이중 클릭하면 그 커밋이 전체 페이지 세부사항으로 열립니다. 열을 넓히거나 좁히려면 왼쪽 가장자리를 드래그합니다. Spooky는 너비를 기억합니다.

Blame은 이미 커밋된 파일에만 쓸 수 있습니다. 새 파일이나 추적되지 않는 파일, 바이너리 파일, 하위 모듈은 표시할 수 없습니다.

## 특정 리비전의 파일 보기 {#show-file}

작업 사본을 바꾸지 않고 어느 커밋 시점의 파일을 읽으려면:

- 작업 사본에서 파일을 오른쪽 클릭하고 :ui[showFile.show]{1="units.ts"}를 선택합니다. HEAD의 버전이 표시됩니다.
- 커밋의 변경 세트나 파일 트리에서는 :ui[fileHistory.showAt]{1="units.ts" 2="e2dda2bc"}를 선택합니다.

머리줄은 경로처럼 읽습니다. 리비전 › 파일 순입니다.

- 리비전을 클릭하면 다른 커밋을 고를 수 있습니다. 목록에서 커밋을 이중 클릭하면 그 커밋으로 바뀝니다.
- 파일 이름을 클릭하면 같은 커밋의 다른 파일을 고를 수 있습니다.
- :ui[showFile.raw]과 :ui[blame.title]은 파일 원문과 [Blame](#blame) 사이를 바꿉니다.
- 머리줄 위에 포인터를 올려 두면 :ui[fileHistory.title]과 :ui[fileHistory.showCommit]가 나옵니다.

머리줄 아래에는 Spooky가 파일을 바꾼 사람 수를 아바타와 함께 표시합니다. 텍스트에는 테마와 :ui[app.name > settings.title] › :ui[settings.text]의 설정이 쓰입니다. [텍스트](/guide/settings/appearance/#text)를 참고하세요.

Blame과 마찬가지로 이 보기는 새 파일이나 추적되지 않는 파일, 바이너리 파일, 하위 모듈을 표시할 수 없습니다.

## 리비전에서 파일 복원하기 {#restore}

파일을 이전 커밋 시점의 상태로 되돌려 놓으려면:

1. 파일 기록에서 커밋을 오른쪽 클릭하고 메뉴에서 :ui[fileHistory.restoreAt]{1="units.ts" 2="e2dda2bc"}을 선택합니다. [커밋 세부사항](/guide/history/commit-details/#changeset)에서는 항목이 :ui[fileHistory.restoreInWorkingCopy]{1="units.ts" 2="e2dda2bc"}입니다.
2. Spooky가 먼저 묻습니다. :ui[fileHistory.restore.submit]을 클릭합니다.

파일의 스테이지된 변경과 스테이지되지 않은 변경이 모두 대체됩니다. 그 커밋에 파일이 없었다면 파일이 삭제됩니다. 커밋되는 것은 없습니다. 복원된 파일은 작업 사본에 스테이지된 변경으로 나타납니다.

되돌리려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다.

변경 세트나 파일 트리에서는 파일이나 폴더 여러 개를 한 번에 복원할 수 있습니다.

:::note[서버 저장소]
파일은 서버에서 덮어써집니다. :ui[dialog.doNotAskAgain]을 선택하면 다음부터 묻지 않습니다. 다시 묻게 하려면 :ui[app.name > settings.title] › :ui[settings.general]에서 :ui[settings.warnRestoringOnServer]를 켭니다. [확인 대화상자](/guide/settings/general/#confirmations)를 참고하세요.
:::

## 함께 보기

- [커밋 세부사항](/guide/history/commit-details/)
- [작업 사본](/guide/work/working-copy/)
- [실행 취소와 복구](/guide/work/undo/)

---
title: "변경 사항 검토하고 스테이지하기"
description: "파일의 변경 사항을 읽고, Diff 표시 방식을 조정하고, 파일, 블록, 줄 단위로 변경 사항을 스테이지하거나 버립니다."
---

작업 사본에서 파일을 선택하면 오른쪽 열에 그 파일의 Diff, 곧 무엇이 바뀌었는지가 줄 단위로 표시됩니다. 여기에서 다음 커밋에 들어갈 부분만 스테이지하고 나머지는 버릴 수 있습니다.

## Diff 읽기 {#read}

Diff는 블록으로 나뉩니다. 블록은 변경된 줄 한 무리와 그 주변의 변경되지 않은 줄 몇 개입니다. 블록의 머리줄은 블록이 파일의 어디에 있는지 알려 줍니다.

- 추가된 줄은 초록색, 삭제된 줄은 빨간색입니다. 줄 번호 두 열은 파일의 이전 버전과 새 버전의 번호입니다.
- 파일에 스테이지된 변경과 스테이지되지 않은 변경이 모두 있으면 열 맨 위의 :ui[working.unstaged]과 :ui[working.staged]으로 서로 바꿔 봅니다. 변경이 없는 쪽은 흐리게 표시됩니다.
- Diff 아래의 막대에는 블록 개수와 추가되고 삭제된 줄 수가 표시됩니다.
- 이미지의 Diff는 이전 그림과 새 그림을 보여 줍니다. :ui[diff.twoUp]는 둘을 나란히 놓습니다. :ui[diff.oneUp]는 한 번에 하나씩 보여 주고, :ui[diff.old]과 :ui[diff.new] 사이를 바꿔 가며 봅니다.

Diff가 아주 크면 윈도우가 느려질 수 있어서 Spooky가 먼저 묻습니다. :ui[working.largeDiff] 보려면 :ui[working.showDiff]를 클릭합니다. 크기 제한은 :ui[app.name > settings.title] › :ui[settings.general]의 :ui[working.diffThreshold] 항목입니다. 기본값은 20,000 kB입니다. [기록과 Diff](/guide/settings/general/#history)를 참고하세요.

## Diff 옵션 {#options}

Diff 아래의 막대에는 가장 자주 바꾸는 옵션이 있습니다.

- 왼쪽 끝에 버튼이 두 개 있습니다. 포인터를 올려 두면 이름이 표시됩니다.
  - :ui[diff.ignoreWhitespace]는 공백과 탭만 바뀐 변경을 빼놓습니다. 파일에서 그 밖에 바뀐 것이 없으면 Diff에 이렇게 표시됩니다. :ui[diff.onlyWhitespace]
  - :ui[diff.showEntireFile]는 파일 전체를 변경 사항과 함께 보여 줍니다. 지금 보고 있는 Diff에만 적용됩니다.
- 오른쪽 끝의 :ui[diff.context]는 각 변경 주변에 변경되지 않은 줄을 몇 줄 보여 줄지 정합니다. 기본값은 3입니다. :ui[menu.view > diff.contextMenu]에서 선택해도 됩니다.

공백 설정과 컨텍스트 설정은 모든 곳에 적용됩니다. 모든 저장소, 작업 사본, 기록이 해당됩니다.

더 많은 옵션은 :ui[app.name > settings.title] › :ui[settings.text]에 있습니다.

| 설정 | 하는 일 |
|---|---|
| :ui[text.enableSyntaxColoring] | 코드를 언어에 맞춰 색칠합니다. 기본적으로 켜져 있습니다. |
| :ui[text.syntaxColoringInDiffs] | Diff에서도 구문 색상을 씁니다. 기본적으로 꺼져 있습니다. |
| :ui[text.showInvisibles] | 공백, 탭, 줄 끝을 기호로 표시합니다 |
| :ui[text.tabWidth] | 탭 하나의 너비. 공백 개수로 정합니다. |

이 설정은 [텍스트](/guide/settings/appearance/#text)에서 더 자세히 설명합니다. 색상은 테마에서 옵니다. [테마](/guide/settings/appearance/#themes)를 참고하세요.

## 파일 전체 스테이지하기 {#stage-file}

스테이지는 다음 커밋에 들어갈 변경 사항을 고르는 일입니다. 파일 전체를 스테이지하려면 다음 중 하나를 합니다.

- 파일 앞의 체크상자를 선택합니다. 그 파일이 선택되어 있으면 선택한 모든 파일이 스테이지됩니다.
- 파일을 선택하고 <kbd>스페이스 바</kbd>를 누릅니다. 선택한 파일에 스테이지되지 않은 변경이 있으면 스페이스 바가 그 파일을 스테이지합니다. 없으면 스테이지 해제합니다.
- 목록 위의 :ui[working.stageAll]를 클릭하거나 :ui[workspace.title > working.stageAllMenu](<kbd>⇧⌘E</kbd>)를 선택합니다.

스테이지를 해제하려면 체크상자를 선택 해제하거나, <kbd>스페이스 바</kbd>를 다시 누르거나, :ui[workspace.title > working.unstageAllMenu](<kbd>⌥⇧⌘E</kbd>)를 선택합니다. 모든 변경이 스테이지되면 :ui[working.stageAll] 버튼이 :ui[working.unstageAll]로 바뀝니다. 일부만 스테이지된 동안에는 <kbd>⌥</kbd>을 누르고 있으면 버튼이 바뀝니다.

## 블록 스테이지하기 {#chunks}

블록마다 머리줄 오른쪽 끝에 버튼이 있습니다.

- :ui[working.unstaged] 쪽: :ui[working.discardChunk]와 :ui[working.stageChunk]
- :ui[working.staged] 쪽: :ui[working.unstageChunk]

블록은 바로 반대쪽으로 옮겨집니다. 파일의 나머지 부분은 제자리에 남습니다.

## 줄 스테이지하기 {#lines}

한 블록에 서로 다른 커밋에 들어갈 변경이 섞여 있으면 일부 줄만 스테이지합니다.

1. 변경된 줄의 줄 번호를 클릭해 선택합니다. 다시 클릭하면 선택이 해제됩니다.
2. 줄을 더 선택하려면 그 줄의 번호도 클릭합니다. 줄 번호 위를 드래그하면 이어진 줄들이 선택되고, <kbd>⇧</kbd>를 누른 채 클릭하면 그 사이의 모든 줄이 선택됩니다.
3. 블록 머리줄의 :ui[working.stageLines]를 클릭합니다.

::screenshot[src/readings.ts의 Diff에 있는 블록 하나. 줄 번호로 다섯 줄이 선택되어 있고, 블록 머리줄에 선택한 줄 버리기와 선택한 줄 스테이지 버튼이 있습니다.]{name="staging" frame="closeup"}

변경된 줄만 선택할 수 있습니다. 선택은 블록마다 따로이고, 블록의 버튼은 그 블록에서 선택한 줄에 작용합니다. :ui[working.staged] 쪽에서는 버튼이 :ui[working.unstageLines]입니다.

## 변경 사항 버리기 {#discard}

버리기는 남기고 싶지 않은 변경 사항을 없앱니다.

- **파일 하나**: 파일을 오른쪽 클릭하고 메뉴에서 :ui[working.discard.menu]를 선택하거나, :ui[workspace.title > working.discardMenu](<kbd>⇧⌘⌫</kbd>)를 선택합니다.
- **전부**: 메뉴 막대에서 :ui[workspace.title > working.discardAllMenu]를 선택합니다.
- **블록 하나 또는 일부 줄**: 블록 머리줄의 :ui[working.discardChunk]나 :ui[working.discardLines]를 클릭합니다.

파일은 Spooky가 먼저 묻습니다. 추적 중인 파일은 스테이지된 변경까지 포함해 마지막 커밋의 상태로 돌아갑니다. 새 파일은 휴지통으로 갑니다. 계속하려면 :ui[working.discard]나 :ui[working.discardAll.submit]를 클릭합니다.

블록과 줄은 Spooky가 이렇게 묻습니다. :ui[working.discardContent.title] :ui[dialog.doNotAskAgain]을 선택하면 다음부터 묻지 않습니다. 다시 묻게 하려면 :ui[app.name > settings.title] › :ui[settings.general]에서 :ui[settings.warnDiscardingChunks]를 켭니다. [확인 대화상자](/guide/settings/general/#confirmations)를 참고하세요.

:::caution
버린 변경 사항은 어떤 커밋에도 들어 있지 않습니다. 되찾는 방법은 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)뿐이고, 저장소가 다시 바뀌기 전까지만 됩니다. 새 파일은 휴지통에 남아 있는 동안에는 휴지통에서 돌아옵니다.
:::

:::note[서버 저장소]
버리기는 서버의 파일을 덮어씁니다. 새 파일은 서버의 휴지통으로 갑니다. 서버에 휴지통이 없으면 완전히 삭제됩니다. 이 질문에는 :ui[dialog.doNotAskAgain]이 있습니다. 다시 묻게 하려면 :ui[settings.general]에서 :ui[settings.warnDiscardingOnServer]를 켭니다.
:::

## 다른 앱에서 비교하기 {#external}

FileMerge나 Kaleidoscope 같은 비교 앱에서 변경을 보려면:

- 오른쪽 열 맨 위의 파일 이름 위에 포인터를 올려 두고 :ui[externalTool.action.diffTool]를 클릭합니다. 지금 보고 있는 쪽을 비교합니다.
- 또는 파일을 오른쪽 클릭하고 :ui[externalTool.compare] 하위 메뉴에서 :ui[externalTool.compare.workingTreeToBase], :ui[externalTool.compare.workingTreeToIndex], :ui[externalTool.compare.indexToBase] 가운데 하나를 선택합니다.

처음에는 Spooky가 어떤 앱을 쓸지 묻습니다. 나중에 바꾸려면 :ui[app.name > settings.title] › :ui[settings.gitConfig]의 :ui[externalTool.diffTool] 항목을 사용합니다. Spooky는 Araxis Merge, BBEdit, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge, TextMate, Visual Studio Code를 지원합니다. [비교 및 병합 도구](/guide/settings/integration/#diff-merge-tools)를 참고하세요.

:::note[서버 저장소]
비교 앱은 이 Mac의 임시 폴더에 있는 파일 사본을 받습니다. 이 폴더는 저장소를 닫을 때 제거됩니다.
:::

## 함께 보기

- [작업 사본](/guide/work/working-copy/)
- [변경 사항 커밋하기](/guide/work/commit/)
- [실행 취소와 복구](/guide/work/undo/)

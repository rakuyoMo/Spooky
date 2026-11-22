---
title: "충돌 해결하기"
description: "병합, 리베이스 등 진행 중인 작업에서 생긴 충돌을 충돌 마법사나 외부 병합 도구로 해결한 다음, 계속하거나 중단합니다."
---

충돌은 양쪽이 파일의 같은 부분을 바꿔서 Git이 어느 변경을 남길지 알 수 없을 때 생깁니다. 병합, 리베이스, 체리픽, 되돌리기는 그 지점에서 멈추고, 스태시 적용도 마찬가지입니다. 각 파일에 무엇을 넣을지 정한 다음 작업을 마칩니다.

::screenshot[“feature/units-toggle”을 “main”에 병합하는 중의 작업 사본. 가운데 열 맨 위의 노란 배너에 해결되지 않은 충돌 1개, 0개 해결됨이라고 적혀 있고 중단 버튼이 있습니다. 파일 목록에서 src/units.ts가 충돌함으로 표시되어 있습니다. 오른쪽에는 카드 두 장이 각 브랜치의 units.ts 버전을 보여 주고, 화살표가 아래의 빈 결과 상자와 병합 도구 선택 버튼을 가리킵니다.]{name="conflict" frame="window" markers="24,18 47,57 76,37 76,73 84,86"}

1. 배너는 진행 중인 작업과 남은 충돌 개수를 보여 줍니다.
2. 충돌한 파일. 선택하면 충돌 마법사가 열립니다.
3. 파일의 두 버전. 양쪽에서 하나씩 옵니다.
4. 결과: 파일이 어떤 모습이 될지 보여 줍니다.
5. 파일을 해결하거나 병합 도구를 여는 버튼.

## 진행 중인 작업 {#banner}

병합, 리베이스, 체리픽, 되돌리기가 진행 중인 동안에는 작업 사본 맨 위에 배너가 있습니다.

- 제목은 무슨 일이 진행 중인지 알려 줍니다. 예: :ui[conflict.title.merge]{1="feature/units-toggle" 2="main"}.
- 그 아래에 해결되지 않은 충돌 개수가 있습니다. 작업이 충돌에서 멈춘 뒤에는 해결된 파일 개수가 괄호 안에 이어집니다.
- 짧은 안내가 다음에 할 일을 알려 줍니다. 리베이스나 여러 커밋을 차례로 처리하는 동안에는 진행 막대가 지금 몇 번째 단계인지 보여 줍니다.
- :ui[working.onlyConflicts]는 파일 목록을 이 충돌의 파일로 좁힙니다. 해결한 파일도 목록에 남습니다. Spooky는 이 선택을 모든 저장소에 대해 기억합니다.
- :ui[working.abort]은 작업을 취소합니다. [계속하거나 중단하기](#continue)를 참고하세요.

모든 충돌이 해결될 때까지 커밋 영역은 가려져 있습니다.

## 충돌 마법사 사용하기 {#wizard}

작업 사본에서 충돌한 파일을 선택합니다. 오른쪽에 충돌 마법사가 열리고, :ui[conflict.version]{1="main"}처럼 양쪽에 카드가 하나씩 있습니다. 카드에는 파일, 그쪽에서 파일에 한 일(예: :ui[conflict.change.modified]), 그 버전이 나온 커밋이 표시됩니다.

한쪽을 남기려면:

1. 그쪽 카드를 클릭합니다. 결과 상자에 그 버전이 표시됩니다.
2. :ui[conflict.resolveUsing]{1="main"}을 클릭합니다.

Spooky가 그 버전을 파일에 쓰고 스테이지합니다. 파일은 해결된 것으로 칩니다. 그쪽에서 파일을 삭제했다면 파일이 삭제됩니다.

양쪽을 합치려면 두 카드를 모두 클릭한 다음 결과 상자 아래의 버튼을 클릭합니다. [다른 앱에서 병합하기](#merge-tool)에서 설명하는 병합 도구가 열립니다.

텍스트 편집기 등에서 이미 파일을 직접 편집했다면 결과 상자에 :ui[conflict.result]이 표시됩니다. :ui[conflict.resolveCurrent]을 클릭하면 파일을 지금 상태 그대로 스테이지합니다. Spooky로 돌아오면 마법사가 파일을 다시 읽습니다.

카드의 “…” 버튼은 그 버전의 메뉴를 엽니다.

- :ui[conflict.open]{1="main"}, 또는 다른 앱으로 열기
- :ui[conflict.export]{1="main"}
- :ui[conflict.compareOther]{1="feature/units-toggle"}
- :ui[conflict.compareBase]

## 다른 앱에서 병합하기 {#merge-tool}

병합 도구는 두 버전을 나란히 보여 주고 변경을 줄 단위로 고르게 해 줍니다. 한 번에 파일 하나를 다루고, 양쪽에 모두 파일이 있을 때 쓸 수 있습니다.

1. 충돌 마법사에서 :ui[externalTool.chooseMergeTool]을 클릭하고 앱을 고릅니다. 한 번 고른 뒤에는 버튼이 :ui[externalTool.mergeIn]{1="FileMerge"}으로 바뀝니다.
2. 그 앱에서 파일을 병합하고, 결과를 저장하고, 앱을 종료합니다.

Spooky가 결과를 파일에 쓰고 해결됨으로 표시합니다. 앱이 결과를 저장하지 않았으면 Spooky가 :ui[externalTool.noResult]이라고 알리고, 충돌은 그대로 남습니다.

FileMerge는 조금 다르게 동작합니다. FileMerge가 열려 있는 동안 Spooky에 :ui[externalTool.finishMerge]{1="FileMerge"}가 표시됩니다. FileMerge에서 결과를 저장한 다음 :ui[externalTool.done]를 클릭합니다.

Spooky는 Araxis Merge, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge, Visual Studio Code를 지원합니다. 앱을 바꾸려면 :ui[app.name > settings.title] › :ui[settings.gitConfig]에서 :ui[externalTool.mergeTool] 항목을 변경합니다. 같은 곳에서 :ui[externalTool.keepBackups]를 켜면 병합하기 전의 파일이 `src/units.ts.orig` 같은 이름으로 남습니다. [비교 및 병합 도구](/guide/settings/integration/#diff-merge-tools)를 참고하세요.

병합하는 동안 파일이 다른 곳에서 바뀌었으면 Spooky가 덮어쓰기 전에 묻습니다.

:::note[서버 저장소]
병합 도구는 이 Mac의 임시 폴더에 있는 각 버전의 사본을 받습니다. Spooky가 결과를 서버에 다시 쓴 다음 파일을 해결됨으로 표시합니다. 이 폴더는 저장소를 닫을 때 삭제됩니다.
:::

## 그 밖의 해결 방법 {#other-ways}

충돌한 파일을 하나 이상 오른쪽 클릭합니다.

- :ui[conflict.menu.resolve]
  - :ui[conflict.markResolved.one]{1="src/units.ts"}는 파일을 지금 상태 그대로 스테이지합니다. 파일의 체크상자를 선택해도 같습니다.
  - :ui[conflict.resolveUsingVersion]{1="main"}은 마법사처럼 한쪽을 남깁니다.
- :ui[conflict.menu.restore]
  - :ui[conflict.restoreUnmerged.one]{1="src/units.ts"}은 이미 해결한 파일이라도 충돌을 되살립니다.
  - :ui[conflict.restoreVersion]{1="main"}과 :ui[conflict.restoreAncestor]은 한 버전을 파일에 넣습니다. 파일은 해결되지 않은 상태로 남습니다.

:::caution
복원은 묻지 않고 작업 사본의 파일을 덮어씁니다. 파일에 해 둔 편집은 사라집니다.
:::

스태시나 패치를 적용하다가 충돌로 멈춘 경우에는 계속하거나 중단할 작업이 없고 배너도 없습니다. 마법사는 들어오는 쪽을 :ui[conflict.version.applied]이라고 부릅니다. 파일을 해결하고 나면 변경 사항은 다른 변경과 똑같이 작업 사본에 있습니다.

## 계속하거나 중단하기 {#continue}

모든 충돌이 해결되면 커밋 영역이 다시 나타나고, Git이 이 작업을 위해 준비한 메시지가 들어 있습니다.

- **병합, 또는 커밋 하나의 체리픽이나 되돌리기**: 메시지를 확인한 다음 :ui[working.commit]을 클릭합니다.
- **리베이스, 또는 여러 커밋의 체리픽이나 되돌리기**: 메시지를 확인한 다음 :ui[working.continue]을 클릭합니다. Spooky가 이 단계를 커밋하고 다음 단계로 넘어가며, 거기서 다시 충돌로 멈출 수 있습니다.
- **커밋을 편집하려고 멈춘 리베이스 단계**: 커밋을 만든 다음 배너의 :ui[working.endEditing]를 클릭합니다.

원래 있던 버전을 남긴 경우처럼 커밋할 내용이 남지 않을 때도 있습니다. 이때 :ui[working.commit]이나 :ui[working.continue]을 클릭하면 Spooky가 이렇게 묻습니다. :ui[commit.empty.title] 빈 커밋을 만들려면 :ui[commit.empty.use]을 클릭합니다. 다른 버튼은 병합을 중단하거나, 리베이스 또는 연속 작업에서 이 단계를 건너뜁니다. 리베이스나 연속 작업에서는 배너의 :ui[working.skip]를 클릭해도 됩니다.

그만두려면 배너의 :ui[working.abort]을 클릭합니다. 저장소가 작업을 시작하기 전 상태로 돌아갑니다.

:::caution
중단은 묻지 않고 바로 실행되며 실행 취소할 수 없습니다. 해결해 둔 충돌은 사라집니다.
:::

## 함께 보기

- [변경 사항 검토하고 스테이지하기](/guide/work/diff/)
- [스태시](/guide/work/stash/)
- [실행 취소와 복구](/guide/work/undo/)

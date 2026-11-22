---
title: "스태시"
description: "스태시를 저장하고, 적용하고, 살펴보고, 자동 스태시를 사용합니다."
---

스태시는 로컬 변경 사항을 커밋하지 않고 따로 치워 둡니다. 브랜치를 전환하거나 풀할 때처럼 잠깐 깨끗한 작업 사본이 필요하고, 그 뒤에 변경 사항을 되찾고 싶을 때 씁니다.

스태시는 저장소에 속합니다. 원격으로 푸시되지 않습니다.

## 스태시 저장하기 {#save}

1. :ui[workspace.title > stash.saveMenu](<kbd>⇧⌘S</kbd>)을 선택하거나 도구 막대의 :ui[toolbar.saveStash]을 클릭합니다.
2. 원하면 :ui[stash.message] 필드에 변경 사항을 설명해 둡니다. 나중에 스태시를 찾기 쉽습니다.
3. 새 파일도 치워 두려면 :ui[stash.includeUntracked]을 선택합니다. Spooky는 이 선택을 기억합니다.
4. :ui[stash.save]을 클릭합니다.

모든 변경 사항이 스태시에 들어가고 작업 사본은 다시 깨끗해집니다. 저장할 것이 없으면 Spooky가 :ui[stash.error.noChanges]이라고 알립니다. 새 파일은 :ui[stash.includeUntracked]을 선택했을 때만 칩니다.

변경 사항의 사본을 저장하면서 작업은 계속하려면 :ui[workspace.title > stash.snapshotMenu](<kbd>⌃⇧⌘S</kbd>)를 대신 선택합니다. 대화상자는 같고, 작업 사본은 그대로 남습니다.

## 일부 파일만 스태시하기 {#partial}

일부 파일만 치워 두려면 작업 사본에서 파일을 선택하고, 오른쪽 클릭한 다음, 메뉴에서 :ui[stash.stashFile]{1="README.md"}나 :ui[stash.stashItems]{1="3"}를 선택합니다. 그 아래의 스냅샷 항목은 파일을 그대로 둡니다.

파일을 사이드바의 :ui[stash.title]로 드래그해도 됩니다.

선택한 새 파일은 :ui[stash.includeUntracked]을 선택했든 아니든 항상 스태시에 들어갑니다.

:::tip
메뉴가 열려 있는 동안 <kbd>⌥</kbd>을 누르고 있으면 항목이 :ui[stash.quickStashFile]{1="README.md"} 같은 빠른 버전으로 바뀝니다. 대화상자 없이 바로 저장하고, 메시지는 Git이 씁니다.
:::

## 스태시 보기 {#view}

사이드바에서 :ui[stash.title]를 클릭하거나 :ui[menu.view > stash.show](<kbd>⌘3</kbd>)를 선택합니다.

왼쪽 목록에는 가장 새로운 스태시가 맨 위에 나옵니다. 각 행에는 :ui[stash.basedOn]과 스태시를 저장한 브랜치, 날짜, 메시지가 표시됩니다. 목록을 걸러 보려면 도구 막대의 검색 필드에 입력합니다.

::screenshot[스태시 보기. 왼쪽 목록에 스태시 세 개가 있고 Halfway through the units toggle이 선택되어 있습니다. 오른쪽에 그 세부사항이 있고, 커밋 정보 아래에 적용, 삭제, 비교 도구 버튼이 보입니다.]{name="work-stashes" frame="window" markers="33,36 82,35.5"}

1. 스태시 목록
2. :ui[stash.applyButton], :ui[stash.deleteButton], :ui[history.diffTool]

스태시를 선택하면 오른쪽에 변경 사항이 커밋 세부사항과 같은 모습으로 표시됩니다. 세부사항 위에 포인터를 올려 두면 :ui[stash.applyButton], :ui[stash.deleteButton], :ui[history.diffTool] 버튼이 나타납니다. :ui[history.diffTool]는 스태시를 비교 앱에서 엽니다.

## 스태시 적용하기 {#apply}

적용은 스태시의 변경 사항을 작업 사본으로 되돌려 놓습니다.

1. :ui[workspace.title > stash.applyMenu](<kbd>⌥⇧⌘S</kbd>)을 선택하거나 도구 막대의 :ui[toolbar.applyStash]을 클릭합니다. 스태시를 사이드바의 :ui[workspace.title]이나 현재 브랜치로 드래그해도 됩니다.
2. :ui[stash.picker] 메뉴에서 스태시를 선택합니다. 스태시 보기에서는 선택한 스태시가 이미 골라져 있습니다.
3. 옵션을 설정합니다.
   - :ui[stash.deleteAfterApply]는 변경 사항이 돌아온 뒤 스태시를 제거합니다.
   - :ui[stash.restoreIndex]은 스태시를 저장할 때 스테이지되어 있던 것을 다시 스테이지합니다.
4. :ui[stash.apply]을 클릭합니다.

Spooky는 두 옵션을 다음을 위해 기억합니다.

변경 사항이 지금 작업 사본에 있는 내용과 부딪히면 Spooky가 :ui[stash.error.conflicts]이라고 알립니다. :ui[stash.deleteAfterApply]를 선택했더라도 스태시는 남습니다. [충돌 해결하기](/guide/work/conflicts/)에서 설명한 대로 충돌을 해결합니다.

파일 하나만 되돌리려면 스태시를 열고 세부사항에서 그 파일을 사이드바의 :ui[workspace.title]으로 드래그합니다.

## 스태시 삭제하기 {#delete}

스태시 보기에서 스태시를 오른쪽 클릭하고 메뉴에서 :ui[stash.deleteNamed]{1="Halfway through the units toggle"}를 선택합니다. 스태시를 여러 개 선택했으면 항목이 :ui[stash.deleteMultiple]{1="2"}로 바뀝니다. <kbd>⌘⌫</kbd>를 눌러도 됩니다.

Spooky는 항상 먼저 묻습니다. 삭제한 스태시를 되찾으려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다.

## 자동 스태시 {#auto-stash}

브랜치 전환, 풀, 병합처럼 로컬 변경 사항이 있으면 실행할 수 없는 작업이 있습니다. 이런 작업이 막히면 Spooky가 변경 사항을 먼저 스태시할지 묻습니다.

::screenshot[작업을 막는 로컬 변경 사항을 스태시할지 묻는 대화상자. 선택 사항인 메시지 필드, 작업이 끝나면 변경 사항 다시 적용 체크상자, 그리고 중단, 스태시 안 함, 변경 사항 스태시 버튼이 있습니다.]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm]는 변경 사항을 스태시하고 작업을 실행합니다.
- :ui[stash.autoStash.skip]은 스태시하지 않고 작업을 실행합니다. 변경 사항이 여전히 작업을 막으면 원래대로 실패합니다.
- :ui[stash.autoStash.abort]은 작업을 취소합니다.

:ui[stash.autoStash.reapply]을 선택하면 작업이 끝나자마자 변경 사항이 돌아옵니다. 선택하지 않으면 스태시가 목록에 남고, 나중에 직접 적용할 수 있습니다. Spooky는 이 선택을 기억합니다.

추적 중인 파일에 변경이 있는 채로 브랜치를 전환하면, 그 변경이 방해가 되지 않더라도 Spooky가 시작하기 전에 묻습니다.

도중에 문제가 생기면 변경 사항은 스태시에 남고, Spooky가 무슨 일이 있었는지 알려 줍니다.

더 이상 묻지 않게 하려면 :ui[app.name > settings.title] › :ui[settings.general]에서 :ui[stash.offerAutoStash]를 끕니다. [작업](/guide/settings/general/#operations)을 참고하세요.

## 함께 보기

- [작업 사본](/guide/work/working-copy/)
- [충돌 해결하기](/guide/work/conflicts/)
- [브랜치](/guide/branches/branches/)

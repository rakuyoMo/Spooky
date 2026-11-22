---
title: "기록 다시 쓰기"
description: "커밋을 되돌리고, 체리픽하고, 재설정하고, 대화형으로 리베이스하고, 이전 커밋을 수정합니다."
---

여기의 명령은 대부분 [기록](/guide/history/browse/) 목록에서 시작합니다. 커밋을 오른쪽 클릭하거나, 먼저 여러 개를 선택합니다. 되돌리기와 체리픽은 새 커밋을 추가합니다. 나머지는 이미 있는 커밋을 다시 씁니다.

:::caution
다시 쓴 커밋은 새 해시를 갖습니다. 이미 푸시한 커밋이면 브랜치와 업스트림이 갈라지고, 다시 푸시하려면 강제 푸시가 필요합니다. 이전 커밋을 이미 받은 사람은 기록을 다시 맞춰야 합니다. [강제 푸시](/guide/branches/sync/#force-push)를 참고하세요.
:::

체리픽과 재설정을 빼면, 이 명령들은 목록이 지금 있는 브랜치만 보여 줄 때에만 커밋의 메뉴에 나타납니다. 그렇게 하려면 :ui[menu.view > history.showHead](<kbd>⌘0</kbd>)를 선택하거나 사이드바에서 브랜치를 클릭합니다.

::screenshot[목록이 지금 있는 브랜치를 보여 줄 때 커밋 2daa6982의 단축 메뉴. 재설정, 되돌리기, 다른 곳으로 리베이스 항목이 있고, 이어서 이 커밋의 수정, 편집, 커밋 메시지 편집, 삭제 항목이 있습니다.]{name="history-commit-menu" frame="closeup"}

## 커밋 되돌리기 {#revert}

되돌리기는 이전 커밋의 변경 사항을 취소하는 커밋을 추가합니다. 이전 커밋은 기록에 남으므로, 이미 푸시한 것을 무르는 안전한 방법입니다.

1. 커밋을 오른쪽 클릭하고 메뉴에서 :ui[rewrite.menu.revert]{1="e2dda2bc"}를 선택합니다. 커밋을 여러 개 선택했으면 항목이 :ui[rewrite.menu.revertMany]{1="3"}로 바뀝니다.
2. :ui[rewrite.revert.commit]은 기본적으로 켜져 있어서, 되돌린 커밋마다 커밋이 하나씩 생깁니다. 끄면 변경 사항이 작업 사본에 남습니다. Spooky는 이 선택을 기억합니다.
3. :ui[rewrite.revert.button]를 클릭합니다.

여러 커밋은 가장 새로운 것부터 오래된 것 순으로 되돌립니다. 병합 커밋을 되돌리려면 :ui[rewrite.mainline] 항목에서 주 흐름으로 칠 쪽의 부모를 선택합니다. 병합 커밋은 하나씩만 되돌릴 수 있습니다.

커밋 세부사항과 [여러 커밋 선택](/guide/history/commit-details/#multiple)에도 :ui[rewrite.revert.button] 버튼이 있습니다.

## 커밋 체리픽하기 {#cherry-pick}

체리픽은 다른 브랜치에 있는 커밋의 변경 사항을 지금 있는 브랜치에 새 커밋으로 복사합니다.

1. 사이드바에서 다른 브랜치를 클릭해 그 기록을 봅니다.
2. 커밋을 오른쪽 클릭하고 메뉴에서 :ui[rewrite.menu.cherryPick]{1="e2dda2bc"}을 선택합니다. 커밋을 여러 개 선택했으면 항목이 :ui[rewrite.menu.cherryPickMany]{1="3"}이고, 오른쪽의 :ui[rewrite.cherryPick.button]을 클릭해도 됩니다.
3. 옵션을 선택합니다. Spooky가 기억합니다.
   - :ui[rewrite.cherryPick.commit](기본적으로 켜짐)은 커밋을 하나씩 커밋합니다. 끄면 변경 사항을 작업 사본에 적용하기만 합니다.
   - :ui[rewrite.cherryPick.fastForward]는 브랜치가 그 커밋의 부모에 있을 때, 커밋을 복사하는 대신 브랜치를 그 커밋으로 옮깁니다. 첫 번째 옵션이 켜져 있을 때만 적용됩니다.
4. :ui[rewrite.cherryPick.button]을 클릭합니다.

커밋은 가장 오래된 것부터 새로운 것 순으로 적용됩니다. 병합 커밋에는 되돌리기와 마찬가지로 :ui[rewrite.mainline] 선택이 필요합니다.

목록이 지금 있는 브랜치를 보여 주는 동안에는, 업스트림에 있고 아직 풀하지 않은 커밋에만 이 항목이 나타납니다.

목록의 커밋을 사이드바의 :ui[workspace.title]이나 지금 있는 브랜치로 드래그해도 됩니다. 놓을 때 <kbd>⌥</kbd>을 누르고 있으면 체리픽 대신 되돌립니다.

## 이전 커밋으로 재설정하기 {#reset}

재설정은 지금 있는 브랜치를 다른 커밋으로 옮깁니다. 그 뒤의 커밋은 브랜치에서 빠집니다.

1. 커밋을 오른쪽 클릭하고 메뉴에서 :ui[rewrite.menu.reset]{1="e2dda2bc"}을 선택합니다. 커밋 세부사항의 :ui[history.rollback]을 클릭하거나 메뉴 막대에서 :ui[workspace.title > rewrite.reset.menu]을 선택해도 됩니다.
2. :ui[rewrite.revision] 필드를 확인합니다. 브랜치, 원격 브랜치, 태그를 고르거나 해시를 입력할 수 있습니다. 대화상자에 브랜치에서 빠질 커밋이 나열됩니다.
3. :ui[rewrite.reset.mode] 항목을 선택합니다.
   - :ui[rewrite.reset.soft]는 스테이징 영역과 작업 사본을 그대로 둡니다. 빠지는 커밋의 변경 사항은 스테이지된 상태로 남습니다.
   - :ui[rewrite.reset.mixed]는 스테이징 영역을 재설정하고 작업 사본은 그대로 둡니다. 그 변경 사항은 스테이지되지 않은 상태가 됩니다.
   - :ui[rewrite.reset.hard]는 둘 다 재설정합니다. 커밋하지 않은 변경과 빠지는 커밋의 변경 사항은 버려집니다.
4. :ui[rewrite.reset.button]을 클릭합니다.

대화상자는 매번 :ui[rewrite.reset.soft]로 시작합니다. 재설정은 변경 사항을 스태시할지 묻지 않습니다.

:::caution
:ui[rewrite.reset.hard]는 추적 중인 파일의 커밋하지 않은 변경을 버립니다. 그런 변경이 있으면 대화상자가 경고합니다. <kbd>⌘Z</kbd>로 되찾을 수 있지만, Spooky를 종료하기 전까지만 됩니다.
:::

## 커밋을 다른 베이스로 리베이스하기 {#rebase-onto}

:ui[rewrite.rebaseOnto]는 커밋을 다른 커밋 위로 옮깁니다.

- 브랜치의 한 구간을 통째로 옮기려면 메뉴 막대에서 :ui[workspace.title > rewrite.rebaseOnto.menu]를 선택합니다. :ui[rewrite.rebaseOnto.current] 필드와 :ui[rewrite.rebaseOnto.new] 필드를 채웁니다. 현재 베이스 뒤의 커밋이 새 베이스 위에 다시 적용됩니다.
- 일부 커밋만 옮기려면 커밋을 선택하고 오른쪽 클릭합니다. 메뉴에서 :ui[rewrite.menu.rebaseOntoMany]{1="3"}를, 커밋 하나라면 :ui[rewrite.menu.rebaseOnto]{1="e2dda2bc"}를 선택한 다음 :ui[rewrite.rebaseOnto.new] 필드를 채웁니다. 같은 구간에서 선택하지 않은 커밋은 브랜치에서 제거됩니다.

두 베이스 모두 체크아웃한 커밋일 수 없습니다. 대화상자에는 다시 쓰일 커밋이 나열되고, 일부가 이미 푸시되었거나 다른 브랜치에 있으면 경고가 나옵니다. :ui[sync.skipHooks]는 이번에 저장소의 pre-rebase 훅을 건너뜁니다. 시작하려면 :ui[rewrite.rebaseOnto.button]를 클릭합니다.

브랜치를 다른 브랜치 위로 리베이스하려면 [리베이스](/guide/branches/merge-rebase/#rebase)를 참고하세요.

## 스쿼시, Fixup, 삭제, 이동 {#interactive}

이 명령들은 지금 있는 브랜치의 이어진 커밋들을 다시 씁니다. 커밋을 선택하고 오른쪽 클릭한 다음 선택합니다.

- :ui[rewrite.menu.squashMany]{1="3"}: 가장 오래된 커밋에 합칩니다. 메시지가 합쳐지고, 목록에서 새 커밋이 선택됩니다.
- :ui[rewrite.menu.fixupMany]{1="3"}: 가장 오래된 커밋에 합치고 그 커밋의 메시지만 남깁니다.
- :ui[rewrite.menu.deleteMany]{1="3"}: 브랜치에서 제거합니다. 커밋 하나를 선택했으면 :ui[rewrite.menu.delete]{1="e2dda2bc"}가 같은 일을 합니다.

목록 안에서 커밋을 드래그해도 됩니다.

- 다른 커밋 위에 놓으면 그 커밋에 스쿼시됩니다. 놓을 때 <kbd>⌥</kbd>을 누르고 있으면 Fixup이 됩니다. 놓을 자리의 레이블에 :ui[rewrite.squash.button]나 :ui[rewrite.fixup.button]이라고 표시됩니다.
- 두 행 사이에 놓으면 거기로 옮겨집니다. 레이블에 :ui[branch.moveHere]이라고 표시됩니다.

이 모든 경우에 Spooky는 무엇이든 다시 쓰기 전에 묻습니다. 대화상자에는 다시 쓰일 모든 커밋이 :ui[rewrite.note.squash]나 :ui[rewrite.note.drop]처럼 그 커밋에 일어날 일과 함께 나열됩니다. 노란색 경고 표시는 이미 푸시되었거나 다른 브랜치에 있는 커밋을 가리키고, 목록 위의 경고가 이를 설명합니다. 이미 업스트림에 있는 커밋을 삭제할 때는 먼저 한 번 더 묻습니다.

::screenshot[커밋 두 개를 10e44ab8에 스쿼시하기 전에 묻는 대화상자. 맨 위의 경고 두 개는 일부 커밋이 이미 업스트림 브랜치나 다른 브랜치에 있다고 알립니다. 아래 목록에는 다시 쓰일 커밋 네 개와 각각에 일어날 일이 표시됩니다. 푸시된 커밋은 행 끝에 노란색 경고 표시가 있습니다. 버튼은 취소와 커밋 스쿼시입니다.]{name="history-rewrite-confirm" frame="dialog"}

## 커밋 메시지 편집하기 {#reword}

1. 커밋을 오른쪽 클릭하고 메뉴에서 :ui[rewrite.menu.reword]{1="e2dda2bc"}을 선택합니다.
2. :ui[working.subject]과 :ui[working.body]을 바꿉니다. 주석 줄은 [커밋 영역](/guide/work/commit/#comments)에서와 같이 처리됩니다.
3. :ui[rewrite.reword.button]을 클릭합니다.

그 뒤의 커밋도 다시 쓰이고, 목록에서 새 해시를 가진 그 커밋이 선택됩니다. 커밋이 이미 업스트림에 있으면 Spooky가 대화상자를 열기 전에 묻습니다.

## 커밋 편집하기 {#edit}

편집은 커밋에서 멈추고 그 변경 사항을 작업 사본에 되돌려 놓습니다. 커밋을 나누거나 다시 만들 수 있습니다.

1. 커밋을 오른쪽 클릭하고 :ui[rewrite.menu.edit]{1="e2dda2bc"}을 선택합니다. :ui[rewrite.edit.button]으로 확인합니다.
2. 배너에 :ui[conflict.title.edit]{1="e2dda2bc" 2="main"}이라고 표시됩니다. 커밋의 변경 사항은 스테이지되지 않은 채 작업 사본에 있습니다.
3. 평소처럼 스테이지하고 커밋합니다. 커밋은 몇 개로 나눠도 됩니다.
4. 배너의 :ui[working.endEditing]를 클릭합니다. 그 뒤의 커밋이 위에 다시 적용됩니다.

그만두려면 배너의 :ui[working.abort]을 클릭합니다. 저장소의 첫 커밋은 편집할 수 없습니다.

## 이전 커밋 수정하기 {#amend}

이전 커밋 수정은 [최근 커밋 수정](/guide/work/commit/#amend)과 같은 방식으로 그 커밋에 변경 사항을 더합니다.

1. 커밋을 오른쪽 클릭하고 :ui[rewrite.menu.amend]{1="e2dda2bc"}을 선택합니다. Spooky는 확인 없이 바로 시작합니다.
2. 리베이스가 그 커밋에서 멈춥니다. 변경하고 스테이지합니다.
3. 커밋 영역에서 :ui[working.amend]을 선택하고 커밋합니다.
4. 배너의 :ui[working.endEditing]를 클릭합니다. 그 뒤의 커밋이 위에 다시 적용됩니다.

시작할 때 로컬 변경 사항이 있으면 Spooky가 먼저 스태시할지 묻습니다. 변경 사항은 그 뒤에도 스태시에 남으므로, 리베이스가 멈춰 있는 동안이나 나중에 적용할 수 있습니다.

## 자동 스쿼시 {#autosquash}

커밋은 스스로를 이전 커밋의 수정으로 표시할 수 있습니다. 제목을 `fixup!`, `squash!`, `amend!` 중 하나로 시작하고 그 뒤에 이전 커밋의 제목을 씁니다. 커밋 영역이 [제목을 자동 완성](/guide/work/commit/#autocomplete)해 줍니다.

목록이 검색 없이 지금 있는 브랜치를 보여 주고 최근 커밋 1,000개 안에 이런 커밋이 있으면, 머리줄 아래에 :ui[rewrite.autosquash] 배너가 나타납니다. 배너의 :ui[rewrite.autosquash.button]를 클릭하고 확인합니다. 표시된 커밋은 각각 가리키는 커밋에 합쳐집니다.

- `fixup!`은 이전 커밋의 메시지를 남깁니다.
- `squash!`는 두 메시지를 합칩니다.
- `amend!`는 이전 커밋의 메시지를 자기 메시지로 바꿉니다.

×를 클릭하면 배너가 당분간 가려집니다.

## 다시 쓰기를 시작할 수 없을 때 {#errors}

Spooky는 무엇이든 다시 쓰기 전에 커밋을 확인합니다. 문제가 있으면 설명하고, 아무것도 바뀌지 않습니다.

| 메시지 | 이유 |
|---|---|
| :ui[rewrite.error.notInHead] | 커밋이 모두 지금 있는 브랜치의 기록에, 한 줄기 위에 있어야 합니다. |
| :ui[rewrite.error.merges] | 중간에 병합 커밋이 있어서 다시 쓰면 병합이 펴집니다. 마지막 병합 뒤의 커밋을 선택합니다. |
| :ui[rewrite.error.root] | 저장소의 첫 커밋에는 변경 사항을 돌려놓을 부모가 없습니다. |
| :ui[rewrite.error.selection] | 스쿼시에는 커밋이 적어도 두 개 필요하고, 대상은 합쳐지는 커밋 가운데 하나일 수 없습니다. |
| :ui[rewrite.error.autosquash] | 최근 커밋 가운데 이전 커밋을 가리키도록 표시된 것이 없습니다. |
| :ui[rewrite.error.changed] | Spooky가 읽은 뒤에 브랜치가 바뀌었습니다. 기록을 새로 고치고 다시 시도합니다. |

## 로컬 변경 사항과 충돌 {#local-changes}

되돌리기, 체리픽, 리베이스에는 방해가 되지 않는 작업 사본이 필요합니다. 로컬 변경 사항이 이 가운데 하나를 막으면 Spooky가 [먼저 스태시할지](/guide/work/stash/#auto-stash) 묻습니다. 이전 커밋 수정은 시작하기 전에 묻습니다.

도중에 커밋이 충돌하면 Spooky가 멈추고 [작업 배너](/guide/work/conflicts/#banner)를 표시합니다. 충돌을 해결한 다음 거기에서 계속하거나 중단합니다.

## 다시 쓰기 실행 취소하기 {#undo}

되돌리기, 체리픽, 재설정, 다시 쓰기를 무르려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다. 커밋을 편집하려는 경우처럼 리베이스가 멈춰 있는 동안에는 먼저 마치거나 중단합니다. 충돌에서 멈춘 리베이스나 체리픽은 실행 취소할 수 없습니다. [실행 취소와 복구](/guide/work/undo/)를 참고하세요.

이전 커밋은 한동안 [Reflog](/guide/work/undo/#reflog)에도 남아 있습니다.

:::note[서버 저장소]
커밋은 서버에서 다시 쓰입니다. 기록을 다시 쓰는 대화상자는 모두 실행되는 서버의 이름을 표시합니다.
:::

## 함께 보기

- [충돌 해결하기](/guide/work/conflicts/)
- [실행 취소와 복구](/guide/work/undo/)
- [병합과 리베이스](/guide/branches/merge-rebase/)

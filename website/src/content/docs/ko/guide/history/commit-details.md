---
title: "커밋 세부사항"
description: "커밋의 세부사항, 변경 세트, 파일 트리, 서명 상태를 살펴보고, 리비전을 비교하고, 파일을 내보냅니다."
---

[기록](/guide/history/browse/)에서 커밋을 선택하면 오른쪽 열에 세부사항이 표시됩니다. 누가 언제 만들었는지, 전체 메시지, 바뀐 파일이 나옵니다.

## 머리 부분 {#header}

맨 위의 막대에는 커밋의 짧은 해시와 :ui[history.changeset] 버튼, :ui[history.tree] 버튼이 있습니다. 해시는 선택해서 복사할 수 있습니다. 막대 아래의 머리 부분에는 다음이 나열됩니다.

- :ui[history.author]와 :ui[history.committer], 그리고 각각의 날짜. 오른쪽의 아바타는 작성자의 것입니다. 다른 사람이 커밋했다면 커미터의 아바타가 그 왼쪽에 있습니다.
- :ui[history.refs]: 커밋을 가리키는 브랜치와 태그
- :ui[history.hash]: 전체 해시
- :ui[history.parentHash]: 부모마다 한 행
- :ui[history.treeHash]
- 커밋에 서명이 있으면 서명. [서명](#signatures)을 참고하세요.

오른쪽 위의 화살표를 클릭하면 머리 부분이 작성자, 날짜, 참조만 남기고 접힙니다. Spooky는 이 선택을 기억합니다. 머리 부분 다음에 전체 메시지가 이어집니다.

### 동작 버튼 {#actions}

세부사항 위에 포인터를 올려 두면 머리 부분과 메시지 사이의 선 위에 버튼 한 줄이 나타납니다.

- :ui[history.rollback]은 현재 브랜치를 이 커밋으로 재설정하는 대화상자를 엽니다. [이전 커밋으로 재설정하기](/guide/history/rewrite/#reset)를 참고하세요.
- :ui[rewrite.revert.button]는 이 커밋을 취소하는 커밋을 추가하는 대화상자를 엽니다. [커밋 되돌리기](/guide/history/rewrite/#revert)를 참고하세요.
- :ui[history.diffTool]는 커밋의 모든 변경 사항을 비교 도구에서 엽니다. [다른 앱에서 비교하기](/guide/work/diff/#external)를 참고하세요.

:ui[history.rollback]과 :ui[rewrite.revert.button]는 목록이 지금 있는 브랜치를 보여 줄 때만 나타납니다.

## 변경 세트 {#changeset}

:ui[history.changeset]는 커밋이 바꾼 파일을 경로순으로 나열합니다. 목록 위의 줄에는 파일, 추가, 삭제의 개수가 표시됩니다.

- 파일 옆의 화살표를 클릭하면 그 파일의 변경 사항이 표시됩니다. 모든 파일의 변경 사항을 보이거나 가리려면 목록 위 줄 맨 앞의 :ui[history.expandAll]나 :ui[history.collapseAll]를 클릭하거나, <kbd>⌃⌘→</kbd> 또는 <kbd>⌃⌘←</kbd>를 누릅니다.
- 파일을 클릭하면 선택됩니다. <kbd>⇧</kbd>나 <kbd>⌘</kbd>를 누른 채 클릭하면 여러 개가 선택됩니다. <kbd>↑</kbd> <kbd>↓</kbd>는 선택을 옮깁니다.

파일은 처음에 접혀 있습니다. 알아서 펼쳐지게 하려면 :ui[menu.view > history.diffs]의 :ui[history.autoExpand.title] 아래에서 숫자를 선택합니다. 바뀐 파일이 그 숫자 이하인 커밋은 모든 Diff가 펼쳐집니다. :ui[history.autoExpand.always]는 언제나 모두 펼칩니다.

병합 커밋에서는 :ui[app.name > settings.title] › :ui[settings.general]의 :ui[history.mergeDiff] 항목이 변경 세트에 무엇을 보여 줄지 정합니다.

- :ui[history.mergeDiff.firstParent](기본값)는 병합이 브랜치에 들여온 변경 사항을 보여 줍니다.
- :ui[history.mergeDiff.mergedFilePaths]은 모든 부모와 다른 파일만 보여 줍니다.
- :ui[history.mergeDiff.off]은 변경 사항을 보여 주지 않습니다.

[기록과 Diff](/guide/settings/general/#history)를 참고하세요.

파일을 오른쪽 클릭하면 다음을 할 수 있습니다.

- 파일의 경로 또는 저장소 안에서의 경로 복사
- 이 커밋 시점의 파일, 파일의 Blame, 파일의 기록 보기. [파일 기록과 Blame](/guide/history/file-views/)을 참고하세요.
- 커밋의 첫 번째 부모와 비교해 비교 도구에서 열기
- 작업 사본의 파일을 이 커밋의 버전으로 복원. [리비전에서 파일 복원하기](/guide/history/file-views/#restore)를 참고하세요.
- 이 커밋의 버전을 Mac에 저장

파일을 여러 개 선택하면 함께 비교 도구에서 열거나, 복원하거나, 내보낼 수 있습니다.

## 파일 트리 {#tree}

:ui[history.tree]는 바뀐 파일만이 아니라 저장소의 모든 파일을 이 커밋 시점의 모습으로 보여 줍니다. 폴더 옆의 화살표를 클릭하면 폴더가 열립니다.

파일이나 폴더를 오른쪽 클릭하면 다음을 할 수 있습니다.

- 파일을 기본 앱이나 직접 고른 앱에서 열기
- 파일, 파일의 Blame, 파일의 기록 보기
- 작업 사본에서 이 커밋의 버전으로 복원
- 내보내기, 또는 zip 아카이브로 저장

열기와 보기는 파일에만 쓸 수 있습니다. 항목을 여러 개 선택하면 함께 열거나, 복원하거나, 내보내거나, 아카이브로 만들 수 있습니다. 내보낸 항목은 선택한 폴더에 들어갑니다. 같은 이름의 항목이 이미 있으면 Spooky가 덮어쓰기 전에 묻습니다.

## 전체 페이지 세부사항 {#full-page}

목록에서 커밋을 이중 클릭하면 세부사항이 윈도우 전체를 씁니다. 왼쪽 열에는 커밋이 표시되고 그 아래에 바뀐 파일 목록이 있습니다. 오른쪽 열에는 선택한 파일의 변경 사항이 표시됩니다.

- 왼쪽 위의 짧은 해시를 클릭하면 다른 커밋을 고를 수 있습니다. 목록에서 커밋을 이중 클릭하면 그 커밋으로 바뀝니다.
- 파일을 이중 클릭하거나 <kbd>Return</kbd>을 누르면 이 커밋의 버전이 기본 앱에서 열립니다.

기록으로 돌아가려면 :ui[menu.view > navigation.back](<kbd>⌘[</kbd>)를 선택하거나 도구 막대의 :ui[toolbar.previous]을 클릭합니다.

## 여러 커밋 {#multiple}

커밋을 둘 이상 선택하면 오른쪽 열에 개수가 표시됩니다. 그 아래에 다음 버튼이 있습니다.

- :ui[rewrite.cherryPick.button]은 커밋을 지금 있는 브랜치에 적용합니다. 목록이 그 브랜치를 보여 주는 동안에는 버튼이 :ui[rewrite.revert.button]로 바뀝니다. [기록 다시 쓰기](/guide/history/rewrite/)를 참고하세요.
- :ui[compare.submit]는 커밋을 정확히 두 개 선택했을 때 나타납니다. 더 오래된 커밋에서 더 새로운 커밋으로 무엇이 바뀌었는지 보여 줍니다. <kbd>⌥</kbd>을 누르고 있으면 반대 방향으로 비교합니다.

## 서명 {#signatures}

세부사항은 선택한 커밋의 서명을 확인합니다. 펼친 머리 부분에 키와 :ui[signature.good] 같은 상태가 표시됩니다.

목록에서도 서명을 보려면 [보기 옵션](/guide/history/browse/#view-options)에서 :ui[signature.verify]을 켭니다. 그러면 서명된 커밋의 행 끝에 점이 붙습니다.

- 초록색: 서명이 유효합니다.
- 빨간색: 서명이 유효하지 않습니다.
- 노란색: 그 밖의 상태. 키가 만료되었거나 Spooky가 서명을 확인할 수 없는 경우입니다.

점을 클릭하면 키와 상태가 표시됩니다.

## 두 리비전 비교하기 {#compare}

커밋, 브랜치, 태그 가운데 아무 둘 사이에서 무엇이 바뀌었는지 보려면:

1. 메뉴 막대에서 :ui[menu.repository > compare.menu]를 선택합니다. 또는 커밋을 오른쪽 클릭하고 :ui[compare.menuFrom]{1="e2dda2bc"}를 선택해 그 커밋에서 시작합니다.
2. :ui[compare.base] 필드와 :ui[compare.target] 필드를 채웁니다. 메뉴에 브랜치, 원격 브랜치, 태그가 나열됩니다. 해시를 직접 입력해도 됩니다.
3. :ui[compare.submit]를 클릭합니다.

오른쪽 열에 비교 결과가 표시됩니다. :ui[compare.commits]은 두 번째 리비전에 있고 첫 번째 리비전에는 없는 커밋을 나열합니다. :ui[history.changeset]는 첫 번째에서 두 번째로 바뀐 내용을 보여 줍니다. 닫으려면 오른쪽 위의 ×를 클릭하거나 다른 커밋을 선택합니다.

커밋을 두 개 선택했으면 메뉴에 :ui[compare.menuPair]{1="e2dda2bc" 2="f6b437e0"}가 바로 나옵니다.

## 파일 내보내기 {#export}

커밋 시점의 모든 파일을 그대로 저장하려면:

1. 커밋을 오른쪽 클릭하고 메뉴에서 :ui[export.menuFrom]{1="e2dda2bc"}를 선택합니다. 메뉴 막대의 :ui[menu.repository > export.menu]는 선택한 커밋에서 시작합니다.
2. 리비전을 확인합니다. zip 파일 하나로 받으려면 :ui[export.createArchive]을 선택합니다.
3. :ui[export.submit]를 클릭하고 저장할 위치를 선택합니다.

아카이브로 만들지 않으면 저장소 이름과 짧은 해시로 된 이름의 폴더가 생깁니다.

내보내기는 [활동 윈도우](/guide/advanced/queue-activity/)에 나타나고, 거기에서 취소할 수 있습니다.

## 패치 저장하기 {#patch}

패치는 커밋의 변경 사항이 담긴 텍스트 파일입니다. 다른 저장소에서 `git am`으로 적용할 수 있습니다.

1. 커밋을 오른쪽 클릭하고 메뉴에서 :ui[patch.menu]{1="e2dda2bc"}을 선택합니다. 커밋을 여러 개 선택했으면 이 항목이 커밋마다 패치를 저장합니다.
2. 각 경로 앞의 `a/`와 `b/`를 빼려면 :ui[patch.omitPrefixes]을 선택합니다.
3. :ui[patch.save]을 클릭하고 폴더를 선택합니다.

커밋마다 파일이 따로 생기고, `0001-Add-a-theme-toggle-to-the-header.patch`처럼 오래된 것부터 번호가 붙습니다. 끝나면 Finder가 열리고 파일이 선택되어 있습니다. 저장도 활동 윈도우에 나타납니다.

메뉴에서 <kbd>⌥</kbd>을 누르고 있으면 :ui[patch.quickMenu]{1="e2dda2bc"}이 나옵니다. 마지막으로 정한 :ui[patch.omitPrefixes] 선택을 써서 저장소 폴더에 바로 저장합니다.

:::note[서버 저장소]
내보낸 파일과 :ui[patch.save]으로 저장한 패치는 Mac에 저장됩니다. 빠르게 저장한 패치는 서버에 있는 저장소 폴더에 들어갑니다.
:::

## 커밋 정보 복사하기 {#copy}

커밋을 오른쪽 클릭하면 다음을 복사할 수 있습니다.

- :ui[history.copyHash]: 전체 해시
- :ui[history.copyInfo]: 짧은 해시와 메시지의 첫 줄

커밋을 여러 개 선택했으면 커밋마다 한 줄씩 복사됩니다.

## 함께 보기

- [기록 살펴보기](/guide/history/browse/)
- [파일 기록과 Blame](/guide/history/file-views/)
- [기록 다시 쓰기](/guide/history/rewrite/)

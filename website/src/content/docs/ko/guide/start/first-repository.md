---
title: "첫 번째 저장소"
description: "Mac에 있는 저장소를 열고, 변경하고, 스테이지하고, 커밋하고, 푸시하는 과정을 처음부터 끝까지 따라 합니다."
---

이 페이지는 작업 한 바퀴를 처음부터 끝까지 안내합니다. Mac에 있는 저장소를 열고, 파일을 바꾸고, 변경 사항을 스테이지하고, 커밋한 다음, 그 커밋을 원격으로 푸시합니다.

푸시할 수 있는 원격이 있는 Git 저장소가 Mac에 있어야 합니다. 아직 없다면 [저장소 윈도우](/guide/repositories/manager/)에서 저장소를 복제하거나 만드는 방법을 확인합니다.

## 저장소 열기 {#open}

1. :ui[menu.file > action.openLocal](<kbd>⌘O</kbd>)를 선택합니다.
2. 저장소의 폴더를 선택한 다음 :ui[repositories.panel.prompt]를 클릭합니다.

Spooky가 저장소를 열고 :ui[workspace.title]을 보여 줍니다. 저장소 목록에도 이 저장소를 추가합니다. 다음부터는 거기에서 열 수 있습니다.

저장소 안의 어느 폴더를 골라도 됩니다. Spooky는 저장소 전체를 엽니다. 폴더가 Git 저장소 안에 있지 않으면 Spooky가 :ui[bookmarks.noRepository.title]이라고 알려 줍니다. :ui[bookmarks.noRepository.create]를 클릭하면 그 폴더를 새 저장소로 만들고, :ui[action.cancel]를 클릭하면 다른 폴더를 고를 수 있습니다.

:::note[서버 저장소]
서버에 있는 저장소에서 작업하려면 :ui[action.addRemote]로 추가합니다. 방법은 [서버 저장소 추가](/guide/server/add/)에 있습니다. 저장소를 연 뒤에는 이 페이지의 나머지 내용이 똑같이 적용됩니다.
:::

## 변경하기 {#change}

아무 편집기로나 저장소의 파일을 편집하고 저장합니다. Spooky가 변경을 알아차리고 :ui[workspace.title]에 그 파일을 표시합니다. 변경 사항이 나타나지 않으면 :ui[action.refresh]을 클릭하거나 <kbd>⌘R</kbd>을 누릅니다.

파일을 선택하면 오른쪽 열에서 무엇이 바뀌었는지 볼 수 있습니다. 추가된 줄은 초록색, 삭제된 줄은 빨간색입니다.

## 변경 사항 스테이지하기 {#stage}

Git은 바꾼 것을 전부 커밋하지 않습니다. 스테이지한 것만 커밋합니다. 스테이지를 하면 다음 커밋에 넣을 변경 사항을 고를 수 있습니다. 나머지는 나중을 위해 작업 사본에 남습니다.

파일을 스테이지하려면 다음 중 하나를 합니다.

- 파일 앞의 체크상자를 선택합니다.
- 파일을 하나 이상 선택하고 <kbd>스페이스 바</kbd>를 누릅니다.
- :ui[working.stageAll]를 클릭해 변경된 파일을 모두 스테이지합니다.

스테이지된 파일은 체크상자가 선택된 상태로 표시됩니다. 파일의 일부 줄만 스테이지하려면 [변경 사항 검토하고 스테이지하기](/guide/work/diff/)를 참고하세요.

## 커밋하기 {#commit}

커밋은 스테이지된 변경 사항을 저장소의 기록에 저장합니다. 무엇을 왜 바꿨는지 적은 메시지가 함께 들어갑니다.

1. :ui[working.subject]을 클릭하고 변경 사항을 짧게 요약해 입력합니다. 입력하는 동안 커밋 영역이 펼쳐집니다.
2. 더 설명하고 싶으면 :ui[working.body]에 적습니다.
3. :ui[working.commit]을 클릭하거나 <kbd>⌘↩</kbd>을 누릅니다.

::screenshot[제목에 “Add gust alerts and a humidity chart”가 입력된 커밋 영역. 그 아래에 비어 있는 상세 설명, 최근 커밋 수정과 사인오프 체크상자, 작성자의 이름과 이메일, 모두 스테이지 버튼과 커밋 버튼이 있습니다. 아래의 파일 목록에는 체크상자가 선택된 파일 세 개가 있습니다.]{name="start-commit" frame="closeup"}

펼쳐진 커밋 영역에서 알아 둘 점은 다음과 같습니다.

- 제목 필드 끝의 숫자는 남은 글자 수입니다. 그보다 길어지면 제목이 권장 길이를 넘습니다.
- :ui[working.commit]은 제목에 글자가 들어갈 때까지 흐리게 표시됩니다.
- 오른쪽의 이름과 이메일은 커밋에 작성자로 기록됩니다. 바꾸려면 [사용자 프로필과 Git 구성](/guide/settings/identity/)을 참고하세요.
- :ui[working.amend]과 :ui[commit.signOff]는 [변경 사항 커밋하기](/guide/work/commit/)에서 설명합니다.

커밋하고 나면 커밋된 파일은 목록에서 사라집니다. 사이드바에서 현재 브랜치에 ↑1이 표시됩니다. Mac에는 있지만 원격에는 아직 없는 커밋이 하나라는 뜻입니다.

## 푸시하기 {#push}

푸시는 커밋을 원격으로 보냅니다. 다른 사람이 거기에서 커밋을 받을 수 있고, 원격에는 백업용 사본이 남습니다.

1. 도구 막대에서 :ui[sync.push]를 클릭하거나 :ui[menu.repository > sync.pushMenu](<kbd>⇧⌘U</kbd>)를 선택합니다.
2. :ui[sync.destination]이 푸시하려는 원격 브랜치인지 확인합니다. 브랜치가 이미 원격 브랜치를 추적하고 있으면 그 브랜치가 선택되어 있습니다.
3. :ui[sync.pushHead]를 클릭합니다.

::screenshot[HEAD 푸시 대화상자. 로컬 브랜치 “main”의 새 커밋을 대상 origin/main으로 푸시합니다. 아래에 접힌 옵션 섹션과 취소 버튼, HEAD 푸시 버튼이 있습니다.]{name="sync" frame="dialog"}

푸시가 끝나면 브랜치 옆의 ↑1이 사라집니다. :ui[dialog.options]은 [푸시](/guide/branches/sync/#push)에서 설명합니다. 브랜치를 처음 푸시하려면 [브랜치 게시하기](/guide/branches/sync/#publish)를 참고하세요.

:::tip
<kbd>⌥</kbd>을 누른 채 :ui[sync.push] 버튼을 클릭합니다. 버튼이 :ui[sync.quickPush]로 바뀌고, 대화상자 없이 현재 브랜치를 추적 브랜치로 바로 푸시합니다.
:::

## 함께 보기

- [작업 사본](/guide/work/working-copy/)
- [변경 사항 커밋하기](/guide/work/commit/)
- [가져오기, 풀, 푸시](/guide/branches/sync/)

---
title: "태그와 원격"
description: "태그를 만들고, 게시하고, 삭제하고, 원격을 추가하고, 편집하고, 이름을 바꾸고, 제거합니다."
---

태그는 사이드바의 :ui[sidebar.tags] 아래에, 원격은 :ui[remote.group] 아래에 나열됩니다. 둘 다 자체 메뉴가 있습니다. 오른쪽 클릭하면 할 수 있는 일이 나옵니다.

## 태그 {#tags}

태그는 커밋에 움직이지 않는 이름을 붙입니다. 보통 `v0.4.0` 같은 릴리스에 씁니다. 브랜치와 달리 커밋해도 움직이지 않습니다.

태그 위에 포인터를 올려 두면 태그가 가리키는 커밋과, 메시지가 있으면 메시지도 볼 수 있습니다. 태그를 이중 클릭하면 태그의 커밋을 체크아웃합니다. [태그나 커밋 체크아웃하기](/guide/branches/branches/#checkout-revision)를 참고하세요.

브랜치와 마찬가지로 이름에 `/`가 있는 태그는 폴더에 들어갑니다. 최신 몇 개만 표시하거나 반대 순서로 정렬하려면 [필터링과 그룹화](/guide/branches/branches/#filter)를 참고하세요.

### 태그 만들기 {#create-tag}

1. :ui[menu.repository > tag.createMenu](<kbd>⇧⌘T</kbd>)를 선택합니다. 사이드바 맨 아래의 추가 버튼을 클릭하고 메뉴에서 선택해도 됩니다. 특정 브랜치나 커밋에 태그를 붙이려면 그 항목을 오른쪽 클릭하고 메뉴에서 :ui[tag.createFrom]{1="main"}를 선택합니다.
2. :ui[reference.name]에 이름을 입력합니다.
3. :ui[tag.revision]은 태그를 붙일 커밋입니다. 처음에는 현재 브랜치이거나 오른쪽 클릭한 항목입니다.
4. 원하면 :ui[tag.messageField]를 씁니다. 메시지가 없으면 태그는 커밋의 이름일 뿐입니다. 메시지가 있으면 Git이 태그를 누가 언제 만들었는지도 저장합니다.
5. 태그에 서명하려면 :ui[tag.sign]을 선택하고 :ui[tag.signingKey]에서 키를 고릅니다. :ui[tag.signingKey.configured]는 Git에 설정된 키를 사용합니다. 서명된 태그에는 메시지가 있어야 합니다. Spooky는 서명 여부를 기억합니다.
6. :ui[tag.create.submit]를 클릭합니다.

커밋이나 로컬 브랜치를 :ui[sidebar.tags] 또는 태그 폴더 위로 드래그해도 됩니다.

새 태그는 게시하기 전까지 이 저장소에만 있습니다. 다시 없애려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다.

### 태그 게시하기 {#publish-tag}

1. 태그를 오른쪽 클릭하고 메뉴에서 :ui[tag.publishMenu]{1="v0.4.0"}를 선택하거나, 메뉴 막대에서 :ui[menu.repository > tag.publishMainMenu]를 선택합니다. 태그를 원격 위로 드래그해도 됩니다.
2. :ui[tag.local]와 :ui[sync.remote]을 확인합니다. 태그를 다른 원격 위로 드래그하지 않았다면 원격은 현재 브랜치가 추적하는 원격입니다.
3. 저장소의 Git 훅을 실행하지 않고 푸시하려면 :ui[sync.skipHooks]를 선택합니다.
4. :ui[tag.publish]를 클릭합니다.

태그 게시는 실행 취소할 수 있습니다. 실행 취소하면 원격에서 태그가 다시 삭제됩니다.

모든 태그를 한꺼번에 원격으로 푸시하려면 원격을 오른쪽 클릭하고 메뉴에서 :ui[tag.pushAll]{1="origin"}를 선택합니다. 푸시 대화상자에서도 모든 태그를 함께 보낼 수 있습니다. [푸시](/guide/branches/sync/#push)를 참고하세요.

### 태그 삭제하기 {#delete-tag}

태그를 오른쪽 클릭하고 메뉴에서 :ui[reference.deleteMenu]{1="v0.1.0"}를 선택합니다. 사이드바에 초점이 있을 때 태그를 하나 이상 선택하고 <kbd>⌘⌫</kbd>를 눌러도 됩니다.

Spooky는 항상 먼저 물어봅니다. 원격에서도 태그를 삭제하려면 :ui[tag.deleteRemote]를 선택하고 :ui[sync.remote]에서 원격을 고릅니다.

이 저장소에서만 태그를 삭제한 경우에는 실행 취소할 수 있습니다. 원격에서 삭제한 경우에는 실행 취소할 수 없습니다.

## 원격 {#remotes}

원격은 가져오고 푸시하는 대상이 되는 저장소의 또 다른 사본이며, 호스팅 서비스에 있는 경우가 많습니다. 복제해 온 원격은 보통 `origin`이라고 부릅니다.

:ui[remote.group] 아래에는 원격마다 그 브랜치가 나열됩니다. 원격 위에 포인터를 올려 두면 가져오기 URL과 푸시 URL을 볼 수 있습니다.

원격을 오른쪽 클릭하면 메뉴가 나옵니다.

- :ui[remote.fetchMenu]{1="origin"}와 :ui[sync.prune]는 이 원격의 가져오기 대화상자를 엽니다. [가져오기](/guide/branches/sync/#fetch)를 참고하세요.
- :ui[remote.viewInBrowser]{1="origin"}는 원격의 웹 페이지를 엽니다. HTTP(S), SSH, `git://` URL에서는 되고 로컬 경로에서는 안 됩니다.
- 나머지 항목은 아래에 설명한 대로 원격을 추가하고, 편집하고, 이름을 바꾸고, 삭제합니다.

:::note[서버 저장소]
원격에는 서버에서, 서버의 네트워크와 SSH 키로 접속합니다. Mac에서 되는 URL이 서버에서는 안 될 수 있습니다.
:::

### 원격 추가하기 {#add-remote}

1. 메뉴 막대에서 :ui[menu.repository > remote.addMainMenu]를 선택합니다. 사이드바 맨 아래의 추가 버튼을 클릭하거나 :ui[remote.group]을 오른쪽 클릭하고 메뉴에서 :ui[remote.addMenu]를 선택해도 됩니다.
2. :ui[reference.name]에 `upstream` 같은 짧은 이름을 입력합니다.
3. :ui[remote.url]에 주소를 붙여넣습니다.
4. :ui[remote.add.submit]를 클릭합니다.

Spooky는 원격을 추가하기 전에 연결을 확인합니다. 연결할 수 없으면 대화상자가 열린 채로 남습니다. 오타를 고치고 다시 시도할 수 있습니다. 원격이 추가되면 Spooky가 곧바로 가져옵니다.

### 원격 설정 {#remote-settings}

사이드바에서 원격을 클릭하면 설정이 열립니다. 맨 위의 전환 버튼에 페이지가 두 개 있습니다.

- :ui[remote.page.general]은 Git이 원격과 통신하는 방법을 보여 줍니다.
- :ui[remote.page.branches]는 원격의 브랜치를 각각이 가리키는 커밋과 함께 나열합니다.

:ui[remote.page.general]의 행 위에 포인터를 올려 두면 버튼이 나타납니다.

| 설정 | 하는 일 |
|---|---|
| :ui[remote.field.fetchURL] | Spooky가 가져오는 곳입니다. 원격을 오른쪽 클릭하고 :ui[remote.editConnection]을 선택해도 편집할 수 있습니다. |
| :ui[remote.skipFetchAll] | 이 원격을 자동 가져오기와 :ui[sync.fetchAll]에서 제외합니다. |
| :ui[remote.field.fetchRefspecs] | 어떤 브랜치를 가져오고 어디에 둘지 정합니다. |
| :ui[remote.field.pushURL] | Spooky가 푸시하는 곳입니다. 설정하기 전까지는 푸시에 가져오기 URL을 사용하며, 회색으로 표시됩니다. :ui[remote.action.unset]를 누르면 그 상태로 돌아갑니다. |
| :ui[remote.field.pushRefspecs] | 어떤 브랜치를 어디로 푸시할지 정합니다. |

refspec은 한쪽의 브랜치 이름을 다른 쪽의 이름에 대응시키는 규칙입니다. 대부분의 원격은 Git이 설정해 둔 하나만 있으면 됩니다. 추가하려면 :ui[remote.group.fetch] 또는 :ui[remote.group.push] 옆의 :ui[remote.action.addRefspec]를 클릭합니다.

Spooky는 새 URL을 저장하기 전에 확인합니다. 원격 설정의 변경은 실행 취소할 수 있습니다.

### 원격 이름 변경 또는 제거하기 {#rename-remote}

원격을 오른쪽 클릭하고 메뉴에서 :ui[reference.renameMenu]{1="origin"} 또는 :ui[reference.deleteMenu]{1="origin"}를 선택합니다.

원격을 제거하면 원격과 그 원격 브랜치가 이 저장소에서 제거됩니다. 원격이 가리키는 저장소는 바뀌지 않습니다. 이름 변경과 제거 모두 실행 취소할 수 있습니다.

## 함께 보기

- [브랜치](/guide/branches/branches/)
- [가져오기, 풀, 푸시](/guide/branches/sync/)
- [실행 취소와 복구](/guide/work/undo/)

---
title: "가져오기, 풀, 푸시"
description: "가져오고, 풀하고, 푸시하고, 브랜치를 처음 게시하고, 동기화하고, 강제 푸시하고, 자동으로 가져옵니다."
---

이 작업들은 [원격](/guide/branches/tags-remotes/#remotes)과 커밋을 주고받습니다.

- 가져오기는 원격에서 새 커밋을 다운로드합니다. 내 브랜치와 작업 사본은 그대로입니다.
- 풀은 원격 브랜치를 가져와서 그 커밋을 현재 브랜치에 합칩니다.
- 푸시는 내 커밋을 원격 브랜치로 보냅니다.

도구 막대에 :ui[sync.fetch], :ui[sync.pull], :ui[sync.push]가 나란히 있고, 그 옆에 :ui[sync.sync]가 있습니다. 같은 작업이 :ui[menu.repository] 메뉴에도 있습니다.

가져오기, 풀, 푸시, 동기화는 실행 취소 기록에 남지 않으므로 실행 취소할 수 없습니다. 브랜치 게시는 실행 취소할 수 있습니다.

:::note[서버 저장소]
원격에는 서버에서, 서버의 네트워크와 SSH 키로 접속합니다. 원격이 암호를 요구하면 Spooky가 사용자에게 물어봅니다. [암호와 암호문 입력 요청](/guide/server/connection/#prompts)을 참고하세요.
:::

## 가져오기 {#fetch}

1. 도구 막대에서 :ui[sync.fetch]를 클릭하거나 :ui[menu.repository > sync.fetchMenu](<kbd>⇧⌘F</kbd>)를 선택합니다. 원격 하나만 가져오려면 사이드바에서 원격을 오른쪽 클릭하고 메뉴에서 :ui[remote.fetchMenu]{1="origin"}를 선택합니다.
2. :ui[sync.remote]에서 원격을 고르거나 :ui[sync.allRemotes]를 선택합니다.
3. 옵션을 설정합니다.
   - :ui[sync.prune]는 원격에서 삭제된 원격 브랜치를 제거합니다. 처음에는 켜져 있습니다.
   - :ui[sync.fetchSubmodules]는 체크아웃된 하위 모듈의 새 커밋도 가져옵니다.
   - :ui[sync.allTags]는 원격의 모든 태그도 가져옵니다.
4. :ui[sync.fetch]를 클릭합니다.

Spooky는 :ui[sync.allTags]를 뺀 모든 옵션을 기억합니다.

가져온 뒤에는 사이드바의 원격 브랜치가 최신 상태가 되고, 로컬 브랜치의 ↓에 풀할 수 있는 커밋 수가 표시됩니다.

:ui[menu.repository > sync.fetchAll]는 대화상자 없이 곧바로 모든 원격을 가져옵니다. [설정](/guide/branches/tags-remotes/#remote-settings)에서 :ui[remote.skipFetchAll]로 설정한 원격은 건너뜁니다.

## 풀 {#pull}

1. 도구 막대에서 :ui[sync.pull]을 클릭하거나 :ui[menu.repository > sync.pullMenu](<kbd>⇧⌘P</kbd>)을 선택합니다. 특정 원격 브랜치를 풀하려면 그 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[branch.pullMenu]{1="origin/main"}을 선택합니다.
2. :ui[sync.remoteBranch]에서 브랜치를 고릅니다. 처음에는 현재 브랜치의 [업스트림](/guide/branches/branches/#track)입니다.
3. 둘을 병합 커밋으로 합치는 대신 내 커밋을 풀한 커밋 위에 올리려면 :ui[sync.rebase]을 선택합니다. Spooky는 이 선택을 기억합니다.
4. 옵션 아래의 미리 보기가 풀에서 충돌이 생길지 알려 줍니다. [충돌 미리 보기](/guide/branches/merge-rebase/#preview)를 참고하세요.
5. 옵션을 설정합니다.
   - :ui[merge.verify]은 풀하는 커밋에 신뢰할 수 있는 서명이 없으면 풀을 멈춥니다. Spooky는 이 옵션을 기억합니다.
   - :ui[sync.skipHooks]는 이번에만 저장소의 Git 훅을 건너뜁니다.
6. :ui[sync.pull]을 클릭합니다.

풀하려면 추적 중인 파일에 변경이 없어야 합니다. 변경이 있으면 Spooky가 변경 사항을 먼저 스태시하자고 제안합니다. [자동 스태시](/guide/work/stash/#auto-stash)를 참고하세요. 새 파일은 풀이 덮어쓰게 될 때만 방해가 됩니다.

풀에서 충돌이 생기면 Spooky가 작업 사본으로 전환하고 배너를 표시합니다. [충돌 해결하기](/guide/work/conflicts/#banner)를 참고하세요.

## 푸시 {#push}

1. 도구 막대에서 :ui[sync.push]를 클릭하거나 :ui[menu.repository > sync.pushMenu](<kbd>⇧⌘U</kbd>)를 선택합니다.
2. :ui[sync.destination]에서 원격 브랜치를 고릅니다. 처음에는 현재 브랜치의 업스트림입니다.
3. 옵션을 설정합니다.
   - :ui[sync.pushAllTags]는 모든 로컬 태그도 푸시합니다.
   - :ui[sync.forcePush]는 일반 푸시가 안 될 때 원격 브랜치를 덮어씁니다. [강제 푸시](#force-push)를 참고하세요.
   - :ui[sync.pushSubmodules]는 이번 푸시가 참조하는 하위 모듈 커밋을 처리합니다. :ui[sync.pushSubmodules.onDemand]와 :ui[sync.pushSubmodules.check] 중에서 선택합니다.
   - :ui[sync.skipHooks]는 이번에만 저장소의 Git 훅을 건너뜁니다.
4. :ui[sync.pushHead]를 클릭합니다.

Spooky는 태그 옵션과 하위 모듈 옵션을 기억합니다.

현재 브랜치가 아직 원격 브랜치를 추적하지 않으면 :ui[sync.push]가 게시 대화상자를 대신 엽니다. [브랜치 게시하기](#publish)를 참고하세요. 저장소에 원격이 하나도 없으면 저장소를 게시하는 대화상자를 엽니다. [저장소 게시하기](/guide/hosting/accounts/#publish)를 참고하세요.

다른 사람이 원격 브랜치에 먼저 푸시했다면 원격이 내 푸시를 거부합니다. 그 커밋을 풀한 다음 다시 푸시합니다.

현재 브랜치가 아닌 브랜치를 푸시하려면 사이드바에서 그 브랜치를 원격 브랜치 위로 드래그합니다. :ui[sync.pushBranch] 대화상자가 브랜치를 그곳으로 푸시합니다. 옵션이 없는 일반 푸시이며, 브랜치가 추적하는 대상은 바뀌지 않습니다.

## 브랜치 게시하기 {#publish}

새 브랜치는 게시하기 전까지 내 저장소에만 있습니다. 게시하면 원격에 브랜치가 만들어집니다.

1. :ui[menu.repository > sync.publishMenu]를 선택하거나, 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[branch.publishMenu]{1="feature/station-map"}를 선택합니다. 사이드바에서 브랜치를 원격 위로 드래그해도 됩니다.
2. :ui[branch.local]와 :ui[sync.remote]을 확인합니다. :ui[branch.name]은 원격에서 쓸 이름이며, 처음에는 로컬 이름과 같습니다.
3. :ui[sync.setUpstream]은 내 브랜치가 새 원격 브랜치를 추적하게 해서, 이후의 풀과 푸시가 그곳으로 가게 합니다. 처음에는 켜져 있습니다.
4. 저장소의 Git 훅을 건너뛰려면 :ui[sync.skipHooks]를 선택합니다.
5. :ui[sync.publish]를 클릭합니다.

게시를 되돌리려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다.

## 동기화 {#sync}

동기화는 현재 브랜치에서 가져오기, 풀, 푸시를 차례로 실행합니다.

1. 도구 막대에서 :ui[sync.sync]를 클릭하거나 :ui[menu.repository > sync.syncMenu](<kbd>⇧⌘Y</kbd>)를 선택합니다.
2. :ui[sync.remoteBranch]에서 브랜치를 고릅니다. 처음에는 현재 브랜치의 업스트림입니다.
3. 원하면 :ui[sync.rebase]을 선택합니다. 아래의 미리 보기가 풀에서 충돌이 생길지 알려 줍니다.
4. 옵션을 설정합니다. :ui[merge.verify], :ui[sync.pushAllTags], :ui[sync.pushSubmodules], :ui[sync.skipHooks]는 풀과 푸시에서와 똑같이 동작합니다.
5. :ui[sync.syncHead]를 클릭합니다.

풀과 마찬가지로 Spooky가 추적 중인 파일의 변경 사항을 먼저 스태시하자고 제안합니다.

어느 단계가 실패하면 Spooky가 거기에서 멈추고, 어느 단계에서 멈췄는지와 어느 단계가 끝났는지 알려 줍니다. :ui[activity.title]에는 풀과 푸시가 각각 기록됩니다.

## 다른 곳으로 푸시하기 {#push-to}

브랜치, 태그 또는 커밋을 원격의 아무 브랜치나 참조로 푸시하려면 다음과 같이 합니다.

1. :ui[menu.repository > sync.pushToMenu]를 선택하거나, 브랜치를 오른쪽 클릭하고 메뉴에서 :ui[branch.pushToMenu]{1="main"}를 선택합니다. 태그의 메뉴에도 :ui[tag.pushToMenu]{1="v0.4.0"}가 있습니다.
2. :ui[sync.revision]에서 푸시할 것을, :ui[sync.remote]에서 원격을 고릅니다.
3. :ui[sync.refSpec]에 푸시할 곳을 입력합니다. 새 브랜치 이름이나 기존 브랜치 이름, 또는 `refs/tags/v0.4.0` 같은 전체 참조입니다.
4. :ui[sync.pushRevision]를 클릭합니다.

브랜치라면 대화상자는 브랜치가 추적하는 원격 브랜치로 시작합니다. 태그라면 `refs/tags/`와 태그 이름으로 시작합니다.

## 강제 푸시 {#force-push}

수정이나 리베이스 등으로 이미 푸시한 커밋을 다시 쓰고 나면 일반 푸시는 거부됩니다. 원격 브랜치에 내 브랜치에는 이제 없는 커밋이 있기 때문입니다. 강제 푸시는 원격 브랜치를 내 브랜치로 바꿉니다.

Spooky는 리스 기반으로만 강제 푸시합니다. 원격 브랜치가 마지막으로 가져왔을 때의 위치에 그대로 있을 때만 푸시가 이루어집니다. 그 사이에 누가 푸시했다면 Git이 거부하고 아무것도 덮어쓰지 않습니다. Spooky는 보호 없는 강제 푸시로 넘어가지 않습니다.

1. :ui[menu.repository > sync.forcePushMenu](<kbd>⌃⌘U</kbd>)를 선택하거나, 로컬 브랜치를 오른쪽 클릭하고 메뉴에서 선택합니다.
2. :ui[branch.target]에서 로컬 브랜치를, :ui[sync.destination]에서 원격 브랜치를 고릅니다.
3. 그 아래의 비교 결과를 읽습니다. 푸시가 원격 브랜치에 커밋을 몇 개 추가하고 몇 개를 덮어쓰는지 나옵니다. 그리고 다음과 같이 표시됩니다.
   - 초록색 줄은 원격 브랜치가 내 브랜치를 다시 쓰기 전의 버전에 있다는 뜻입니다. 보통은 이 경우입니다.
   - 노란색 줄은 원격 브랜치가 다른 곳에 있거나 내 브랜치에 있었던 적이 없는 커밋이 있다는 뜻입니다. 정말 덮어써도 되는지 확인합니다.
   - 두 브랜치가 같은 커밋에 있으면 푸시할 것이 없습니다.
4. :ui[sync.forcePush]를 클릭합니다.

::screenshot[리스 기반 강제 푸시 대화상자. 로컬 브랜치는 feature/units-toggle이고 원격 브랜치는 origin/feature/units-toggle입니다. 그 아래에 초록색 체크 표시가 있는 줄이 원격 브랜치가 이 브랜치를 다시 쓰기 전의 버전에 있다고 알려 줍니다.]{name="branches-force-push" frame="dialog" markers="16.4,67.5"}

1. 비교 결과

푸시 대화상자의 :ui[sync.forcePush] 옵션도 같은 보호를 사용합니다.

:::tip
:ui[menu.view > menu.customizeToolbar]를 선택하면 도구 막대에 :ui[toolbar.forcePush]와 :ui[toolbar.pushTo]를 추가할 수 있습니다.
:::

## 빠른 버전 {#quick}

<kbd>⌥</kbd>을 누르고 있으면 도구 막대의 :ui[sync.fetch], :ui[sync.pull], :ui[sync.push], :ui[sync.sync]가 :ui[sync.quickFetch], :ui[sync.quickPull], :ui[sync.quickPush], :ui[sync.quickSync]로 바뀝니다. 메뉴 항목도 같은 방식으로 바뀝니다. 예를 들면 :ui[sync.quickPushMenu]입니다.

빠른 버전은 대화상자 없이 곧바로 실행됩니다.

- 현재 브랜치의 업스트림을 대상으로 합니다.
- 대화상자에서 마지막으로 선택한 옵션을 사용합니다. :ui[sync.skipHooks]는 이어받지 않습니다.
- :ui[sync.quickFetch]는 현재 브랜치가 추적하는 원격을 가져옵니다. 마지막으로 :ui[sync.allRemotes]를 선택했거나 브랜치가 아무것도 추적하지 않으면 모든 원격을 가져옵니다.
- 현재 브랜치가 원격 브랜치를 추적하지 않으면 :ui[sync.quickPush]와 :ui[sync.quickSync]가 그렇다고 알려 줍니다.

오른쪽 클릭 메뉴에도 빠른 버전이 있습니다. 원격에는 :ui[sync.quickFetchNamed]{1="origin"}가, 원격 브랜치에는 :ui[sync.quickPullNamed]{1="origin/main"}이 있습니다.

## 자동으로 가져오기 {#auto-fetch}

Spooky는 백그라운드에서 가져와서 원격 브랜치와 ↓의 수를 최신으로 유지할 수 있습니다. :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch]에서 주기를 선택합니다. :ui[settings.autoFetch.never], 5분, 10분, 30분마다 또는 :ui[settings.autoFetch.hour] 중 하나입니다. 처음에는 30분마다입니다. [작업](/guide/settings/general/#operations)을 참고하세요.

- Spooky는 저장소를 열고 약 10초 뒤에, 그 뒤로는 몇 분마다 가져올 때가 된 원격을 찾습니다. 한 번도 가져온 적이 없거나 마지막으로 가져온 뒤 주기가 지난 원격이 대상입니다.
- 윈도우에 저장소가 표시되어 있고 열린 대화상자가 없을 때만 가져옵니다. Spooky가 백그라운드에 있어도 계속합니다.
- 저장소에서 다른 작업이 실행되고 있지 않을 때만 시작합니다. 가져오는 동안 다른 작업을 시작하면 가져오기가 멈추고 그 작업이 먼저 실행됩니다. :ui[activity.title]에 어느 작업 때문에 멈췄는지 기록됩니다.
- 암호를 묻지 않습니다. 실패하면 오류는 :ui[activity.title]에만 나타납니다.
- 가져오기 대화상자에서 마지막으로 선택한 정리 옵션과 하위 모듈 옵션을 사용하고, :ui[remote.skipFetchAll]로 설정한 원격은 건너뜁니다.
- 로컬 저장소에서는 Mac의 경로인 원격을 건너뛰고, Mac이 오프라인일 때는 가져오지 않습니다.

## 함께 보기

- [병합과 리베이스](/guide/branches/merge-rebase/)
- [브랜치](/guide/branches/branches/)
- [작업 대기열과 활동](/guide/advanced/queue-activity/)
- [스태시](/guide/work/stash/)

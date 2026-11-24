---
title: "일반, 업데이트, 환경"
description: "설정 윈도우의 구성을 살펴보고, 일반, 업데이트, 환경 페이지의 옵션을 설정합니다."
---

설정은 Spooky 전체에 적용됩니다. 대부분은 바꾸는 즉시 적용됩니다. 저장 버튼은 없습니다.

## 설정 윈도우 {#window}

:ui[app.name > settings.title](<kbd>⌘,</kbd>)을 선택합니다. 페이지는 윈도우 위쪽에 나열되어 있고, 제목에는 현재 페이지가 표시됩니다.

| 페이지 | 설정하는 것 | 설명하는 곳 |
|---|---|---|
| :ui[settings.general] | 복제, 백그라운드 작업, 확인 대화상자, 기록, 파일 목록, 윈도우 | [일반](#general) |
| :ui[settings.appearance] | 라이트 또는 다크, 앱 아이콘 | [모양과 테마](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | Git 프로그램, 전역 Git 커미터 신원, 서명, 외부 비교 및 병합 도구 | [사용자 프로필과 Git 구성](/guide/settings/identity/#git-config) |
| :ui[settings.text] | Diff와 파일의 구문 색상, 보이지 않는 문자, 탭 너비 | [모양과 테마](/guide/settings/appearance/#text) |
| :ui[settings.editor] | 커밋 메시지를 검사하고 줄을 바꾸는 방식 | [모양과 테마](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | Diff와 파일의 색상과 서체 | [모양과 테마](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | 커밋할 때 바꿔 가며 쓰는 커미터 신원 | [사용자 프로필과 Git 구성](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | GitHub와 GitLab 계정 | [호스팅 계정](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | 서버의 호스트 별칭. `~/.ssh/config`에 저장됩니다 | [SSH 준비하기](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | github.com의 링크, SSH 에이전트, 충돌 보고서 | [통합](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | 이 Mac의 Git에 쓰는 환경 변수, 서버 환경 확인 | [환경](#environment) |
| :ui[settings.updates] | Spooky가 스스로 업데이트하는 방식 | [업데이트](#updates) |

커미터 신원이나 서명처럼 저장소 하나에만 해당하는 설정은 개별 저장소 윈도우에 있습니다. [저장소 설정](/guide/settings/identity/#repository)을 참고하세요.

## 일반 {#general}

:ui[settings.general] 페이지는 긴 목록입니다. 아래의 섹션은 이 목록을 위에서 아래로 따라갑니다.

::screenshot[설정 윈도우의 일반 페이지. 복제 위치, 터미널 앱, 작업 및 확인 옵션, 기록 및 Diff 옵션, 파일 목록 옵션이 있습니다.]{name="settings-general" frame="window"}

### 복제와 터미널 {#cloning}

| 설정 | 하는 일 |
|---|---|
| :ui[settings.cloneDirectory] | 복제 대화상자가 새 저장소를 둘 곳으로 제안하는 위치입니다. 처음에는 홈 폴더입니다. `~/Development`가 있으면 메뉴에 함께 나옵니다. 다른 폴더를 고르려면 :ui[settings.cloneDirectory.select]을 선택합니다. |
| :ui[settings.terminal] | :ui[action.openTerminal]가 사용하는 앱입니다. [터미널](/guide/settings/integration/#terminal)을 참고하세요. |

### 작업 {#operations}

| 설정 | 기본값 | 하는 일 |
|---|---|---|
| :ui[settings.autoFetch] | 30분마다 | Spooky가 백그라운드에서 가져오기를 실행하는 주기입니다. [자동으로 가져오기](/guide/branches/sync/#auto-fetch)를 참고하세요. |
| :ui[stash.offerAutoStash] | 켬 | 로컬 변경 사항 때문에 작업이 막히면 먼저 스태시할지 묻습니다. [자동 스태시](/guide/work/stash/#auto-stash)를 참고하세요. |
| :ui[settings.autoUpdateSubmodules] | 끔 | 하위 모듈의 포인터를 옮기는 작업 뒤에, 체크아웃된 하위 모듈을 묻지 않고 업데이트합니다. [다른 작업 뒤에 업데이트하기](/guide/advanced/submodules/#auto-update)를 참고하세요. |
| :ui[branch.cleanNames] | 켬 | 입력하는 동안 브랜치, 태그, 원격의 이름을 Git에 맞게 고칩니다. [브랜치 만들기](/guide/branches/branches/#create)를 참고하세요. |
| :ui[settings.autoArchive] | 끔 | 끝난 것으로 보이는 브랜치를 보관합니다. [자동으로 보관하기](/guide/branches/review/#auto-archive)를 참고하세요. |

### 확인 대화상자 {#confirmations}

다음 질문에는 각각 :ui[dialog.doNotAskAgain]이 있습니다. 거기에서 선택하면 여기의 해당 설정이 꺼집니다. 질문을 다시 받으려면 설정을 다시 켭니다. 처음에는 네 가지 모두 켜져 있습니다.

| 설정 | 묻는 때 |
|---|---|
| :ui[settings.warnDiscardingChunks] | 어느 저장소에서든 블록이나 줄을 버리기 전. [변경 사항 버리기](/guide/work/diff/#discard)를 참고하세요. |
| :ui[settings.warnDiscardingOnServer] | 서버 저장소에서 파일 전체를 버리기 전 |
| :ui[settings.warnDeletingOnServer] | 휴지통이 없는 서버에서 파일을 완전히 삭제하기 전 |
| :ui[settings.warnRestoringOnServer] | 서버 저장소에서 리비전의 파일을 복원하기 전. [리비전에서 파일 복원하기](/guide/history/file-views/#restore)를 참고하세요. |

로컬 저장소에서는 파일 전체를 버릴 때 항상 묻습니다.

### 기록과 Diff {#history}

| 설정 | 기본값 | 하는 일 |
|---|---|---|
| :ui[history.pageSize] | 100 | 기록이 한 번에 불러오는 커밋 수: 100, 200, 500, 1,000 |
| :ui[settings.dateFormat] | 절대 | 절대 날짜는 26. 10. 26.처럼 짧습니다. 상대 날짜는 오늘과 어제를 “오늘”, “어제”로 쓰고 다른 날짜는 전체를 풀어 씁니다. 메뉴에 각각의 예가 나옵니다. |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | 병합 커밋의 변경 세트가 보여 주는 내용입니다. [변경 세트](/guide/history/commit-details/#changeset)를 참고하세요. |
| :ui[working.diffThreshold] | 20,000 | Diff가 이 킬로바이트 수보다 크면 표시하기 전에 묻습니다. 값을 고르거나 입력합니다. [Diff 읽기](/guide/work/diff/#read)를 참고하세요. |

날짜 형식은 기록, 스태시, 파일 기록, Reflog에 적용됩니다.

### 파일 목록 {#file-list}

| 설정 | 기본값 | 하는 일 |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | 또는 파일을 비교 도구에서 엽니다 |
| :ui[files.openSubmodules] | 켬 | 하위 모듈을 이중 클릭하면 다른 앱이 아니라 Spooky에서 엽니다 |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | 또는 파일을 훑어보기로 표시합니다 |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | 또는 :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | 또는 긴 이름의 가운데를 줄입니다 |

작업 사본에서 이 설정이 어떻게 동작하는지는 [파일 목록 설정](/guide/work/working-copy/#settings)을 참고하세요.

### 윈도우와 저장소 목록 {#windows}

| 설정 | 기본값 | 하는 일 |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | Spooky가 시작할 때 다시 여는 것입니다. [하던 곳에서 이어 가기](/guide/repositories/navigation/#restore)를 참고하세요. |
| :ui[settings.showLaunchWindow] | 끔 | Spooky가 시작할 때 최근 저장소가 있는 윈도우를 표시합니다 |
| :ui[settings.showWorktreesInRepositoryList] | 끔 | 저장소 목록에 각 저장소의 작업 트리를 나열합니다 |
| :ui[settings.showHostAliasesInRepositoryList] | 켬 | 저장소 목록에 각 서버 저장소의 호스트 별칭을 표시합니다 |
| :ui[settings.showDeveloperMenu] | 끔 | Spooky 자체를 테스트하는 도구가 있는 :ui[menu.developer] 메뉴를 추가합니다 |

## 업데이트 {#updates}

:ui[settings.updates] 페이지에서 릴리스 채널, Spooky가 스스로 업데이트를 확인하고 다운로드할지 여부, 확인 주기를 설정합니다. 각 옵션은 [Spooky를 최신 상태로 유지하기](/guide/start/install/#updates)에서 설명합니다.

## 환경 {#environment}

Finder나 Dock에서 연 앱은 터미널에서 쓰는 환경을 받지 못합니다. 예를 들어 `PATH`에 `/opt/homebrew/bin` 같은 폴더가 빠져 있을 수 있습니다. 그러면 Git 훅, 자격 증명 도우미, Git LFS를 찾지 못할 수 있습니다. :ui[settings.environment] 페이지에서 이 Mac의 Git에 대해 이 문제를 해결합니다.

### 이 Mac의 변수 {#local-variables}

| 설정 | 하는 일 |
|---|---|
| :ui[settings.environment.loginShell] | 로그인 셸을 한 번 시작해 시작 파일이 설정하는 변수를 읽고 Git에 전달합니다. 아래의 표에 읽은 내용이 나옵니다. 처음에는 켜져 있습니다. |
| :ui[settings.environment.custom] | 직접 추가하는 변수입니다. 추가 버튼으로 추가하고, 제거 버튼으로 선택한 변수를 제거합니다. 로그인 셸의 변수보다 우선합니다. |

알아 둘 점은 다음과 같습니다.

- 변경 내용은 다음 Git 명령부터 적용됩니다. Spooky를 재시작할 필요가 없습니다.
- 로그인 셸은 Spooky가 시작할 때마다 다시 읽습니다. 읽기에 실패하면 페이지에서 알려 줍니다.
- 사용자 지정 변수 두 개의 이름이 같으면 아래에 있는 것이 적용됩니다. 이름이 올바르지 않은 변수는 표에 남지만 Git에 전달되지 않습니다.
- 시스템 에이전트가 아닌 SSH 에이전트를 쓰려면 여기 또는 로그인 셸에서 `SSH_AUTH_SOCK`을 설정합니다. [SSH 에이전트](/guide/settings/integration/#ssh-agent)를 참고하세요.

:::note[서버 저장소]
이 변수는 이 Mac의 Git에만 적용됩니다. 서버의 Git은 서버의 환경을 사용합니다.
:::

### 서버 확인하기 {#server-check}

페이지 아래쪽에서는 저장소를 추가하지 않고도 서버에서 Git이 받는 환경을 볼 수 있습니다.

1. :ui[remote.host] 필드에 호스트 별칭을 입력합니다. :ui[settings.environment.server.hosts] 메뉴에서 골라도 됩니다. 이 메뉴에는 서버 저장소의 서버가 나옵니다.
2. :ui[settings.environment.server.check]을 클릭합니다.

::screenshot[설정의 환경 페이지 아래쪽에 있는 서버 확인. 호스트 별칭을 확인한 결과로 서버에서 찾은 Git과 그 버전이 표시되어 있습니다.]{name="settings-environment" frame="closeup"}

결과에는 SSH 로그인에서 찾은 Git과 그 버전이 표시되거나 :ui[settings.environment.server.noGit]이 표시됩니다. 그 아래에는 `PATH`의 각 폴더와, 이름이 `GIT_`로 시작하는 변수의 이름이 나옵니다. Git을 찾을 수 없으면 [서버에서 Git을 찾을 수 없음](/reference/troubleshooting/#server-path)을 참고하세요.

## 함께 보기

- [모양과 테마](/guide/settings/appearance/)
- [사용자 프로필과 Git 구성](/guide/settings/identity/)
- [통합](/guide/settings/integration/)
- [Spooky 설치하기](/guide/start/install/)

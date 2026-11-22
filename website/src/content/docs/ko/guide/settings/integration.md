---
title: "통합"
description: "외부 비교 및 병합 도구, 편집기, 터미널을 고르고 Finder와 함께 쓰는 방법을 알아봅니다."
---

Spooky는 Mac의 다른 앱과 함께 동작합니다. 브라우저, 비교 및 병합 앱, 편집기, 터미널, Finder입니다. 이 페이지는 각각을 어디에서 설정하는지 보여 줍니다.

## 통합 페이지 {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration]에는 설정이 세 가지 있습니다.

### github.com의 링크 {#github-links}

github.com에서 저장소를 데스크탑 앱으로 여는 버튼은 Mac으로 링크를 보냅니다. :ui[settings.github]에서 어느 앱이 그 링크를 받을지 정합니다. 메뉴에는 Mac에서 이런 링크를 열 수 있는 앱이 나옵니다.

Spooky를 선택하면 이런 링크가 복제 대화상자를 엽니다. [저장소 복제하기](/guide/repositories/navigation/#link-clone)를 참고하세요.

### SSH 에이전트 {#ssh-agent}

SSH 에이전트는 잠금이 풀린 키를 바로 쓸 수 있게 보관합니다. Spooky는 SSH로 서버와 원격에 로그인할 때, 그리고 SSH 키로 커밋에 서명할 때 에이전트를 사용합니다.

:ui[settings.sshAgent]에는 선택지가 :ui[settings.sshAgent.system] 하나뿐입니다. Spooky는 다음 순서로 에이전트를 찾습니다.

1. :ui[settings.environment] 페이지에서 직접 추가한 변수의 `SSH_AUTH_SOCK`([이 Mac의 변수](/guide/settings/general/#local-variables) 참고)
2. 로그인 셸의 `SSH_AUTH_SOCK`. 그 페이지에서 로그인 셸 읽기가 켜져 있을 때입니다
3. macOS가 시작해 주는 에이전트

암호 관리자에 딸린 에이전트 같은 다른 에이전트를 쓰려면 :ui[settings.environment] 페이지 또는 로그인 셸에서 `SSH_AUTH_SOCK`을 설정합니다.

에이전트가 실행 중이 아니면 메뉴 옆에 노란색 경고 버튼이 나타납니다. 클릭하면 무엇을 해야 하는지 볼 수 있습니다.

:::note[서버 저장소]
Spooky는 에이전트를 서버로 전달하지 않습니다. 서버의 Git은 그 컴퓨터의 에이전트와 키를 사용합니다.
:::

### 충돌 보고서 {#crash-reports}

지난번에 Spooky가 예기치 않게 종료되었으면 다음에 실행할 때 충돌을 보고할지 묻습니다. :ui[settings.crashReports.always]를 선택하면 묻지 않고 바로 이슈 페이지를 엽니다. 처음에는 꺼져 있습니다.

보고서에 들어가는 내용은 [충돌 보고서](/reference/data-privacy/#crash-reports)를 참고하세요.

## 비교 및 병합 도구 {#diff-merge-tools}

도구는 :ui[settings.gitConfig] 페이지에서 설정합니다.

| 설정 | 하는 일 |
|---|---|
| :ui[externalTool.diffTool] | 파일을 비교하는 앱입니다. 처음에는 :ui[externalTool.noneSelected]입니다. |
| :ui[externalTool.directoryDiff] | 파일 여러 개를 비교할 때 한 윈도우에서 두 폴더로 엽니다. Kaleidoscope만 지원합니다. 다른 앱은 파일을 하나씩 엽니다. 처음에는 켜져 있습니다. |
| :ui[externalTool.mergeTool] | 충돌을 해결하는 앱입니다. 처음에는 :ui[externalTool.noneSelected]입니다. |
| :ui[externalTool.keepBackups] | 병합 전의 파일을 이름 끝에 `.orig`를 붙여 옆에 남깁니다. 처음에는 꺼져 있습니다. |

Spooky는 다음 앱과 함께 동작합니다.

| 앱 | 비교 | 병합 |
|---|---|---|
| Araxis Merge | 예 | 예 |
| BBEdit | 예 | 아니요 |
| Beyond Compare | 예 | 예 |
| DeltaWalker | 예 | 예 |
| FileMerge | 예 | 예 |
| Kaleidoscope | 예 | 예 |
| P4Merge | 예 | 예 |
| TextMate | 예 | 아니요 |
| Visual Studio Code | 예 | 예 |

메뉴에는 설치되지 않은 앱도 나오지만 선택할 수는 없습니다. 도구를 고르기 전에 사용하면 Spooky가 어느 앱을 쓸지 묻습니다.

사용 방법은 [다른 앱에서 비교하기](/guide/work/diff/#external)와 [다른 앱에서 병합하기](/guide/work/conflicts/#merge-tool)를 참고하세요.

## 편집기 {#editors}

Spooky에는 편집기 설정이 따로 없습니다. 파일을 다른 앱에서 열려면 작업 사본에서 오른쪽 클릭하고 :ui[files.open] 또는 :ui[files.openWith]를 선택합니다. :ui[files.openWith] 하위 메뉴에는 그 파일을 열 수 있는 앱이 나오고, 기본 앱이 맨 앞에 있습니다. 같은 하위 메뉴가 커밋의 파일 트리와 충돌 마법사에도 있습니다.

서버 저장소에서 Visual Studio Code, Visual Studio Code Insiders, Cursor는 Remote SSH 확장 프로그램이 설치되어 있으면 서버의 파일을 직접 엽니다. 다른 앱은 사본을 받습니다. 저장하면 Spooky가 변경 내용을 서버에 다시 씁니다. [터미널과 다른 앱](/guide/server/local-location/#terminal)을 참고하세요.

## 터미널 {#terminal}

:ui[settings.general] 페이지의 :ui[settings.terminal]에서 :ui[action.openTerminal]에 쓸 앱을 고릅니다. Spooky는 터미널, iTerm, Warp, Ghostty, WezTerm, Otty와 함께 동작합니다. 메뉴에는 설치된 앱이 나옵니다. 처음에는 터미널을 사용합니다.

:ui[action.openTerminal]는 다음 위치에 있습니다.

- :ui[menu.file] 메뉴
- 도구 막대의 :ui[toolbar.terminal]
- 사이드바에 있는 작업 사본의 메뉴
- 작업 사본 파일 목록에 있는 파일이나 폴더의 메뉴. 터미널이 그 폴더에서, 또는 파일이 들어 있는 폴더에서 열립니다.
- 저장소 윈도우에 있는 저장소의 메뉴와 최근 복제한 항목의 메뉴
- 사이드바에 있는 작업 트리의 메뉴
- [빠른 동작](/guide/repositories/navigation/#quick-actions)

로컬 저장소에서는 터미널이 이 Mac의 폴더에서 열립니다. 서버 저장소에서는 SSH로 로그인해 서버의 폴더로 이동합니다. [터미널과 다른 앱](/guide/server/local-location/#terminal)을 참고하세요.

Spooky가 터미널이나 iTerm을 처음 열 때 macOS가 Spooky의 제어를 허용할지 묻습니다. 허용하지 않으면 Spooky가 :ui[error.terminal]을 표시합니다. 나중에 허용하려면 **Apple 메뉴 › 시스템 설정 › 개인정보 보호 및 보안 › 자동화**로 이동해 Spooky 아래의 앱을 켭니다.

## Finder {#finder}

- **폴더 보기**: :ui[action.revealFinder]는 저장소 폴더나 파일을 Finder에 표시합니다. 서버 저장소에서는 이 Mac의 위치가 필요합니다. [Finder에서 보기](/guide/server/local-location/#show-in-finder)를 참고하세요.
- **저장소 추가하기**: Finder에서 저장소 폴더를 저장소 윈도우로 드래그합니다. [저장소 추가하기](/guide/repositories/manager/#add)를 참고하세요.
- **Dock**: Spooky 아이콘에 폴더를 놓으면 그 폴더가 들어 있는 저장소가 열립니다. 아이콘을 오른쪽 클릭하면 서버 저장소를 포함한 최근 저장소를 선택할 수 있습니다. [최근 저장소와 Dock](/guide/repositories/navigation/#recent)을 참고하세요.
- **테마**: Finder에서 `.spookytheme` 파일을 열면 테마가 추가됩니다. [테마 공유하기](/guide/settings/appearance/#share-themes)를 참고하세요.

## 함께 보기

- [일반, 업데이트, 환경](/guide/settings/general/)
- [사용자 프로필과 Git 구성](/guide/settings/identity/)
- [이 Mac의 위치](/guide/server/local-location/)
- [SSH 준비하기](/guide/server/prepare-ssh/)

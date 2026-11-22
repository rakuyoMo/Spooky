---
title: "윈도우와 탐색"
description: "윈도우와 탭을 다루고, 뒤로 및 앞으로 이동하고, 빠른 동작을 쓰고, 윈도우를 복원하고, Dock 메뉴를 쓰고, spooky:// 링크를 여는 방법을 알아봅니다."
---

이 페이지는 Spooky 안에서 이동하는 방법을 다룹니다. 저장소를 여러 개 열어 두는 방법, 보기 사이를 오가는 방법, 빠른 동작으로 어디로든 이동하는 방법, 하던 곳으로 돌아오는 방법을 알아봅니다.

## 윈도우와 탭 {#windows}

각 윈도우나 탭은 저장소 보기 또는 저장소 하나를 보여 줍니다.

- :ui[menu.file > menu.newTab](<kbd>⌘T</kbd>)은 저장소 보기가 있는 새 탭을 엽니다. 탭 막대 끝의 추가 버튼도 같은 일을 합니다.
- :ui[menu.file > menu.newWindow](<kbd>⌘N</kbd>)는 저장소 보기가 있는 새 윈도우를 엽니다.
- :ui[menu.view > menu.showRepositories](<kbd>⌃⌘R</kbd>)는 현재 윈도우에 저장소 보기를 표시합니다.

저장소가 이미 열려 있으면, 다시 열 때 그 저장소를 보여 주는 윈도우로 전환됩니다. 그래도 두 번째 윈도우에서 열려면 저장소 목록에서 오른쪽 클릭하고 :ui[bookmarks.openNewWindow]{1="driftwood"}를 선택합니다.

### 보기 전환하기 {#views}

:ui[menu.view] 메뉴에서 저장소의 보기를 전환합니다.

| 단축키 | 메뉴 항목 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title](<kbd>⌃⌘0</kbd>)은 활동 윈도우를 엽니다. Spooky가 실행했거나 실행 중인 작업이 나열됩니다. [작업 대기열과 활동](/guide/advanced/queue-activity/)을 참고하세요.

## 뒤로 및 앞으로 이동하기 {#back-forward}

각 윈도우는 저장소 보기를 포함해 방문한 보기와 저장소를 기억합니다. 지나온 길을 되짚으려면 다음을 사용합니다.

- :ui[menu.view > navigation.back](<kbd>⌘[</kbd>) 또는 도구 막대의 :ui[toolbar.previous]
- :ui[menu.view > navigation.forward](<kbd>⌘]</kbd>) 또는 도구 막대의 :ui[toolbar.next]

뒤로 간 다음 새로운 것을 열면, 앞으로 갈 수 있던 위치는 사라집니다.

## 빠른 동작 {#quick-actions}

빠른 동작을 쓰면 입력해서 무언가를 찾고, 키보드에서 손을 떼지 않고 그 항목에 동작을 실행할 수 있습니다. 저장소가 표시되어 있는 동안 사용할 수 있습니다. :ui[menu.file > quickActions.menu](<kbd>⇧⌘A</kbd>)을 선택하거나 도구 막대의 :ui[toolbar.quickActions]을 클릭합니다.

::screenshot[개별 저장소 윈도우 위에 열린 빠른 동작. “dark”가 입력되어 있습니다. 첫 번째 결과인 브랜치 feature/dark-mode가 선택되어 있고, 기본 동작과 더 많은 동작에 대한 안내가 표시됩니다. 그 아래에 원격 브랜치 origin/feature/dark-mode, 어두운 모양, Default (Dark) 테마, 메시지에 dark가 들어간 커밋 두 개가 있습니다.]{name="quick-actions" frame="window"}

아무것도 입력하지 않으면 패널에 저장소의 보기가 나오고, 이어서 브랜치(현재 브랜치가 맨 앞), 작업 트리, 원격, 하위 모듈, 원격 브랜치, 태그, 스태시, 사용자 프로필, 모양과 테마가 나옵니다. 입력하면 목록이 좁혀집니다. Spooky는 다음도 찾습니다.

- 현재 브랜치에서 이름이 일치하는 파일
- 커밋 해시의 16진수 문자 5–64개를 입력했을 때 그 커밋
- 현재 브랜치에서 메시지에 입력한 텍스트가 들어 있는 커밋(최대 100개)

파일과 커밋은 입력을 멈추고 잠시 뒤에 목록 끝에 나타납니다.

패널에서는 다음 키를 사용합니다.

| 키 | 하는 일 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 선택을 이동합니다 |
| <kbd>↩</kbd> | 선택한 항목의 기본 동작을 실행합니다 |
| <kbd>Tab</kbd>, 또는 텍스트 끝에서 <kbd>→</kbd> | 선택한 항목의 모든 동작을 나열합니다 |
| 텍스트가 없을 때 <kbd>←</kbd>, 또는 <kbd>⇧Tab</kbd> | 동작 목록에서 돌아갑니다 |
| <kbd>Esc</kbd> | 텍스트를 지웁니다. 텍스트가 없으면 동작 목록에서 돌아가거나 패널을 닫습니다 |

지금 실행할 수 있는 동작만 나열됩니다.

## 하던 곳에서 이어 가기 {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration]에서 Spooky가 시작할 때 무엇을 보여 줄지 정합니다.

| 선택 | Spooky가 시작할 때 |
|---|---|
| :ui[settings.windowRestoration.always] | 윈도우와 탭을 다시 엽니다. 각각 종료할 때 보여 주던 저장소와 보기를 표시합니다. |
| :ui[settings.windowRestoration.never] | 저장소 윈도우만 표시합니다 |
| :ui[settings.windowRestoration.system] | 앱을 종료할 때 윈도우를 유지할지에 관한 macOS 설정을 따릅니다. 기본값입니다. |

복원된 저장소를 더 이상 찾을 수 없으면 그 윈도우에 저장소가 사라졌다고 표시됩니다. [사라진 저장소](/guide/repositories/manager/#missing)를 참고하세요.

:ui[settings.showLaunchWindow]를 켜면 시작할 때 최근 저장소를 나열하는 윈도우가 나타납니다. 저장소를 이중 클릭하거나, 선택하고 <kbd>↩</kbd>을 눌러 엽니다. 개별 저장소 윈도우가 앞으로 나오면 이 윈도우는 저절로 닫힙니다. 두 설정 모두 [윈도우와 저장소 목록](/guide/settings/general/#windows)을 참고하세요.

:::note[서버 저장소]
복원된 서버 저장소는 Spooky가 시작할 때 서버에 다시 연결합니다.
:::

## 최근 저장소와 Dock {#recent}

:ui[menu.file > menu.openRecent]에는 Mac과 서버에서 최근에 연 저장소가 나열됩니다. 맨 아래의 :ui[menu.clearRecent]는 목록을 비웁니다. 저장소 윈도우의 북마크는 그대로 남습니다.

**Dock**에서 Spooky 아이콘을 오른쪽 클릭하면 :ui[menu.newWindow]와 최근 저장소가 있는 메뉴가 나옵니다. 저장소를 선택하면 열립니다. Spooky가 아직 실행 중이 아니어도 됩니다.

Dock의 Spooky 아이콘에 폴더를 놓아서 그 폴더가 들어 있는 저장소를 열 수도 있습니다. 폴더가 Git 저장소 안에 있지 않으면 Spooky가 저장소를 만들지 묻습니다.

## 링크로 Spooky 열기 {#links}

`spooky://`로 시작하는 링크는 저장소나 복제를 엽니다. 이런 링크를 다른 앱, 스크립트, 메모에 넣어 둘 수 있습니다.

### 저장소 열기 {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository`는 필수입니다. Mac에 있는 저장소의 절대 경로이거나, 서버 저장소라면 `alias:path`이며, URL 인코딩합니다.
- `view`는 선택 사항입니다. 없으면 저장소가 마지막에 보여 주던 보기로 열립니다.
- `view` 대신 쓰는 줄임 표기가 두 가지 있습니다. `branch=<name>`은 그 브랜치의 기록을 열고, `commit=<hash>`는 그 커밋을 엽니다.

| `view` | 여는 것 | 추가 매개변수 |
|---|---|---|
| `workingCopy` | 작업 사본 | |
| `history` | 기록 | `ref=<reference>`. `refs/heads/main` 같은 전체 참조 이름이며 여러 번 쓸 수 있습니다 |
| `commit` | 커밋 | `commit=<hash>` |
| `stashes` | 스태시 | |
| `reflog` | Reflog | |
| `pullRequests` | 풀 리퀘스트 또는 머지 리퀘스트 | |
| `branchesReview` | 브랜치 검토 | |
| `settings` | 저장소 설정 | |
| `remote` | 원격 | `remote=<name>` |
| `submodule` | 하위 모듈 | `path=<path>` |
| `worktree` | 작업 트리 | `path=<path>` |
| `fileHistory` | 파일의 기록 | `path=<path>` |
| `file` | 파일 | `path=<path>`. 선택적으로 `revision=<revision>`과 `mode=blame` 또는 `mode=raw` |

예를 들어 다음 링크는 `/Volumes/Projects/driftwood`에 있는 저장소에서 `main` 브랜치의 기록을 엽니다.

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### 저장소 복제하기 {#link-clone}

```
spooky://clone?url=<address>
```

주소가 채워진 복제 대화상자가 열립니다. 저장할 위치를 고르고 :ui[clone.submit]를 클릭하기 전에는 아무것도 복제되지 않습니다. [저장소 복제하기](/guide/repositories/manager/#clone)를 참고하세요.

:ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github]를 Spooky로 설정하면, github.com에서 저장소를 데스크탑 앱으로 여는 링크도 이 복제 대화상자를 엽니다. [github.com의 링크](/guide/settings/integration/#github-links)를 참고하세요.

알 수 없는 보기를 지정하거나 상대 경로를 쓴 링크처럼 사용할 수 없는 링크도 있습니다. 이런 링크는 Spooky가 :ui[link.invalid.title]을 표시할 뿐 다른 일은 하지 않습니다.

## 함께 보기

- [Spooky 둘러보기](/guide/start/tour/)
- [저장소 윈도우](/guide/repositories/manager/)
- [키보드 단축키](/reference/shortcuts/)

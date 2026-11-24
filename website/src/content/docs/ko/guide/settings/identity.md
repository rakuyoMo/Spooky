---
title: "사용자 프로필과 Git 구성"
description: "사용자 프로필과 Git 구성을 관리하고, 저장소 하나의 설정을 조정합니다."
---

Git은 모든 커밋에 이름과 이메일을 기록하고, 키로 서명할 수도 있습니다. Spooky에서는 세 곳에서 이를 설정합니다.

- :ui[app.name > settings.title]의 :ui[settings.profiles]에는 바꿔 가며 쓰는 커미터 신원을 보관합니다.
- :ui[app.name > settings.title]의 :ui[settings.gitConfig]에서는 Git 프로그램과 전역 커미터 신원, 서명을 설정합니다.
- 저장소 하나의 설정은 그 저장소에서 전역 설정보다 우선합니다.

## 사용자 프로필 {#profiles}

사용자 프로필은 이름, 이메일, 선택 사항인 서명 키를 “Work” 같은 제목으로 저장한 것입니다. Spooky는 프로필을 이 Mac에 보관합니다. 로컬 저장소와 서버 저장소 모두에서 쓸 수 있습니다.

프로필을 추가하려면 다음과 같이 합니다.

1. :ui[app.name > settings.title] › :ui[settings.profiles]을 선택합니다.
2. 목록 아래의 추가 버튼을 클릭합니다.
3. :ui[profiles.title], :ui[profiles.userName], :ui[profiles.email] 필드를 채웁니다. 원하면 이 Mac에서 찾은 키 중에서 :ui[profiles.signingKey]를 선택합니다.
4. :ui[profiles.create.submit]을 클릭합니다.

제목, 사용자 이름, 이메일은 필수입니다. 두 프로필이 같은 제목을 쓰거나, 사용자 이름과 이메일이 모두 같을 수는 없습니다.

프로필을 바꾸려면 선택하고 :ui[profiles.edit]을 클릭합니다. 삭제하려면 선택하고 제거 버튼을 클릭합니다. 프로필을 삭제해도 Git 설정은 바뀌지 않습니다.

지금 쓰는 커미터 신원이 아직 프로필이 아니면 그 메뉴에서 :ui[profiles.addCurrent]{1="alex@example.com"}를 선택합니다. 제목을 입력하고 :ui[profiles.add.submit]를 클릭합니다.

### 프로필 사용하기 {#use-profile}

커미터 신원 옆의 사진을 클릭하면 프로필이 나오고, 사용 중인 프로필 옆에 체크 표시가 있습니다. 프로필을 선택했을 때 무엇이 바뀌는지는 선택한 곳에 따라 다릅니다.

| 위치 | 바뀌는 것 | 먼저 묻는지 |
|---|---|---|
| 커밋 영역, 또는 [저장소 설정](#repository)의 :ui[bookmarks.detail.identity] | 이 저장소 자체의 Git 설정. [커밋하는 사람 고르기](/guide/work/commit/#identity)를 참고하세요. | 예 |
| 설정의 :ui[settings.gitConfig] | 이 Mac의 전역 Git 설정 | 아니요 |

프로필의 이름과 이메일은 `user.name`과 `user.email`에 기록됩니다. 서명 키가 있는 프로필은 `user.signingkey`와 `gpg.format`도 설정합니다.

[빠른 동작](/guide/repositories/navigation/#quick-actions)에도 프로필이 나옵니다. :ui[quickActions.setCommitter]은 커밋 영역과 같은 방식으로 동작합니다. :ui[quickActions.setGlobalUser]은 먼저 물은 다음, 저장소가 있는 컴퓨터의 전역 Git 설정에 이름과 이메일을 설정합니다.

:::note[서버 저장소]
서버 저장소에서 프로필을 선택하면 서버에 있는 저장소의 설정이 바뀝니다. 거기에서 커밋하는 다른 도구도 같은 커미터 신원을 사용합니다. 서버 저장소에서 :ui[quickActions.setGlobalUser]은 서버의 전역 설정에 씁니다.
:::

## Git 구성 {#git-config}

:ui[settings.gitConfig] 페이지는 네 부분으로 되어 있습니다. Git 프로그램, 커미터 신원, 서명, 외부 도구입니다. 도구는 [통합](/guide/settings/integration/#diff-merge-tools)에서 설명합니다.

::screenshot[설정 윈도우의 Git 구성 페이지. Git 프로그램, 전역 이름과 이메일, 서명 설정, 비교 및 병합 도구가 있습니다.]{name="settings-git-config" frame="window" markers="20,16.7 20,29.4 20,44.6 20,82.5"}

1. Git 프로그램
2. 커미터 신원
3. 서명
4. 외부 도구

### Git 프로그램 {#git-program}

:ui[settings.gitProgram]에는 이 Mac에 있는 Git 프로그램 중 버전이 충분히 높은 것이 버전과 함께 나옵니다. Spooky는 일반적인 위치를 살펴봅니다. `/usr/bin/git`(시스템의 것으로 표시되며 처음에 사용됨), Command Line Tools, Xcode, Homebrew, MacPorts입니다.

목록에 없는 Git을 쓰려면 :ui[settings.gitProgram.choose]을 선택하고 프로그램을 고릅니다. 파일이 Git이 아니거나 버전이 너무 낮으면 Spooky가 이유를 알려 주고 원래 쓰던 것을 유지합니다. 메뉴 아래의 줄에 Spooky가 받아들이는 최소 버전이 표시됩니다.

:::note[서버 저장소]
이 설정은 로컬 저장소에만 적용됩니다. 서버 저장소는 서버의 Git을 사용합니다. [시스템 요구 사항](/reference/requirements/#servers)을 참고하세요.
:::

### 전역 커미터 신원 {#global-identity}

:ui[gitConfig.userName]과 :ui[gitConfig.email]은 Git의 전역 `user.name`과 `user.email`입니다. 이 Mac의 모든 저장소가 이 값을 사용합니다. 자체 값이 있는 저장소는 예외입니다.

변경 내용은 <kbd>Return</kbd>을 누르거나 필드를 벗어날 때 저장됩니다. 필드를 비우면 설정이 제거됩니다. 아래의 줄에 어느 파일에 저장되는지 표시됩니다. 보통 `~/.gitconfig`입니다.

오른쪽의 사진을 클릭하면 [프로필](#use-profile)을 선택하거나 관리할 수 있습니다.

### 서명 {#signing}

이 설정은 이 Mac에서 자체 설정이 없는 모든 저장소에서 Git이 커밋에 서명하는 방식을 정합니다.

| 설정 | 하는 일 |
|---|---|
| :ui[gitConfig.sshProgram] | SSH 키로 서명하는 프로그램입니다. 처음에는 :ui[gitConfig.sshProgram.system]을 사용합니다. 1Password가 설치되어 있으면 그 서명 프로그램도 나옵니다. |
| :ui[gitConfig.gpgProgram] | OpenPGP 키에 쓰는 GnuPG 프로그램입니다. 이 Mac에 있는 것 중 버전이 충분히 높은 것이 나옵니다. 다른 것을 고르려면 :ui[gitConfig.gpgProgram.select]을 선택합니다. |
| :ui[gitConfig.signingKey] | 서명에 쓸 키입니다. GnuPG 키링의 비밀 키 또는 SSH 에이전트에 로드된 키입니다. 키를 선택하면 OpenPGP와 SSH 중 무엇으로 서명할지도 Git에 알려 줍니다. |
| :ui[gitConfig.allowedSigners] | 서명을 신뢰하는 SSH 키가 적힌 파일입니다. Git이 서명을 확인할 때 사용합니다. `~/.ssh/allowed_signers`를 선택하거나, 다른 파일을 고르거나, :ui[gitConfig.allowedSigners.none]을 선택합니다. |
| :ui[gitConfig.signCommits] | 모든 커밋에 서명합니다 |
| :ui[gitConfig.ensureEmailMatch] | OpenPGP 키의 이메일이 전역 이메일과 다르면 경고합니다. 처음에는 켜져 있습니다. |

실행할 수 없는 서명 프로그램처럼 살펴봐야 할 것이 있으면 설정 옆에 노란색 경고 버튼이 나타납니다. 클릭하면 무엇이 문제인지 볼 수 있습니다.

서명된 커밋과 암호문 입력 요청은 [커밋에 서명하기](/guide/work/commit/#signing)에서 설명합니다.

## 저장소 설정 {#repository}

저장소마다 자체 설정이 있습니다. 보려면 사이드바의 :ui[workspace.group] 아래에서 :ui[repositorySettings.title]을 클릭합니다. 위쪽의 버튼으로 네 섹션을 전환합니다.

변경 내용은 저장소 자체의 Git 설정에 기록되고, 저장소의 다른 작업과 함께 차례를 기다립니다. 저장소가 설정하지 않은 것은 전역 설정에서 가져옵니다.

::screenshot[주 윈도우의 저장소 설정. 일반 탭에 저장소의 이름, 경로, 설명, 커미터 신원, 서명 설정이 있습니다.]{name="settings-repository" frame="window" markers="79.2,9.8 60,38.8"}

1. 섹션을 전환하는 버튼
2. :ui[bookmarks.detail.identity]

### 일반 {#repository-general}

| 항목 | 보여 주는 것 |
|---|---|
| :ui[repositorySettings.name]과 :ui[repositorySettings.path] | 저장소가 있는 위치 |
| :ui[repositorySettings.localLocation] | 서버 저장소의 경우, 저장소의 폴더가 이 Mac의 어디에 있는지. [위치 설정하기](/guide/server/local-location/#set)를 참고하세요. |
| :ui[bookmarks.detail.description] | 저장소의 설명. [저장소 윈도우](/guide/repositories/manager/)에도 표시됩니다. 바꾸려면 :ui[bookmarks.detail.edit]을 클릭합니다. |
| :ui[bookmarks.detail.identity] | 이 저장소가 커밋할 때 쓰는 이름과 이메일. 사진을 클릭해 [프로필](#use-profile)을 사용하거나, :ui[bookmarks.detail.edit]을 클릭해 이 저장소에만 쓸 이름과 이메일을 입력합니다. |

:ui[repositorySettings.signing] 아래의 :ui[repositorySettings.signCommits], :ui[repositorySettings.signingKey], :ui[repositorySettings.allowedSigners]은 [전역 설정](#signing)과 같은 방식으로 동작하되 이 저장소에만 적용됩니다.

### Git LFS, 무시, 제외 {#repository-files}

- :ui[repositorySettings.lfs]에는 Git LFS 버전과 :ui[repositorySettings.lfs.patterns]이 표시됩니다. [Git LFS](/guide/advanced/lfs/)를 참고하세요.
- :ui[repositorySettings.ignores]에는 저장소 최상위에 있는 `.gitignore`의 규칙이 나옵니다. 이 파일을 커밋하면 다른 사람과 규칙을 공유합니다.
- :ui[repositorySettings.excludes]에는 Git의 `info/exclude`에 있는 규칙이 나옵니다. 저장소의 이 사본에만 적용됩니다.

규칙을 바꾸려면 :ui[repositorySettings.openInEditor]를 클릭합니다. 파일은 Mac에서 그 파일에 쓰는 앱으로 열립니다. 파일이 아직 없으면 Spooky가 먼저 만듭니다.

:::note[서버 저장소]
설정은 서버에서 읽고 씁니다. 저장소가 연결되어 있는 동안에만 바꿀 수 있습니다. :ui[repositorySettings.openInEditor]는 작업 사본이 서버의 파일을 여는 것과 같은 방식으로 파일을 엽니다. [터미널과 다른 앱](/guide/server/local-location/#terminal)을 참고하세요.
:::

## 함께 보기

- [변경 사항 커밋하기](/guide/work/commit/)
- [일반, 업데이트, 환경](/guide/settings/general/)
- [통합](/guide/settings/integration/)
- [시스템 요구 사항](/reference/requirements/)

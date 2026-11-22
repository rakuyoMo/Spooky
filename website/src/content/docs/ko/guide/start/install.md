---
title: "Spooky 설치하기"
description: "시스템 요구 사항을 확인하고, Spooky를 다운로드하고, 처음 열고, 최신 상태로 유지하고, 언어를 고르고, 제거하는 방법을 알아봅니다."
---

이 페이지는 Spooky를 다운로드해서 처음 열 때까지의 과정을 안내합니다. 업데이트, 인터페이스 언어, Spooky를 제거하는 방법도 다룹니다.

## 시스템 요구 사항 {#requirements}

- macOS 26 이상
- Git 2.41 이상

다른 Git을 고르지 않으면 Spooky는 `/usr/bin/git`의 Git을 사용합니다. 다른 Git을 고르려면 :ui[app.name > settings.title](<kbd>⌘,</kbd>)을 열고 :ui[settings.gitConfig]을 클릭한 다음, :ui[settings.gitProgram] 메뉴에서 프로그램을 선택합니다. 이 메뉴에는 Spooky가 찾은 Git 프로그램 중 버전이 충분히 높은 것이 나옵니다. 다른 위치의 Git을 쓰려면 :ui[settings.gitProgram.choose]을 선택합니다. 최소 버전은 메뉴 아래에 표시됩니다. [Git 프로그램](/guide/settings/identity/#git-program)을 참고하세요.

:::note[서버 저장소]
서버에도 Git 2.41 이상이 필요합니다. Spooky는 `~/.ssh/config`의 호스트 별칭을 사용해 SSH로 서버에 접속합니다. 설정에서 고른 Git은 Mac에 있는 저장소에만 적용됩니다. 서버 저장소는 서버의 Git을 사용합니다. [시스템 요구 사항](/reference/requirements/)과 [SSH 준비하기](/guide/server/prepare-ssh/)를 참고하세요.
:::

## 다운로드 {#download}

1. GitHub에서 [Spooky 릴리스 페이지](https://github.com/rakuyoMo/Spooky/releases)를 엽니다.
2. 최신 안정 릴리스를 찾습니다. 이름은 `v` 뒤에 버전 번호가 붙은 형태입니다. 이름이 “(beta)”나 “(development)”로 끝나는 것은 테스트 빌드입니다.
3. 이름이 `Spooky-` 뒤에 버전 번호가 붙은 zip 파일을 다운로드합니다.
4. 다운로드한 zip 파일을 이중 클릭해 압축을 풉니다.
5. Spooky를 **응용 프로그램** 폴더로 드래그합니다.

## Spooky 처음 열기 {#first-launch}

Spooky는 Apple의 공증을 받지 않았습니다. 처음 열면 macOS가 실행을 막고 경고를 표시합니다. 그래도 열려면 다음과 같이 합니다.

1. **응용 프로그램** 폴더에서 Spooky를 이중 클릭합니다. 경고가 나타나면 닫습니다.
2. **Apple 메뉴 › 시스템 설정**을 선택한 다음, 사이드바에서 **개인정보 보호 및 보안**을 클릭합니다. 아래로 스크롤해야 할 수도 있습니다.
3. **보안**으로 이동한 다음 **그래도 열기**를 클릭합니다. 이 버튼은 Spooky를 열려고 시도한 뒤 약 한 시간 동안 사용할 수 있습니다.
4. 로그인 암호를 입력한 다음 **확인**을 클릭합니다.

macOS가 이 선택을 기억합니다. 그 뒤로는 Spooky가 정상적으로 열립니다. Spooky는 저장소 윈도우로 시작합니다. 거기에 무엇이 보이는지는 [Spooky 둘러보기](/guide/start/tour/)에서 설명합니다.

## Spooky를 최신 상태로 유지하기 {#updates}

기본적으로 Spooky는 업데이트를 스스로 확인합니다. :ui[app.name > updates.check]을 선택하면 바로 확인합니다.

모든 업데이트에는 서명이 되어 있습니다. Spooky는 업데이트를 설치하기 전에 서명을 확인합니다. 확인을 통과하지 못한 업데이트는 지금 쓰는 Spooky를 대체하지 않습니다.

Spooky의 업데이트 방식을 바꾸려면 :ui[app.name > settings.title]을 열고 :ui[settings.updates]를 클릭합니다.

| 설정 | 하는 일 |
|---|---|
| :ui[updates.channel] | 어떤 릴리스를 받을지 정합니다. [릴리스 채널](#channels)을 참고하세요. |
| :ui[updates.automaticChecks] | 백그라운드에서 업데이트를 확인합니다. 기본으로 켜져 있습니다. |
| :ui[updates.automaticDownloads] | 백그라운드에서 업데이트를 다운로드하고 Spooky를 종료할 때 설치합니다. 기본으로 꺼져 있습니다. 자동 확인이 켜져 있고 Spooky가 쓰기 권한이 있는 폴더에 있을 때만 사용할 수 있습니다. |
| :ui[updates.interval] | 확인하는 주기입니다. :ui[updates.interval.hourly], :ui[updates.interval.daily], :ui[updates.interval.weekly] 중에서 고릅니다. 기본값은 매일입니다. 자동 확인이 켜져 있을 때만 사용할 수 있습니다. |

마지막 행인 :ui[updates.lastCheck]은 Spooky가 마지막으로 확인한 시점을 보여 줍니다. 아직 확인한 적이 없으면 :ui[updates.never]으로 표시됩니다.

### 릴리스 채널 {#channels}

| 채널 | 받는 릴리스 |
|---|---|
| :ui[updates.channel.stable] | 안정 릴리스. 기본값입니다. |
| :ui[updates.channel.beta] | 안정 릴리스와 베타 릴리스 |
| :ui[updates.channel.development] | 개발 빌드를 포함한 모든 릴리스 |

### 바뀐 내용 {#whats-new}

새 버전의 Spooky를 처음 시작하면 개별 저장소 윈도우의 사이드바 아래쪽에 :ui[whatsNew.card.title]이 표시됩니다. :ui[whatsNew.card.learnMore]를 클릭하면 바뀐 내용을 읽을 수 있습니다. 카드를 그냥 닫아도 됩니다.

나중에 다시 읽으려면 :ui[menu.help > help.whatsNew]을 선택합니다. :ui[menu.help > help.releaseNotes]는 GitHub의 릴리스 페이지를 엽니다.

## 인터페이스 언어 선택하기 {#language}

Spooky는 영어, 중국어(간체), 중국어(번체), 일본어, 한국어, 독일어, 프랑스어, 스페인어를 지원합니다. macOS에서 설정한 언어 순서를 따릅니다. 설정한 언어 중 지원하는 언어가 없으면 영어를 사용합니다.

Spooky에서만 다른 언어를 쓰려면 다음과 같이 합니다.

1. **Apple 메뉴 › 시스템 설정**을 선택한 다음, 사이드바에서 **일반**을 클릭합니다.
2. **언어 및 지역**을 클릭한 다음 **응용 프로그램**으로 이동합니다.
3. **추가** 버튼을 클릭하고 Spooky와 언어를 선택한 다음 **추가**를 클릭합니다.
4. Spooky가 열려 있으면 종료한 뒤 다시 엽니다.

시스템 언어로 되돌리려면 같은 목록에서 Spooky를 선택하고 **제거** 버튼을 클릭합니다.

## 제거 {#uninstall}

1. :ui[app.name > menu.quit](<kbd>⌘Q</kbd>)로 Spooky를 종료합니다.
2. **응용 프로그램** 폴더의 Spooky를 **휴지통**으로 옮깁니다.

설정과 데이터는 Mac에 남습니다. 이것도 지우려면 다음과 같이 합니다.

- 설정: **터미널**에서 `defaults delete com.rakuyo.spooky`를 실행합니다.
- 테마, 활동 기록 등 그 밖의 데이터: `~/Library/Application Support/Spooky/` 폴더를 삭제합니다.
- 캐시: `~/Library/Caches/com.rakuyo.spooky/` 폴더와, `~/Library/HTTPStorages/`에서 이름이 `com.rakuyo.spooky`로 시작하는 항목을 삭제합니다.
- Spooky가 저장한 암호와 토큰: 키체인에서 이름이 `com.rakuyo.spooky.`로 시작하는 항목을 삭제합니다.
- 사용한 각 서버: 서버의 홈 폴더에 있는 `~/.spooky/` 폴더를 삭제합니다.

Spooky가 저장소의 Git 구성에 추가한 `branch.<name>.spooky-*` 항목은 저장소에 그대로 남습니다. Spooky가 무엇을 어디에 저장하는지는 [데이터와 개인정보 보호](/reference/data-privacy/)에 정리되어 있습니다.

## 함께 보기

- [Spooky 둘러보기](/guide/start/tour/)
- [시스템 요구 사항](/reference/requirements/)
- [데이터와 개인정보 보호](/reference/data-privacy/)

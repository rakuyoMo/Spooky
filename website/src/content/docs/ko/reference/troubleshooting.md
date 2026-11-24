---
title: "문제 해결"
description: "연결 실패, 오래된 Git, 권한, 서버의 PATH 같은 흔한 문제를 해결하고, 문제를 보고하는 방법을 알아봅니다."
---

아래의 각 문제는 화면에 보이는 것부터 시작해서 왜 일어나는지, 무엇을 해야 하는지 설명합니다. Spooky의 오류 중 상당수는 Git이나 SSH의 원래 출력도 보여 주며, 거기에 정확한 원인이 적혀 있는 경우가 많습니다.

## 서버에 연결할 수 없음 {#connect}

연결 문제는 다음 중 한 곳에 나타납니다.

- :ui[remote.form.title] 대화상자가 열린 채로 남고 무엇을 고쳐야 하는지 알려 줍니다. 경우별 설명은 [확인이 실패했을 때](/guide/server/add/#results)를 참고하세요.
- 서버 저장소를 열면 :ui[missing.unreachable.title]{1="driftwood-server"}이 표시됩니다. [연결이 끊긴 동안](/guide/server/connection/#offline)을 참고하세요.
- 열려 있는 서버 저장소에서 목록 맨 위의 띠가 노란색으로 바뀌고 이유를 알려 줍니다. [연결 상태](/guide/server/connection/#status)를 참고하세요.

먼저 Spooky 밖에서 같은 로그인을 해 봅니다. 터미널에서 자신의 호스트 별칭으로 다음을 실행합니다.

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

실패하면 문제는 Mac과 서버 사이에 있습니다. 출력의 종류별 의미는 [Spooky가 연결하는 방식으로 테스트하기](/guide/server/prepare-ssh/#test)를 참고하세요. 터미널에서는 되는데 Spooky가 여전히 로그인하지 못하면 Spooky가 다른 SSH 에이전트를 사용하고 있을 수 있습니다. [SSH 에이전트](/guide/settings/integration/#ssh-agent)를 참고하세요.

Spooky가 표시하는 이유를 보면 어디를 살펴봐야 할지 알 수 있습니다.

| 이유 | 해야 할 일 |
|---|---|
| :ui[remoteError.authentication] | 서버가 키를 받아 주지 않거나 Mac이 키를 잠금 해제하지 못합니다. 재시동한 뒤에는 [Mac을 재시동한 뒤](/guide/server/prepare-ssh/#after-restart)에 나온 대로 키를 다시 로드합니다. 암호로만 로그인할 수 있는 계정은 사용할 수 없습니다. |
| :ui[remoteError.unknownHostKey] | Mac이 아직 서버를 모릅니다. [한 번 연결하기](/guide/server/prepare-ssh/#fingerprint)에 나온 대로 터미널에서 한 번 연결하고 지문을 확인합니다. Spooky는 지문을 대신 수락하지 않습니다. |
| :ui[remoteError.changedHostKey] | 아직 연결하지 않습니다. 먼저 서버 소유자에게 변경을 확인합니다. |
| :ui[remoteError.unavailable] | 호스트 별칭과 네트워크를 확인합니다. Spooky는 시도가 실패할 때마다 5초 뒤에 다시 시도합니다. 바로 시도하려면 띠에서 :ui[action.reconnect]을 클릭합니다. [연결 끊김과 다시 연결](/guide/server/connection/#reconnect)을 참고하세요. |
| :ui[remoteError.deployment] | 서버에 Spooky가 필요로 하는 것이 없습니다. Unix 소켓 전달, `/usr/bin/perl`, `~/.spooky/bin`과 `/tmp`에 대한 쓰기 권한 중 하나입니다. [서버](/reference/requirements/#servers)를 참고하세요. |

서버에 Git이 없거나 너무 오래되었다면 계속 읽습니다.

## Git이 너무 오래됨 {#git-version}

Spooky에는 Mac과 서버 모두에 Git 2.41.0 이상이 필요합니다.

### Mac에서 {#mac-git}

로컬 저장소를 열 때 Spooky가 다음 중 하나를 표시할 수 있습니다.

- :ui[error.version]. 아래에 Git의 출력이 나옵니다. Spooky가 사용하는 Git 프로그램이 2.41.0보다 오래되었습니다. :ui[app.name > settings.title] › :ui[settings.gitConfig]의 :ui[settings.gitProgram] 옆에서 더 새로운 것을 선택하거나, Xcode 또는 Command Line Tools를 업데이트합니다.
- :ui[error.gitProgram]. 아래에 경로가 나옵니다. 선택한 Git 프로그램이 제거하는 등의 이유로 더 이상 그곳에 없습니다. 같은 곳에서 다른 것을 선택합니다.

메뉴에는 충분히 새로운 Git 프로그램만 나열됩니다. [Git 프로그램](/guide/settings/identity/#git-program)을 참고하세요.

### 서버에서 {#server-git}

연결이 :ui[remoteError.gitVersion]으로 실패합니다. 서버의 Git을 2.41.0 이상으로 업데이트합니다.

서버에 더 새로운 Git이 이미 설치되어 있다면 SSH 로그인이 오래된 것을 먼저 찾는 것입니다. [서버에서 Git을 찾을 수 없음](#server-path)에 나온 대로 `PATH`에서 새 Git의 폴더를 다른 폴더보다 앞에 둡니다.

## 서버에서 Git을 찾을 수 없음 {#server-path}

연결이 :ui[remoteError.gitUnavailable]로 실패합니다. 또는 :ui[app.name > settings.title] › :ui[settings.environment]에서 서버를 확인하면 :ui[settings.environment.server.noGit]이 표시됩니다.

서버에 Git이 설치되어 있지 않다면 Git 2.41.0 이상을 설치합니다. 설치되어 있다면 원인은 대개 `PATH`입니다. Spooky는 대화형 셸 없이 SSH를 통해 서버에서 명령을 실행합니다. 이런 셸은 시작 파일을 더 적게 읽습니다. `~/.zshrc`나 `~/.bash_profile`에서 설정한 `PATH`가 적용되지 않을 수 있습니다.

해결하려면 다음과 같이 합니다.

1. 터미널에서 서버에 로그인하고 `command -v git`을 실행합니다. `/opt/homebrew/bin/git`처럼 Git이 있는 곳이 출력됩니다.
2. Spooky가 받는 `PATH`와 비교합니다. 오류의 출력에 나와 있고, [서버 확인하기](/guide/settings/general/#server-check)의 확인 결과에도 나옵니다.
3. 비대화형 셸이 읽는 시작 파일에서 Git의 폴더를 `PATH`에 추가합니다. 어떤 셸을 쓰는지 보려면 서버에서 `echo $SHELL`을 실행합니다.
   - zsh: `~/.zshenv`
   - bash: `~/.bashrc`. 셸이 대화형이 아닐 때 일찍 끝내는 줄보다 위에 넣습니다

   예를 들면 다음과 같습니다.

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. :ui[settings.environment.server.check]을 다시 클릭하거나 [서버에 연결할 수 없음](#connect)의 테스트를 실행합니다. 그런 다음 다시 연결합니다.

Git LFS와 훅이 실행하는 프로그램도 같은 `PATH`로 찾습니다. 터미널에서는 되는데 Spooky에서 안 되면(예를 들어 명령이 :ui[hostError.lfsUnavailable] 오류로 실패하면) 같은 방법으로 그 폴더를 추가합니다.

## 권한 문제 {#permissions}

| 보이는 것 | 이유와 해야 할 일 |
|---|---|
| :ui[remoteError.pathPermission] | 서버의 사용자가 저장소 폴더를 열거나 읽을 수 없습니다. 서버 소유자에게 접근 권한을 요청하거나, 자신이 소유한 폴더를 선택합니다. |
| :ui[remoteError.diskAccess] | 서버가 Mac이고, 저장소가 문서처럼 macOS가 보호하는 폴더에 있습니다. [Mac을 서버로 사용하기](/guide/server/prepare-ssh/#mac-server)에 나온 대로 원격 사용자의 전체 디스크 접근을 켜거나 저장소를 옮깁니다. |
| :ui[error.ownership] | 이 Mac의 저장소 폴더가 다른 사용자의 것입니다. Git이 그 안에서 동작하기를 거부합니다. 폴더의 소유자를 자신으로 바꿉니다. 그 소유자를 신뢰한다면 Git의 출력이 제안하는 `git config --global --add safe.directory` 명령을 대신 실행해도 됩니다. |
| :ui[error.terminal] | 제목 아래의 세부사항에 무엇이 잘못되었는지 나옵니다. :ui[settings.terminal] 옆에서 선택한 터미널 앱이 더 이상 설치되어 있지 않거나, Spooky가 터미널 또는 iTerm을 제어하도록 허용하지 않은 경우가 많습니다. [터미널](/guide/settings/integration/#terminal)을 참고하세요. |
| :ui[appIcon.writeFailed] | Spooky는 아이콘을 `Spooky.app` 안에 저장합니다. 사용자가 거기에 쓸 수 있어야 합니다. Finder에서 Spooky를 선택하고 **파일 › 정보 가져오기**를 선택한 다음 **공유 및 사용 권한** 아래에 **읽기 및 쓰기**가 있는지 확인합니다. |

:::note[서버 저장소]
서버에서는 다른 사용자의 폴더가 :ui[remoteError.notWorkingTree]으로 실패하고, Git의 출력에 소유권이 언급됩니다. 서버 소유자에게 문의하거나 서버에서 `safe.directory` 명령을 실행합니다.
:::

## 문제 보고하기 {#report}

:ui[menu.help > help.support]을 선택하면 GitHub에서 Spooky의 이슈가 열립니다. 거기에서 같은 문제를 찾아보거나 새 이슈를 엽니다. 무엇을 했는지, 무엇을 기대했는지, 무슨 일이 일어났는지 적습니다. Spooky가 오류를 표시했다면 오류의 제목과 원래 출력을 포함합니다.

진단 보고서가 있으면 무슨 일이 있었는지 알리는 데 도움이 됩니다. :ui[menu.help > help.diagnosticReport]을 선택하고 저장할 곳을 고릅니다. Spooky가 텍스트 파일을 저장하고 Finder에서 보여 줍니다. 보고서를 어디로도 보내지 않습니다. 공유하기 전에 파일을 열어 읽어 봅니다. 무엇이 들어 있는지는 [진단 보고서](/reference/data-privacy/#diagnostic-reports)를 참고하세요.

Spooky가 지난번에 예기치 않게 종료되었다면 다음에 실행할 때 :ui[crash.title]이라고 물어봅니다. :ui[crash.report]를 클릭하면 브라우저에서 GitHub의 새 이슈 페이지가 열리고, 충돌 요약이 채워져 있습니다. 이슈는 브라우저에서 제출해야만 만들어집니다. [충돌 보고서](/reference/data-privacy/#crash-reports)를 참고하세요.

## 함께 보기

- [SSH 준비하기](/guide/server/prepare-ssh/)
- [연결 상태와 다시 연결](/guide/server/connection/)
- [시스템 요구 사항](/reference/requirements/)
- [데이터와 개인정보 보호](/reference/data-privacy/)

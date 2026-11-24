---
title: "SSH 준비하기"
description: "서버 저장소를 추가하기 전에 SSH 키와 ~/.ssh/config의 호스트 별칭을 준비하고, 터미널에서 연결되는지 확인합니다."
---

Spooky는 터미널과 같은 방식으로 SSH를 사용해 서버에 로그인합니다. 암호를 대신 입력해 줄 수 없으므로 SSH 키가 필요합니다. 이 페이지에서는 키와 서버의 짧은 이름을 준비한 다음, 터미널이 아무것도 묻지 않고 연결하는지 확인합니다. 이것이 되면 Spooky도 연결할 수 있습니다.

`ssh`로 이미 암호 없이 서버에 로그인할 수 있다면 [Spooky가 연결하는 방식으로 테스트하기](#test)로 건너뜁니다.

## 필요한 것 {#before}

- SSH로 로그인할 수 있는 서버 계정. 잘 모르겠으면 서버 소유자에게 문의합니다.
- 서버의 Git 2.41.0 이상.
- Mac의 **터미널** 앱.

이 페이지의 명령은 터미널에 입력합니다. 명령을 하나씩 입력하거나 붙여 넣은 다음 Return을 누릅니다.

## 키가 있는지 확인하기 {#key-check}

SSH 키는 파일 한 쌍입니다. 개인 키는 Mac에 남습니다. 공개 키는 이름이 `.pub`로 끝나고 서버에 둡니다.

```sh
ls ~/.ssh
```

목록에 `id_ed25519`와 `id_ed25519.pub`가 있으면 이미 키가 있는 것입니다. [호스트 별칭 추가하기](#alias)로 건너뜁니다. `id_rsa`와 `id_rsa.pub` 같은 다른 쌍도 쓸 수 있습니다. 아래 단계에서 `id_ed25519` 대신 그 이름을 사용합니다.

“No such file or directory”가 표시되거나 목록에 키 쌍이 없으면 새로 만듭니다.

## 키 만들기 {#create-key}

```sh
ssh-keygen -t ed25519 -C "alex@example.com"
```

따옴표 안에는 자신의 이메일 주소를 넣습니다. 키를 알아보기 위한 레이블일 뿐입니다.

1. 키를 저장할 위치를 물으면 Return을 눌러 제안된 위치를 그대로 씁니다.
2. 암호문을 입력하고 한 번 더 입력합니다. 입력하는 동안 화면에는 아무것도 표시되지 않습니다. 암호문은 누군가 파일을 복사해 가더라도 키를 보호합니다.

끝나면 `~/.ssh`에 `id_ed25519`와 `id_ed25519.pub`가 생깁니다.

## 호스트 별칭 추가하기 {#alias}

호스트 별칭은 서버의 짧은 이름입니다. 터미널과 Spooky에서 서버 주소와 사용자 이름 대신 입력합니다. 별칭은 `~/.ssh/config` 파일에 저장됩니다. Spooky의 설정에서 추가합니다.

1. :ui[app.name > settings.title] › :ui[settings.sshHosts]를 선택합니다.
2. 목록 아래의 추가 버튼을 클릭합니다.
3. 필드를 자신의 정보로 채웁니다.
4. :ui[sshHosts.create.submit]를 클릭합니다.

::screenshot[호스트 별칭 추가 대화상자. 별칭은 driftwood-server, 서버 주소는 203.0.113.10, 사용자 이름은 alex이고, 포트는 비어 있으며, 개인 키는 ~/.ssh/id_ed25519입니다. 버튼은 취소와 추가입니다.]{name="settings-ssh-hosts-add" frame="dialog"}

| 필드 | 입력할 내용 |
|---|---|
| :ui[sshHosts.alias] | 별칭. 공백, `@`, `:`, `/`, `*`, `?`가 없는 한 단어로 쓰고, `-`나 `!`로 시작하지 않습니다. |
| :ui[sshHosts.hostName] | 서버의 주소 또는 이름. 예: `203.0.113.10`, `server.example.com` |
| :ui[sshHosts.user] | 서버에서의 사용자 이름 |
| :ui[sshHosts.port] | 포트. 서버의 SSH가 22가 아닌 포트를 사용할 때만 입력합니다 |
| :ui[sshHosts.identityFile] | 위에서 만들었거나 찾은 개인 키. 예: `~/.ssh/id_ed25519` |

:ui[sshHosts.alias]만 필수입니다. Spooky는 별칭과 입력한 필드를 `~/.ssh/config`에 씁니다.

```
Host driftwood-server
    HostName 203.0.113.10
    User alex
    IdentityFile ~/.ssh/id_ed25519
```

`Host *`처럼 패턴을 쓰는 항목이나 `Match` 항목이 있으면, 새 줄은 그런 항목 중 첫 번째 것 위에 들어갑니다. 그 항목이 새 줄의 값을 덮어쓰지 못하게 하기 위해서입니다. 그런 항목이 없으면 파일 끝에 들어갑니다.

### 별칭 변경 또는 삭제하기 {#manage-aliases}

:ui[settings.sshHosts] 페이지에는 `~/.ssh/config`에 있는 별칭이 나열됩니다. 텍스트 편집기에서 추가한 것도 포함됩니다.

::screenshot[설정 윈도우의 SSH 호스트 페이지. 목록에는 별칭, 서버 주소, 사용자 이름, 포트, 개인 키 열이 있습니다. staging, backup-nas, driftwood-server 세 개의 별칭이 있고 driftwood-server가 선택되어 있습니다. 목록 아래에 추가 버튼과 제거 버튼이 있고, 오른쪽에 편집… 버튼이 있습니다.]{name="settings-ssh-hosts" frame="window"}

- 별칭을 바꾸려면 선택하고 :ui[sshHosts.edit]을 클릭합니다. Spooky는 편집한 필드의 줄만 바꿉니다. 그 서버의 다른 SSH 옵션, 다른 서버, 주석은 그대로 둡니다.
- 별칭을 삭제하려면 선택하고 목록 아래의 제거 버튼을 클릭한 다음 확인합니다. Spooky는 그 별칭의 `Host` 줄과 그 아래의 옵션을 삭제합니다.

이름이 여러 개인 항목이나 `Host *`처럼 패턴을 쓰는 항목은 목록에 나오지 않으며, Spooky가 변경하지도 않습니다. 이런 항목은 텍스트 편집기에서 편집합니다.

Spooky로 돌아올 때마다 Spooky는 이 파일을 다시 읽습니다. 대화상자가 열려 있는 동안 다른 앱이 파일을 변경하면 Spooky는 변경 내용을 저장하지 않습니다. 목록이 파일의 현재 내용으로 바뀌므로, 다시 변경합니다.

## Mac이 키의 잠금을 풀게 하기 {#keychain}

Spooky는 로그인할 때 키의 암호문을 묻지 않으므로, Mac이 대신 키의 잠금을 풀어야 합니다. `~/.ssh/config`에 두 줄을 추가하면 모든 서버에 적용됩니다. 키에 암호문이 없으면 이 단계를 건너뜁니다.

1. 텍스트 편집기에서 파일을 엽니다.

   ```sh
   open -e ~/.ssh/config
   ```

2. 파일 끝에 다음 줄을 추가합니다.

   ```
   Host *
       AddKeysToAgent yes
       UseKeychain yes
   ```

3. 파일을 저장하고 텍스트 편집기를 닫습니다.

암호문을 처음 입력하면 Mac이 키체인에 저장합니다. 그 뒤로는 SSH가 묻지 않고 키의 잠금을 풉니다.

## 한 번 연결하기 {#fingerprint}

서버에 처음 연결하면 SSH가 서버의 지문을 확인하라고 요청합니다. Spooky는 지문을 대신 수락하지 않으므로, 먼저 터미널에서 이 과정을 거칩니다.

```sh
ssh driftwood-server
```

1. SSH가 `SHA256:`으로 시작하는 서버의 지문을 보여 주고 계속할지 묻습니다.
2. 서버 소유자가 알려 준 지문과 비교합니다. 서버에서 다음 명령을 실행하면 지문이 출력됩니다.

   ```sh
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. 일치하면 `yes`를 입력하고 Return을 누릅니다. Mac이 서버를 기억하고 다시 묻지 않습니다.

그다음에 일어나는 일은 서버에 따라 다릅니다.

- SSH가 키의 암호문을 물으면 입력합니다. Mac이 키체인에 저장합니다.
- 로그인되었다면 키가 이미 서버에 있는 것입니다. `exit`를 입력한 다음 [Spooky가 연결하는 방식으로 테스트하기](#test)로 건너뜁니다.
- SSH가 서버의 암호를 물으면 일단 <kbd>⌃C</kbd>를 누릅니다. 다음 단계에서 키를 서버에 올립니다.

:::caution
SSH가 원격 호스트의 식별 정보가 바뀌었다고 경고하면 계속하지 않습니다. 서버를 다시 설치했거나 교체했는지 서버 소유자에게 문의합니다.
:::

## 공개 키를 서버에 올리기 {#copy-key}

암호로 서버에 로그인할 수 있으면 다음 명령으로 공개 키를 서버에 복사합니다. 요청이 나오면 서버의 암호를 입력합니다.

```sh
ssh-copy-id -i ~/.ssh/id_ed25519.pub driftwood-server
```

서버가 암호를 받지 않으면 공개 키를 서버 소유자에게 보냅니다. 다음 명령은 공개 키를 클립보드에 복사합니다.

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

서버의 홈 폴더에 있는 `~/.ssh/authorized_keys`에 추가해 달라고 요청합니다. 공개 키는 공유해도 안전합니다. `.pub`가 없는 파일은 절대 보내지 않습니다.

## Spooky가 연결하는 방식으로 테스트하기 {#test}

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

이 명령은 Spooky와 같은 방식으로, 아무것도 묻지 않고 로그인합니다. `git version 2.47.1`처럼 2.41.0 이상의 버전이 바로 출력되면 성공입니다. 이제 [서버 저장소를 추가](/guide/server/add/)할 수 있습니다.

다른 내용이 출력되면 다음과 같이 합니다.

| 표시되는 내용 | 할 일 |
|---|---|
| `Permission denied` | 서버가 아직 키를 받아들이지 않거나, Mac이 키의 잠금을 풀 수 없습니다. [Mac이 키의 잠금을 풀게 하기](#keychain), [공개 키를 서버에 올리기](#copy-key), [Mac을 재시동한 뒤](#after-restart)를 확인합니다. |
| `Host key verification failed` | Mac이 아직 서버를 모릅니다. [한 번 연결하기](#fingerprint)를 참고하세요. |
| `Could not resolve hostname`, `Connection refused`, 또는 `Operation timed out` | :ui[app.name > settings.title] › :ui[settings.sshHosts]에서 별칭의 :ui[sshHosts.hostName]와 :ui[sshHosts.port]를 확인하고, 서버가 켜져 있고 접근 가능한지 확인합니다. |
| `command not found`가 들어 있는 메시지 | 서버에 Git이 설치되어 있지 않거나, SSH 로그인에서 Git을 찾지 못합니다. 서버 소유자에게 문의합니다. |
| 2.41.0보다 낮은 버전 | 서버 소유자에게 Git 업데이트를 요청합니다. |

## Mac을 재시동한 뒤 {#after-restart}

전에는 테스트가 됐는데 재시동한 뒤 `Permission denied`로 실패하면 키를 다시 불러옵니다. 암호문이 키체인에 저장된 키는 다음 명령으로 불러옵니다.

```sh
ssh-add --apple-load-keychain
```

## 다른 SSH 에이전트 사용하기 {#agent}

SSH 에이전트는 잠금이 풀린 키를 SSH가 바로 쓸 수 있게 보관합니다. Spooky는 macOS가 시작해 주는 시스템 에이전트를 사용합니다. 키가 다른 에이전트에 있다면, 예를 들어 암호 관리자에 딸린 에이전트라면 `SSH_AUTH_SOCK`을 그 에이전트의 소켓으로 설정합니다. :ui[app.name > settings.title] › :ui[settings.environment]에서 사용자 지정 변수로 추가하거나 로그인 셸에서 설정합니다. 그러면 Spooky가 그 에이전트로 서버에 로그인합니다. [SSH 에이전트](/guide/settings/integration/#ssh-agent)를 참고하세요.

## Mac을 서버로 사용하기 {#mac-server}

다른 Mac도 서버가 될 수 있습니다. 그 Mac에서 다음과 같이 합니다.

1. **Apple 메뉴 › 시스템 설정**을 선택하고 **일반**을 클릭한 다음 **공유**를 클릭합니다.
2. **원격 로그인**을 켭니다.
3. 저장소가 문서나 데스크탑 같은 보호된 폴더에 있으면 **원격 로그인** 옆의 정보 버튼을 클릭하고 **원격 사용자에 대해 전체 디스크 접근 허용**을 켭니다.

그런 다음 자신의 Mac에서 이 페이지의 과정을 따라 하되, :ui[sshHosts.hostName]에 그 Mac의 주소를 넣습니다.

## 함께 보기

- [서버 저장소의 동작 방식](/guide/server/overview/)
- [서버 저장소 추가](/guide/server/add/)
- [시스템 요구 사항](/reference/requirements/#servers)

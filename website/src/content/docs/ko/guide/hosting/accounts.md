---
title: "호스팅 계정"
description: "GitHub, GitLab.com, 자체 관리형 GitLab 계정을 연결하고, 토큰이 어디에 저장되고 어디에 쓰이는지 알아봅니다."
---

GitHub 또는 GitLab 계정을 추가하면 Spooky에서 풀 리퀘스트와 머지 리퀘스트를 다룰 수 있습니다. Git도 이 계정으로 해당 서비스의 HTTPS 원격에 로그인하므로 사용자 이름과 암호를 묻지 않습니다.

## 계정 추가하기 {#add}

:ui[app.name > settings.title]을 열고 :ui[settings.accounts]을 클릭합니다. 목록 아래의 추가 버튼을 클릭하고 계정이 있는 곳을 선택합니다.

| 선택 항목 | 대상 | 로그인 방법 |
|---|---|---|
| :ui[accounts.add.github] | github.com | 브라우저 또는 개인 액세스 토큰 |
| :ui[accounts.add.gitlab] | GitLab.com | 개인 액세스 토큰 |
| :ui[accounts.add.gitlabSelfManaged] | 자체 서버의 GitLab | 개인 액세스 토큰 또는 사용자 이름과 암호 |

::screenshot[자체 관리형 GitLab 계정을 추가하는 시트. 호스트는 https://gitlab.example.com이고 인증 방식은 사용자 이름과 암호입니다.]{name="hosting-add-account" frame="dialog" markers="79.2,59.7 83.3,50.8"}

1. 호스트
2. 인증 방식

Spooky가 계정을 확인하는 동안 대화상자 맨 아래에 :ui[accounts.validating]이 표시됩니다. :ui[action.cancel]를 누르면 확인이 멈추고 대화상자는 열린 채로 남아서 입력한 내용을 고칠 수 있습니다. 확인에 실패하면 메시지가 이유를 알려 주고, 입력한 내용은 그대로 남습니다.

각 계정은 서비스, 인스턴스, 사용자 이름과 함께 목록에 나타납니다. 같은 서비스에 계정을 두 개 이상 추가할 수 있습니다.

### GitHub {#github}

:ui[accounts.authentication] 옆에서 :ui[accounts.authentication.oauth]을 선택한 상태로 :ui[accounts.add.submit]를 클릭합니다.

1. Spooky가 일회용 코드를 표시하고 복사한 다음 브라우저에서 GitHub를 엽니다.
2. 거기에 코드를 붙여넣고 Spooky를 승인합니다. 그 사이에 다른 것을 복사했다면 :ui[accounts.copyCode]를 클릭해 다시 복사합니다.
3. Spooky를 승인하면 대화상자가 닫히고 계정이 목록에 나타납니다.

코드가 만료되거나 브라우저에서 접근을 거부했다면 처음부터 다시 시작해 새 코드를 받습니다.

토큰을 대신 사용하려면 :ui[accounts.authentication] 옆에서 :ui[accounts.authentication.token]을 선택합니다. 토큰에는 `repo`와 `read:org` 범위가 필요합니다.

### GitLab.com {#gitlab-com}

`api` 범위가 있는 개인 액세스 토큰을 붙여넣습니다.

### 자체 관리형 GitLab {#self-managed}

:ui[accounts.host] 옆에 GitLab 서버의 주소를 입력합니다. 포트와 경로가 있으면 함께 넣습니다. 예를 들면 `https://example.com:8443/gitlab`입니다. 그런 다음 로그인 방법을 선택합니다.

- :ui[accounts.authentication.token]: `api` 범위가 있는 토큰입니다.
- :ui[accounts.authentication.password]: Spooky는 토큰을 받는 데만 암호를 사용하고 암호를 저장하지 않습니다.

사용자 이름과 암호로 로그인하려면 다음이 모두 충족되어야 합니다.

- 서버가 GitLab 18.11 이하를 실행합니다. GitLab 19.0 이상은 더 이상 암호를 토큰으로 바꿔 주지 않습니다.
- 서버가 OAuth 애플리케이션 자격 증명을 요구하지 않습니다. GitLab 13.9는 항상 요구하고, GitLab 17.8 이상은 요구하도록 설정할 수 있습니다.
- 서버가 암호를 사용하는 HTTPS Git을 허용합니다.
- 계정에 GitLab 또는 LDAP 암호가 있고, 2단계 인증을 사용하지 않으며, 통합 인증(SSO)으로만 로그인하는 계정이 아닙니다.

이렇게 받은 토큰은 만료되며, Spooky가 알아서 갱신합니다. GitLab이 갱신해 주지 않게 되면 계정이 다시 인증이 필요한 것으로 표시됩니다.

Spooky에는 GitLab 9.0 이상이 필요합니다. Mac에서 서버에 접속할 수 있어야 하고, Mac이 서버의 인증서를 신뢰해야 합니다. 신뢰하지 않는다면 **키체인 접근**에서 인증서를 신뢰하도록 설정합니다.

## 계정 관리하기 {#manage}

모든 윈도우가 같은 계정을 공유합니다. :ui[app.name > settings.title] › :ui[settings.accounts]에서 다음과 같이 합니다.

- 계정을 다시 인증하려면 계정을 선택하고 목록 아래의 :ui[accounts.reauthenticate]을 클릭합니다. 다시 로그인하거나 새 토큰을 입력합니다. 같은 사용자여야 합니다. 다른 사용자로 로그인하려면 새 계정을 추가합니다.
- 계정을 제거하려면 계정을 선택하고 목록 아래의 제거 버튼을 클릭한 다음 확인합니다. Spooky가 키체인에서 계정의 토큰을 삭제합니다.

:ui[accounts.needsReauthentication]로 표시된 계정은 토큰이 만료되거나 취소되는 등의 이유로 서비스가 더 이상 받아 주지 않는 계정입니다. 다시 사용하려면 다시 인증합니다.

Spooky는 변경을 곧바로 반영합니다. 열려 있는 풀 리퀘스트 목록이나 머지 리퀘스트 목록은 윈도우를 다시 열지 않아도 다시 로드됩니다.

## 계정의 용도 {#uses}

계정은 해당 서비스에 있는 원격에 사용됩니다.

- [풀 리퀘스트와 머지 리퀘스트](/guide/hosting/pull-requests/) 목록
- 커밋 메시지에서 `#` 뒤에 오는 이슈 번호. [자동 완성](/guide/work/commit/#autocomplete)을 참고하세요.
- [브랜치 검토](/guide/branches/review/)의 풀 리퀘스트와 머지 리퀘스트 상태
- 서비스에 [저장소 게시하기](#publish)
- [HTTPS 원격에 로그인하기](#git)

## 원격이 사용하는 계정 {#remotes}

Spooky는 각 원격의 주소를 각 계정의 인스턴스와 맞춰 봅니다. 인스턴스는 github.com, GitLab.com 또는 자체 GitLab 서버입니다.

- **그 인스턴스에 계정이 하나 있는 경우**: Spooky가 그 계정을 사용합니다.
- **그 인스턴스에 계정이 여러 개 있는 경우**: 풀 리퀘스트 목록이 하나를 선택하라고 요청합니다. Spooky는 그 원격에 대한 선택을 기억합니다.
- **아직 계정이 없는 경우**: github.com과 GitLab.com이라면 목록에 그렇게 표시되고 :ui[pullRequests.openAccounts]가 나옵니다.
- **주소가 일치하지 않는 경우**: 예를 들어 원격이 `~/.ssh/config`의 호스트 별칭을 사용할 때입니다. 목록에 :ui[pullRequests.associate] 버튼이 있는 메모가 표시됩니다. 원격이 내 계정 중 하나에 속한다면 버튼을 클릭하고 계정과 프로젝트를 선택합니다.

같은 프로젝트의 HTTPS 주소와 SSH 주소는 같은 계정에 대응됩니다.

## HTTPS 원격에 로그인하기 {#git}

HTTPS 원격이 내 계정 중 하나에 속하면 Git이 그 계정의 토큰으로 로그인합니다. 복제, 가져오기, 풀, 푸시, 자동 가져오기가 모두 해당됩니다.

- SSH 원격은 계속 SSH 키를 사용합니다. 계정은 여기에 영향을 주지 않습니다.
- 이런 주소에서는 macOS 키체인 헬퍼처럼 Git에 설정해 둔 자격 증명 헬퍼 대신 Spooky가 응답합니다. 그 헬퍼들은 토큰을 보거나 저장하지 않습니다.
- 같은 인스턴스에 계정이 여러 개 있고 원격에 사용할 계정을 선택하지 않았다면 Git이 평소처럼 사용자 이름과 암호를 묻습니다.

Git이 토큰을 거부하면 그 명령은 실패합니다. 그 뒤로는 그 계정의 원격에서 Git이 사용자 이름과 암호를 묻고, 대화상자에 계정의 토큰이 받아들여지지 않았다고 표시됩니다. 계정으로 다시 로그인하게 하려면 계정을 다시 인증합니다.

:::note[서버 저장소]
서버의 Git도 토큰으로 로그인합니다. 토큰이 필요할 때마다 Mac의 Spooky에서 받아 옵니다. 토큰은 서버에 저장되지 않습니다.
:::

## 토큰이 저장되는 곳 {#storage}

- 계정 목록은 토큰 없이 Spooky의 환경설정에 있습니다.
- 토큰은 키체인에 `com.rakuyo.spooky.hosting.<address>`라는 이름의 항목으로 들어 있습니다.
- 자체 관리형 GitLab에 사용자 이름과 암호로 로그인하면 Spooky는 그 대가로 받은 토큰을 보관합니다. 암호는 보관하지 않습니다.

토큰은 :ui[activity.title] 기록이나 Spooky의 로그에 들어가지 않습니다.

## 요청이 가는 곳 {#network}

Spooky는 서버 저장소에서도 Mac에서 서비스와 통신합니다.

- GitHub: 브라우저에서 승인하는 동안에는 `github.com`, 그 밖에는 모두 `api.github.com`입니다.
- GitLab: `gitlab.com` 또는 자체 GitLab의 주소입니다.

계정을 추가하거나 다시 인증할 때, 그리고 계정의 용도에 해당하는 기능을 쓸 때 통신합니다. 풀 리퀘스트와 머지 리퀘스트 목록 및 거기에서 하는 일, `#` 뒤의 이슈 번호, 브랜치 검토의 상태, 저장소 게시가 여기에 해당합니다. 사용자 이름과 암호로 로그인한 계정은 토큰도 거기에서 갱신합니다.

이런 요청은 모두 :ui[activity.title] 윈도우의 :ui[activity.service] 페이지에 나타납니다.

GitHub와 GitLab 사용자의 사진은 그 서비스들이 알려 주는 주소에서 가져옵니다. 다운로드한 사진은 메모리에만 있고 Spooky를 종료하면 사라집니다.

Git 자체는 저장소가 있는 곳에서 원격에 연결합니다. 서버 저장소라면 서버입니다. [데이터와 개인정보 보호](/reference/data-privacy/#network)를 참고하세요.

## 저장소 게시하기 {#publish}

열려 있는 저장소로 GitHub나 GitLab에 저장소를 만들려면 메뉴 막대에서 :ui[menu.repository > publish.menu]를 선택합니다. 사이드바에서 :ui[workspace.title]을 오른쪽 클릭하고 메뉴에서 :ui[workspace.publishMenu]를 선택해도 됩니다. 저장소에 아직 원격이 없으면 :ui[sync.push]도 이 대화상자를 엽니다. 계정이 하나 이상 있어야 합니다.

| 필드 | 하는 일 |
|---|---|
| :ui[publish.remote] | 새 원격의 이름입니다. 처음에는 `origin`이고, 저장소에 이미 `origin`이 있으면 `origin-2`입니다. |
| :ui[pullRequests.account] | 저장소를 만들 곳입니다. 내 사용자 아래 또는 내가 속한 조직이나 그룹입니다 |
| :ui[publish.name] | 서비스에서 쓸 이름입니다. 처음에는 저장소 폴더의 이름입니다. |
| :ui[pullRequests.description] | 선택 사항 |
| :ui[publish.visibility] | :ui[publish.visibility.private] 또는 :ui[publish.visibility.public]입니다. GitLab에는 :ui[publish.visibility.internal]도 있습니다. |
| :ui[publish.target] | 원격이 사용할 HTTPS 주소 |

:ui[publish.submit]를 클릭하면 Spooky가 다음을 실행합니다.

1. 서비스에 빈 저장소를 만듭니다.
2. HTTPS 주소로 그 저장소를 원격으로 추가합니다.
3. 모든 로컬 브랜치와 태그를 거기로 푸시합니다. 업스트림이 없는 브랜치는 새 원격 브랜치를 추적하기 시작합니다. 이미 업스트림이 있는 브랜치는 그대로 유지합니다.

그 이름의 저장소가 이미 있으면 Spooky가 그렇다고 알려 주고 덮어쓰지 않습니다. 다른 이름을 선택합니다. 푸시가 실패하면 새 원격과 서비스의 저장소가 모두 남으므로 다시 푸시할 수 있습니다.

게시는 <kbd>⌘Z</kbd>로 실행 취소할 수 없으며, 그 전에 한 작업도 더 이상 실행 취소할 수 없습니다.

## 함께 보기

- [풀 리퀘스트와 머지 리퀘스트](/guide/hosting/pull-requests/)
- [암호와 암호문 입력 요청](/guide/server/connection/#prompts)
- [데이터와 개인정보 보호](/reference/data-privacy/)

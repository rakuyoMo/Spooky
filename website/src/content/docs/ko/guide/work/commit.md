---
title: "변경 사항 커밋하기"
description: "커밋 제목과 설명을 쓰고, 자동 완성을 사용하고, 최근 커밋을 수정하고, 커밋에 쓸 커미터 신원과 서명을 고릅니다."
---

커밋은 스테이지된 변경 사항을 메시지와 함께 저장소의 기록에 저장합니다. 먼저 [변경 사항 검토하고 스테이지하기](/guide/work/diff/)에서 설명한 대로 변경 사항을 스테이지합니다. 그런 다음 작업 사본 맨 위의 커밋 영역에 메시지를 씁니다.

## 메시지 쓰기 {#write}

메시지는 두 부분으로 되어 있습니다.

- :ui[working.subject]은 변경을 요약하는 짧은 한 줄입니다. <kbd>Return</kbd>이나 <kbd>Tab</kbd>을 누르면 설명으로 넘어갑니다. 여기에 여러 줄을 붙여넣으면 첫 줄은 제목에 남고, 나머지는 설명 끝에 추가됩니다.
- :ui[working.body]은 쓰지 않아도 됩니다. 무엇이 왜 바뀌었는지 설명할 때 씁니다.

::screenshot[펼쳐진 커밋 영역. 제목은 Add a units toggle이고 그 아래에 두 줄짜리 설명이 있습니다. 설명 아래쪽에 고정 버튼과 줄 바꿈 버튼이 있습니다. 그 아래에 최근 커밋 수정과 사인오프 체크상자가 있고, 오른쪽에 작성자의 이름, 이메일, 사진이 있습니다. 맨 아래에는 모두 스테이지 버튼과 커밋 버튼이 있습니다.]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. 고정 버튼과 줄 바꿈 버튼
3. 작성자의 사진

커밋 영역은 두 필드 중 하나에 입력하는 동안 펼쳐지고, 설명에 글이 있는 동안 열려 있습니다. 항상 열어 두려면 설명 아래쪽의 고정 버튼을 클릭합니다. 설명의 아래쪽 가장자리를 드래그하면 높이를 늘리거나 줄일 수 있습니다.

입력을 시작하면 제목 끝의 숫자가 남은 글자 수를 셉니다. 제한을 넘은 글자는 강조 표시됩니다.

설명 아래쪽의 다른 버튼은 두 가지 줄 바꿈 방식을 서로 바꿉니다.

- :ui[editor.softWrap]은 필드 가장자리에서 줄을 바꿉니다.
- :ui[editor.hardWrap]은 고정폭 서체를 쓰고 줄을 바꾸지 않습니다. 안내선이 글자 수 제한을 표시하고, 더 긴 줄은 강조 표시됩니다. 현재 단락을 제한에 맞춰 나누려면 :ui[menu.edit > commit.reformatParagraph](<kbd>⇧⌘W</kbd>)을 선택합니다.

다음 옵션은 :ui[app.name > settings.title] › :ui[settings.editor]에 있습니다.

| 설정 | 기본값 |
|---|---|
| :ui[editor.showsCounter] | 켬 |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72. :ui[editor.hardWrap]을 선택했을 때 바꿀 수 있습니다. |
| :ui[editor.showsGuide] | 켬. :ui[editor.hardWrap]과 함께 쓰입니다. |
| :ui[editor.warnsComments] | 켬. [메시지 안의 주석](#comments)을 참고하세요. |
| :ui[editor.stripsComments] | 끔. 경고를 껐을 때 사용할 수 있습니다. |
| :ui[editor.completesIssues] | 켬. [자동 완성](#autocomplete)을 참고하세요. |

[편집기](/guide/settings/appearance/#editor)를 참고하세요.

## 커밋하기 {#commit}

메시지가 준비되면 :ui[working.commit]을 클릭하거나, 메시지를 입력하는 중에 <kbd>⌘↩</kbd>을 누릅니다. 제목에 글이 있고 스테이지된 변경 사항이 있어야 버튼을 쓸 수 있습니다.

윈도우 어디에서든 제목으로 바로 가려면 :ui[workspace.title > working.commitMenu](<kbd>⇧⌘C</kbd>)을 선택합니다.

설명 아래의 체크상자 두 개는 커밋을 바꿉니다.

- :ui[commit.signOff]는 메시지 끝에 내 이름과 이메일이 들어간 `Signed-off-by` 줄을 추가합니다. 체크상자는 모든 저장소에서 마지막으로 둔 상태 그대로 유지됩니다.
- :ui[commit.skipHooks]는 저장소의 `pre-commit` 훅과 `commit-msg` 훅을 실행하지 않고 커밋합니다. 저장소에 이런 훅이 있을 때만 나타나고, 커밋할 때마다 다시 꺼집니다.

커밋에 실패하면 메시지는 커밋 영역에 그대로 남습니다. 방금 만든 커밋을 되돌리려면 :ui[menu.edit > menu.undo](<kbd>⌘Z</kbd>)를 선택합니다. [실행 취소와 복구](/guide/work/undo/)를 참고하세요.

### 메시지 안의 주석 {#comments}

주석 문자를 따로 설정하지 않았다면 Git은 `#`로 시작하는 줄을 주석으로 봅니다. Spooky는 메시지를 쓴 그대로 커밋하므로, 메시지에 이런 줄이 있으면 먼저 묻습니다. :ui[commit.comments]

- :ui[commit.removeComments]는 그 줄들을 빼고 커밋합니다.
- :ui[commit.keepComments]는 그 줄들을 그대로 커밋합니다.

:ui[commit.doNotAskAgain]을 선택하면 다음에도 같은 선택을 씁니다. 다시 묻게 하려면 :ui[app.name > settings.title] › :ui[settings.editor]에서 :ui[editor.warnsComments]를 켭니다. [편집기](/guide/settings/appearance/#editor)를 참고하세요.

메시지에 주석밖에 없으면 Spooky가 이렇게 묻습니다. :ui[commit.commentsOnly] 그래도 커밋하려면 :ui[commit.keepCommentsAndCommit]을 클릭합니다.

## 자동 완성 {#autocomplete}

제목이나 설명에 다음 중 하나를 입력하면, 이어서 입력하는 동안 Spooky가 일치하는 항목을 나열합니다.

| 입력 | 넣는 내용 |
|---|---|
| `c:` | 최근 커밋 100개 가운데 하나의 짧은 해시. 해시, 제목, 작성자의 일부를 입력합니다. |
| `\` | 스테이지된 파일의 경로 |
| `#` | GitHub 또는 GitLab에 열려 있는 이슈의 번호 |
| 제목 맨 앞의 `fixup!` 또는 `squash!` | 이전 커밋의 제목. 이 커밋을 그 커밋의 수정으로 표시합니다. |

::screenshot[c:를 입력한 뒤의 커밋 제목. 아래 목록에 최근 커밋이 작성자, 날짜, 짧은 해시, 제목과 함께 나열됩니다. 첫 번째 항목이 선택되어 있습니다.]{name="work-commit-completion" frame="closeup"}

<kbd>↑</kbd>나 <kbd>↓</kbd>로 항목을 고르고, <kbd>Return</kbd>으로 넣고, <kbd>Esc</kbd>로 목록을 닫습니다.

이슈 번호를 쓰려면 저장소의 원격에 맞는 [호스팅 계정](/guide/hosting/accounts/)이 있어야 하고, :ui[app.name > settings.title] › :ui[settings.editor]에서 :ui[editor.completesIssues]이 켜져 있어야 합니다. [편집기](/guide/settings/appearance/#editor)를 참고하세요. `fixup!`이나 `squash!`로 표시한 커밋은 나중에 대상 커밋에 합칠 수 있습니다. [기록 다시 쓰기](/guide/history/rewrite/)에서 설명합니다.

## 최근 커밋 수정하기 {#amend}

커밋 수정은 최근 커밋을 새 커밋으로 바꿉니다. 메시지를 고치거나 빠뜨린 변경 사항을 넣을 때 씁니다.

1. 설명 아래의 :ui[working.amend]을 선택합니다. Spooky가 최근 커밋의 메시지를 채워 넣고, 체크상자에 그 커밋의 짧은 해시가 표시됩니다.
2. 메시지를 편집하고, 넣을 변경 사항을 스테이지합니다.
3. :ui[working.amend]을 클릭합니다.

체크상자를 선택 해제하면 그 전에 쓰던 메시지로 돌아갑니다.

빠르게 수정하려면 두 메시지 필드 모두 편집 중이 아닐 때 <kbd>⌥</kbd>을 누르고 있습니다. 키를 놓을 때까지 커밋 영역이 최근 커밋 수정으로 바뀝니다. 키를 누른 채로 :ui[working.amend]을 클릭하거나 <kbd>⌥⌘↩</kbd>을 누릅니다. 커밋은 메시지를 그대로 두고 스테이지된 변경 사항을 받아들입니다.

:::caution
최근 커밋을 이미 푸시했다면, 수정한 커밋은 원격에 있는 커밋과 달라집니다. 그 커밋을 푸시하려면 강제 푸시가 필요합니다. [강제 푸시](/guide/branches/sync/#force-push)를 참고하세요.
:::

더 오래된 커밋을 바꾸려면 [기록 다시 쓰기](/guide/history/rewrite/)를 참고하세요.

## 커밋하는 사람 고르기 {#identity}

체크상자 오른쪽의 이름과 이메일이 커밋의 작성자로 기록됩니다. 이 값은 Git의 `user.name` 설정과 `user.email` 설정에서 옵니다. 그 옆의 사진은 이메일 주소로 찾습니다. [데이터와 개인정보 보호](/reference/data-privacy/)를 참고하세요.

회사 이메일처럼 다른 커미터 신원으로 커밋하려면 사용자 프로필을 사용합니다.

1. 사진을 클릭합니다. 메뉴에 프로필이 나열되고, 사용 중인 프로필 옆에 체크 표시가 있습니다.
2. 프로필을 선택합니다.
3. Spooky가 쓰려는 설정을 확인하고 :ui[profiles.apply.submit]을 클릭합니다.

프로필의 이름, 이메일, 서명 키는 이 저장소 자체의 Git 설정에 들어가므로 다른 저장소에는 영향이 없습니다.

현재 커미터 신원이 아직 프로필이 아니면 메뉴에 :ui[profiles.addCurrent]{1="alex@example.com"}가 나오고, 선택하면 프로필로 저장됩니다. 프로필을 설정하려면 같은 메뉴에서 :ui[profiles.manage]를 선택합니다. [사용자 프로필](/guide/settings/identity/#profiles)을 참고하세요.

:::note[서버 저장소]
프로필은 서버에 있는 저장소의 설정에 들어갑니다. 서버의 같은 저장소에서 커밋하는 다른 도구도 이 설정을 씁니다.
:::

## 커밋에 서명하기 {#signing}

서명된 커밋에는 키의 소유자가 만들었다는 증거가 들어 있습니다. Spooky는 SSH 키와 OpenPGP 키를 지원합니다.

커밋 영역의 사진 위에 포인터를 올려 두면 다음 커밋에 서명하는지, 어떤 키로 서명하는지 볼 수 있습니다.

- **모든 저장소**: :ui[app.name > settings.title] › :ui[settings.gitConfig]에서 :ui[gitConfig.signCommits]을 켜고 :ui[gitConfig.signingKey]를 선택합니다. [서명](/guide/settings/identity/#signing)을 참고하세요.
- **저장소 하나**: 사이드바에서 :ui[repositorySettings.title]을 클릭합니다. :ui[repositorySettings.signing] 아래에서 :ui[repositorySettings.signCommits]과 :ui[repositorySettings.signingKey]를 설정합니다. [저장소 설정](/guide/settings/identity/#repository)을 참고하세요.

키에 암호문이 필요하면 Spooky가 :ui[signing.unlock] 대화상자에서 암호문을 묻습니다.

## 함께 보기

- [변경 사항 검토하고 스테이지하기](/guide/work/diff/)
- [실행 취소와 복구](/guide/work/undo/)
- [사용자 프로필과 Git 구성](/guide/settings/identity/)

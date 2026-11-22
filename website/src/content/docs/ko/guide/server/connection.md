---
title: "연결 상태와 다시 연결"
description: "연결 상태, 암호와 암호문 입력 요청, 연결 끊김과 다시 연결, 연결이 끊긴 동안에도 볼 수 있는 내용을 알아봅니다."
---

서버 저장소는 SSH 연결에 의존합니다. 이 페이지는 연결되어 있는지 알아보는 방법, 서버가 묻는 질문의 의미, 연결이 끊겼을 때 일어나는 일을 설명합니다.

## 연결 상태 {#status}

서버 저장소에서는 각 목록 맨 위의 띠에 호스트 별칭과 연결 상태가 표시됩니다. 작업 사본, 기록, 스태시, Reflog, 파일 기록, 커밋의 파일 목록에서 볼 수 있습니다.

| 상태 | 의미 |
|---|---|
| :ui[connection.connecting] | Spooky가 연결을 여는 중입니다. |
| :ui[connection.connected] | 연결이 정상입니다. |
| :ui[connection.reconnecting] | 연결이 끊겨서 Spooky가 다시 시도하는 중입니다. |
| :ui[connection.unavailable] | 마지막 시도가 실패했습니다. Spooky가 5초 뒤에 다시 시도합니다. |

저장소가 연결되어 있지 않은 동안에는 띠가 노란색으로 바뀌고 더 많은 내용이 표시됩니다.

- Spooky가 마지막으로 성공한 스냅샷을 보여 주고 있으며, 연결이 복구될 때까지 쓰기가 비활성화된다는 안내.
- :ui[remoteError.unavailable] 같은 이유. 클릭하면 SSH의 원래 출력을 볼 수 있습니다.
- :ui[action.reconnect] 버튼. 상태가 :ui[connection.unavailable]일 때 표시됩니다.

::screenshot[연결이 끊긴 서버 저장소의 작업 사본 맨 위. 띠에 spooky-test: 사용 불가라고 적혀 있고 다시 연결 버튼이 있습니다. 그 아래에는 Spooky가 마지막으로 성공한 스냅샷을 보여 주고 있으며 연결이 복구될 때까지 쓰기가 비활성화된다는 안내가 있습니다. 접힌 줄에는 서버 연결 불가라고 적혀 있습니다.]{name="server-unavailable" frame="closeup"}

## 암호와 암호문 입력 요청 {#prompts}

Spooky는 아무것도 묻지 않고 서버에 로그인합니다. 하지만 서버의 Git에 답이 필요할 때가 있습니다. HTTPS로 원격에 푸시할 때의 암호가 그런 예입니다. Spooky는 그 질문을 Mac으로 전달해 대화상자로 보여 줍니다.

| 대화상자 | 나타나는 때 |
|---|---|
| :ui[callback.username.title], :ui[callback.password.title] | 원격이 사용자가 누구인지 묻습니다. 보통 HTTPS로 접속하는 원격에서 나타납니다. |
| :ui[callback.privateKey.title] | 서버가 원격에 사용하는 SSH 키가 암호문으로 보호되어 있습니다. |
| :ui[signing.unlock] | 커밋이나 태그에 서명하려면 Git에 서버에 있는 서명 키의 암호문이 필요합니다. |
| :ui[callback.editor] | Git이 메시지 같은 텍스트를 편집해 달라고 요청합니다. |

대화상자의 첫 줄에 서버 이름이 나옵니다. 개인 키 대화상자에는 서버에 있는 키의 경로도 표시됩니다.

사용자 이름이나 암호를 묻는 경우 :ui[callback.saveKeychain]을 선택하면 답을 보관합니다. 그 서버의 Git이 다음에 물으면 Spooky가 키체인에 있는 답으로 응답합니다. GitHub나 GitLab 계정을 추가해 두었다면 Spooky가 그 계정으로 먼저 응답합니다. [호스팅 계정](/guide/hosting/accounts/)을 참고하세요.

알아 둘 점은 다음과 같습니다.

- 각 대화상자는 2분 동안 기다립니다. 그 안에 답하지 않으면 Git은 답을 받지 못하고 명령이 실패합니다.
- 자동 가져오기는 묻지 않습니다. 계정과 키체인에 저장된 답만 사용합니다. 그것으로 부족하면 취소됩니다.
- 서버의 Git을 위한 암호문 대화상자는 서버에 OpenSSH 8.4 이상이 있어야 합니다.

## 연결 끊김과 다시 연결 {#reconnect}

연결이 끊기면 Spooky가 스스로 다시 연결합니다. 시도가 실패할 때마다 상태가 :ui[connection.unavailable]로 표시됩니다. Spooky는 5초 뒤에 다시 시도합니다. 바로 시도하려면 :ui[action.reconnect]을 클릭합니다. 연결이 돌아오면 Spooky가 저장소를 다시 불러옵니다.

연결이 끊겨도 변경 작업이 되풀이되지는 않습니다.

- 저장소의 대기열에서 기다리던 작업은 취소됩니다. 다시 연결된 뒤에도 실행되지 않습니다. 여전히 필요하면 다시 시작합니다.
- 연결이 끊겼을 때 실행 중이던 작업은 다시 시도하지 않습니다. 다시 연결된 뒤 Spooky가 브랜치, 변경 사항의 수, 인덱스 잠금, 병합이나 리베이스가 진행 중인지를 확인합니다.

확인 결과는 :ui[recovery.title] 대화상자에 나타납니다. 작업이 시작되기는 했는지, 현재 커밋이 움직였는지 알려 줍니다. 작업을 다시 시도하기 전에 결과를 살펴봅니다.

## 연결이 끊긴 동안 {#offline}

Spooky가 마지막으로 읽은 내용은 계속 볼 수 있습니다. 목록, 선택한 파일, 그 파일의 변경 사항입니다. 저장소를 바꾸는 동작은 연결이 돌아올 때까지 사용할 수 없습니다.

저장소를 열 때 서버에 접근할 수 없으면 윈도우에 :ui[missing.unreachable.title]{1="driftwood-server"}이 SSH의 출력과 함께 표시됩니다. 다시 시도하려면 :ui[action.refresh]을, 저장소 윈도우로 돌아가려면 :ui[action.close]를 클릭합니다.

:::tip
터미널에서 자신의 호스트 별칭을 넣어 `ssh -o BatchMode=yes driftwood-server git --version`을 실행합니다. 실패하면 문제는 Spooky가 아니라 Mac과 서버 사이에 있습니다. [Spooky가 연결하는 방식으로 테스트하기](/guide/server/prepare-ssh/#test)를 참고하세요.
:::

## 함께 보기

- [SSH 준비하기](/guide/server/prepare-ssh/)
- [서버 저장소 추가](/guide/server/add/)
- [서버 저장소의 동작 방식](/guide/server/overview/)

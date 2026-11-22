---
title: "시스템 요구 사항"
description: "Spooky가 macOS, Git, 서버에 요구하는 사항을 확인합니다."
---

이 페이지에는 Mac과 연결할 서버에서 Spooky에 필요한 것이 나와 있습니다.

## Mac {#mac}

| 항목 | 요구 사항 |
|---|---|
| macOS | macOS 26 이상 |
| Git | Git 2.41.0 이상. :ui[app.name > settings.title] › :ui[settings.gitConfig]의 :ui[settings.gitProgram] 옆에서 다른 것을 선택하지 않으면 Spooky는 `/usr/bin/git`을 사용합니다. [Git 프로그램](/guide/settings/identity/#git-program)을 참고하세요. |
| SSH | macOS에 포함된 SSH. 서버 저장소가 이것으로 연결합니다. |

Spooky는 Git 2.41.0에서 추가된 기능을 사용하므로 그보다 오래된 버전에서는 동작하지 않습니다.

## 서버 {#servers}

서버는 Linux 컴퓨터일 수도, Mac일 수도 있습니다. Spooky는 서버에서 관리자 권한이 필요하지 않으며 서비스를 설치하지 않습니다.

| 항목 | 요구 사항 |
|---|---|
| 로그인 | Mac의 `~/.ssh/config`에 있는 호스트 별칭을 통한 키 기반 SSH 로그인. 암호로만 로그인할 수 있는 계정은 사용할 수 없습니다. [SSH 준비하기](/guide/server/prepare-ssh/)를 참고하세요. |
| Git | Git 2.41.0 이상. 비대화형 SSH 로그인이 사용하는 `PATH`에 있어야 합니다 |
| SSH 서버 | SFTP가 켜져 있고 Unix 소켓 전달이 허용된 OpenSSH. 둘 다 기본적으로 켜져 있습니다. `MaxSessions`는 10 이상이어야 하며, 이것도 기본값입니다. |
| 암호문 입력 요청 | 서버의 Git이 SSH 키의 암호문을 요구한다면 OpenSSH 8.4 이상 |
| Perl | 표준 모듈 `IO::Socket::UNIX`, `JSON::PP`, `POSIX`, `Fcntl`이 있는 `/usr/bin/perl` |
| 파일 | 서버 홈 폴더의 `~/.spooky/bin`과 `/tmp`에 대한 쓰기 권한 |
| 휴지통 | 선택 사항. Mac에서는 macOS 15 이상에 포함된 `/usr/bin/trash`를 사용합니다. Linux에서는 `gio` 또는 `trash-put`을 사용합니다. 없으면 Spooky가 먼저 물어본 다음 파일을 완전히 삭제합니다. |

저장소를 추가하기 전에 서버가 무엇을 제공하는지 보려면 [SSH 준비하기](/guide/server/prepare-ssh/#test)의 테스트를 실행합니다. :ui[app.name > settings.title] › :ui[settings.environment]에서 서버를 확인할 수도 있습니다. [서버 확인하기](/guide/settings/general/#server-check)를 참고하세요.

## 선택 사항 {#optional}

| 사용하려는 기능 | 필요한 것 |
|---|---|
| Git LFS | Git LFS 2.9.0 이상. 저장소가 있는 컴퓨터에서 Git이 사용하는 `PATH`에 있어야 합니다 |
| sshfs 마운트 | Mac에 sshfs와 macFUSE 또는 FUSE-T |
| SMB 마운트 | 서버의 SMB 파일 공유 |
| 풀 리퀘스트와 머지 리퀘스트 | github.com이나 GitLab.com의 계정, 또는 자체 관리형 GitLab 9.0 이상의 계정 |

## 함께 보기

- [Spooky 설치하기](/guide/start/install/)
- [서버 저장소의 동작 방식](/guide/server/overview/)
- [데이터와 개인정보 보호](/reference/data-privacy/)

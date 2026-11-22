---
title: "사용 설명서"
description: "이 사용 설명서의 구성과 어디서부터 읽으면 좋은지 알아봅니다."
---

이 사용 설명서는 Spooky에서 일상적인 Git 작업을 하는 방법을 설명합니다. Mac에 있는 저장소와, 다른 컴퓨터에 그대로 두고 SSH로 접속하는 저장소를 모두 다룹니다. 각 페이지는 한 가지 작업 영역을 다루고, 그 페이지로 무엇을 할 수 있는지부터 설명합니다.

Spooky를 처음 사용한다면 “시작하기”의 페이지를 순서대로 읽습니다. 저장소가 서버에 있다면 이어서 “서버 저장소”를 읽습니다.

Spooky에서 :ui[menu.help > help.help](<kbd>⌘?</kbd>)을 선택하면 이 웹사이트가 열립니다. 많은 대화상자에도 도움말 버튼이 있습니다. 이 버튼은 사용 설명서에서 해당 대화상자를 설명하는 부분을 엽니다.

## 사용 설명서의 구성 {#organization}

| 그룹 | 다루는 내용 |
|---|---|
| [시작하기](/guide/start/install/) | Spooky 설치와 업데이트, 윈도우의 구성, 첫 커밋과 푸시 |
| [저장소 관리](/guide/repositories/manager/) | 저장소 정리, 윈도우와 탭, 뒤로 및 앞으로 이동, 빠른 동작 |
| [서버 저장소](/guide/server/overview/) | Spooky가 서버의 저장소를 다루는 방식, SSH 준비, 서버 저장소 추가, 연결, 이 Mac의 위치 |
| [일상 작업](/guide/work/working-copy/) | 작업 사본, 변경 사항 검토와 스테이지, 커밋, 스태시, 충돌, 실행 취소 |
| [기록](/guide/history/browse/) | 기록 살펴보기, 커밋 세부사항, 파일 기록과 Blame, 기록 다시 쓰기 |
| [브랜치와 동기화](/guide/branches/branches/) | 브랜치, 태그와 원격, 가져오기와 풀과 푸시, 병합과 리베이스, 브랜치 정리 |
| [협업](/guide/hosting/accounts/) | 호스팅 계정, 풀 리퀘스트, 머지 리퀘스트 |
| [그 밖의 Git 기능](/guide/advanced/submodules/) | 하위 모듈, 작업 트리, Git LFS, 작업이 대기열에 쌓이는 방식 |
| [설정과 통합](/guide/settings/general/) | 설정, 모양과 테마, 사용자 프로필과 Git 구성, 다른 앱과 함께 쓰기 |
| [참고 자료](/reference/shortcuts/) | 키보드 단축키, 시스템 요구 사항, 데이터와 개인정보 보호, 문제 해결 |

## 표기 규칙 {#conventions}

### 화면에 표시되는 이름 {#names}

버튼, 메뉴, 옵션, 윈도우의 이름은 :ui[working.commit]처럼 굵게 표시합니다. 이 이름은 Spooky에서 그대로 가져온 것입니다. Spooky를 이 페이지와 같은 언어로 실행하면 화면에서도 같은 이름이 보입니다.

:ui[menu.file > action.openLocal] 같은 메뉴 경로는 메뉴 막대에서 첫 번째 이름을 클릭한 다음, 그 메뉴에서 다음 이름을 선택한다는 뜻입니다.

일부 페이지에는 **시스템 설정**처럼 macOS의 이름도 나옵니다. 이런 이름은 macOS에 표시되는 대로 적습니다.

### 키보드 단축키 {#shortcuts}

단축키는 <kbd>⇧⌘A</kbd>처럼 키 모양으로 표시합니다. 보조 키를 누른 채로 마지막 키를 누릅니다. 기호는 macOS가 메뉴에 표시하는 것과 같습니다.

| 기호 | 키 |
|---|---|
| <kbd>⌘</kbd> | Command |
| <kbd>⇧</kbd> | Shift |
| <kbd>⌥</kbd> | Option |
| <kbd>⌃</kbd> | Control |
| <kbd>↩</kbd> | Return |
| <kbd>⌫</kbd> | Delete |

모든 단축키는 [키보드 단축키](/reference/shortcuts/)에 정리되어 있습니다.

### 서버 저장소에 관한 참고 {#server-notes}

서버 저장소는 다른 컴퓨터에 그대로 있고, Spooky가 SSH로 엽니다. 대부분의 작업은 서버 저장소에서도 같은 방식으로 합니다. 다른 점이 있으면 해당 페이지에서 아래와 같은 참고로 알려 줍니다.

:::note[서버 저장소]
이 제목이 붙은 참고는 서버 저장소에서 무엇이 다른지 알려 줍니다. Mac에 있는 저장소만 사용한다면 건너뛰어도 됩니다.
:::

## 함께 보기

- [Spooky 설치하기](/guide/start/install/)
- [Spooky 둘러보기](/guide/start/tour/)
- [서버 저장소의 동작 방식](/guide/server/overview/)

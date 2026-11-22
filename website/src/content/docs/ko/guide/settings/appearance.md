---
title: "모양과 테마"
description: "모양을 고르고, 내장 테마를 쓰거나 직접 만들어 가져오고 내보내고, 텍스트와 편집기 옵션을 설정하고, 앱 아이콘을 고르는 방법을 알아봅니다."
---

:ui[app.name > settings.title]의 네 페이지가 Spooky의 모습을 정합니다. :ui[settings.appearance]은 앱 전체, :ui[settings.themes]는 Diff와 파일의 색상, :ui[settings.text]는 텍스트 표시 방식, :ui[settings.editor]는 커밋 메시지를 담당합니다.

## 모양 {#appearance}

:ui[settings.appearance.label] 행의 그림을 클릭하면 앱 전체가 바뀝니다.

- :ui[appearance.system]은 macOS를 따릅니다. 기본값입니다.
- :ui[appearance.light]와 :ui[appearance.dark]는 macOS의 설정과 상관없이 그대로 유지됩니다.

개별 저장소 윈도우에서는 [빠른 동작](/guide/repositories/navigation/#quick-actions)으로도 전환할 수 있습니다. 모양을 찾아 :ui[quickActions.setAppearance]을 실행합니다.

## 앱 아이콘 {#app-icon}

모양 아래의 :ui[settings.appIcon.label]에는 고를 수 있는 아이콘이 두 시리즈로 나옵니다.

| 시리즈 | 아이콘 |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise](기본값), :ui[appIcon.front], :ui[appIcon.hide], :ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight], :ui[appIcon.perch], :ui[appIcon.cherryPick], :ui[appIcon.armful] |

아이콘에 포인터를 올리면 왼쪽에 크게 표시됩니다. 그 아래에는 Dock에 나타나는 네 가지 모습이 있습니다. 기본 상태, 서버에 연결된 상태, 다크, 연결된 상태의 다크입니다. 아이콘을 클릭하면 그 아이콘을 사용합니다. 아이콘에 키보드 초점이 있을 때는 화살표 키로 아이콘 사이를 이동하고 <kbd>스페이스 바</kbd>로 현재 아이콘을 사용합니다.

새 아이콘은 Spooky가 실행 중이 아닐 때도 Dock, 앱 전환기(<kbd>⌘Tab</kbd>), Finder에 표시됩니다. 알아 둘 점은 다음과 같습니다.

- 서버 저장소가 연결되어 있는 동안에는 아이콘에 불이 들어옵니다. :ui[appIcon.series.hideAndSeek] 아이콘에서는 서버의 표시등이 켜집니다. :ui[appIcon.series.cherryPick] 아이콘에서는 유령의 눈이 빛나는 별로 바뀝니다.
- 다크 버전은 **시스템 설정 › 모양**의 아이콘 및 위젯 스타일이 다크이거나, 자동이면서 Spooky가 다크일 때 표시됩니다. 투명 또는 색조 스타일에서는 아이콘에 불이 들어오지 않습니다.
- 아이콘을 :ui[appIcon.rise]으로 바꾸거나 그 아이콘에서 다른 아이콘으로 바꾸면 Dock이 한 번 재시작됩니다. 그러지 않으면 Dock에 유지된 Spooky가 계속 이전 아이콘을 표시합니다.
- 그 밖의 아이콘은 Spooky가 `Spooky.app` 안에 저장합니다. 거기에 쓸 수 없으면 페이지에 이유가 표시되고 아이콘은 바뀌지 않습니다.

## 테마 {#themes}

테마는 Diff와 파일 내용에 쓰는 서체와 색상을 정합니다. Spooky에는 두 가지가 들어 있습니다. 라이트 모양용 Default와 다크 모양용 Default (Dark)입니다.

목록에서 선택된 테마가 현재 모양이 사용하는 테마입니다. 라이트와 다크는 각자의 테마를 기억합니다. 다른 모양의 테마를 정하려면 먼저 그 모양으로 전환합니다. 빠른 동작에서도 :ui[quickActions.applyTheme]으로 테마를 전환할 수 있습니다.

::screenshot[설정 윈도우의 테마 페이지. 왼쪽 목록에 Default와 Default (Dark)가 있고 Default가 선택되어 있으며, 아래쪽에 추가 버튼과 제거 버튼이 있습니다. 오른쪽에는 Menlo-Regular 11.0이 적힌 서체 필드, 일반 텍스트, 키워드, 문자열, 주석 등 각자의 색상으로 표시된 텍스트 종류 목록, 서체 색상, 배경, 선택 영역, 추가, 삭제 레이블이 붙은 색상 저장소가 있습니다. 그 아래에는 변경되지 않은 줄, 삭제된 줄, 추가된 줄이 있는 짧은 Diff 미리보기가 있습니다.]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 66.7,56.9 61.1,82.7"}

1. 테마 목록
2. :ui[themes.add]와 :ui[themes.remove]
3. 서체
4. 구문 색상이 구분하는 텍스트 종류
5. 색상 저장소
6. 이 테마로 표시한 Diff 미리보기

### 테마 만들고 편집하기 {#edit-theme}

1. 목록 아래의 추가 버튼을 클릭합니다. Spooky가 현재 모양의 내장 테마 색상으로 :ui[themes.newName]를 추가하고 그 이름을 선택합니다.
2. 이름을 입력하고 <kbd>Return</kbd>을 누릅니다.
3. 서체 필드를 클릭해 서체 패널에서 서체와 크기를 고릅니다.
4. 목록에서 텍스트 종류를 선택한 다음 :ui[themes.text]을 클릭해 색상을 바꿉니다. :ui[themes.background], :ui[themes.selection], :ui[themes.added], :ui[themes.deleted]는 텍스트 주변의 색상을 정합니다.

변경 내용은 바로 저장됩니다. 미리보기에 바로 반영됩니다. 나중에 테마의 이름을 바꾸려면 테마를 선택하고 <kbd>Return</kbd>을 누릅니다.

내장 테마는 편집할 수 있지만 이름을 바꾸거나 삭제할 수는 없습니다. 다른 테마를 삭제하려면 선택하고 제거 버튼을 클릭합니다. 실행 취소할 수 없으므로 Spooky가 먼저 묻습니다. 그 테마를 쓰던 모양은 내장 테마로 돌아갑니다.

### 테마 공유하기 {#share-themes}

각 테마는 `.spookytheme` 파일입니다.

- **내보내기**: 목록의 테마를 Finder의 폴더로 드래그합니다.
- **가져오기**: `.spookytheme` 파일을 목록으로 드래그합니다. Finder에서 열거나 Dock의 Spooky 아이콘에 놓아도 됩니다.

같은 이름의 테마가 있으면 Spooky가 대체할지 묻습니다. 올바른 테마가 아닌 파일은 메시지와 함께 건너뜁니다.

Spooky는 테마를 `~/Library/Application Support/Spooky/Themes/`에 보관합니다. [데이터와 개인정보 보호](/reference/data-privacy/#mac)를 참고하세요.

## 텍스트 {#text}

:ui[settings.text] 페이지에서 Diff와 파일 내용의 텍스트 모습을 정합니다. 색상은 테마에서 가져옵니다.

| 설정 | 기본값 | 하는 일 |
|---|---|---|
| :ui[text.enableSyntaxColoring] | 켬 | 코드를 언어에 맞게 색칠합니다 |
| :ui[text.syntaxColoringInDiffs] | 끔 | Diff에도 구문 색상을 씁니다. 구문 색상이 켜져 있어야 합니다. |
| :ui[text.showInvisibles] | 끔 | 공백, 탭, 줄 끝을 기호로 표시합니다 |
| :ui[text.tabWidth] | 4 | 탭의 너비. 공백 1–100개입니다 |

## 편집기 {#editor}

:ui[settings.editor] 페이지에서 커밋 메시지 필드를 설정합니다. 필드의 동작은 [메시지 쓰기](/guide/work/commit/#write)를 참고하세요.

| 설정 | 기본값 | 하는 일 |
|---|---|---|
| :ui[editor.showsCounter] | 켬 | 제목에 남은 글자 수를 거꾸로 셉니다 |
| :ui[editor.subjectLimit] | 50 | 제목의 권장 최대 글자 수. 값을 고르거나 1–1,000 사이의 값을 입력합니다. |
| :ui[editor.wrapping] | :ui[editor.softWrap] | 또는 :ui[editor.hardWrap]. 고정폭 서체를 쓰고 자동으로 줄을 바꾸지 않습니다 |
| :ui[editor.bodyLimit] | 72 | :ui[editor.hardWrap]의 줄 길이 제한 |
| :ui[editor.showsGuide] | 켬 | :ui[editor.hardWrap]에서 그 제한 위치에 선을 그립니다 |
| :ui[editor.warnsComments] | 켬 | Git이 주석으로 처리할 줄이 있으면 경고합니다. [메시지 안의 주석](/guide/work/commit/#comments)을 참고하세요. |
| :ui[editor.stripsComments] | 끔 | 커밋할 때 그런 줄을 제거합니다. 경고가 꺼져 있을 때 사용할 수 있습니다. |
| :ui[editor.completesIssues] | 켬 | `#` 뒤의 이슈 번호를 자동 완성합니다. [자동 완성](/guide/work/commit/#autocomplete)을 참고하세요. |

## 함께 보기

- [일반, 업데이트, 환경](/guide/settings/general/)
- [변경 사항 검토하고 스테이지하기](/guide/work/diff/)
- [변경 사항 커밋하기](/guide/work/commit/)
- [윈도우와 탐색](/guide/repositories/navigation/)

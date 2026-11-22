---
title: "브랜치 검토"
description: "로컬 브랜치를 기준 브랜치와 비교하고, 정리해도 되는 브랜치를 찾고, 보관 제안을 따르고, 브랜치를 자동으로 보관합니다."
---

브랜치 검토는 로컬 브랜치를 나열하고 각각을 기준 브랜치와 비교합니다. 어떤 브랜치를 병합할 수 있는지, 어떤 브랜치가 충돌하는지, 어떤 브랜치가 오래되었는지, 어떤 브랜치의 원격 브랜치가 없어졌는지 보여 줍니다. 무엇을 병합하고, 보관하고, 삭제할지 정하는 데 도움이 됩니다.

열려면 사이드바 맨 위의 :ui[review.title]를 클릭하거나 :ui[menu.view > review.show](<kbd>⌘5</kbd>)를 선택합니다.

::screenshot[브랜치 검토 윈도우. 기준 브랜치는 main입니다. 목록에는 feature/csv-export부터 spike/radar-overlay까지 브랜치 여섯 개가 있고, 각각 병합 상태, 앞서거나 뒤처진 커밋 수, 추적하는 브랜치가 표시됩니다. feature/units-toggle이 선택되어 있고, 오른쪽의 세부사항에 그 브랜치의 커밋과 충돌 버튼이 표시됩니다.]{name="branches-review" frame="window" markers="41.8,9 47.3,9 22,52 76,9"}

1. 기준 브랜치
2. 필터 버튼
3. 브랜치를 충돌 없이 병합할 수 있는지 여부
4. 충돌 버튼

## 목록 {#list}

목록 맨 위의 :ui[review.compareTo]에서 기준 브랜치를 고릅니다. 처음에는 `next`, `develop`, `dev`, `main`, `master` 중 저장소에 있는 첫 번째 브랜치이고, 없으면 현재 브랜치입니다.

브랜치마다 한 행이 있습니다.

- 왼쪽의 아이콘은 브랜치를 기준 브랜치에 충돌 없이 병합할 수 있는지, 충돌이 생기는지 알려 줍니다. 포인터를 올려 두면 자세한 내용이 나옵니다.
- 오른쪽에는 브랜치가 기준 브랜치보다 커밋 몇 개만큼 앞서고 뒤처져 있는지 나옵니다. Spooky가 비교하는 동안에는 :ui[review.comparing]이라고 표시됩니다.
- 둘째 줄에는 추적하는 원격 브랜치 또는 :ui[review.noTracking]이 표시됩니다. 원격 브랜치가 없어지면 이름이 빨간색으로 바뀝니다.
- 브랜치가 마지막으로 업데이트된 때와 브랜치의 최신 풀 리퀘스트 또는 머지 리퀘스트가 번호, 상태를 나타내는 색상과 함께 표시됩니다.

## 필터링과 정렬 {#filter}

오른쪽 위의 필터 버튼으로 브랜치 일부만 표시합니다.

- :ui[review.filter.stale]과 :ui[review.filter.active]은 브랜치를 오래되었는지에 따라 나눕니다. 오래되었다는 것은 사이드바의 [보기 설정](/guide/branches/branches/#filter)에서 정한 기간 동안 새 커밋이 없다는 뜻이며, 처음에는 6개월입니다.
- :ui[review.filter.trackingError]는 원격 브랜치가 없어진 브랜치를 표시합니다.
- :ui[review.filter.mergeable]과 :ui[review.filter.conflicts]은 기준 브랜치에 병합하면 어떻게 되는지에 따라 나눕니다.
- :ui[pr.filter.with]과 :ui[pr.filter.without]은 열려 있는 풀 리퀘스트나 머지 리퀘스트가 있는지에 따라 나눕니다. 원격의 [호스팅 계정](/guide/hosting/accounts/)이 필요합니다. 계정이 없으면 목록에 그렇게 표시됩니다.
- :ui[review.filter.none]은 모든 브랜치를 다시 표시합니다.

그 옆의 보기 설정 버튼은 목록을 :ui[review.sort.name] 또는 :ui[review.sort.date] 기준으로, :ui[review.sort.ascending] 또는 :ui[review.sort.descending]으로 정렬합니다. Spooky는 필터와 정렬 순서를 모두 기억합니다.

이름으로 브랜치를 찾으려면 도구 막대의 검색 필드에 입력합니다.

## 세부사항 {#details}

브랜치를 선택하면 오른쪽에 기준 브랜치와 비교한 결과가 표시됩니다. 맨 위에는 브랜치와 기준 브랜치가 나옵니다. 병합하면 충돌이 생기는 경우에는 거기에 있는 버튼이 해당 파일을 나열합니다.

:ui[compare.commits]은 브랜치가 기준 브랜치에서 갈라진 뒤에 만든 커밋을 나열합니다. :ui[history.changeset]는 그 커밋들이 무엇을 바꿨는지 보여 줍니다. 둘 위의 요약에는 :ui[review.summary.contributors], :ui[review.summary.updated], :ui[review.summary.tracking], :ui[review.summary.mergeStatus]가 표시됩니다.

브랜치 여러 개를 한꺼번에 선택할 수 있습니다. 예를 들어 함께 보관하거나 삭제할 때 씁니다.

## 브랜치 다루기 {#actions}

브랜치를 오른쪽 클릭하면 사이드바와 같은 메뉴가 나옵니다. 브랜치를 여러 개 선택하면 메뉴가 모두에 적용됩니다.

브랜치가 기준 브랜치와 충돌하면 메뉴에 :ui[review.resolveConflicts]도 있습니다. Spooky가 브랜치를 체크아웃하고 기준 브랜치를 거기에 병합합니다. 그런 다음 브랜치에서 충돌을 해결합니다. [충돌 해결하기](/guide/work/conflicts/)를 참고하세요.

브랜치를 삭제하려면 브랜치를 선택하고 <kbd>⌘⌫</kbd>를 누르거나, 행을 왼쪽으로 쓸어넘기고 :ui[review.delete]를 클릭합니다. Spooky는 사이드바에서와 마찬가지로 먼저 물어봅니다.

## 보관 제안 {#archive-suggestions}

Spooky는 다음과 같은 경우에 로컬 브랜치를 [보관](/guide/branches/branches/#archive)하도록 제안합니다.

- 브랜치가 오래된 경우
- 브랜치의 풀 리퀘스트나 머지 리퀘스트가 병합되었고, 그 뒤로 브랜치에 새 커밋이 없는 경우

고정한 브랜치와 보관한 브랜치는 제안하지 않습니다. `main`, `master`, `trunk`, `dev`, `develop`, `next`와 다른 브랜치의 부모인 브랜치도 제안하지 않습니다.

제안이 있고 자동 보관이 꺼져 있으면 사이드바 맨 아래에 브랜치 수가 적힌 버튼이 나타납니다. 클릭하면 :ui[review.archive.title]이 열립니다.

1. 보관할 브랜치를 선택하거나 :ui[menu.selectAll]을 선택합니다. 처음에는 아무것도 선택되어 있지 않습니다. 브랜치마다 제안된 이유가 표시됩니다. :ui[pr.archive.merged] 또는 :ui[review.filter.stale]입니다.
2. :ui[review.archive.submit]을 클릭합니다.

::screenshot[브랜치 보관 대화상자에 브랜치 세 개가 나열되어 있습니다. 모두 오래됨으로 표시되어 있고 하나가 선택되어 있습니다. 맨 아래에는 브랜치를 자동으로 보관하는 스위치가 있습니다.]{name="branches-archive" frame="dialog"}

보관한 뒤에는 사이드바 맨 아래에 브랜치를 몇 개 보관했는지 알려 주는 메모가 :ui[review.archived.undo] 버튼과 함께 나타납니다. <kbd>⌘Z</kbd>도 쓸 수 있습니다. :ui[activity.title]에는 각 브랜치를 보관한 이유가 기록됩니다.

## 자동으로 보관하기 {#auto-archive}

Spooky는 하루에 한 번 보관할 브랜치가 있는지 확인할 수 있습니다. 다음 중 어느 것으로든 켤 수 있습니다. 모두 같은 설정입니다.

- :ui[review.archive.title] 대화상자의 :ui[review.archive.auto]
- 사이드바 보기 설정의 :ui[sidebar.autoArchive]
- :ui[app.name > settings.title] › :ui[settings.general]의 :ui[settings.autoArchive]([작업](/guide/settings/general/#operations) 참고)

처음에는 꺼져 있습니다.

Spooky는 저장소마다 하루에 한 번, 그 저장소의 윈도우에서 작업하는 동안 제안을 찾습니다. 제안이 있으면 같은 대화상자를 엽니다. 거기에서 보관할 브랜치를 고릅니다. 보관하든 하지 않든 하루 뒤에 다시 확인합니다.

브랜치를 여기에서 제외하려면 브랜치를 오른쪽 클릭하고 메뉴의 보관 항목 아래에 있는 :ui[review.skipAutoArchive]를 선택합니다.

이렇게 브랜치가 보관되면 다음과 같이 됩니다.

- 알림에 :ui[review.archived.notification]이라고 표시됩니다. :ui[activity.title]의 기록 이름은 :ui[review.autoArchive]입니다.
- 사이드바의 :ui[sidebar.archived] 옆에 있는 점은 아직 살펴보지 않은 브랜치가 있다는 표시입니다. 그런 브랜치를 클릭하면 잠시 뒤에 표시가 사라집니다. 모두 지우려면 :ui[sidebar.archived]를 오른쪽 클릭하고 :ui[sidebar.markAllReviewed]를 선택합니다.

## 함께 보기

- [브랜치](/guide/branches/branches/)
- [병합과 리베이스](/guide/branches/merge-rebase/)
- [풀 리퀘스트와 머지 리퀘스트](/guide/hosting/pull-requests/)
- [호스팅 계정](/guide/hosting/accounts/)

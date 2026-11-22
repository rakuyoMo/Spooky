---
title: "하위 모듈"
description: "하위 모듈을 열고, 업데이트하고, 가져오고, 초기화하고, 동기화하고, 이동하고, 이름을 바꾸고, 삭제합니다."
---

하위 모듈은 저장소의 폴더 안에 있는 또 다른 Git 저장소입니다. 저장소는 하위 모듈의 어느 커밋을 쓸지 기록합니다. Spooky는 이 기록을 하위 모듈 포인터라고 부릅니다.

## 사이드바에서 {#sidebar}

하위 모듈은 사이드바의 :ui[submodule.group] 아래에 경로순으로 나열됩니다. 포인터를 올려 두면 이름과 URL이 표시됩니다.

- 흐린 행은 아직 체크아웃되지 않은 하위 모듈입니다.
- 경고 아이콘은 구성이 불완전하거나 URL을 동기화해야 한다는 뜻입니다.
- 숫자는 그 안에서 바뀐 파일의 개수입니다.
- ↑와 ↓는 체크아웃된 커밋이 포인터보다 얼마나 앞서거나 뒤처져 있는지 보여 줍니다.

하위 모듈을 클릭하면 세부사항이 표시됩니다. 체크아웃된 하위 모듈을 이중 클릭하면 같은 윈도우에서 저장소로 열립니다. 열려 있는 동안 도구 막대의 :ui[toolbar.parentRepository]를 클릭하면 돌아갑니다.

작업 사본의 파일 목록에서 체크아웃된 하위 모듈을 이중 클릭해도 같은 방식으로 열립니다. 이 이중 클릭이 다른 파일처럼 열게 하려면 :ui[app.name > settings.title] › :ui[settings.general]에서 :ui[files.openSubmodules]를 끕니다. [파일 목록](/guide/settings/general/#file-list)을 참고하세요.

## 세부사항 {#details}

세부사항은 세 페이지로 되어 있고, 맨 위에서 고릅니다.

- :ui[submodule.page.general]: 이름, 경로, 상태, 로컬 변경, 체크아웃된 커밋, 포인터, 적용 중인 설정. 하위 모듈이 초기화되지 않았거나 `.gitmodules`의 URL이 바뀌었으면 맨 위의 안내에 이를 해결하는 버튼이 있습니다.
- :ui[submodule.page.shared]: `.gitmodules`에 있는 설정. 저장소를 복제하는 모든 사람이 받습니다. 여기에서 바꾼 내용은 작업 사본에 나타납니다. 다른 변경처럼 커밋합니다.
- :ui[submodule.page.local]: 이 저장소 자체의 구성에 있는 설정. 여기에만 적용됩니다. `.gitmodules`보다 우선합니다.

두 구성 페이지에서는 하위 모듈의 이름을 바꾸고, 이동하고, URL을 바꾸고, 옵션 세 가지를 설정할 수 있습니다. :ui[submodule.useDefault]은 옵션을 제거합니다. 그러면 Git의 기본값이 적용됩니다.

- :ui[submodule.field.fetchMode]: 상위 저장소를 가져올 때 이 하위 모듈도 가져올지 정합니다. :ui[submodule.fetchMode.always], :ui[submodule.fetchMode.onDemand](가져온 커밋이 포인터를 바꿀 때만, 기본값), :ui[submodule.fetchMode.never] 가운데 선택합니다.
- :ui[submodule.field.ignoreMode]: 상위 저장소의 작업 사본이 하위 모듈의 어떤 변경을 무시할지 정합니다. :ui[submodule.ignoreMode.none](기본값), :ui[submodule.ignoreMode.untracked], :ui[submodule.ignoreMode.dirty](다른 커밋이 체크아웃된 경우만 변경으로 봄), :ui[submodule.ignoreMode.all] 가운데 선택합니다.
- :ui[submodule.field.updateStrategy]: 업데이트가 하위 모듈을 포인터에 맞추는 방법을 정합니다. :ui[submodule.updateStrategy.checkout](기본값), 현재 브랜치에 대한 :ui[submodule.updateStrategy.rebase] 또는 :ui[submodule.updateStrategy.merge], :ui[submodule.updateStrategy.none] 가운데 선택합니다.

## 하위 모듈 추가하기 {#add}

1. 메뉴 막대에서 :ui[menu.repository > menu.addSubmodule]를 선택합니다. 사이드바 맨 아래의 추가 버튼을 클릭하거나 :ui[submodule.group]을 오른쪽 클릭하고 메뉴에서 :ui[submodule.add.menu]를 선택해도 됩니다.
2. 하위 모듈 저장소의 URL을 입력합니다.
3. :ui[submodule.path] 항목에서 :ui[submodule.path.select]을 선택하고 저장소 안의 빈 폴더를 고릅니다.
4. :ui[submodule.add.submit]를 클릭합니다.

삭제한 하위 모듈이 남긴 것처럼, 저장소에 같은 이름의 하위 모듈 Git 디렉터리가 이미 있으면 Spooky가 어떻게 할지 묻습니다. :ui[submodule.forceAdd.reuse]은 그 디렉터리를 다시 씁니다. :ui[submodule.forceAdd.overwrite]는 삭제하고 다시 복제합니다.

## 가져오기와 업데이트 {#update}

- **가져오기**는 하위 모듈의 원격에서 새 커밋을 내려받습니다. 체크아웃된 내용은 바뀌지 않습니다.
- **업데이트**는 포인터가 기록한 커밋을 체크아웃합니다. 초기화되지 않은 하위 모듈은 먼저 초기화됩니다.

하위 모듈을 오른쪽 클릭하고 메뉴에서 :ui[submodule.fetch.menu]{1="vendor/charts"}나 :ui[submodule.update.menu]{1="vendor/charts"}를 선택합니다. :ui[menu.repository] 메뉴에도 같은 항목이 있고, 모든 하위 모듈을 한 번에 처리하는 항목도 있습니다.

대화상자에는 다음 옵션이 있습니다.

- 가져올 때: :ui[sync.prune]
- 업데이트할 때: :ui[submodule.update.recursive]. 하위 모듈 안의 하위 모듈도 업데이트합니다. 그 원격은 이미 설정된 자격 증명으로 접근할 수 있어야 합니다. Spooky는 도중에 자격 증명을 물을 수 없습니다.

오른쪽 클릭 메뉴에서 <kbd>⌥</kbd>을 누르고 있으면 :ui[submodule.quickFetch]{1="vendor/charts"}와 :ui[submodule.quickUpdate]{1="vendor/charts"}가 나옵니다. 대화상자를 건너뛰고 지난번의 옵션을 씁니다. 메뉴 막대의 :ui[menu.fetchAllSubmodules]와 :ui[menu.updateAllSubmodules]도 그렇습니다.

업데이트는 할 일이 있을 때만 쓸 수 있습니다. 하위 모듈이 체크아웃되지 않았거나 다른 커밋이 체크아웃된 경우입니다.

### 다른 작업 뒤에 업데이트하기 {#auto-update}

체크아웃, 풀, 병합 등의 작업은 체크아웃된 하위 모듈의 포인터를 바꿀 수 있습니다. 그 뒤에 Spooky가 해당 하위 모듈을 업데이트할지 묻습니다. :ui[submodule.autoUpdate.always]를 선택하면 그때부터는 바로 업데이트합니다. :ui[app.name > settings.title] › :ui[settings.general]의 :ui[settings.autoUpdateSubmodules]로 다시 끌 수 있습니다. [작업](/guide/settings/general/#operations)을 참고하세요.

### 초기화와 동기화 {#initialize}

- **초기화**는 하위 모듈의 설정을 `.gitmodules`에서 저장소의 구성으로 복사합니다. 그 뒤에 업데이트하면 체크아웃됩니다.
- **동기화**는 `.gitmodules`의 URL이 바뀌었을 때 씁니다. 저장소 구성의 URL과 하위 모듈 자체 저장소의 URL을 새 URL에 맞춥니다.

둘 다 오른쪽 클릭 메뉴에 있고, 필요할 때는 :ui[submodule.page.general] 페이지의 안내에도 나옵니다.

## 다른 리비전 체크아웃하기 {#checkout}

체크아웃된 하위 모듈을 오른쪽 클릭하고 :ui[submodule.checkoutRevision]에서 하위 모듈의 브랜치나 태그를 선택합니다. 현재 것에는 체크 표시가 있습니다.

하위 모듈 안의 변경이 방해가 되면 체크아웃은 실패합니다. Spooky는 그 변경을 스태시할지 묻지 않습니다. 저장소의 스태시는 하위 모듈을 포함하지 않습니다.

저장소의 포인터는 하위 모듈의 새 커밋을 커밋할 때까지 움직이지 않습니다.

## 이동, 이름 변경, 삭제 {#manage}

세 가지 모두 오른쪽 클릭 메뉴에 있습니다.

- **이동**은 하위 모듈의 경로를 바꿉니다. :ui[submodule.move.rename]을 선택하면 이름도 새 경로로 바뀝니다.
- **이름 변경**은 이름을 바꿉니다. `.gitmodules`와 구성은 이 이름으로 하위 모듈을 가리킵니다. 폴더는 제자리에 남습니다.
- **삭제**는 하위 모듈을 저장소에서 제거합니다. :ui[submodule.delete.keepWorkingTree]를 선택하면 구성만 제거하고 파일은 남깁니다. 안에 변경이 있으면 Spooky가 묻고, :ui[submodule.forceDelete.submit]로 그래도 삭제할 수 있습니다.

이 작업들은 `.gitmodules`와 저장소의 인덱스를 바꿉니다. 다른 사람도 받도록 커밋합니다.

삭제한 뒤에도 하위 모듈의 Git 디렉터리는 저장소의 `.git` 폴더 안에 남습니다. 다시 추가할 때 재사용할 수 있습니다.

### 하위 모듈 복구하기 {#repair}

하위 모듈의 구성이 불완전하면 세부사항에 :ui[submodule.invalid]이라고 표시되고 버튼이 두 개 나옵니다. :ui[submodule.repair.submit]는 빠진 것을 복원합니다. `.gitmodules`의 항목, 포인터, 체크아웃된 저장소가 그 대상입니다. Spooky가 하위 모듈의 URL을 어디에서도 찾지 못하면 삭제하고 다시 추가합니다.

## 실행 취소 {#undo}

하위 모듈 추가, 이동, 이름 변경, 삭제, 하위 모듈에서 다른 리비전 체크아웃, URL이나 옵션 변경은 실행 취소할 수 있습니다. [실행 취소와 복구](/guide/work/undo/)를 참고하세요.

초기화, 동기화, 복구는 실행 취소할 수 없습니다. 이 가운데 하나를 한 뒤에는 그 전의 작업도 더는 실행 취소할 수 없습니다.

가져오기와 업데이트는 저장소의 가져오기, 풀과 마찬가지로 기록되지 않습니다. 그 전의 작업은 여전히 실행 취소할 수 있습니다.

:::note[서버 저장소]
이 모든 일은 서버에서 실행됩니다. 하위 모듈을 추가할 때는 서버에 있는 폴더를 고릅니다.
:::

## 함께 보기

- [가져오기, 풀, 푸시](/guide/branches/sync/)
- [작업 트리](/guide/advanced/worktrees/)
- [실행 취소와 복구](/guide/work/undo/)

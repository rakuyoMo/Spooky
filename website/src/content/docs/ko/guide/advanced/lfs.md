---
title: "Git LFS"
description: "Git LFS를 켜고, 파일과 패턴을 추적하고, LFS 콘텐츠를 가져오고 풀하고 푸시합니다."
---

Git LFS는 큰 파일을 저장소의 기록 밖에 둡니다. 저장소에는 파일마다 작은 포인터 파일이 저장됩니다. 내용은 원격의 LFS 저장 공간으로 갑니다.

Spooky는 저장소가 있는 컴퓨터에서 Git LFS를 실행합니다.

## 필요한 것 {#requirements}

Git LFS 2.9.0 이상이 저장소가 있는 컴퓨터에서 Git이 쓰는 `PATH`에 있어야 합니다.

확인하려면 사이드바의 :ui[workspace.group] 아래에서 :ui[repositorySettings.title]을 클릭합니다. :ui[repositorySettings.lfs] 섹션에 Git LFS의 :ui[lfs.version]이 표시됩니다. [Git LFS, 무시, 제외](/guide/settings/identity/#repository-files)를 참고하세요.

Git LFS를 찾을 수 없거나 너무 오래된 버전이면 거기에 해결 방법이 표시됩니다.

- **Mac에서**: Git LFS를 설치하거나 업데이트합니다. 설치했는데도 찾지 못하면 :ui[app.name > settings.title] › :ui[settings.environment]을 엽니다. :ui[settings.environment.loginShell]를 선택하거나 `PATH`를 사용자 지정 변수로 추가합니다. [이 Mac의 변수](/guide/settings/general/#local-variables)를 참고하세요.
- **서버에서**: 서버에 Git LFS를 설치하거나 업데이트합니다. 그 폴더를 비대화형 SSH 세션의 `PATH`에 추가합니다. 예를 들어 `~/.zshenv`에 씁니다.

Git LFS가 없는 동안에는 그 섹션에서 Git LFS가 필요한 버튼을 쓸 수 없습니다.

Git LFS를 쓰는 저장소에서는 브랜치 전환이나 스테이지 같은 작업도 같은 이유로 실패할 수 있습니다. 이때 :ui[hostError.lfsUnavailable] 오류와 함께 같은 해결 방법이 표시됩니다.

## Git LFS 켜기 {#enable}

저장소 설정의 :ui[repositorySettings.lfs] 섹션에서 :ui[lfs.enable]을 클릭합니다. 이 저장소에만 Git LFS가 설정됩니다. 전역 Git 구성은 바뀌지 않습니다. [Git LFS, 무시, 제외](/guide/settings/identity/#repository-files)를 참고하세요.

Spooky는 Git에 Git LFS 필터가 설정되어 있고 저장소에 Git LFS 훅이 있을 때 그 저장소가 Git LFS를 쓴다고 봅니다. 그 전까지 이 섹션에는 :ui[lfs.enable]만 나옵니다. LFS 메뉴 항목도 쓸 수 없습니다.

Git LFS를 쓰는 저장소를 복제할 때는 :ui[clone.lfs]를 선택합니다. [저장소 복제하기](/guide/repositories/manager/#clone)를 참고하세요.

Git LFS를 업데이트한 뒤에는 메뉴 막대에서 :ui[menu.repository > lfs.menu > lfs.menu.update]를 선택해 저장소의 Git LFS 훅을 업데이트합니다.

## 파일 추적하기 {#track}

추적 패턴과 일치하는 파일은 Git LFS로 저장됩니다. 패턴은 저장소 루트의 `.gitattributes`에 들어갑니다. 저장소를 쓰는 모든 사람이 패턴을 받습니다. `.gitattributes`의 변경은 작업 사본에 나타납니다. 다른 변경처럼 커밋합니다.

패턴을 추가하려면 저장소 설정에서 :ui[lfs.createPattern]를 클릭하거나 메뉴 막대에서 :ui[menu.repository > lfs.menu > lfs.menu.track]을 선택합니다. `*.psd` 같은 패턴을 입력한 다음 :ui[files.pattern.save]을 클릭합니다.

::screenshot[저장소 설정의 Git LFS 섹션. 설치된 Git LFS 버전과 추적 패턴 두 개, *.psd와 *.mp4가 표시됩니다. *.psd 행에는 패턴 위에 포인터가 있을 때 나타나는 제거 버튼이 보입니다.]{name="advanced-lfs-settings" frame="window" markers="36.3,24 91.6,35.6 46.4,34.4"}

1. 설치된 Git LFS 버전
2. 패턴을 제거하는 버튼
3. :ui[lfs.createPattern]

작업 사본에서 파일을 오른쪽 클릭하고 :ui[lfs.menu]에서 선택해도 됩니다.

- :ui[lfs.trackFile]: 선택한 파일만 정확한 경로로 추적합니다. 파일이 여러 개면 개수가 표시됩니다.
- :ui[lfs.trackType.single]{1="psd"}: 확장자가 같은 모든 파일을 추적합니다. 파일이 여러 개면 :ui[lfs.trackType]입니다. 각 파일의 확장자가 모두 포함됩니다.
- :ui[lfs.createPattern.menu]: 선택한 첫 파일의 경로에서 시작해 패턴을 직접 입력합니다.

폴더에는 :ui[lfs.createPattern.menu]만 쓸 수 있습니다.

### 패턴 추적 중단하기 {#untrack}

저장소 설정에서 패턴 옆의 :ui[lfs.remove]를 클릭하고 확인합니다. 패턴이 `.gitattributes`에서 빠집니다. 이미 Git LFS로 저장된 파일은 그대로입니다.

Git LFS가 패턴을 제거하지 못하면 Spooky가 어떤 패턴이 남았는지 알려 줍니다. :ui[repositorySettings.lfs.patterns] 옆의 :ui[repositorySettings.openInEditor]로 직접 제거합니다. [Git LFS, 무시, 제외](/guide/settings/identity/#repository-files)를 참고하세요.

## LFS 콘텐츠 가져오기, 풀, 푸시 {#transfer}

Git LFS가 설정되어 있으면 Git은 보통 파일을 체크아웃하면서 LFS 콘텐츠를 내려받습니다. 푸시할 때 콘텐츠를 올립니다. 직접 하려면 메뉴 막대의 :ui[menu.repository > lfs.menu]에서 선택합니다.

| 항목 | 하는 일 |
|---|---|
| :ui[lfs.menu.fetch] | 현재 체크아웃에 필요한 LFS 콘텐츠를 내려받습니다. 작업 사본은 바뀌지 않습니다. |
| :ui[lfs.menu.pull] | 콘텐츠를 내려받은 다음 작업 사본의 포인터 파일을 그 콘텐츠로 바꿉니다. |
| :ui[lfs.menu.push] | 모든 로컬 브랜치와 태그가 쓰는 LFS 콘텐츠 가운데 원격에 아직 없는 것을 올립니다. |

대화상자에서 원격을 선택합니다. 처음에는 현재 브랜치의 업스트림이 있는 원격이 선택되고, 업스트림이 없으면 첫 번째 원격이 선택됩니다. 진행 상황은 사이드바 맨 아래의 [활동 영역](/guide/advanced/queue-activity/#activity-area)에 나타납니다.

## 실행 취소 {#undo}

Git LFS 켜기, 추적 패턴 추가, 추적 패턴 제거는 실행 취소할 수 있습니다. [실행 취소와 복구](/guide/work/undo/)를 참고하세요.

훅 업데이트는 실행 취소할 수 없습니다. 그 전의 작업도 더는 실행 취소할 수 없습니다.

LFS 콘텐츠 가져오기, 풀, 푸시는 저장소의 가져오기, 풀, 푸시와 마찬가지로 기록되지 않습니다. 그 전의 작업은 여전히 실행 취소할 수 있습니다.

:::note[서버 저장소]
Git LFS는 서버에서 실행됩니다. LFS 콘텐츠는 서버와 원격 사이를 오갑니다. 서버 저장소를 쓸 때 Mac에는 Git LFS가 필요 없습니다.
:::

## 함께 보기

- [시스템 요구 사항](/reference/requirements/#optional)
- [하위 모듈](/guide/advanced/submodules/)
- [저장소 윈도우](/guide/repositories/manager/)

---
title: "Git LFS"
description: "啟用 Git LFS，按檔案或規則追蹤，擷取、拉取與推送 LFS 內容。"
---

Git LFS 讓大檔案不進入儲存庫的歷史。儲存庫裡為每個大檔案存一個小小的指標檔案。內容放在遠端的 LFS 儲存空間裡。

Spooky 在儲存庫所在的機器上執行 Git LFS。

## 需要什麼 {#requirements}

Git LFS 2.9.0 或更新的版本，要在儲存庫所在機器上 Git 用的 `PATH` 裡。

想確認的話，按一下側邊欄 :ui[workspace.group] 下的 :ui[repositorySettings.title]。:ui[repositorySettings.lfs] 一段寫著 Git LFS 的 :ui[lfs.version]，見 [Git LFS、忽略與排除](/guide/settings/identity/#repository-files)。

找不到 Git LFS 或者版本太舊時，那裡會有一則提示說明怎麼解決：

- **在你的 Mac 上**：安裝或更新 Git LFS。已經裝了卻找不到時，開啟 :ui[app.name > settings.title] › :ui[settings.environment]。勾選 :ui[settings.environment.loginShell]，或者把 `PATH` 加入為自訂變數，見 [本機的變數](/guide/settings/general/#local-variables)。
- **在伺服器上**：在那裡安裝或更新 Git LFS。把它所在的資料夾加進非互動式 SSH 工作階段的 `PATH`，例如寫在 `~/.zshenv` 裡。

缺少 Git LFS 時，這一段裡需要它的按鈕都無法使用。

## 啟用 Git LFS {#enable}

在儲存庫設定的 :ui[repositorySettings.lfs] 一段裡按一下 :ui[lfs.enable]。這只為這個儲存庫設定 Git LFS，不變更你的全域 Git 設定，見 [Git LFS、忽略與排除](/guide/settings/identity/#repository-files)。

Git 設定好了 Git LFS 的過濾器、儲存庫裡也有 Git LFS 的掛鉤時，Spooky 才認為這個儲存庫在用 Git LFS。在此之前，這一段只提供 :ui[lfs.enable]，LFS 的選單項目也無法使用。

複製使用 Git LFS 的儲存庫時，勾選 :ui[clone.lfs]。見 [複製儲存庫](/guide/repositories/manager/#clone)。

更新 Git LFS 之後，選 :ui[menu.repository > lfs.menu > lfs.menu.update]，更新儲存庫裡 Git LFS 的掛鉤。

## 追蹤檔案 {#track}

符合追蹤規則的檔案交給 Git LFS 存放。規則寫在儲存庫根目錄的 `.gitattributes` 裡，用這個儲存庫的人都會拿到。`.gitattributes` 的變更會出現在工作區裡。像別的變更一樣提交它。

想加入規則，在儲存庫設定裡按一下 :ui[lfs.createPattern]，或者選 :ui[menu.repository > lfs.menu > lfs.menu.track]。填一條規則，例如 `*.psd`，再按一下 :ui[files.pattern.save]。

::screenshot[儲存庫設定裡的 Git LFS 一節，寫著裝好的 Git LFS 版本，下面是 *.psd 與 *.mp4 兩條追蹤規則。*.psd 這一列露出了移除按鈕，指標停在規則上時它才出現。]{name="advanced-lfs-settings" frame="window" markers="34.5,24 90,35.6 48.8,34.4"}

1. 裝好的 Git LFS 版本
2. 移除規則的按鈕
3. :ui[lfs.createPattern]

也可以在工作區裡對檔案按右鍵，從 :ui[lfs.menu] 裡選：

- :ui[lfs.trackFile]：只追蹤選取的這些檔案，按它們確切的路徑。選了幾個檔案時，這一項會寫出個數。
- :ui[lfs.trackType.single]{1="psd"}：追蹤副檔名相同的所有檔案。選了幾個檔案時，這一項是 :ui[lfs.trackType]，按它們各自的副檔名追蹤。
- :ui[lfs.createPattern.menu]：自己填規則，一開始是第一個選取檔案的路徑。

對資料夾，只能用 :ui[lfs.createPattern.menu]。

### 停止追蹤一條規則 {#untrack}

在儲存庫設定裡，按一下規則旁邊的 :ui[lfs.remove] 並確認。這條規則會從 `.gitattributes` 裡去掉。已經存進 Git LFS 的檔案保持原樣。

Git LFS 去不掉某條規則時，Spooky 會寫出還剩哪些。用 :ui[repositorySettings.lfs.patterns] 旁邊的 :ui[repositorySettings.openInEditor] 手動去掉它們，見 [Git LFS、忽略與排除](/guide/settings/identity/#repository-files)。

## 擷取、拉取與推送 LFS 內容 {#transfer}

設定好 Git LFS 之後，Git 通常會在簽出檔案時下載 LFS 內容，在推送時上傳。想自己來做，從選單列的 :ui[menu.repository > lfs.menu] 裡選：

| 選單項目 | 作用 |
|---|---|
| :ui[lfs.menu.fetch] | 下載目前簽出需要的 LFS 內容，工作區不變。 |
| :ui[lfs.menu.pull] | 下載這些內容，再把工作區裡的指標檔案換成實際內容。 |
| :ui[lfs.menu.push] | 上傳所有本機分支和標籤用到的、遠端還沒有的 LFS 內容。 |

在對話框裡選一個遠端。一開始是目前分支上游所在的遠端，沒有上游時是第一個遠端。進度顯示在側邊欄底部的 [活動區](/guide/advanced/queue-activity/#activity-area)。

## 還原 {#undo}

啟用 Git LFS、加入追蹤規則和去掉追蹤規則，都可以還原。見 [還原與找回](/guide/work/undo/)。

更新掛鉤無法還原。在它之前的操作也無法再還原。

擷取、拉取和推送 LFS 內容跟儲存庫的擷取、拉取、推送一樣，不記進還原記錄。在它們之前的操作照樣可以還原。

:::note[伺服器儲存庫]
Git LFS 在伺服器上執行，LFS 內容在伺服器和遠端之間傳輸。伺服器儲存庫不需要你的 Mac 裝 Git LFS。
:::

## 相關頁面

- [系統需求](/reference/requirements/#optional)
- [子模組](/guide/advanced/submodules/)
- [儲存庫管理視窗](/guide/repositories/manager/)

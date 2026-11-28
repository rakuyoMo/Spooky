---
title: "一般、更新與環境"
description: "認識設定視窗，以及一般、更新、環境三頁的選項。"
---

設定對整個 Spooky 生效。大多數設定一改就生效，沒有「儲存」按鈕。

## 設定視窗 {#window}

選 :ui[app.name > settings.title]（<kbd>⌘,</kbd>）。各頁排在視窗頂部，視窗標題是目前這一頁的名稱。

| 頁 | 設定什麼 | 說明在 |
|---|---|---|
| :ui[settings.general] | 複製、背景操作、確認、歷史、檔案列表與視窗 | [一般](#general) |
| :ui[settings.appearance] | 淺色或深色，以及應用程式圖示 | [外觀與主題](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | Git 程式、全域的 Git 身分、簽署，以及外部比較與合併工具 | [身分設定檔與 Git 設定](/guide/settings/identity/#git-config) |
| :ui[settings.text] | Diff 與檔案裡的語法著色、不可見字元與 Tab 寬度 | [外觀與主題](/guide/settings/appearance/#text) |
| :ui[settings.editor] | 怎樣檢查提交訊息、怎樣換行 | [外觀與主題](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | Diff 與檔案的配色和字型 | [外觀與主題](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | 提交時可以換用的幾個身分 | [身分設定檔與 Git 設定](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | GitHub 與 GitLab 帳號 | [託管帳號](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | 伺服器的主機別名，儲存在 `~/.ssh/config` 裡 | [準備 SSH](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | github.com 的連結、SSH agent 與當機報告 | [整合](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | 本機 Git 用的環境變數，以及檢查伺服器的環境 | [環境](#environment) |
| :ui[settings.updates] | Spooky 怎樣更新自己 | [更新](#updates) |

單一儲存庫的設定，例如它的身分與簽署，在儲存庫視窗裡。見 [儲存庫設定](/guide/settings/identity/#repository)。

## 一般 {#general}

:ui[settings.general] 頁很長，下面幾節按從上到下的順序介紹。

::screenshot[設定視窗的一般頁，列著複製位置、終端機程式、操作與確認的選項、歷史與 Diff 的選項，以及檔案列表的選項。]{name="settings-general" frame="window"}

### 複製與終端機 {#cloning}

| 設定 | 作用 |
|---|---|
| :ui[settings.cloneDirectory] | 複製對話框建議把新儲存庫放在哪裡。起初是個人資料夾。有 `~/Development` 的話，選單裡也會列出它。選 :ui[settings.cloneDirectory.select] 可以換成別的資料夾。 |
| :ui[settings.terminal] | :ui[action.openTerminal] 用哪個 App。見 [終端機](/guide/settings/integration/#terminal)。 |

### 操作 {#operations}

| 設定 | 預設 | 作用 |
|---|---|---|
| :ui[settings.autoFetch] | 每 30 分鐘 | Spooky 在背景擷取的頻率。見 [自動擷取](/guide/branches/sync/#auto-fetch)。 |
| :ui[stash.offerAutoStash] | 開啟 | 本機變更擋住操作時，問要不要先儲藏它們。見 [自動儲藏](/guide/work/stash/#auto-stash)。 |
| :ui[settings.autoUpdateSubmodules] | 關閉 | 操作移動了已簽出子模組的指標後，不問就更新它們。見 [在別的操作之後更新](/guide/advanced/submodules/#auto-update)。 |
| :ui[branch.cleanNames] | 開啟 | 輸入時把分支、標籤與遠端的名稱改成 Git 接受的樣子。見 [新增分支](/guide/branches/branches/#create)。 |
| :ui[settings.autoArchive] | 關閉 | 把看起來已經做完的分支封存。見 [自動封存](/guide/branches/review/#auto-archive)。 |

### 確認 {#confirmations}

下面這幾個詢問裡都有 :ui[dialog.doNotAskAgain]。在詢問裡勾選它，這裡對應的設定就關掉了。重新開啟設定，詢問就又會出現。四項起初都是開啟的。

| 設定 | 在這之前先問 |
|---|---|
| :ui[settings.warnDiscardingChunks] | 捨棄區塊或行，任何儲存庫都算。見 [捨棄變更](/guide/work/diff/#discard)。 |
| :ui[settings.warnDiscardingOnServer] | 在伺服器儲存庫裡捨棄整個檔案 |
| :ui[settings.warnDeletingOnServer] | 伺服器沒有垃圾桶時，永久刪除檔案 |
| :ui[settings.warnRestoringOnServer] | 在伺服器儲存庫裡把檔案回復成某個版本。見 [從某個版本回復檔案](/guide/history/file-views/#restore)。 |

在本機儲存庫裡捨棄整個檔案，總是會先問。

### 歷史與 Diff {#history}

| 設定 | 預設 | 作用 |
|---|---|---|
| :ui[history.pageSize] | 100 | 歷史一次讀入多少個提交：100、200、500 或 1000 |
| :ui[settings.dateFormat] | 絕對日期 | 絕對日期是簡短的寫法，如 2026/10/26。相對日期在今天和昨天寫「今天」「昨天」，其餘日子寫完整日期。選單裡各有一個範例。 |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | 合併提交的變更集顯示什麼。見 [變更集](/guide/history/commit-details/#changeset)。 |
| :ui[working.diffThreshold] | 20000 | Diff 超過這麼多 kB 時，先問再顯示。可以從選單裡選，也可以直接輸入。見 [看懂 Diff](/guide/work/diff/#read)。 |

日期格式作用於歷史、儲藏、檔案歷史與 Reflog。

### 檔案列表 {#file-list}

| 設定 | 預設 | 作用 |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | 也可以改成在比較工具裡開啟 |
| :ui[files.openSubmodules] | 開啟 | 按兩下子模組時在 Spooky 裡開啟它，不交給別的 App |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | 也可以改成用快速查看預覽檔案 |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | 也可以選 :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | 也可以改成省略長檔名的中間 |

它們在工作區裡的效果見 [檔案列表的設定](/guide/work/working-copy/#settings)。

### 視窗與儲存庫管理 {#windows}

| 設定 | 預設 | 作用 |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | Spooky 啟動時重新開啟什麼。見 [回到上次離開的地方](/guide/repositories/navigation/#restore)。 |
| :ui[settings.showLaunchWindow] | 關閉 | Spooky 啟動時顯示一個列出最近儲存庫的視窗 |
| :ui[settings.showWorktreesInRepositoryList] | 關閉 | 在儲存庫管理裡列出每個儲存庫的工作樹 |
| :ui[settings.showHostAliasesInRepositoryList] | 開啟 | 在儲存庫管理裡顯示每個伺服器儲存庫的主機別名 |
| :ui[settings.showDeveloperMenu] | 關閉 | 加上 :ui[menu.developer] 選單，裡面是測試 Spooky 本身用的工具 |

## 更新 {#updates}

:ui[settings.updates] 頁設定更新頻道、是否自動檢查與下載更新，以及多久檢查一次。各項的說明見 [保持更新](/guide/start/install/#updates)。

## 環境 {#environment}

從 Finder 或 Dock 開啟的 App，拿不到你在終端機裡的環境。例如 `PATH` 裡可能少了 `/opt/homebrew/bin` 這樣的資料夾，Git 掛鉤、憑證輔助程式與 Git LFS 就可能找不到。:ui[settings.environment] 頁為本機的 Git 補上這些。

### 本機的變數 {#local-variables}

| 設定 | 作用 |
|---|---|
| :ui[settings.environment.loginShell] | 啟動一次你的登入 shell，讀出它的啟動檔設定的變數，交給 Git 與工具列按鈕的腳本。下方的表格列出讀到了什麼。起初是開啟的。 |
| :ui[settings.environment.custom] | 你自己加的變數。按一下加入按鈕加一個，按一下移除按鈕移除選取的那個。它們會覆寫登入 shell 裡的同名變數。 |

還有幾點：

- 變更從下一條 Git 指令開始生效，不用重新啟動 Spooky。
- 每次 Spooky 啟動時，都會重新讀取登入 shell。讀取失敗時，頁面上會寫出來。
- 兩個自訂變數同名時，靠下的那個生效。名稱不合法的變數留在表格裡，但不會交給 Git。
- 想用系統之外的 SSH agent，在這裡或登入 shell 裡設定 `SSH_AUTH_SOCK`。見 [SSH agent](/guide/settings/integration/#ssh-agent)。

:::note[伺服器儲存庫]
這些變數只作用於本機的 Git 與工具列按鈕的腳本。伺服器上的 Git 用伺服器自己的環境。
:::

### 檢查伺服器 {#server-check}

在頁面底部，不加入儲存庫也能看到 Git 在伺服器上拿到的環境：

1. 在 :ui[remote.host] 旁邊的輸入框裡填主機別名，也可以從 :ui[settings.environment.server.hosts] 選單裡選一個。這個選單列出你的伺服器儲存庫所在的伺服器。
2. 按一下 :ui[settings.environment.server.check]。

::screenshot[設定視窗環境頁底部的伺服器檢查。檢查過一個主機別名，結果顯示伺服器上找到的 Git 及其版本。]{name="settings-environment" frame="closeup"}

結果裡有 SSH 登入時找到的 Git 及其版本，找不到時寫 :ui[settings.environment.server.noGit]。下面是 `PATH` 裡的每個資料夾，以及以 `GIT_` 開頭的變數名稱。找不到 Git 時，見 [伺服器上找不到 Git](/reference/troubleshooting/#server-path)。

## 相關頁面

- [外觀與主題](/guide/settings/appearance/)
- [身分設定檔與 Git 設定](/guide/settings/identity/)
- [整合](/guide/settings/integration/)
- [安裝 Spooky](/guide/start/install/)

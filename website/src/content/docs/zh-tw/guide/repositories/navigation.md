---
title: "視窗與導覽"
description: "使用視窗與標籤頁、上一頁與下一頁、快速操作、視窗回復、Dock 選單和 spooky:// 連結。"
---

這一頁講怎樣同時開著幾個儲存庫、在視圖之間切換、用快速操作跳到想去的地方，還有下次啟動時怎樣回到上次離開的地方。

## 視窗與標籤頁 {#windows}

每個視窗或標籤頁顯示的要麼是儲存庫管理，要麼是一個儲存庫。

- :ui[menu.file > menu.newTab]（<kbd>⌘T</kbd>）新開一個顯示儲存庫管理的標籤頁。標籤頁列末尾的加入按鈕作用相同。
- :ui[menu.file > menu.newWindow]（<kbd>⌘N</kbd>）新開一個顯示儲存庫管理的視窗。
- :ui[menu.view > menu.showRepositories]（<kbd>⌃⌘R</kbd>）在目前視窗裡顯示儲存庫管理。

儲存庫已經開著時，再開啟它會切換到顯示它的那個視窗。還是想在第二個視窗裡開啟，就在儲存庫管理的列表裡在它上面按右鍵，選 :ui[bookmarks.openNewWindow]{1="driftwood"}。

### 切換視圖 {#views}

:ui[menu.view] 選單用來切換儲存庫的各個視圖：

| 快速鍵 | 選單項目 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title]（<kbd>⌃⌘0</kbd>）開啟活動視窗。裡面列出 Spooky 執行過和正在執行的操作，見 [操作排隊與活動](/guide/advanced/queue-activity/)。

## 上一頁與下一頁 {#back-forward}

每個視窗都記得你去過的視圖與儲存庫，包括儲存庫管理。想原路返回：

- :ui[menu.view > navigation.back]（<kbd>⌘[</kbd>），或工具列上的 :ui[toolbar.previous]
- :ui[menu.view > navigation.forward]（<kbd>⌘]</kbd>），或工具列上的 :ui[toolbar.next]

回到上一頁之後再開啟別的地方，原來可以前往的那些下一頁就沒有了。

## 快速操作 {#quick-actions}

快速操作讓你輸入幾個字就找到想要的東西，直接對它執行操作，手不用離開鍵盤。視窗裡顯示著儲存庫時才能用。選 :ui[menu.file > quickActions.menu]（<kbd>⇧⌘A</kbd>）。

::screenshot[快速操作面板蓋在儲存庫視窗上，輸入框裡是「dark」。選取的第一個結果是分支 feature/dark-mode，右側顯示它的預設操作與查看更多操作的提示。下面依序是遠端分支 origin/feature/dark-mode、深色外觀、Default (Dark) 主題，以及兩個說明裡提到 dark 的提交。]{name="quick-actions" frame="window"}

什麼都沒輸入時，面板依序列出儲存庫的各個視圖、分支（目前分支在最前）、工作樹、遠端、子模組、遠端分支、標籤、儲藏、身分設定檔、外觀與主題。輸入文字後列表會縮小，Spooky 還會尋找：

- 目前分支裡名稱相符的檔案
- 輸入 5 到 64 個十六進位字元時，雜湊以此開頭的提交
- 目前分支上說明裡含有這段文字的提交，最多 100 個

停止輸入一會兒後，檔案與提交會加到列表末尾。

面板裡可以用這些按鍵：

| 按鍵 | 作用 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 移動選取的列 |
| <kbd>↩</kbd> | 對選取的項目執行預設操作 |
| <kbd>Tab</kbd>，或在文字末尾按 <kbd>→</kbd> | 列出選取項目的全部操作 |
| 沒有文字時按 <kbd>←</kbd>，或按 <kbd>⇧Tab</kbd> | 從操作列表返回 |
| <kbd>Esc</kbd> | 清空文字；沒有文字時，從操作列表返回或關閉面板 |

列出的只有目前能執行的操作。

## 回到上次離開的地方 {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration] 決定 Spooky 啟動時顯示什麼：

| 選項 | Spooky 啟動時 |
|---|---|
| :ui[settings.windowRestoration.always] | 重新開啟你的視窗與標籤頁，每個都顯示結束時的儲存庫與視圖 |
| :ui[settings.windowRestoration.never] | 只顯示儲存庫管理視窗 |
| :ui[settings.windowRestoration.system] | 按 macOS 裡結束 App 時是否保留視窗的設定決定。這是預設的選項 |

回復的儲存庫已經找不到時，它的視窗會說明儲存庫遺失了，見 [遺失的儲存庫](/guide/repositories/manager/#missing)。

開啟 :ui[settings.showLaunchWindow] 後，Spooky 啟動時還會開啟一個列出最近儲存庫的視窗。按兩下其中一個，或選取後按 <kbd>↩</kbd>，就會開啟它。有儲存庫視窗來到最前面後，這個視窗會自己關閉。這兩項設定見 [視窗與儲存庫管理](/guide/settings/general/#windows)。

:::note[伺服器儲存庫]
回復的伺服器儲存庫會在 Spooky 啟動時重新連線伺服器。
:::

## 最近的儲存庫與 Dock {#recent}

:ui[menu.file > menu.openRecent] 列出你最近開啟過的儲存庫，這台 Mac 上的與伺服器上的都有。底部的 :ui[menu.clearRecent] 清空這份列表。儲存庫管理裡的書籤不受影響。

在 **Dock** 裡的 Spooky 圖示上按右鍵，選單裡有 :ui[menu.newWindow] 與最近的儲存庫。選一個儲存庫就會開啟它，Spooky 還沒執行時也一樣。

也可以把資料夾拖到 Dock 裡的 Spooky 圖示上，開啟它所在的儲存庫。資料夾不在 Git 儲存庫裡時，Spooky 會詢問是否新增一個。

## 用連結開啟 Spooky {#links}

以 `spooky://` 開頭的連結能開啟一個儲存庫，或者發起複製。這種連結可以放在其他 App、指令碼或筆記裡。

### 開啟儲存庫 {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository` 必填，寫儲存庫在這台 Mac 上的絕對路徑。伺服器儲存庫寫成 `alias:path`。都要經過 URL 編碼。
- `view` 可以不寫。不寫時，儲存庫開啟後顯示上次的視圖。
- 有兩種簡寫可以代替 `view`：`branch=<name>` 開啟這個分支的歷史，`commit=<hash>` 開啟這個提交。

| `view` | 開啟 | 其他參數 |
|---|---|---|
| `workingCopy` | 工作區 | |
| `history` | 歷史 | `ref=<reference>`，完整的參照名稱，例如 `refs/heads/main`；可以寫多個 |
| `commit` | 一個提交 | `commit=<hash>` |
| `stashes` | 儲藏 | |
| `reflog` | Reflog | |
| `pullRequests` | Pull Request 或 Merge Request | |
| `branchesReview` | 分支整理 | |
| `settings` | 儲存庫設定 | |
| `remote` | 一個遠端 | `remote=<name>` |
| `submodule` | 一個子模組 | `path=<path>` |
| `worktree` | 一個工作樹 | `path=<path>` |
| `fileHistory` | 一個檔案的歷史 | `path=<path>` |
| `file` | 一個檔案 | `path=<path>`，可以再加 `revision=<revision>`，還可以加 `mode=blame` 或 `mode=raw` |

例如，下面這個連結開啟 `/Volumes/Projects/driftwood` 這個儲存庫裡 `main` 分支的歷史：

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### 複製儲存庫 {#link-clone}

```
spooky://clone?url=<address>
```

這個連結會開啟複製對話框，位址已經填好。你選好放在哪裡、按了 :ui[clone.submit] 之後才會開始複製，見 [複製儲存庫](/guide/repositories/manager/#clone)。

:ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github] 設為 Spooky 時，github.com 上用桌面 App 開啟儲存庫的連結也會開啟這個複製對話框，見 [來自 github.com 的連結](/guide/settings/integration/#github-links)。

連結無法使用時，例如寫了不認得的視圖，或者給的是相對路徑，Spooky 只顯示 :ui[link.invalid.title]，不做別的事。

## 相關頁面

- [介面導覽](/guide/start/tour/)
- [儲存庫管理視窗](/guide/repositories/manager/)
- [鍵盤快速鍵](/reference/shortcuts/)

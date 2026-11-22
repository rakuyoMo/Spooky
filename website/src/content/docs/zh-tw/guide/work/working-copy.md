---
title: "工作區"
description: "檢視變更檔案的狀態，用平鋪或樹狀顯示檔案列表，排序與搜尋，處理未追蹤與忽略的檔案，使用檔案操作與快速查看。"
---

工作區顯示上次提交以來你改了什麼。在這裡挑出要提交的變更，檢視檔案，也把不該讓 Git 追蹤的檔案擋在外面。

按一下側邊欄最上面的 :ui[workspace.title]，或選 :ui[menu.view > menu.showWorkingCopy]（<kbd>⌘1</kbd>），就能開啟它。中間一欄上方是提交區，下面列出有變更的檔案。提交區的用法見 [提交變更](/guide/work/commit/)。

## 看懂狀態 {#status}

每個有變更的檔案佔一列：一個註記框、兩個狀態標記，再來是檔案名稱。

- 註記框表示變更有沒有暫存。顯示一條短橫線時，表示檔案只暫存了一部分。
- 左邊的標記是已暫存的變更，右邊的標記是還沒暫存的變更。
- 字母是 Git 的狀態代碼：M 是修改，A 是新增，D 是刪除，R 是重新命名。Git 還沒追蹤的新檔案顯示 ?，被忽略的檔案顯示 !。
- 有衝突的檔案顯示兩個衝突代碼，例如 U U。見 [解決衝突](/guide/work/conflicts/)。

把指標停在標記上，可以看到狀態的文字說明。

列表上方那一列是目前的分支，後面跟著它追蹤的遠端分支。沒有追蹤分支時，這一列寫著 :ui[branch.noTracking]。

檔案有變化時，Spooky 會自己更新列表。想全部重新讀一遍，按一下 :ui[action.refresh] 或按 <kbd>⌘R</kbd>。

:::note[伺服器儲存庫]
儲存庫視窗在最前面時，Spooky 每 2 秒查一次伺服器上的變化，其餘時候每 10 秒查一次。伺服器回應慢時，會查得少一些。在伺服器上做的變更，可能要過這麼久才顯示出來。見 [伺服器儲存庫有哪些不同](/guide/server/overview/#differences)。
:::

## 平鋪或樹狀顯示 {#view}

:ui[menu.view > files.statusMenu] 選單決定列表顯示什麼。分支那一列右端的按鈕裡也是這幾項。

| 選單項目 | 作用 |
|---|---|
| :ui[working.list]（<kbd>⌃⌘L</kbd>） | 每個檔案一列，顯示完整路徑 |
| :ui[working.tree]（<kbd>⌃⌘T</kbd>） | 檔案按所在的資料夾分組。按兩下資料夾可以展開或收合 |
| :ui[files.showNonModified]（<kbd>⌃⌘M</kbd>） | 列出儲存庫裡的所有檔案，不只是有變更的。樹狀顯示時可用 |
| :ui[files.showIgnored]（<kbd>⌃⌘I</kbd>） | 列出 Git 忽略的檔案 |
| :ui[files.showAssumeUnchanged] | 列出標記為 assume-unchanged 的檔案，見 [未追蹤與忽略的檔案](#untracked-ignored) |

平鋪還是樹狀，每個儲存庫各記各的，新開啟的儲存庫預設平鋪。其餘幾項對所有儲存庫都生效。

## 排序 {#sort}

按一下 :ui[status.filename] 或 :ui[status.column] 的欄標題，按這一欄排序。再按一次，順序反過來。排序方式在所有儲存庫與視窗裡都一樣。

第一次按 :ui[status.column]，已暫存的檔案排在最前面。接著是其餘的變更，然後是新檔案，最後是未變更與被忽略的檔案。

## 搜尋檔案 {#search}

1. 按 <kbd>⌘F</kbd>，或按一下工具列上的搜尋框。框裡寫著 :ui[history.search.forFile]。
2. 輸入檔案路徑的一部分。Spooky 會列出按順序包含這些字母的檔案。
3. 選一個檔案，列表就只顯示這個路徑。列出的最後一項會顯示路徑裡含有你輸入內容的所有檔案。

清空搜尋框，所有檔案就又顯示出來了。

## 未追蹤與忽略的檔案 {#untracked-ignored}

新檔案在暫存並提交之前是未追蹤的。未追蹤的檔案顯示 ?，和其餘變更列在一起。想把它加進下一個提交，像別的變更一樣暫存它就行。

有些檔案永遠不該提交，例如建置產物或自己的筆記。不想讓 Git 列出它們，在檔案上按右鍵，選一種規則：

- :ui[files.ignore] 把規則加到儲存庫根目錄的 `.gitignore` 檔案裡。提交 `.gitignore` 以後，規則對所有使用這個儲存庫的人都生效。
- :ui[files.exclude] 把規則加到 Git 資料夾裡的 `info/exclude`。規則只對這一份儲存庫生效，不會被提交。

兩個子選單都可以只忽略這一項，忽略所有同名的項目，忽略所有相同副檔名的項目，或者自己輸入一條規則。

忽略規則對 Git 已經追蹤的檔案沒有作用。忽略一個已追蹤的檔案時，Spooky 會問要不要同時停止追蹤它。按一下 :ui[files.untrack] 停止追蹤，按一下 :ui[files.untrackIgnored.skip] 繼續追蹤。兩種情況下，檔案都留在你的資料夾裡。

不加忽略規則、只想停止追蹤某個檔案，在它上面按右鍵，選 :ui[files.untrack]。下一個提交會把它從儲存庫裡刪掉，檔案仍留在你的資料夾裡。

:ui[files.mark > files.assumeUnchanged.set] 讓 Git 不理會你對某個已追蹤檔案的本機變更，例如只在這台 Mac 上改的設定檔。檔案會從列表裡消失。想再看到它，開啟 :ui[files.showAssumeUnchanged]，再選 :ui[files.mark > files.assumeUnchanged.unset]。

## 檔案操作 {#file-actions}

在檔案上按右鍵，就能看到它的各種操作。按右鍵的這一列在所選範圍之內時，操作作用於所有選取的檔案；在所選範圍之外時，只作用於按的這一列。

::screenshot[在工作區裡對 src/readings.ts 按右鍵跳出的選單。從上往下依序是開啟檔案與拷貝路徑、快速查看、暫存與丟到垃圾桶、衝突、捨棄與儲藏、Blame 與檔案歷史、忽略，以及比較。]{name="work-file-menu" frame="closeup"}

| 想要 | 選 |
|---|---|
| 開啟檔案 | :ui[files.open]，或從 :ui[files.openWith] 裡選一個 App。也可以直接按兩下檔案 |
| 拷貝路徑 | :ui[workspace.copyPathMenu] 或 :ui[working.copyRelative] |
| 在 Finder 或終端機裡檢視 | :ui[action.revealFinder] 或 :ui[action.openTerminal] |
| 移動或重新命名 | :ui[files.move.menu] |
| 丟到垃圾桶 | :ui[files.trash]，或按 <kbd>⌘⌫</kbd> |
| 丟掉變更 | :ui[working.discard.menu]（見 [捨棄變更](/guide/work/diff/#discard)） |
| 放進儲藏 | 見 [儲藏部分檔案](/guide/work/stash/#partial) |
| 還原成以前的版本 | :ui[files.revert.menu] |
| 檢視它的歷史 | :ui[quickActions.showFileHistory] 或 :ui[quickActions.showBlame]（見 [檔案歷史與 Blame](/guide/history/file-views/)） |
| 在其他 App 裡比較 | :ui[externalTool.compare]（見 [在其他 App 裡比較](/guide/work/diff/#external)） |

:ui[files.trash] 不會先問。丟到垃圾桶的已追蹤檔案會顯示成一個已暫存的刪除。想把它拿回來，選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

:::note[伺服器儲存庫]
:ui[files.trash] 把檔案移到伺服器的垃圾桶。伺服器沒有垃圾桶時，這一項寫作 :ui[files.delete]，Spooky 會先問你，再永久刪除檔案。大多數 App 拿到的是檔案的副本，儲存後 Spooky 把變更寫回伺服器。見 [終端機與其他 App](/guide/server/local-location/#terminal)。
:::

## 快速查看 {#quick-look}

不開啟 App 也想看看檔案的內容，在它上面按右鍵，選 :ui[files.quickLook.single]{1="README.md"}。

常用快速查看的話，可以讓空白鍵開啟它：選 :ui[app.name > settings.title] › :ui[settings.general]，把 :ui[files.spacebar] 設為 :ui[files.spacebar.quickLook]。預設情況下，空白鍵暫存或取消暫存所選的檔案。見 [檔案列表](/guide/settings/general/#file-list)。

:::note[伺服器儲存庫]
Spooky 先把檔案下載到這台 Mac 上的一個暫存資料夾裡。關閉儲存庫時，這個資料夾會被刪掉。
:::

## 檔案列表的設定 {#settings}

這幾項在 :ui[app.name > settings.title] › :ui[settings.general] 裡：

| 設定 | 可選的值 |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile]（預設）或 :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging]（預設）或 :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] 或 :ui[files.fontSize.medium]（預設） |
| :ui[files.truncation] | :ui[files.truncation.beginning]（預設）或 :ui[files.truncation.middle] |

見 [檔案列表](/guide/settings/general/#file-list)。

## 相關頁面

- [檢視與挑選變更](/guide/work/diff/)
- [提交變更](/guide/work/commit/)
- [檔案歷史與 Blame](/guide/history/file-views/)

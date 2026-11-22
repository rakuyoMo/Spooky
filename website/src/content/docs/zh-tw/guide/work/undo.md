---
title: "還原與找回"
description: "了解 ⌘Z 能還原什麼、有些操作為什麼無法還原，以及用 Reflog 找回遺失的提交。"
---

在 Spooky 裡對儲存庫做的大多數事，都能用 <kbd>⌘Z</kbd> 收回。其餘的，Git 的 Reflog 記著分支去過哪裡，所以提交很少會真的遺失。

## 還原與重做 {#undo}

選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）收回上一個操作，選單項目裡會寫出操作的名稱。選 :ui[menu.edit > menu.redo]（<kbd>⇧⌘Z</kbd>）再做一次。可以一步步往回還原好幾個操作，從最近的開始。

能還原的，例如：

- 暫存、提交與修補
- 捨棄變更，把檔案丟到垃圾桶
- 儲存、套用與刪除儲藏
- 簽出、新增、重新命名與刪除分支，新增標籤
- 釘選與封存分支，設定上游，快轉
- 合併、變基、摘取、反轉與重設
- 加入、重新命名與刪除遠端，修改遠端的設定
- 發布分支與標籤，重新命名遠端分支
- 標記 assume-unchanged，啟用 Git LFS，變更子模組

丟到垃圾桶的檔案，會從垃圾桶放回原處。還原重設時，如果已追蹤的檔案有變更，Spooky 會先問要不要把它們儲藏起來。新的儲藏會留在列表裡。

在提交訊息這類文字框裡輸入時，<kbd>⌘Z</kbd> 還原的是輸入的文字。

每個儲存庫有一份還原記錄，這個儲存庫的所有視窗共用。Spooky 結束之前它一直都在。還原要用的快照存在儲存庫自己的 Git 資料庫裡，不會推送到任何地方。

:::note[伺服器儲存庫]
快照存在伺服器上的儲存庫裡。丟到伺服器垃圾桶的檔案，也從那裡放回去。
:::

## 無法還原的操作 {#cant-undo}

還原是把儲存庫恢復成原來的樣子。有些變更超出了 Spooky 能恢復的範圍：

- 刪除遠端上的分支與標籤。連同遠端分支一起刪除本機分支是個例外：還原會把兩個都建回來。
- 修改提交者身分、忽略規則或其他 Git 設定。
- 合併、變基等操作進行期間做的任何事，包括繼續或中止這個操作。
- 停在衝突上的變基或摘取。停在衝突上的合併或反轉可以還原，效果就是中止它。
- 被永久刪除的新檔案，例如在沒有垃圾桶的伺服器上。
- 子模組的初始化、同步與修復，工作樹的各種操作，更新 Git LFS 的掛鉤，以及把儲存庫發布到託管服務。見 [子模組](/guide/advanced/submodules/#undo)、[工作樹](/guide/advanced/worktrees/#undo)、[Git LFS](/guide/advanced/lfs/#undo) 與 [發布儲存庫](/guide/hosting/accounts/#publish)。

做了這類操作以後，選單項目會寫明這個操作無法還原。在它之前的操作也都無法還原了。

擷取、拉取、推送與同步不會記進還原記錄，也就無法還原。子模組的擷取與更新，以及擷取、拉取、推送 LFS 內容，也是這樣。

## 暫時無法還原 {#blocked}

只有儲存庫還保持著操作結束時的樣子，才能還原。不是這樣時，選單項目會變灰，並在括號裡寫明原因：

| 原因 | 怎麼辦 |
|---|---|
| :ui[undo.reason.busy] | 等正在執行的操作結束，或者先完成進行中的合併、變基等操作 |
| :ui[undo.reason.disconnected] | 重新連上伺服器 |
| :ui[undo.reason.changed] | 儲存庫在那之後又變了：拉取或同步帶來了新提交，或者終端機、其他 App 變更了它。把它改回去，就又能還原了 |

真正還原之前，Spooky 會再檢查一遍儲存庫。有東西擋著的話，它會停下來說明原因，什麼都不會變更。

| 提示 | 原因 |
|---|---|
| :ui[undo.error.changed] | 儲存庫已經和 Spooky 記下的狀態對不上 |
| :ui[undo.error.untracked] | 恢復會覆寫或刪掉未追蹤的檔案 |
| :ui[undo.error.hidden] | 標記了 assume-unchanged 的檔案有本機變更，或者儲存庫用了 skip-worktree |
| :ui[undo.error.inProgress] | 先完成或中止合併、變基、摘取或反轉 |
| :ui[undo.error.conflicts] | 先解決衝突。見 [解決衝突](/guide/work/conflicts/) |
| :ui[undo.error.trash] | 有些檔案已經不在垃圾桶裡，或者原來的位置上有了別的檔案 |

## 用 Reflog 找回提交 {#reflog}

Git 會記下 HEAD 和每個本機分支指向過哪些提交。因為重設、變基或刪除分支而遺失的提交，通常還能在這裡找到。從來沒提交過的變更不在其中。

1. 選 :ui[menu.view > reflog.show]（<kbd>⌘6</kbd>）。
2. 在頂端的 :ui[reflog.ref] 裡選 HEAD 或一個本機分支。
3. 找到那一筆記錄。每一筆寫著短雜湊、發生了什麼和時間，下面是 Git 記的說明。想篩選列表，在工具列的搜尋框裡輸入。
4. 選取這筆記錄，就能看到這個提交的詳細資訊。

::screenshot[HEAD 的 Reflog 視圖。每筆記錄寫著短雜湊、commit、checkout、reset 這類動作和日期，下面是說明。右邊是所選記錄的提交詳細資訊。]{name="work-reflog" frame="window" markers="33.5,9 44.1,37.1 84.4,21.3"}

1. :ui[reflog.ref] 選單
2. 選取的記錄
3. 這個提交的詳細資訊

在這筆記錄上按右鍵，把提交找回來：

- :ui[reflog.createBranch]{1="9e0d36a7"} 在那裡新增一個分支，現有的分支都不動。
- :ui[reflog.restore]{1="feature/units-toggle" 2="9e0d36a7"} 把正在看的分支移回那個提交，工作區和暫存區不變。Spooky 會先問，做完也能還原。
- :ui[reflog.cherryPick]{1="9e0d36a7"} 把這個提交複製到目前的分支上。也可以把記錄拖到側邊欄的 :ui[workspace.title] 或目前的分支上。
- :ui[reflog.reset]{1="9e0d36a7"} 開啟重設對話框，把目前的分支移到那個提交。
- :ui[patch.menu]{1="9e0d36a7"} 把這個提交存成修補檔。

想在側邊欄裡顯示 :ui[reflog.title]，在 :ui[sidebar.viewSettings] 裡開啟 :ui[sidebar.showReflog]。

:::caution
Git 會慢慢清理舊的 Reflog 記錄。預設情況下，記錄保留 90 天；提交已經不在分支上的，保留 30 天。提交遺失了要盡早找回。
:::

:::note[伺服器儲存庫]
Reflog 在伺服器上的儲存庫裡，Spooky 從那裡讀取。
:::

## 相關頁面

- [提交變更](/guide/work/commit/)
- [解決衝突](/guide/work/conflicts/)
- [改寫歷史](/guide/history/rewrite/)

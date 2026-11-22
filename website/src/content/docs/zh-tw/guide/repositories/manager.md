---
title: "儲存庫管理視窗"
description: "在儲存庫管理視窗裡收藏、分組、開啟、複製、新增、尋找與刪除儲存庫，還能找回遺失的儲存庫。"
---

儲存庫管理視窗存著一份你常用的儲存庫列表，這台 Mac 上的和伺服器上的都在裡面。列表裡的每一項是一個書籤，指向一個儲存庫。刪掉書籤時，儲存庫資料夾留在原處。把資料夾移到垃圾桶要另外勾選。這一頁講怎樣加入、整理、開啟和刪除儲存庫。

在儲存庫視窗裡想回到列表，按一下工具列上的 :ui[toolbar.bookmarks]，或選 :ui[menu.view > menu.showRepositories]（<kbd>⌃⌘R</kbd>）。

::screenshot[儲存庫管理視窗。側邊欄裡有 Driftwood Labs 與 Notes 兩個群組，裡面是各自的儲存庫，其中一個是伺服器儲存庫，名稱以主機別名開頭。右邊是所選儲存庫 driftwood 的詳細資訊：位置、上次開啟的時間、最近的提交、描述、提交者身分、目前分支、變更檔案的數量與遠端。]{name="repositories" frame="window"}

## 加入儲存庫 {#add}

側邊欄底部的加入按鈕帶有一個選單，用來往列表裡加入：

| 選單項目 | 作用 |
|---|---|
| :ui[bookmarks.newGroup] | 在所選項目的下方新增一個群組，接著輸入名稱 |
| :ui[bookmarks.add] | 加入已經在這台 Mac 上的儲存庫，可以一次選好幾個資料夾 |
| :ui[action.addRemote] | 加入伺服器上的儲存庫，見 [加入伺服器儲存庫](/guide/server/add/) |
| :ui[bookmarks.create] | 新增一個空儲存庫，見 [新增儲存庫](#create) |
| :ui[clone.menu] | 從遠端複製一個儲存庫，見 [複製儲存庫](#clone) |
| :ui[scan.menu] | 找出某個資料夾裡的儲存庫，見 [尋找儲存庫](#scan) |

新加入的項目放進所選的群組。也可以直接從 Finder 把儲存庫資料夾拖進列表。用 :ui[menu.file > action.openLocal] 開啟的儲存庫，如果還不在列表裡，會被加到列表末尾。

### 新增儲存庫 {#create}

1. 在加入按鈕的選單裡選 :ui[bookmarks.create]。
2. 在 :ui[bookmarks.create.name] 裡輸入新儲存庫的名稱，它也是儲存庫資料夾的名稱。
3. 按一下 :ui[bookmarks.create.location] 旁邊的 :ui[bookmarks.create.choose]，選擇在哪個資料夾裡新增。預設是你的個人資料夾。
4. 按一下 :ui[bookmarks.create.submit]。

Spooky 新增這個資料夾，把它初始化為一個空的 Git 儲存庫，加進所選的群組，然後開啟它。

### 複製儲存庫 {#clone}

複製（clone）就是把遠端的儲存庫連同歷史，拷貝到一個新資料夾裡。

1. 在加入按鈕的選單裡選 :ui[clone.menu]，或按 <kbd>⌃⌘C</kbd>。
2. 在 :ui[clone.url] 裡填寫儲存庫的位址，例如以 `https://` 或 `git@` 開頭的位址。
3. 在 :ui[clone.to] 裡選 :ui[clone.machine.local] 或一台伺服器。已經在用的伺服器會列在裡面。要用別的伺服器，選 :ui[clone.machine.other]，填上它的 :ui[remote.host]。
4. 在 :ui[clone.directory] 裡選擇複製到哪個資料夾。Spooky 會在裡面新增一個以儲存庫名稱命名的資料夾。
5. 保持勾選 :ui[clone.submodules]，儲存庫的子模組會一起簽出。儲存庫用 Git LFS 存放大型檔案時，勾選 :ui[clone.lfs]。
6. 按一下 :ui[clone.submit]。

Spooky 先檢查能不能連上遠端。連不上時，對話框不關，會寫出原因，改好位址再試就行。連上後對話框關閉，複製在背景進行。進度顯示在列表裡這個儲存庫的那一列。複製完成後，Spooky 會發出一則 :ui[clone.notification.title] 通知。

複製到這台 Mac 時，資料夾預設是你的個人資料夾，或者是 :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory] 裡設定的資料夾，見 [複製與終端機](/guide/settings/general/#cloning)。

有最近的複製時，工具列上會出現 :ui[toolbar.clone]。按一下它會顯示 :ui[clone.recent.title]。在那裡可以停止正在進行的複製，用 :ui[clone.retry] 重新開始失敗或取消的複製，或者把它 :ui[clone.remove]。按兩下完成的複製就能開啟它。:ui[clone.recent.clear] 清空這份列表。

:::note[伺服器儲存庫]
複製到伺服器時，Spooky 在伺服器上檢查連線、執行複製。新儲存庫作為伺服器儲存庫加進列表。資料夾要填伺服器上的絕對路徑，也可以按一下 :ui[clone.browse] 挑選。Spooky 會記住每台伺服器上次用的資料夾。
:::

也可以把儲存庫的位址拖進列表，或者用連結發起複製，見 [視窗與導覽](/guide/repositories/navigation/)。

### 尋找儲存庫 {#scan}

1. 在加入按鈕的選單裡選 :ui[scan.menu]。
2. 在 :ui[scan.in] 裡選 :ui[clone.machine.local] 或一台伺服器，再選要尋找的資料夾。
3. 按一下 :ui[scan.start]。找到的儲存庫會陸續列出來。想停下，按一下 :ui[scan.stop]。
4. 找到的儲存庫預設都已勾選。取消勾選不想要的，再按一下 :ui[scan.add]。

已經在列表裡的儲存庫不會再列出。可以接連尋找幾個資料夾或幾台伺服器，結果會累加起來。

## 整理列表 {#organize}

- 新增群組：在加入按鈕的選單裡選 :ui[bookmarks.newGroup]，再輸入名稱。
- 調整順序或移進別的群組：直接拖移。
- 重新命名：在這一項上按右鍵，選 :ui[bookmarks.rename]。在列表裡替儲存庫重新命名，不會改動它的資料夾名稱。
- 按名稱排序：按右鍵，選 :ui[bookmarks.sortChildren] 替一個群組裡的項目排序，或選 :ui[bookmarks.sortParent] 替這一項所在的群組排序。

:ui[app.name > settings.title] › :ui[settings.general] 裡有兩個選項決定列表顯示什麼：

- :ui[settings.showWorktreesInRepositoryList]：有其他工作樹的儲存庫可以展開，列出這些工作樹。開啟工作樹的方式和開啟儲存庫一樣。預設關閉。
- :ui[settings.showHostAliasesInRepositoryList]：伺服器儲存庫的名稱以主機別名開頭。預設開啟。

見 [視窗與儲存庫管理](/guide/settings/general/#windows)。

## 開啟儲存庫 {#open}

按兩下一個儲存庫，或選取後按 <kbd>↩</kbd>。儲存庫在同一個視窗裡開啟，取代列表。儲存庫已經在另一個視窗裡開啟時，Spooky 會切換到那個視窗。

在一個儲存庫上按右鍵還有更多選擇：

- :ui[bookmarks.open]{1="driftwood"} 與 :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder]、:ui[action.copyPath] 與 :ui[action.openTerminal]

右邊的詳細資訊裡也有 :ui[action.open] 與 :ui[bookmarks.multiple.delete] 按鈕。按一下那裡的 :ui[bookmarks.detail.edit]，可以修改 :ui[bookmarks.detail.description] 與 :ui[bookmarks.detail.identity]。:ui[bookmarks.detail.unset] 去掉替這個儲存庫另外設定的身分。每個遠端旁邊的 :ui[bookmarks.detail.viewInBrowser] 會開啟它的網頁。這裡的描述與身分，和 [儲存庫設定](/guide/settings/identity/#repository) 裡的是同一份。

:::note[伺服器儲存庫]
:ui[action.copyPath] 拷貝的路徑前面帶著主機別名，形如 `alias:/path/to/repository`。伺服器儲存庫的詳細資訊在選取時才讀取。選取它時，Spooky 可能會去連線伺服器。
:::

## 遺失的儲存庫 {#missing}

儲存庫的資料夾被移動、重新命名或刪除後，它在列表裡的名稱會變灰，帶一個警告標記。詳細資訊裡寫著 :ui[bookmarks.detail.missing]每次顯示列表時，Spooky 都會檢查這台 Mac 上的儲存庫。

開啟一個遺失的儲存庫時，視窗顯示 :ui[missing.title]。按一下 :ui[action.refresh] 重新檢查，例如重新接上磁碟之後。按一下 :ui[action.close] 回到列表。

要修好這一項，把它刪掉，再從儲存庫現在的位置重新加入。

:::note[伺服器儲存庫]
伺服器儲存庫只在選取或開啟時檢查。連不上伺服器時，視窗顯示 :ui[missing.unreachable.title]{1="alias"}，下面是 SSH 回報的內容，見 [連線狀態與重新連線](/guide/server/connection/)。
:::

## 刪除儲存庫 {#delete}

選取一項或幾項，然後用下面任一種做法：

- 按 <kbd>⌫</kbd>。
- 按右鍵，選 :ui[bookmarks.delete]{1="driftwood"}。群組選 :ui[bookmarks.deleteFolder]，選了幾項時選 :ui[bookmarks.deleteMultiple]{1="2"}。
- 按一下詳細資訊裡的 :ui[bookmarks.multiple.delete]。

儲存庫資料夾還在時，Spooky 會先問 :ui[bookmarks.delete.title]{1="driftwood"}只有書籤會被移除，資料夾留在原處。想把資料夾也移到垃圾桶，勾選 :ui[bookmarks.delete.trash]。按一下 :ui[bookmarks.delete.submit] 確認。

空的群組和資料夾已經不在的項目會直接刪除，不再詢問。

:::caution
移到垃圾桶的是整個儲存庫資料夾，包括還沒提交的變更。清空垃圾桶之前，還可以從垃圾桶裡找回。每次開啟對話框時，移到垃圾桶的註記框都是不勾選的。
:::

有資料夾移不動時，Spooky 顯示 :ui[bookmarks.trashFailed.title]，列出留下的資料夾。你的個人資料夾、包含它的資料夾和磁碟的最上層，Spooky 都不會移到垃圾桶。

:::note[伺服器儲存庫]
刪除伺服器儲存庫時，Spooky 總會先問一句。它的資料夾會移進那台伺服器上的垃圾桶，不是你 Mac 上的。
:::

## 相關頁面

- [視窗與導覽](/guide/repositories/navigation/)
- [加入伺服器儲存庫](/guide/server/add/)
- [工作樹](/guide/advanced/worktrees/)

---
title: "介面導覽"
description: "認識儲存庫管理視窗與儲存庫視窗：側邊欄、工具列、三欄和快速操作。"
---

Spooky 的視窗顯示兩樣東西：儲存庫管理和儲存庫。儲存庫管理列出你所有的儲存庫，儲存庫視窗是你實際工作的地方。這一頁介紹兩者的各個部分，手冊的其他頁都用這些名稱。

## 儲存庫管理視窗 {#repositories-window}

第一次開啟 Spooky 時，視窗顯示儲存庫管理。側邊欄在 :ui[repositories.title] 下列出你的儲存庫。儲存庫可以分進不同的群組。

- 選取一個儲存庫，右邊顯示它的詳細資訊：位置、上次開啟的時間、最近的提交、目前分支與變更、遠端。
- 選取一個群組或什麼都不選，右邊是一塊寫著 :ui[bookmarks.dropZone.title] 的區域，下面有 :ui[bookmarks.dropZone.add]、:ui[action.addRemote]、:ui[bookmarks.dropZone.create] 與 :ui[bookmarks.dropZone.clone] 幾個按鈕。
- 側邊欄底部的加入按鈕用來加入群組與儲存庫。

按兩下一個儲存庫就能開啟它。儲存庫在同一個視窗裡開啟，取代儲存庫管理。想回到列表，按一下側邊欄上方的 :ui[toolbar.bookmarks]。[儲存庫管理視窗](/guide/repositories/manager/) 詳細介紹這個列表。

## 儲存庫視窗 {#repository-window}

開啟儲存庫後，視窗標題顯示儲存庫的名稱。下面一行是目前的視圖和簡短的摘要，例如分支與變更檔案的數量。

::screenshot[一個儲存庫視窗。左邊的側邊欄列出儲存庫的各個視圖、分支、標籤與遠端；頂部是工具列；中間一欄上方是提交區，下方是變更的檔案列表；右邊一欄顯示所選檔案的變更。]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. 側邊欄
2. 工具列
3. 中間一欄：目前視圖的列表
4. 右邊一欄：中間一欄所選內容的詳細資訊

:::note[伺服器儲存庫]
視窗標題以主機別名開頭，形如 `alias:name`。工具列上多出一項 :ui[toolbar.host]，顯示主機別名。連線中斷時視窗顯示什麼，見 [連線狀態與重新連線](/guide/server/connection/)。
:::

### 側邊欄 {#sidebar}

最上面的 :ui[workspace.group] 一組用來切換儲存庫的各個視圖：

| 視圖 | 顯示的內容 |
|---|---|
| :ui[workspace.title] | 還沒提交的變更。旁邊的數字是變更檔案的數量 |
| :ui[history.title] | 提交記錄 |
| :ui[stash.title] | 暫時收起來的變更 |
| :ui[pr.title] | 託管服務上的 Pull Request 或 Merge Request |
| :ui[review.title] | 你的分支，用來找出可以清理的分支 |
| :ui[reflog.title] | HEAD 去過哪些地方。在 :ui[sidebar.viewSettings] 裡開啟 :ui[sidebar.showReflog] 後才顯示 |
| :ui[repositorySettings.title] | 這個儲存庫的設定，見 [儲存庫設定](/guide/settings/identity/#repository) |

再往下依序是 :ui[sidebar.pinned]（釘選了分支後才有）、:ui[branch.group]、:ui[sidebar.archived]、:ui[sidebar.tags]、:ui[remote.group]、:ui[submodule.group] 與 :ui[worktree.group]。:ui[branch.group] 裡，帶 HEAD 標記的是你目前所在的分支。↑3 這樣的箭頭加數字，表示還有幾個提交沒推送。

側邊欄底部一欄有 :ui[sidebar.filter] 輸入框、新增分支等參照用的 :ui[reference.addMenu] 按鈕、決定側邊欄顯示什麼的 :ui[sidebar.viewSettings]。

### 工具列 {#toolbar}

工具列上的按鈕從左到右依序是：

- :ui[toolbar.bookmarks]：回到儲存庫管理
- :ui[toolbar.previous] 與 :ui[toolbar.next]：在去過的視圖之間往回、往前
- :ui[toolbar.finder] 與 :ui[toolbar.terminal]：在 Finder 裡顯示儲存庫資料夾，或在終端機裡開啟它
- :ui[sync.fetch]、:ui[sync.pull] 與 :ui[sync.push]：與遠端交換提交
- :ui[toolbar.forcePush]：改寫過提交之後，用你的分支取代遠端分支
- :ui[toolbar.applyStash] 與 :ui[toolbar.saveStash]：取回收起來的變更，或把目前的變更收起來
- :ui[toolbar.createBranch]：新增一個分支
- :ui[action.refresh]：重新讀取儲存庫
- :ui[action.search]：篩選目前視圖的列表

按住 <kbd>⌥</kbd> 時，:ui[sync.fetch]、:ui[sync.pull] 與 :ui[sync.push] 會換成快速版本，例如 :ui[sync.quickPush]。快速版本直接對追蹤分支執行，不跳出對話框。

有最近的複製時，工具列上還會出現 :ui[toolbar.clone]，見 [儲存庫管理視窗](/guide/repositories/manager/)。想增減按鈕，選 :ui[menu.view > menu.customizeToolbar]。除了上面這些，還可以加上 :ui[toolbar.quickActions]、:ui[toolbar.synchronize]、:ui[sync.merge] 與 :ui[sync.rebaseHead]，以及 :ui[toolbar.pushTo]。還可以建立執行自己腳本的按鈕，見 [工具列按鈕](/guide/settings/integration/#toolbar-buttons)。

### 三欄 {#columns}

左邊一欄是側邊欄。中間一欄是所選視圖的列表。在 :ui[workspace.title] 裡是提交區與變更的檔案，在 :ui[history.title] 裡是提交記錄。

右邊一欄顯示中間所選內容的詳細資訊。在 :ui[workspace.title] 裡，就是所選檔案的變更。一個檔案既有已暫存、又有未暫存的變更時，用頂部的 :ui[working.staged] 與 :ui[working.unstaged] 切換。什麼都沒選時，這一欄顯示 :ui[detail.empty.title]。

### 窄視窗 {#narrow-window}

視窗窄到放不下三欄時，會換成窄視窗的版面。把視窗拉寬，三欄就回來了，寬度和原來一樣。

::screenshot[一個很窄的儲存庫視窗。工具列下面的一列用來切換視圖；提交區與變更的檔案列表在上，所選檔案的變更在下。]{name="tour-narrow-window" frame="window" markers="75,9 75,40 75,84"}

1. 切換視圖的一列，取代側邊欄
2. 目前視圖的列表
3. 列表裡所選內容的詳細資訊

- 切換視圖的一列裡是側邊欄 :ui[workspace.group] 下的各個視圖，放不下的，橫向捲動這一列就能看到。要看分支、標籤、遠端和其他視圖，按一下這一列開頭的 :ui[sidebar.menu]，側邊欄會蓋在視圖上面。再按一下 :ui[sidebar.menu]，或按一下側邊欄外面，就能收起它。
- 列表在上，詳細資訊在下。拖移兩者之間的分隔線，可以調整各自的高度。
- :ui[toolbar.bookmarks]、:ui[toolbar.previous] 與 :ui[toolbar.next] 排在視窗標題前面，和搜尋框一起一直留在工具列上。其他放不下的按鈕收進工具列末尾的 » 選單，:ui[sync.fetch]、:ui[sync.pull] 與 :ui[sync.push] 最後才收進去。

版面切換時，所在的視圖、選取的內容和正在寫的提交訊息都不變。

儲存庫管理視窗變窄時也會換版面：儲存庫列表在上，所選儲存庫的詳細資訊在下。

想固定用一種版面，在 :ui[menu.view > menu.layout] 裡選 :ui[menu.layout.narrow] 或 :ui[menu.layout.wide]，視窗不論寬窄都用這種版面。選 :ui[menu.layout.automatic]，版面重新跟著視窗的寬度變。這個選擇對所有視窗生效。

### 快速操作 {#quick-actions}

選 :ui[menu.file > quickActions.menu] 或按 <kbd>⇧⌘A</kbd>，會開啟一個面板。輸入文字找到某個視圖、分支、檔案或提交，再對它執行操作，手不用離開鍵盤。它能找到什麼、用哪些按鍵，見 [視窗與導覽](/guide/repositories/navigation/)。

## 相關頁面

- [第一個儲存庫](/guide/start/first-repository/)
- [儲存庫管理視窗](/guide/repositories/manager/)
- [視窗與導覽](/guide/repositories/navigation/)

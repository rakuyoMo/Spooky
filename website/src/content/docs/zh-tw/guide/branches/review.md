---
title: "分支整理"
description: "把本機分支和一個基準分支比較，找出可以清理的分支，參考封存建議，以及自動封存分支。"
---

分支整理列出你的本機分支，把每一個都和一個基準分支比較。哪些分支可以合併、哪些會衝突、哪些已經陳舊、哪些的遠端分支已經不在了，一眼就能看到。這樣你就能決定合併、封存還是刪除。

想開啟它，按一下側邊欄頂端的 :ui[review.title]，或者選 :ui[menu.view > review.show]（<kbd>⌘5</kbd>）。

::screenshot[分支整理視窗。基準分支是 main。列表裡是從 feature/csv-export 到 spike/radar-overlay 的六個分支，各自帶著合併狀態、領先與落後的提交數和追蹤的分支。選取的是 feature/units-toggle，右邊的詳細資訊列出它的提交，頂端有一個衝突按鈕。]{name="branches-review" frame="window" markers="35.4,9 47.3,9 22,52 76,9"}

1. 基準分支
2. 篩選按鈕
3. 能否順利合併
4. 衝突按鈕

## 列表 {#list}

在列表頂端的 :ui[review.compareTo] 裡選基準分支。一開始是儲存庫裡有的 `next`、`develop`、`dev`、`main`、`master` 中排在最前的一個，都沒有時是目前所在的分支。

每個分支一列：

- 左邊的圖示說明這個分支能不能乾淨地併入基準，還是會產生衝突。把指標停在上面可以看到說明。
- 右邊是這個分支比基準領先、落後幾個提交。Spooky 比較時顯示 :ui[review.comparing]。
- 第二行是它追蹤的遠端分支，沒有時寫 :ui[review.noTracking]。遠端分支已經不在時，名稱會變紅。
- 分支最後更新的時間，以及這個分支最近的 Pull Request 或 Merge Request，帶著編號和表示狀態的顏色。

## 篩選與排序 {#filter}

右上角的篩選按鈕只顯示一部分分支：

- :ui[review.filter.stale] 與 :ui[review.filter.active] 按是否陳舊分開。陳舊是指多久沒有新提交，時間長度在側邊欄的 [顯示設定](/guide/branches/branches/#filter) 裡設定，一開始是 6 個月。
- :ui[review.filter.trackingError] 顯示遠端分支已經不在的分支。
- :ui[review.filter.mergeable] 與 :ui[review.filter.conflicts] 按併入基準的結果來分。
- :ui[pr.filter.with] 與 :ui[pr.filter.without] 按有沒有開啟中的 Pull Request 或 Merge Request 來分。這需要為遠端加入 [託管帳號](/guide/hosting/accounts/)。沒有帳號時，列表會提示。
- :ui[review.filter.none] 重新顯示全部分支。

旁邊的顯示設定按鈕可以按 :ui[review.sort.name] 或 :ui[review.sort.date] 排序，按 :ui[review.sort.ascending] 或 :ui[review.sort.descending] 排列。篩選和排序 Spooky 都會記住。

想按名稱找分支，在工具列的搜尋欄位裡輸入。

## 詳細資訊 {#details}

選取一個分支，右邊會顯示它和基準的比較。頂端寫著分支和基準。併入會衝突時，那裡有一個按鈕列出衝突的檔案。

:ui[compare.commits] 列出這個分支從基準分出來之後的提交。:ui[history.changeset] 顯示這些提交改了什麼。兩者上方的摘要寫著 :ui[review.summary.contributors]、:ui[review.summary.updated]、:ui[review.summary.tracking] 與 :ui[review.summary.mergeStatus]。

可以一次選取幾個分支，例如一起封存或刪除。

## 處理分支 {#actions}

在分支上按右鍵，選單和側邊欄裡的一樣。選取了幾個分支時，選單作用於全部所選分支。

分支和基準會衝突時，選單裡還有 :ui[review.resolveConflicts]。Spooky 會簽出這個分支，把基準合併進來。然後你在分支上解決衝突，見 [解決衝突](/guide/work/conflicts/)。

想刪除分支，選取後按 <kbd>⌘⌫</kbd>，或者在一列上向左滑動，按一下 :ui[review.delete]。和在側邊欄裡一樣，Spooky 會先問一下。

## 封存建議 {#archive-suggestions}

符合下面任一條件的本機分支，Spooky 會建議 [封存](/guide/branches/branches/#archive)：

- 它已經陳舊。
- 它的 Pull Request 或 Merge Request 已經合併，之後分支上沒有新提交。

釘選和已封存的分支不會被建議。`main`、`master`、`trunk`、`dev`、`develop`、`next`，以及當了別的分支父分支的分支，也不會。

有建議、又沒有開啟自動封存時，側邊欄底部會出現一個帶著分支數的按鈕。按一下它開啟 :ui[review.archive.title]：

1. 勾選要封存的分支，或者勾選 :ui[menu.selectAll]。一開始一個都沒勾。每個分支後面寫著建議的原因：:ui[pr.archive.merged] 或 :ui[review.filter.stale]。
2. 按一下 :ui[review.archive.submit]。

::screenshot[封存分支對話框列出三個分支，每個後面都標著陳舊，勾選了其中一個。底部是自動封存分支的開關。]{name="branches-archive" frame="dialog"}

封存之後，側邊欄底部會有一行說明封存了幾個分支，旁邊是 :ui[review.archived.undo] 按鈕。<kbd>⌘Z</kbd> 也可以。:ui[activity.title] 裡記著每個分支為什麼被封存。

## 自動封存 {#auto-archive}

Spooky 可以每天檢查一次有沒有要封存的分支。下面幾處都能開啟它，它們是同一個設定：

- :ui[review.archive.title] 對話框裡的 :ui[review.archive.auto]
- 側邊欄顯示設定裡的 :ui[sidebar.autoArchive]
- :ui[app.name > settings.title] › :ui[settings.general] 裡的 :ui[settings.autoArchive]，見 [操作](/guide/settings/general/#operations)

一開始是關閉的。

每個儲存庫每天一次，在你使用它的視窗時，Spooky 會找一遍封存建議。有的話，它會開啟同一個對話框。你在裡面勾選要封存的分支。不論這次封存了沒有，都要等一天後再檢查。

想讓某個分支不參與，在它上面按右鍵，勾選選單裡封存項目下面的 :ui[review.skipAutoArchive]。

這樣封存了分支之後：

- 系統通知會顯示 :ui[review.archived.notification]。:ui[activity.title] 裡的記錄叫 :ui[review.autoArchive]。
- 側邊欄 :ui[sidebar.archived] 旁的圓點表示有你還沒看過的分支。按一下其中一個，過一會兒它的標記就會消失。想一次清掉，在 :ui[sidebar.archived] 上按右鍵，選 :ui[sidebar.markAllReviewed]。

## 相關頁面

- [分支](/guide/branches/branches/)
- [合併與變基](/guide/branches/merge-rebase/)
- [Pull Request 與 Merge Request](/guide/hosting/pull-requests/)
- [託管帳號](/guide/hosting/accounts/)

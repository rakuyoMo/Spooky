---
title: "瀏覽歷史"
description: "瀏覽提交列表與提交圖，看懂參照徽章，搜尋與篩選提交，調整視圖選項。"
---

:ui[history.title] 視圖從新到舊列出儲存庫的提交，旁邊的提交圖畫出它們之間的關係。選取一個提交，右邊就顯示它的詳細資訊。

::screenshot[一個儲存庫的歷史視圖。列表上方的表頭寫著「所有分支、遠端與標籤」，最右端是視圖選項按鈕。提交按月分組，排在 2026 年 11 月的小標題下面。左邊的彩色線條把提交連起來，作者名字旁邊有 HEAD、main、v0.4.0 等徽章。右邊是所選提交的詳細資訊，最上面是「變更集」與「檔案樹」兩個按鈕。]{name="history" frame="window" markers="50,13.75 42,23 22.5,62 81,9"}

1. 表頭：列表顯示的範圍，以及視圖選項
2. 指向提交的分支與標籤的徽章
3. 提交圖
4. 所選提交的詳細資訊，見 [提交詳細資訊](/guide/history/commit-details/)

## 開啟歷史 {#open}

- 選 :ui[menu.view > menu.showHistory]（<kbd>⌘2</kbd>），或按一下側邊欄的 :ui[history.title]，就能把所有分支、遠端分支與標籤放在一起看。表頭寫著 :ui[history.all]。
- 按一下側邊欄裡的一個分支、標籤或遠端分支，就只看它的歷史。按住 <kbd>⌘</kbd> 再按別的，可以把幾個放在一起看。
- 選 :ui[menu.view > history.showHead]（<kbd>⌘0</kbd>），看目前所在分支的歷史。

看的是設了上游的本機分支時，表頭把兩者都寫出來，形如 `main › origin/main`。列表裡還會有上游上那些你還沒拉取的提交。

## 提交列表 {#list}

每一列寫著作者的大頭貼與名字、日期、短雜湊，以及提交訊息的第一行。提交預設按月分組。

列表顯示的是設了上游的本機分支時：

- ↑ 標出還沒推送的提交。
- ↓ 標出還沒拉取的提交，這些列的顏色會變淺。

Spooky 先讀出前 100 個提交，捲到底時再讀後面的 100 個。想一次多讀一些，在 :ui[app.name > settings.title] › :ui[settings.general] 裡改 :ui[history.pageSize]。同一頁的 :ui[settings.dateFormat] 決定列表裡日期的寫法，見 [歷史與 Diff](/guide/settings/general/#history)。

按一下提交就選取它。按住 <kbd>⇧</kbd> 或 <kbd>⌘</kbd> 再按，可以選取多個。按 <kbd>⌘C</kbd> 拷貝所選提交的完整雜湊。按兩下提交，就整頁開啟它的詳細資訊。

在提交上按右鍵，可以看到對它能做的所有操作。如果這個提交沒被選取，選單只作用於它一個，原來的選取範圍保持不變。

## 提交圖 {#graph}

左邊的提交圖把每個提交畫成一個圓點，再往下連到它的父提交。往下伸出不只一條線的，是合併提交。

想隱藏它，在 [視圖選項](#view-options) 裡關掉 :ui[history.showGraph]（<kbd>⌃⌘G</kbd>）。:ui[history.firstParentOnly] 在每個合併處只沿第一父提交往下走，經合併帶進來的提交就不顯示了。

## 參照徽章 {#badges}

作者名字旁邊的徽章表示有什麼指向這個提交：

| 徽章 | 指向提交的是 |
|---|---|
| 藍色的 HEAD | 目前簽出的提交 |
| 藍色 | 本機分支 |
| 灰色 | 遠端分支 |
| 黃色 | 標籤 |
| 紅色 | 儲藏 |

目前所在的分支排在最前面。放不下的徽章會收成一個「…」。

按一下標籤的徽章，可以看到標籤的簽章：用的是哪把金鑰、簽章是否有效，或者 :ui[signature.unsigned]。

## 搜尋與篩選 {#search}

1. 按 <kbd>⌘F</kbd>，或按一下工具列上的搜尋框。
2. 按一下框裡的放大鏡，選要搜尋什麼：:ui[history.search.message]、:ui[history.search.author]、:ui[history.search.committer]、:ui[history.search.file]、:ui[history.search.hash]、:ui[history.search.sinceDate] 或 :ui[history.search.untilDate]。
3. 輸入內容，列表就只顯示符合的提交。

輸入時，Spooky 會給出作者、提交者與檔案路徑的建議。搜尋提交訊息時，建議裡還能換成別的搜尋方式。輸入的是日期時，第一項建議是搜尋這個日期以來的提交。

各種方式怎樣比對：

- 提交訊息、作者與提交者按正規表示式比對，不分大小寫。
- 檔案比對變更過它的提交。資料夾比對變更過其中任何內容的提交。
- 提交雜湊至少要寫前 4 個字元。

搜尋條件會顯示在表頭下面的一列裡。想再加一個條件，按一下加入按鈕，在新的一列開頭的選單裡選它的種類。日期條件可以選 :ui[history.search.after]、:ui[history.search.before] 或 :ui[history.search.range]。想刪掉一個條件，按一下它的移除按鈕。

有幾個條件時：

- 種類不同的條件要全部符合。
- 種類相同的幾個條件，符合其中一個就行。日期例外：每個日期條件都要符合。

按 <kbd>Esc</kbd> 離開搜尋框，列表仍是篩選後的樣子。切換到別的視圖時，搜尋就結束了。

## 視圖選項 {#view-options}

按一下表頭最右端的視圖選項按鈕，或者選 :ui[menu.view > history.title]：

| 選項 | 作用 |
|---|---|
| :ui[history.showGraph] | 顯示提交圖。預設開啟 |
| :ui[history.firstParentOnly] | 在每個合併處只沿第一父提交往下走 |
| :ui[history.sortBy] | :ui[history.sort.topo] 把同一條開發線上的提交排在一起。:ui[history.sort.date] 按日期排列。顯示提交圖時 :ui[history.sort.topo] 始終開啟。兩項都開啟時按日期排列 |
| :ui[history.groupBy] | 按天、按週或按月給提交分組並加上小標題，也可以不分組。只在按日期排列時有效 |
| :ui[history.medium] / :ui[history.small] | 每個提交佔兩行或一行。小號列只在顯示提交圖時有效 |
| :ui[signature.verify] | 標出帶簽章的提交，見 [簽章](/guide/history/commit-details/#signatures) |
| :ui[history.compareBranches] | 見 [與另一個分支比較](#compare-branches) |

這些選項對所有視窗和所有儲存庫都有效。Spooky 會記住它們。

## 與另一個分支比較 {#compare-branches}

想看一個本機分支和另一個分支的關係：

1. 按一下側邊欄裡的這個分支。
2. 按一下表頭裡的比較按鈕。也可以在視圖選項裡開啟 :ui[history.compareBranches]，或者按 <kbd>⌃⌥⌘C</kbd>。
3. 在 :ui[history.compareTo] 旁邊的選單裡選另一個分支。這個分支有父分支時，Spooky 先選父分支。

列表裡有一列標出兩個分支分開的地方。它下面的提交也屬於另一個分支，顏色會變淺。如果這個分支還沒有自己的提交，列表裡寫著 :ui[history.noNewCommits]。

表頭還可能出現兩個徽章。一個是另一個分支上有、這個分支還沒有的提交數。另一個在合併另一個分支會產生衝突時出現，按一下它可以列出這些檔案。

## 在歷史中找到一個提交 {#reveal}

列表只顯示部分分支時，在提交上按右鍵，選 :ui[quickActions.revealInHistory]。列表會換成所有分支，並選取這個提交。

如果這個提交排得很後面，在前 1 萬個提交之外，Spooky 會先問你要不要把歷史讀到那麼遠。如果歷史裡沒有這個提交，列表上方會有一列說明。

## 相關頁面

- [提交詳細資訊](/guide/history/commit-details/)
- [改寫歷史](/guide/history/rewrite/)
- [分支](/guide/branches/branches/)

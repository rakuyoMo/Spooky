---
title: "檔案歷史與 Blame"
description: "檢視一個檔案的歷史，用 Blame 看每一行由誰變更，檢視檔案在某個版本的原文，以及從那個版本回復檔案。"
---

這幾個視圖一次只看一個檔案：哪些提交改過它，每一行是誰寫的，以及它在過去任何時候的樣子。

## 檔案歷史 {#file-history}

想看改過一個檔案的所有提交：

- 在工作區裡對這個檔案按右鍵，選 :ui[fileHistory.showHistoryOf]{1="units.ts"}。
- 或者把指標移到右邊一欄頂端的檔案名稱上，按一下 :ui[fileHistory.title]。
- 在 [提交詳細資訊](/guide/history/commit-details/#changeset) 裡，對變更集或檔案樹中的檔案按右鍵，選同一項。

在工作區裡，也可以選取一個資料夾，按一下右邊一欄頂端的 :ui[fileHistory.title]。這時的歷史包括其中所有的檔案。

左邊一欄從新到舊列出提交，按月分組。最上面寫著檔案名稱與提交的個數。按一下檔案名稱可以換成別的檔案。

選取一個提交，右邊就顯示它對這個檔案改了什麼。換到 :ui[showFile.raw] 可以看到這個提交裡的完整檔案，換回 :ui[fileHistory.diff] 再看變更。把指標移到頂端的短雜湊上，還有這幾個按鈕：

- :ui[blame.title] 顯示這個提交時每一行是誰寫的，見 [Blame](#blame)。
- :ui[fileHistory.showCommit] 用 [整頁詳細資訊](/guide/history/commit-details/#full-page) 開啟這個提交。
- :ui[externalTool.action.diffTool] 用你的比較工具開啟這次變更。

::screenshot[src/units.ts 的檔案歷史。左欄頂端是檔案名稱與提交數，下面按月列出改過它的提交。右邊是所選提交在這個檔案裡的變更。指標停在短雜湊上，右上角 Diff 與「原文」切換的旁邊露出 Blame、「顯示提交」與「比較工具」三個按鈕。]{name="history-file-history" frame="window" markers="28.5,9 94.6,13.25 86,13.25"}

1. 檔案名稱與提交的個數
2. :ui[fileHistory.diff] 與 :ui[showFile.raw] 的切換
3. 指標移到短雜湊上時出現的按鈕

按兩下提交，或者按 <kbd>Return</kbd>，同樣會用整頁詳細資訊開啟它。在提交上按右鍵，選單裡有同樣的操作，還能回復或匯出這個提交裡的檔案。

### 搜尋檔案歷史 {#file-history-search}

在工具列的搜尋框裡輸入，列表就只剩符合的提交。按一下框裡的放大鏡，選要搜尋什麼：:ui[fileHistory.scope.message]、:ui[fileHistory.scope.hash]、:ui[fileHistory.scope.author] 或 :ui[fileHistory.scope.committer]。

- 說明、作者與提交者按輸入的文字比對，不分大小寫。作者與提交者按名字或電子郵件比對。
- 輸入提交雜湊、分支或標籤時，顯示到那裡為止最近一個改過這個檔案的提交。

## Blame {#blame}

Blame 顯示整個檔案，右邊有一欄寫著每一塊最後是哪個提交改的。每一塊顯示作者的大頭貼、提交訊息的第一行、作者，以及是多久以前。

- 在工作區裡對檔案按右鍵，選 :ui[blame.show]{1="units.ts"}。或者把指標移到右邊一欄頂端的檔案名稱上，按一下 :ui[blame.title]。
- 在一個提交的變更集或檔案樹裡，選 :ui[fileHistory.blameAt]{1="units.ts" 2="e2dda2bc"}，看檔案在那時的樣子。

::screenshot[src/units.ts 的 Blame。左邊是檔案，右邊一欄寫著每一塊最後由哪個提交變更：大頭貼、提交訊息、作者和多久以前。Drop trailing zeros from temperatures 的幾塊亮著。]{name="history-blame" frame="window" markers="84,22 84,82.5"}

1. 寫著每一塊由哪個提交改的那一欄
2. 按下的提交亮起來的幾塊

按一下一塊，可以看到它的提交的摘要。同一個提交的所有區塊都會亮起來。按兩下一塊，就用整頁詳細資訊開啟它的提交。想把這一欄調寬或調窄，拖移它的左邊緣。Spooky 會記住寬度。

Blame 只能看已經提交過的檔案。新檔案、未追蹤的檔案、二進位檔案與子模組都無法檢視。

## 檢視檔案在某個版本的原文 {#show-file}

想看一個檔案在任何一個提交裡的樣子，又不動工作區：

- 在工作區裡對檔案按右鍵，選 :ui[showFile.show]{1="units.ts"}。這裡顯示的是 HEAD 裡的版本。
- 在一個提交的變更集或檔案樹裡，選 :ui[fileHistory.showAt]{1="units.ts" 2="e2dda2bc"}。

標頭像一條路徑：版本 › 檔案。

- 按一下版本可以換一個提交：在列表裡按兩下提交就換成它。
- 按一下檔案名稱，可以換成同一個提交裡的別的檔案。
- :ui[showFile.raw] 與 :ui[blame.title] 在原文與 [Blame](#blame) 之間切換。
- 把指標移到標頭上，還有 :ui[fileHistory.title] 與 :ui[fileHistory.showCommit]。

標頭下面寫著改過這個檔案的人數，以及他們的大頭貼。內文用你的主題，以及 :ui[app.name > settings.title] › :ui[settings.text] 裡的設定，見 [文字](/guide/settings/appearance/#text)。

這個視圖與 Blame 一樣，無法檢視新檔案、未追蹤的檔案、二進位檔案與子模組。

## 從某個版本回復檔案 {#restore}

想把一個檔案改回更早的提交裡的樣子：

1. 在檔案歷史裡對這個提交按右鍵，在選單裡選 :ui[fileHistory.restoreAt]{1="units.ts" 2="e2dda2bc"}。在 [提交詳細資訊](/guide/history/commit-details/#changeset) 裡，這一項是 :ui[fileHistory.restoreInWorkingCopy]{1="units.ts" 2="e2dda2bc"}。
2. Spooky 會先問你。按一下 :ui[fileHistory.restore.submit]。

檔案裡已暫存與未暫存的變更都會被換掉。如果那個提交裡沒有這個檔案，它就會被刪除。回復不會提交：回復後的檔案出現在工作區裡，是已暫存的變更。

想收回，選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

在變更集或檔案樹裡，可以一次回復多個檔案或資料夾。

:::note[伺服器儲存庫]
伺服器上的檔案會被覆寫。勾選 :ui[dialog.doNotAskAgain]，下次就不再問。想重新被問，在 :ui[app.name > settings.title] › :ui[settings.general] 裡開啟 :ui[settings.warnRestoringOnServer]，見 [確認](/guide/settings/general/#confirmations)。
:::

## 相關頁面

- [提交詳細資訊](/guide/history/commit-details/)
- [工作區](/guide/work/working-copy/)
- [還原與找回](/guide/work/undo/)

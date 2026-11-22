---
title: "第一個儲存庫"
description: "開啟一個本機儲存庫，從變更、暫存、提交到推送，完整地走一遍。"
---

這一頁帶你完整地走一遍：開啟這台 Mac 上的一個儲存庫，修改一個檔案，暫存變更，提交，再把提交推送到遠端。

你需要這台 Mac 上的一個 Git 儲存庫，它要有一個你能推送的遠端。還沒有的話，[儲存庫管理視窗](/guide/repositories/manager/) 裡講了怎樣複製或新增一個。

## 開啟儲存庫 {#open}

1. 選 :ui[menu.file > action.openLocal]（<kbd>⌘O</kbd>）。
2. 選取儲存庫所在的資料夾，按一下 :ui[repositories.panel.prompt]。

Spooky 開啟儲存庫，顯示它的 :ui[workspace.title]。儲存庫也會加進儲存庫管理的列表，下次可以直接從那裡開啟。

選儲存庫裡的任何一個資料夾都可以，Spooky 會開啟整個儲存庫。所選的資料夾不在 Git 儲存庫裡時，Spooky 會提示 :ui[bookmarks.noRepository.title]。按一下 :ui[bookmarks.noRepository.create] 把這個資料夾變成新儲存庫，或者按一下 :ui[action.cancel] 另選一個。

:::note[伺服器儲存庫]
要在伺服器上的儲存庫裡工作，改用 :ui[action.addRemote] 加入它，做法見 [加入伺服器儲存庫](/guide/server/add/)。儲存庫開啟以後，這一頁其餘的步驟都一樣。
:::

## 修改檔案 {#change}

用任意編輯器改一下儲存庫裡的某個檔案，然後儲存。Spooky 會發現這處變更，把檔案列進 :ui[workspace.title]。變更沒有出現的話，按一下 :ui[action.refresh] 或按 <kbd>⌘R</kbd>。

選取這個檔案，右邊一欄顯示改了什麼：新增的行是綠色，刪掉的行是紅色。

## 暫存變更 {#stage}

Git 只提交你暫存的變更，不是你改過的全部內容。暫存就是挑出哪些變更進入下一個提交。其餘的變更留在工作區裡，以後再說。

暫存一個檔案，用下面任一種做法：

- 勾選檔案前面的註記框。
- 選取一個或幾個檔案，按 <kbd>空白鍵</kbd>。
- 按一下 :ui[working.stageAll]，暫存所有變更的檔案。

已暫存的檔案保持勾選。只想暫存檔案裡的某幾行，見 [檢視與挑選變更](/guide/work/diff/)。

## 提交 {#commit}

提交把已暫存的變更存進儲存庫的歷史。每個提交都附帶一段說明，寫明改了什麼、為什麼改。

1. 按一下 :ui[working.subject]，輸入一句簡短的概述。輸入時提交區會展開。
2. 還想多寫幾句，寫在 :ui[working.body] 裡。
3. 按一下 :ui[working.commit]，或按 <kbd>⌘↩</kbd>。

::screenshot[提交區，提交標題裡已輸入「Add gust alerts and a humidity chart」。下面依序是空著的詳細說明、「修補最近提交」與「署名」兩個註記框、作者的名字與電子郵件，以及「全部暫存」與「提交」按鈕。再下面的檔案列表裡有三個檔案已勾選。]{name="start-commit" frame="closeup"}

展開的提交區裡還有幾樣東西：

- 標題框末尾的數字是還能輸入的字元數。超過這個數，標題就比建議的長了。
- 標題裡沒有文字時，:ui[working.commit] 一直是灰色的。
- 右邊的名字與電子郵件會作為作者記進提交。想修改，見 [身分設定檔與 Git 設定](/guide/settings/identity/)。
- :ui[working.amend] 與 :ui[commit.signOff] 的用法見 [提交變更](/guide/work/commit/)。

提交之後，提交過的檔案從列表裡消失。側邊欄裡目前分支的旁邊會顯示 ↑1，意思是有一個提交在你的 Mac 上，還沒到遠端。

## 推送 {#push}

推送把你的提交送到遠端。別人能從遠端拿到這些提交，遠端也多了一份備份。

1. 按一下工具列上的 :ui[sync.push]，或選 :ui[menu.repository > sync.pushMenu]（<kbd>⇧⌘U</kbd>）。
2. 確認 :ui[sync.destination] 是你要推送到的遠端分支。分支已經追蹤了某個遠端分支時，預設選的就是它。
3. 按一下 :ui[sync.pushHead]。

::screenshot[「推送 HEAD」對話框：把本機分支「main」上的新提交推送到目標 origin/main。下面是收合的「選項」一節，以及「取消」與「推送 HEAD」按鈕。]{name="sync" frame="dialog"}

推送完成後，分支旁邊的 ↑1 就消失了。:ui[dialog.options] 裡的設定見 [推送](/guide/branches/sync/#push)。第一次推送一個分支，見 [發布分支](/guide/branches/sync/#publish)。

:::tip
按住 <kbd>⌥</kbd> 再按一下 :ui[sync.push] 按鈕，它會變成 :ui[sync.quickPush]。這樣不跳出對話框，直接把目前分支推送到它的追蹤分支。
:::

## 相關頁面

- [工作區](/guide/work/working-copy/)
- [提交變更](/guide/work/commit/)
- [擷取、拉取與推送](/guide/branches/sync/)

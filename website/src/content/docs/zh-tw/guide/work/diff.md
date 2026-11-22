---
title: "檢視與挑選變更"
description: "檢視檔案裡改了什麼，調整 Diff 的顯示方式，按檔案、按區塊、按行暫存與捨棄變更。"
---

在工作區裡選取一個檔案，右邊一欄就顯示它的 Diff，也就是逐行列出改了什麼。在這裡可以只暫存屬於下一個提交的部分，把不要的丟掉。

## 看懂 Diff {#read}

Diff 分成一個個區塊。區塊是一組有變更的行，前後帶幾行沒改的內容。區塊的標題行寫明這一塊在檔案裡的位置。

- 新增的行是綠色，刪掉的行是紅色。左邊兩欄行號，分別對應檔案的舊版與新版。
- 檔案既有已暫存的變更，也有沒暫存的變更時，用這一欄頂端的 :ui[working.unstaged] 與 :ui[working.staged] 切換。沒有變更的一側是灰的。
- Diff 下面的底欄顯示一共幾個區塊，增加和刪除了多少行。
- 圖片的 Diff 顯示新舊兩張圖。:ui[diff.twoUp] 把兩張並排放，:ui[diff.oneUp] 一次顯示一張，在 :ui[diff.old] 與 :ui[diff.new] 之間切換。

特別大的 Diff 會讓視窗變慢，所以 Spooky 先問一句：:ui[working.largeDiff]按一下 :ui[working.showDiff] 就能看到。大小的上限是 :ui[app.name > settings.title] › :ui[settings.general] 裡的 :ui[working.diffThreshold]，預設 20,000 kB，見 [歷史與 Diff](/guide/settings/general/#history)。

## Diff 的顯示選項 {#options}

最常改的幾個選項在 Diff 下面的底欄上：

- 左端有兩個按鈕。把指標停在按鈕上，可以看到它的名稱。
  - :ui[diff.ignoreWhitespace] 隱藏只動了空格與 Tab 字元的變更。檔案裡沒有別的變更時，Diff 顯示 :ui[diff.onlyWhitespace]
  - :ui[diff.showEntireFile] 顯示整個檔案，變更留在原處。它只對正在看的這個 Diff 生效。
- 右端的 :ui[diff.context] 決定每處變更前後顯示幾行沒改的內容，預設 3 行。也可以從 :ui[menu.view > diff.contextMenu] 裡選。

空白與上下文這兩項到處都生效：所有儲存庫、工作區和歷史裡都一樣。

更多選項在 :ui[app.name > settings.title] › :ui[settings.text] 裡：

| 設定 | 作用 |
|---|---|
| :ui[text.enableSyntaxColoring] | 依程式碼的語言著色。預設開啟 |
| :ui[text.syntaxColoringInDiffs] | Diff 裡也用語法著色。預設關閉 |
| :ui[text.showInvisibles] | 用符號顯示空格、Tab 字元與換行 |
| :ui[text.tabWidth] | 一個 Tab 字元佔幾個空格寬 |

這幾項的詳細說明見 [文字](/guide/settings/appearance/#text)。顏色來自主題，見 [主題](/guide/settings/appearance/#themes)。

## 暫存整個檔案 {#stage-file}

暫存就是挑出哪些變更進入下一個提交。暫存整個檔案，用下面任一種做法：

- 勾選檔案前面的註記框。這個檔案在選取的範圍裡時，所有選取的檔案一起暫存。
- 選取檔案，按 <kbd>空白鍵</kbd>。所選的檔案有沒暫存的變更時，空白鍵暫存它；否則取消暫存。
- 按一下列表上方的 :ui[working.stageAll]，或選 :ui[workspace.title > working.stageAllMenu]（<kbd>⇧⌘E</kbd>）。

取消暫存：取消勾選註記框，再按一次 <kbd>空白鍵</kbd>，或選 :ui[workspace.title > working.unstageAllMenu]（<kbd>⌥⇧⌘E</kbd>）。全部暫存以後，:ui[working.stageAll] 按鈕會變成 :ui[working.unstageAll]。只暫存了一部分時，按住 <kbd>⌥</kbd> 也能讓它變過來。

## 暫存區塊 {#chunks}

每個區塊的標題行右端都有按鈕：

- :ui[working.unstaged] 一側：:ui[working.discardChunk] 與 :ui[working.stageChunk]
- :ui[working.staged] 一側：:ui[working.unstageChunk]

按了以後，這一塊馬上移到另一側，檔案裡其餘的變更不動。

## 暫存行 {#lines}

一個區塊裡混著屬於不同提交的變更時，可以只暫存其中幾行。

1. 按一下某行變更的行號，選取這一行。再按一次就取消選取。
2. 想多選幾行，接著按它們的行號。在行號上拖過去，可以選取連續的幾行；按住 <kbd>⇧</kbd> 再按，會選取中間的每一行。
3. 按一下區塊標題行上的 :ui[working.stageLines]。

::screenshot[src/readings.ts 的 Diff 裡的一個區塊。用行號選取了五行，區塊的標題行上是「捨棄所選行」與「暫存所選行」兩個按鈕。]{name="staging" frame="closeup"}

只有變更的行能選取。每個區塊各有各的選取範圍，區塊上的按鈕只對這一塊裡選取的行有作用。在 :ui[working.staged] 一側，按鈕是 :ui[working.unstageLines]。

## 捨棄變更 {#discard}

捨棄就是丟掉不想要的變更。

- **一個檔案**：在它上面按右鍵，選 :ui[working.discard.menu]；或者選 :ui[workspace.title > working.discardMenu]（<kbd>⇧⌘⌫</kbd>）。
- **全部變更**：選 :ui[workspace.title > working.discardAllMenu]。
- **一個區塊或幾行**：按一下區塊標題行上的 :ui[working.discardChunk] 或 :ui[working.discardLines]。

捨棄檔案時，Spooky 會先問你。已追蹤的檔案回到最後一次提交時的樣子，已暫存的變更也一起丟掉。新檔案移到垃圾桶。按一下 :ui[working.discard] 或 :ui[working.discardAll.submit] 繼續。

捨棄區塊或行時，Spooky 會問 :ui[working.discardContent.title]勾選 :ui[dialog.doNotAskAgain]，下次就不再問。想恢復這個提問，在 :ui[app.name > settings.title] › :ui[settings.general] 裡開啟 :ui[settings.warnDiscardingChunks]，見 [確認](/guide/settings/general/#confirmations)。

:::caution
捨棄的變更不在任何提交裡。唯一的回頭路是 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>），而且只在儲存庫還沒有再變化之前有效。新檔案只要還在垃圾桶裡，就能拿回來。
:::

:::note[伺服器儲存庫]
捨棄會覆寫伺服器上的檔案。新檔案移到伺服器的垃圾桶；伺服器沒有垃圾桶時，直接永久刪除。提問的對話框裡有 :ui[dialog.doNotAskAgain]。想恢復這個提問，在 :ui[settings.general] 裡開啟 :ui[settings.warnDiscardingOnServer]。
:::

## 在其他 App 裡比較 {#external}

想用 FileMerge、Kaleidoscope 這類比較工具看變更：

- 把指標停在右邊一欄頂端的檔案名稱上，按一下 :ui[externalTool.action.diffTool]。比較的是你正在看的那一側。
- 或者在檔案上按右鍵，從 :ui[externalTool.compare] 子選單裡選：:ui[externalTool.compare.workingTreeToBase]、:ui[externalTool.compare.workingTreeToIndex] 或 :ui[externalTool.compare.indexToBase]。

第一次用時，Spooky 會問你用哪個 App。以後想換，改 :ui[app.name > settings.title] › :ui[settings.gitConfig] 裡的 :ui[externalTool.diffTool]。Spooky 支援 Araxis Merge、BBEdit、Beyond Compare、DeltaWalker、FileMerge、Kaleidoscope、P4Merge、TextMate 與 Visual Studio Code，見 [比較與合併工具](/guide/settings/integration/#diff-merge-tools)。

:::note[伺服器儲存庫]
比較工具拿到的是檔案的副本，放在這台 Mac 上的一個暫存資料夾裡。關閉儲存庫時，這個資料夾會被刪掉。
:::

## 相關頁面

- [工作區](/guide/work/working-copy/)
- [提交變更](/guide/work/commit/)
- [還原與找回](/guide/work/undo/)

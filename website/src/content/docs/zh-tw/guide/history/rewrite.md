---
title: "改寫歷史"
description: "反轉、摘取與重設提交，互動式變基，以及修補更早的提交。"
---

這裡的大多數操作都從 [歷史](/guide/history/browse/) 列表開始：在提交上按右鍵，或者先選取幾個。反轉與摘取會新增提交，其餘的操作則改寫已有的提交。

:::caution
改寫後的提交會換成新的雜湊。如果它們已經推送過，你的分支就會和上游分岔，再推送需要強制推送；已經拿到舊提交的人，也得自己理順歷史。見 [安全強制推送](/guide/branches/sync/#force-push)。
:::

除了摘取與重設，下面這些操作只在列表只顯示你所在的分支時，才會出現在提交的選單裡。要切過去，選 :ui[menu.view > history.showHead]（<kbd>⌘0</kbd>），或者按一下側邊欄裡的這個分支。

::screenshot[列表顯示所在分支時，對提交 2daa6982 按右鍵跳出的選單。裡面有重設、反轉與變基到別處，再往下是這個提交的修補、編輯、編輯提交訊息與刪除。]{name="history-commit-menu" frame="closeup"}

## 反轉提交 {#revert}

反轉會新增一個提交，抵銷之前某個提交的變更。原來的提交還留在歷史裡，所以想收回已經推送的內容時，這是穩妥的做法。

1. 在這個提交上按右鍵，在選單裡選 :ui[rewrite.menu.revert]{1="e2dda2bc"}。選取多個提交時，這一項是 :ui[rewrite.menu.revertMany]{1="3"}。
2. :ui[rewrite.revert.commit] 預設開啟，每個被反轉的提交各得到一個新提交。關掉它，變更就只留在工作區裡。Spooky 會記住這個選擇。
3. 按一下 :ui[rewrite.revert.button]。

多個提交從新到舊依序反轉。反轉合併提交時，要選 :ui[rewrite.mainline]，也就是把哪個父提交那一邊當作主線。合併提交只能單獨反轉。

提交詳細資訊與 [多個提交](/guide/history/commit-details/#multiple) 的右邊一欄裡也有 :ui[rewrite.revert.button] 按鈕。

## 摘取提交 {#cherry-pick}

摘取把別的分支上提交的變更複製到你所在的分支上，成為新的提交。

1. 按一下側邊欄裡的另一個分支，看它的歷史。
2. 在這個提交上按右鍵，在選單裡選 :ui[rewrite.menu.cherryPick]{1="e2dda2bc"}。選取多個提交時，這一項是 :ui[rewrite.menu.cherryPickMany]{1="3"}，也可以按一下右邊的 :ui[rewrite.cherryPick.button]。
3. 選好選項，Spooky 會記住它們：
   - :ui[rewrite.cherryPick.commit]（預設開啟）把每個提交都提交下來。關掉它，變更就只套用到工作區。
   - :ui[rewrite.cherryPick.fastForward]：你的分支正好在這個提交的父提交上時，直接把分支移到這個提交，不再複製。只在第一個選項開啟時有效。
4. 按一下 :ui[rewrite.cherryPick.button]。

提交從舊到新依序套用。和反轉一樣，合併提交要選 :ui[rewrite.mainline]。

列表顯示的是你所在的分支時，只有上游上那些你還沒拉取的提交才有這一項。

也可以把提交從列表拖到側邊欄的 :ui[workspace.title] 或你所在的分支上。放開時按住 <kbd>⌥</kbd>，就改成反轉。

## 重設到更早的提交 {#reset}

重設會把你所在的分支移到另一個提交上，之後的提交就離開了這個分支。

1. 在這個提交上按右鍵，在選單裡選 :ui[rewrite.menu.reset]{1="e2dda2bc"}。也可以按一下提交詳細資訊裡的 :ui[history.rollback]，或者在選單列裡選 :ui[workspace.title > rewrite.reset.menu]。
2. 核對 :ui[rewrite.revision]。可以選一個分支、遠端分支或標籤，也可以輸入雜湊。對話框會列出將要離開這個分支的提交。
3. 選一種 :ui[rewrite.reset.mode]：
   - :ui[rewrite.reset.soft]：暫存區與工作區都不變，離開分支的那些提交的變更留在暫存區裡。
   - :ui[rewrite.reset.mixed]：重設暫存區，工作區不變，那些變更變成未暫存的。
   - :ui[rewrite.reset.hard]：兩者都重設。未提交的變更，以及離開分支的那些提交的變更，都會被丟掉。
4. 按一下 :ui[rewrite.reset.button]。

對話框每次都從 :ui[rewrite.reset.soft] 開始。重設不會提議先儲藏你的變更。

:::caution
:ui[rewrite.reset.hard] 會丟掉已追蹤檔案裡未提交的變更，有這樣的變更時對話框會提醒你。按 <kbd>⌘Z</kbd> 可以找回它們，但只在你結束 Spooky 之前有效。
:::

## 把提交變基到別處 {#rebase-onto}

:ui[rewrite.rebaseOnto] 把一些提交挪到另一個提交的上面。

- 想挪動分支上的一整段，在選單列裡選 :ui[workspace.title > rewrite.rebaseOnto.menu]，填好 :ui[rewrite.rebaseOnto.current] 與 :ui[rewrite.rebaseOnto.new]。目前基點之後的提交會在新基點上重放一遍。
- 只想挪動其中幾個，選取它們後按右鍵，在選單裡選 :ui[rewrite.menu.rebaseOntoMany]{1="3"}（只有一個時是 :ui[rewrite.menu.rebaseOnto]{1="e2dda2bc"}），再填好 :ui[rewrite.rebaseOnto.new]。同一段裡沒選取的提交會從分支上去掉。

兩個基點都不能是目前簽出的提交。對話框會列出將被改寫的提交，其中有已經推送或已經在別的分支裡的，會給出警告。:ui[sync.skipHooks] 讓這一次略過儲存庫的 pre-rebase 掛鉤。按一下 :ui[rewrite.rebaseOnto.button] 開始。

想把一個分支變基到另一個分支上，見 [變基](/guide/branches/merge-rebase/#rebase)。

## 壓縮、Fixup、刪除與移動 {#interactive}

這些操作改寫你所在分支上的一段提交。選取這些提交，按右鍵，然後選：

- :ui[rewrite.menu.squashMany]{1="3"}，把它們併進其中最舊的一個，提交訊息合在一起。完成後，列表會選取新的提交。
- :ui[rewrite.menu.fixupMany]{1="3"}，同樣併進最舊的一個，只保留它的提交訊息。
- :ui[rewrite.menu.deleteMany]{1="3"}，把它們從分支上刪掉。只選取一個提交時，用 :ui[rewrite.menu.delete]{1="e2dda2bc"}。

也可以在列表裡拖移提交：

- 放到另一個提交上，就壓縮進那個提交。放開時按住 <kbd>⌥</kbd>，就改成 Fixup。落點旁會寫著 :ui[rewrite.squash.button] 或 :ui[rewrite.fixup.button]。
- 放到兩列之間，就把它們移到那裡。落點旁寫著 :ui[branch.moveHere]。

這些操作在改寫之前，Spooky 都會先問你。對話框列出每個將被改寫的提交，以及它會怎樣，例如 :ui[rewrite.note.squash] 或 :ui[rewrite.note.drop]。已經推送或已經在別的分支裡的提交，列尾有黃色的警告標誌，列表上方會說明原因。要刪除的提交已經在上游裡時，Spooky 還會先多問一句。

::screenshot[把兩個提交壓縮進 10e44ab8 之前跳出的確認對話框。頂端的兩則警告說，有的提交已經在上游分支上，或者已經在別的分支裡。下面的列表是會被改寫的四個提交，以及每個提交會怎樣。已經推送的那個提交，列尾有黃色的警告標誌。按鈕是「取消」與「壓縮提交」。]{name="history-rewrite-confirm" frame="dialog"}

## 編輯提交訊息 {#reword}

1. 在這個提交上按右鍵，在選單裡選 :ui[rewrite.menu.reword]{1="e2dda2bc"}。
2. 修改 :ui[working.subject] 與 :ui[working.body]。註解行的處理和 [提交區](/guide/work/commit/#comments) 一樣。
3. 按一下 :ui[rewrite.reword.button]。

它之後的提交也會一起改寫，完成後列表會按新的雜湊選取這個提交。如果這個提交已經在上游裡，Spooky 會在開啟對話框之前先問你。

## 編輯提交 {#edit}

編輯會在一個提交處停下，把它的變更放回工作區，方便你把它拆開或者重做。

1. 在這個提交上按右鍵，選 :ui[rewrite.menu.edit]{1="e2dda2bc"}，再按一下 :ui[rewrite.edit.button] 確認。
2. 橫幅上寫著 :ui[conflict.title.edit]{1="e2dda2bc" 2="main"}。這個提交的變更出現在工作區裡，是未暫存的。
3. 像平常一樣暫存與提交，拆成幾個提交都可以。
4. 按一下橫幅上的 :ui[working.endEditing]。之後的提交會在上面重放。

想放棄，按一下橫幅上的 :ui[working.abort]。儲存庫的第一個提交無法編輯。

## 修補更早的提交 {#amend}

修補更早的提交，就是把變更加進那個提交裡，和 [修補上一次提交](/guide/work/commit/#amend) 一樣。

1. 在這個提交上按右鍵，選 :ui[rewrite.menu.amend]{1="e2dda2bc"}。Spooky 直接開始，不先確認。
2. 變基停在這個提交上。做好變更並暫存。
3. 在提交區裡勾選 :ui[working.amend]，然後提交。
4. 按一下橫幅上的 :ui[working.endEditing]。之後的提交會在上面重放。

開始時如果有本機變更，Spooky 會先提議把它們儲藏起來。它們之後還留在儲藏裡，你可以在變基停下時套用，也可以以後再說。

## 自動壓縮 {#autosquash}

一個提交可以把自己標成對之前某個提交的修正：標題以 `fixup!`、`squash!` 或 `amend!` 開頭，後面跟著那個提交的標題。提交區會幫你 [補全這個標題](/guide/work/commit/#autocomplete)。

列表顯示的是你所在的分支、沒有搜尋條件，並且最近 1000 個提交裡有這樣的提交時，表頭下面會出現一條標題為 :ui[rewrite.autosquash] 的橫幅。按一下橫幅上的 :ui[rewrite.autosquash.button]，確認以後，每個帶標記的提交都會併進它指明的那個提交：

- `fixup!` 保留原來那個提交的訊息。
- `squash!` 把兩則訊息合在一起。
- `amend!` 用自己的訊息取代原來那個提交的訊息。

按一下 × 可以暫時隱藏這條橫幅。

## 無法開始改寫時 {#errors}

改寫之前，Spooky 會先檢查這些提交。有問題時它會說明原因，什麼也不改：

| 提示 | 原因 |
|---|---|
| :ui[rewrite.error.notInHead] | 這些提交都必須在你所在分支的歷史裡，並且在同一條線上 |
| :ui[rewrite.error.merges] | 中間隔著一個合併提交，改寫會把它攤平。請選最後一次合併之後的提交 |
| :ui[rewrite.error.root] | 儲存庫的第一個提交沒有父提交，變更沒地方放回去 |
| :ui[rewrite.error.selection] | 壓縮至少需要兩個提交，目標也不能是要併進去的提交之一 |
| :ui[rewrite.error.autosquash] | 最近的提交裡沒有標記為之前某個提交的修正的 |
| :ui[rewrite.error.changed] | Spooky 讀取之後分支又變了。重新整理歷史，再試一次 |

## 本機變更與衝突 {#local-changes}

反轉、摘取與變基都需要工作區不礙事。本機變更擋住了它們時，Spooky 會提議 [先儲藏起來](/guide/work/stash/#auto-stash)。修補更早的提交則在開始之前就問。

途中有提交發生衝突時，Spooky 會停下來，顯示 [操作橫幅](/guide/work/conflicts/#banner)。解決衝突以後，在橫幅上繼續或中止。

## 還原改寫 {#undo}

選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>），可以收回反轉、摘取、重設或改寫。變基停在中途時，例如在編輯一個提交，要先把它做完或中止。停在衝突上的變基或摘取無法還原。見 [還原與找回](/guide/work/undo/)。

舊的提交還會在 [Reflog](/guide/work/undo/#reflog) 裡留一段時間。

:::note[伺服器儲存庫]
提交在伺服器上改寫。會改寫歷史的對話框都寫明了在哪台伺服器上執行。
:::

## 相關頁面

- [解決衝突](/guide/work/conflicts/)
- [還原與找回](/guide/work/undo/)
- [合併與變基](/guide/branches/merge-rebase/)

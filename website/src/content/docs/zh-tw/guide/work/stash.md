---
title: "儲藏"
description: "儲存、套用與檢視儲藏，以及使用自動儲藏。"
---

儲藏把本機變更先放到一邊，不用提交。需要暫時騰出乾淨的工作區、之後再把變更拿回來時，就用它，例如切換分支或拉取之前。

儲藏屬於這個儲存庫，不會推送到遠端。

## 儲存儲藏 {#save}

1. 選 :ui[workspace.title > stash.saveMenu]（<kbd>⇧⌘S</kbd>），或者按一下工具列上的 :ui[toolbar.saveStash]。
2. 可以在 :ui[stash.message] 裡寫幾句說明，以後好找。
3. 想把新檔案也放到一邊，勾選 :ui[stash.includeUntracked]。Spooky 會記住這個選擇。
4. 按一下 :ui[stash.save]。

所有變更都進了儲藏，工作區又乾淨了。沒有可儲存的變更時，Spooky 會提示 :ui[stash.error.noChanges]。只有勾選了 :ui[stash.includeUntracked]，新檔案才算在內。

想存一份變更、但接著改下去，改選 :ui[workspace.title > stash.snapshotMenu]（<kbd>⌃⇧⌘S</kbd>）。對話框一樣，工作區保持原樣。

## 儲藏部分檔案 {#partial}

只想把幾個檔案放到一邊，在工作區裡選取它們，按右鍵，選 :ui[stash.stashFile]{1="README.md"} 或 :ui[stash.stashItems]{1="3"}。下面的快照項目會讓檔案保持原樣。

也可以把檔案拖到側邊欄的 :ui[stash.title] 上。

選取的新檔案一定會進儲藏，不管有沒有勾選 :ui[stash.includeUntracked]。

:::tip
選單開啟時按住 <kbd>⌥</kbd>，這些項目會變成快速版本，例如 :ui[stash.quickStashFile]{1="README.md"}。它們不跳出對話框，直接儲存，說明由 Git 來寫。
:::

## 檢視儲藏 {#view}

按一下側邊欄裡的 :ui[stash.title]，或者選 :ui[menu.view > stash.show]（<kbd>⌘3</kbd>）。

左邊的列表把最新的儲藏排在最前面。每一列寫著 :ui[stash.basedOn] 和儲存時所在的分支，還有日期與說明。想篩選列表，在工具列的搜尋框裡輸入。

::screenshot[儲藏視圖。左邊的列表裡有三個儲藏，選取的是 Halfway through the units toggle。右邊是它的詳細資訊，提交訊息下面露出「套用」「刪除」與「比較工具」三個按鈕。]{name="work-stashes" frame="window" markers="33,36 84,35.5"}

1. 儲藏列表
2. :ui[stash.applyButton]、:ui[stash.deleteButton] 與 :ui[history.diffTool]

選取一個儲藏，右邊就顯示它的變更，版面和提交詳細資訊一樣。把指標停在詳細資訊上，會出現 :ui[stash.applyButton]、:ui[stash.deleteButton] 與 :ui[history.diffTool] 三個按鈕。:ui[history.diffTool] 在比較工具裡開啟這個儲藏。

## 套用儲藏 {#apply}

套用就是把儲藏裡的變更拿回工作區。

1. 選 :ui[workspace.title > stash.applyMenu]（<kbd>⌥⇧⌘S</kbd>），或者按一下工具列上的 :ui[toolbar.applyStash]。也可以把儲藏拖到側邊欄的 :ui[workspace.title] 或目前的分支上。
2. 在 :ui[stash.picker] 裡選儲藏。在儲藏視圖裡，選取的那個已經選好了。
3. 設定選項：
   - :ui[stash.deleteAfterApply]：變更拿回來以後刪掉這個儲藏。
   - :ui[stash.restoreIndex]：儲存儲藏時已暫存的變更，重新暫存。
4. 按一下 :ui[stash.apply]。

這兩個選項 Spooky 都會記住。

儲藏裡的變更和工作區現在的內容衝突時，Spooky 會提示 :ui[stash.error.conflicts]。即使勾選了 :ui[stash.deleteAfterApply]，儲藏也會留著。衝突的解決方法見 [解決衝突](/guide/work/conflicts/)。

只想拿回一個檔案，開啟儲藏，把這個檔案從詳細資訊裡拖到側邊欄的 :ui[workspace.title] 上。

## 刪除儲藏 {#delete}

在儲藏視圖裡對一個儲藏按右鍵，選 :ui[stash.deleteNamed]{1="Halfway through the units toggle"}。選取了幾個儲藏時，這一項是 :ui[stash.deleteMultiple]{1="2"}。也可以按 <kbd>⌘⌫</kbd>。

Spooky 每次都會先問。刪掉以後想拿回來，選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

## 自動儲藏 {#auto-stash}

有些操作在有本機變更時不能進行，例如切換分支、拉取或合併。被擋住時，Spooky 會問要不要先把變更儲藏起來。

::screenshot[本機變更擋住了操作，對話框問要不要先把它們儲藏起來。裡面有一個可以不填的說明框、「操作完成後還原這些變更」註記框，以及「中止」「不儲藏」與「儲藏變更」三個按鈕。]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm]：儲藏變更，再進行操作。
- :ui[stash.autoStash.skip]：不儲藏，直接進行操作。變更仍然擋著的話，操作照常失敗。
- :ui[stash.autoStash.abort]：取消操作。

勾選 :ui[stash.autoStash.reapply]，操作一完成就把變更拿回來。不勾選的話，儲藏留在列表裡，以後自己套用。Spooky 會記住這個選擇。

已追蹤的檔案有變更時切換分支，Spooky 會在開始前就問，即使這些變更並不妨礙切換。

中間哪一步出了問題，變更都留在儲藏裡，Spooky 會告訴你發生了什麼。

不想再被問，在 :ui[app.name > settings.title] › :ui[settings.general] 裡關掉 :ui[stash.offerAutoStash]，見 [操作](/guide/settings/general/#operations)。

## 相關頁面

- [工作區](/guide/work/working-copy/)
- [解決衝突](/guide/work/conflicts/)
- [分支](/guide/branches/branches/)

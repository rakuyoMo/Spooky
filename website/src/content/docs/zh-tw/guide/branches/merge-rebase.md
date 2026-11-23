---
title: "合併與重定基底"
description: "合併與重定基底分支，開始前預覽衝突，用父分支更新分支，以及在側邊欄裡拖放分支。"
---

合併和重定基底都會把另一個分支的提交帶進目前所在的分支：

- 合併把兩段歷史接在一起，通常會多一個合併提交。
- 重定基底把你的提交挪到另一個分支的提交後面。歷史保持一條直線，但你的提交會被改寫。

這兩個操作都從 :ui[workspace.title] 選單開始。想把 :ui[sync.merge] 與 :ui[sync.rebaseHead] 放到工具列上，選 :ui[menu.view > menu.customizeToolbar]，把它們拖上去。

## 合併 {#merge}

1. 選 :ui[workspace.title > sync.mergeMenu]（<kbd>⇧⌘M</kbd>）。也可以在側邊欄裡對目前所在的分支按右鍵，選 :ui[workspace.mergeMenu]，或者把另一個分支拖到它上面。
2. 在 :ui[branch.target] 裡選要合併的內容：本機分支、遠端分支或標籤。一開始是目前分支的上游。
3. 選擇怎麼提交：
   - :ui[merge.squash]：把全部變更暫存起來，由你自己做成一個提交，不產生合併提交。
   - :ui[merge.alwaysCommit]：即使 Git 只需把你的分支往前移，也產生一個合併提交。
   - :ui[merge.autoCommit]：合併後馬上提交。只有勾選了 :ui[merge.alwaysCommit] 時才能取消它。取消後，合併進來的變更留在工作區裡，等你提交。
4. 合併會遇到衝突時，下方會有一行提示，見 [預覽衝突](#preview)。
5. 設定選項：
   - :ui[merge.verify]：合併進來的提交沒有可信簽章時停下。
   - :ui[sync.skipHooks]：這一次不執行儲存庫的 Git 掛鉤。
6. 按一下 :ui[sync.merge]。

Spooky 會記住 :ui[merge.alwaysCommit]、:ui[merge.autoCommit] 與 :ui[merge.verify]。

合併遇到衝突時，Spooky 會切到工作區並顯示一條橫幅，見 [解決衝突](/guide/work/conflicts/#banner)。

<kbd>⌘Z</kbd> 可以還原合併。合併停在衝突上時，還原就是中止它。

## 重定基底 {#rebase}

1. 選 :ui[workspace.title > sync.rebaseMenu]（<kbd>⇧⌘R</kbd>）。也可以在目前所在的分支上按右鍵，選 :ui[workspace.rebaseMenu]。
2. 在 :ui[branch.target] 裡選要重定基底到哪個分支上。一開始是目前分支的上游。
3. 看一下預覽，需要的話勾選 :ui[sync.skipHooks]。
4. 按一下 :ui[sync.rebaseHead]。

完成的重定基底可以用 <kbd>⌘Z</kbd> 還原。停在衝突上的重定基底不能還原：解決衝突後繼續，或者在橫幅上中止它。

只想把一部分提交挪到另一個基底上，見 [把提交重定基底到別處](/guide/history/rewrite/#rebase-onto)。

:::caution
重定基底會改寫你的提交。這些提交已經推送過的話，下一次推送就得用 [安全強制推送](/guide/branches/sync/#force-push)。
:::

## 本機變更 {#local-changes}

合併時，已追蹤的檔案不能有變更。新檔案只有在合併會覆寫它們時才會擋路。

重定基底和用父分支更新分支時，工作區裡不能有任何變更，新檔案也不行。

本機變更擋住了其中一個操作時，Spooky 會提議先把變更儲藏起來，見 [自動儲藏](/guide/work/stash/#auto-stash)。

## 預覽衝突 {#preview}

開始之前，合併、重定基底、拉取與同步對話框會檢查兩邊會不會衝突，並在對話框裡顯示結果：

- Spooky 比對時顯示 :ui[merge.checking]。
- 有幾個檔案衝突。把指標停在這一行上，可以看到是哪些檔案。
- :ui[merge.clean] 或 :ui[merge.unchanged]。
- 檢查沒能完成時顯示 :ui[merge.unavailable]。把指標停在這一行上，可以看到原因。

合併對話框不顯示 :ui[merge.clean] 與 :ui[merge.unchanged]。其他對話框每種結果都會顯示。

## 快速版本 {#quick}

按住 <kbd>⌥</kbd>，加到工具列上的 :ui[sync.merge] 與 :ui[sync.rebaseHead] 會變成 :ui[sync.quickMerge] 與 :ui[sync.quickRebase]。它們不跳出對話框，直接執行：

- :ui[sync.quickMerge] 合併目前分支的上游。
- :ui[sync.quickRebase] 把目前分支重定基底到它的上游上。

快速合併用你上次在合併對話框裡選的提交方式與簽署選項。兩者和對話框一樣，會提議先儲藏本機變更。

側邊欄選單裡的項目也一樣會變。例如 :ui[workspace.mergeMenu] 會變成 :ui[sync.quickMergeInto]{1="origin/main" 2="main"}。

## 用父分支更新分支 {#update}

分支有 [父分支](/guide/branches/branches/#parent) 時，更新會把父分支的新提交帶進來。

1. 在分支上按右鍵，選 :ui[branch.updateNamed]{1="feature/units-toggle"}。檢視這個分支的歷史、而父分支有新提交時，橫幅 :ui[history.parentBanner.title] 上也有 :ui[review.updateBranch.menu] 按鈕。
2. 核對 :ui[review.update.branch]。下面一行寫著會從父分支帶進幾個提交。
3. 在 :ui[review.update.strategy] 裡選 :ui[review.update.merge] 或 :ui[review.update.rebase]。選 :ui[review.update.merge] 時還可以勾選 :ui[merge.alwaysCommit]。
4. 看一下預覽：:ui[review.update.conflicts]、:ui[review.update.clean] 或 :ui[review.update.noChanges]。
5. 設定選項：:ui[merge.verify]（只用於合併）與 :ui[sync.skipHooks]。
6. 按一下 :ui[review.update.button]。

Spooky 會先簽出這個分支，再合併或重定基底。只有父分支有這個分支沒有的提交、又沒有別的操作在進行時，才能更新。

對目前所在的分支，側邊欄選單裡的 :ui[branch.mergeWith]{1="main"} 與 :ui[branch.rebaseOn]{1="main"} 會開啟合併與重定基底對話框，父分支已經選好。

:::tip
開啟選單後按住 <kbd>⌥</kbd>，:ui[branch.updateNamed]{1="feature/units-toggle"} 會變成 :ui[branch.quickUpdateNamed]{1="feature/units-toggle"}。它不跳出對話框，直接合併父分支。
:::

## 拖放 {#drag-and-drop}

不少分支操作可以從側邊欄裡的拖移開始。拖移時，指標旁的標示會說明放開後做什麼。在收合的資料夾或遠端上停一會兒，它就會展開。

| 拖移 | 拖到 | 結果 |
|---|---|---|
| 本機分支 | :ui[workspace.title] 或目前所在的分支 | 合併對話框。按住 <kbd>⌥</kbd> 是重定基底對話框。 |
| 遠端分支 | :ui[workspace.title] 或目前所在的分支 | 拉取對話框 |
| 遠端分支，按住 <kbd>⌥</kbd> | 目前所在的分支 | 它成為目前分支的上游。 |
| 本機分支、標籤或提交 | :ui[branch.group] | 從它新增分支的對話框 |
| 遠端分支 | :ui[branch.group] | 追蹤它的對話框 |
| 本機分支 | 遠端 | 發布對話框 |
| 本機分支 | 遠端分支 | :ui[sync.pushBranch] 對話框 |
| 本機分支或提交 | :ui[sidebar.tags] 或標籤資料夾 | 新增標籤的對話框 |
| 標籤 | 遠端 | 發布標籤的對話框 |
| 本機分支 | :ui[sidebar.pinned] 或 :ui[sidebar.archived] | 分支被釘選或封存。 |
| 本機分支 | :ui[worktree.group] | 為它新增工作樹的對話框 |

想把分支移進資料夾，把它拖到資料夾上。分支會重新命名為資料夾名稱加上它名稱的最後一段，不跳出對話框。遠端分支只能移進它自己遠端下的資料夾。想把分支移出資料夾，把它拖到列表的頂端或底部邊緣。重新命名可以用 <kbd>⌘Z</kbd> 還原。

也可以把歷史裡的提交拖到 :ui[workspace.title] 或目前所在的分支上，摘取這些提交。按住 <kbd>⌥</kbd> 則是反轉它們，見 [摘取提交](/guide/history/rewrite/#cherry-pick)。把提交變更集裡的單一檔案拖過去，只會把這個檔案的變更套用到工作區，不會暫存。

## 相關頁面

- [解決衝突](/guide/work/conflicts/)
- [改寫歷史](/guide/history/rewrite/)
- [擷取、拉取與推送](/guide/branches/sync/)
- [分支](/guide/branches/branches/)

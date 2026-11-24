---
title: "工作樹"
description: "在額外的工作樹裡簽出分支，以及開啟、移動、修復與刪除工作樹。"
---

工作樹是從同一個儲存庫簽出的另一個資料夾。每個工作樹有自己簽出的分支和工作區。它們共用儲存庫的提交和分支。這樣你可以在第二個分支上工作，不用在第一個資料夾裡儲藏或切換分支。

一個分支同一時間只能在一個工作樹裡簽出。

## 在側邊欄裡 {#sidebar}

工作樹列在側邊欄的 :ui[worktree.group] 下，按名稱排序。名稱是工作樹路徑的最後一段。視窗裡開啟著的那個工作樹不列出。把指標停在一個工作樹上，可以看到它簽出在哪裡。

按一下工作樹，可以看到它的名稱、路徑、目前的版本和分支。按兩下它，會在同一個視窗裡開啟。

在別的工作樹裡簽出的分支，圖示上帶著一個小角標。在它上面按右鍵，選單裡寫著它在哪個工作樹裡。選單裡還有開啟或刪除那個工作樹的項目。見 [簽出分支](/guide/branches/branches/#checkout)。

想在儲存庫管理視窗裡也列出工作樹，見 [整理列表](/guide/repositories/manager/#organize)。

## 加入工作樹 {#add}

任選一種方式開始：

- 選 :ui[menu.repository > menu.addWorktree]。
- 按一下側邊欄底部的加入按鈕，或者在 :ui[worktree.group] 上按右鍵，在選單裡選 :ui[worktree.add.menu]。
- 在一個本機分支上按右鍵，選 :ui[worktree.checkoutBranch]{1="feature/units-toggle"}。
- 把一個本機分支拖到 :ui[worktree.group] 上。

在對話框裡：

1. 在 :ui[worktree.revision] 一欄選擇或輸入要簽出的分支或版本。從分支開始時，這一欄已經填好。
2. 在 :ui[worktree.destination] 一欄填新資料夾的完整路徑。:ui[submodule.path.select] 按鈕從儲存庫資料夾的旁邊開始。它會建議一個由儲存庫名稱和版本組成的名稱。這個資料夾必須還不存在，或者是空的。
3. 勾選 :ui[worktree.detach]，會在這個版本上簽出分離的 HEAD，不佔用任何分支。
4. 按一下 :ui[worktree.add.submit]。

分支已經在某個工作樹裡簽出時，對話框會提示。勾選 :ui[worktree.detach]，或者 :ui[dialog.options] 裡的 :ui[worktree.force]，就能照樣建立。

儲存庫裡至少要有一個提交。工作樹建好後，視窗還停在原來開啟的儲存庫上。新的工作樹出現在側邊欄裡。

## 開啟工作樹 {#open}

工作樹像別的儲存庫一樣開啟。在側邊欄裡對它按右鍵，從選單裡選：

- :ui[worktree.open.current]、:ui[worktree.open.newTab] 或 :ui[worktree.open.newWindow]
- :ui[worktree.reveal]、:ui[action.copyPath] 或 :ui[action.openTerminal]

## 移動工作樹 {#move}

在工作樹上按右鍵，選 :ui[worktree.move.menu]。填新的路徑，或者按一下 :ui[submodule.path.select]。工作樹裡的變更會跟著一起移過去。

## 刪除工作樹 {#remove}

在工作樹上按右鍵，選 :ui[worktree.remove.menu]。這會刪掉工作樹的資料夾。它簽出過的分支還留在儲存庫裡。

工作樹裡有變更或未追蹤的檔案時，Git 會拒絕刪除。勾選 :ui[worktree.remove.force]，就連同它們一起刪掉。

儲存庫的主工作樹，也就是放著 `.git` 目錄的那個資料夾，不能移動或刪除。開啟著別的工作樹時，它會出現在列表裡。

## 修復工作樹 {#repair}

工作樹的資料夾在 Spooky 之外被移走或刪掉後，這個工作樹就失效了。它在側邊欄裡帶著警告圖示。你也不能開啟它。它的詳細資訊寫著 :ui[worktree.invalid] 和 Git 給出的原因，下面有兩個按鈕：

- :ui[worktree.invalid.repair]：資料夾被你移走了時，在 :ui[worktree.location] 選單裡選 :ui[submodule.path.select]，找到它現在的位置。Spooky 核對過這個資料夾確實是這個儲存庫的這個工作樹之後，按一下 :ui[worktree.relocate.submit]。
- :ui[worktree.invalid.remove]：資料夾已經沒有了時，這會把工作樹剩下的登記從儲存庫裡去掉。

工作樹的右鍵選單裡也有這兩項。

## 還原 {#undo}

加入、移動、刪除和修復工作樹都不能用 <kbd>⌘Z</kbd> 還原。做過其中一項之後，在它之前的操作也無法再還原。見 [還原與找回](/guide/work/undo/)。

:::note[伺服器儲存庫]
工作樹建在伺服器上，路徑也是伺服器上的路徑。:ui[submodule.path.select] 瀏覽的是伺服器上的資料夾。

Spooky 能在你的 Mac 上找到工作樹的資料夾時，才能用 :ui[worktree.reveal]。工作樹在儲存庫資料夾裡面時，Spooky 經儲存庫的位置找到它。否則在你的 Mac 掛載的卷宗裡找。見 [在這台 Mac 上的位置](/guide/server/local-location/)。
:::

## 相關頁面

- [分支](/guide/branches/branches/)
- [子模組](/guide/advanced/submodules/)
- [儲存庫管理視窗](/guide/repositories/manager/)

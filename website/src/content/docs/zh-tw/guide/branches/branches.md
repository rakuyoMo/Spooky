---
title: "分支"
description: "新增、簽出、追蹤、重新命名、刪除、釘選與封存分支，設定父分支，在側邊欄裡篩選與分組分支。"
---

本機分支列在側邊欄的 :ui[branch.group] 下。對分支做的事大多從這裡開始：在它上面按右鍵開啟選單，或者把它拖到別處。

::screenshot[側邊欄的下半部分。分支下面，main 帶著 HEAD 標記和 ↑3，feature 資料夾裡是 dark-mode、station-map 與 units-toggle。已封存分支是空的。標籤下列著 v0.1.0 到 v0.4.0。遠端下面，origin 裡有帶房子圖示的 main 和收合的 feature 資料夾。底部列左邊是篩選輸入框，右邊是新增與顯示設定兩個按鈕。]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. 目前所在的分支，帶著 HEAD 標記和還沒推送的提交數
2. 名稱以 `feature/` 開頭的分支所在的資料夾
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. 新增按鈕與顯示設定按鈕

## 在側邊欄裡 {#sidebar}

按一下分支，歷史裡就顯示它的提交。按兩下它就簽出。

追蹤遠端分支的分支會顯示兩邊差了多少。↑ 是你有、遠端還沒有的提交數。↓ 是遠端有、你還沒有的提交數。把指標停在分支上，可以看到它追蹤的是哪個分支。

很久沒有新提交的分支是陳舊的分支。它的名稱會變暗，後面跟著一個時鐘和多久沒更新。`main`、`master`、`trunk`、`dev`、`develop`、`next`，以及當了別的分支父分支的分支，都不會算作陳舊。

:ui[remote.group] 下，房子圖示標出每個遠端的預設分支。

## 新增分支 {#create}

1. 選 :ui[menu.repository > branch.createMenu]（<kbd>⌘B</kbd>）。也可以按一下側邊欄底部的新增按鈕，或者在 :ui[branch.group] 上按右鍵，在選單裡選它。
2. 在 :ui[reference.name] 裡輸入名稱。
3. 在 :ui[branch.start] 裡選分支從哪裡開始。一開始是目前所在的分支，或者你按右鍵的那一項。
4. 設定選項：
   - :ui[branch.trackStart] 讓新分支追蹤起點。只有起點是分支時才能勾選。
   - :ui[branch.pin] 把新分支放進 :ui[sidebar.pinned]。
   - :ui[branch.checkoutCreated] 建立後馬上切換到新分支。Spooky 會記住這個選擇。
   - :ui[branch.parentOption] 把起點設為新分支的 [父分支](#parent)。
5. 按一下 :ui[branch.create]。

想從某個分支、標籤或提交開始，在它上面按右鍵，選 :ui[branch.createFromMenu]{1="main"}。也可以把它拖到 :ui[branch.group] 上。

輸入時，Spooky 會把名稱改成 Git 能用的樣子：空格和 Git 不允許的字元換成 `-` 或者去掉。想照原樣輸入，到 :ui[app.name > settings.title] › :ui[settings.general] 裡關掉 :ui[branch.cleanNames]，見 [操作](/guide/settings/general/#operations)。

名稱裡的 `/` 會把分支放進資料夾，例如 `feature/units-toggle` 在 `feature` 裡。在資料夾上按右鍵，選 :ui[branch.createMenu]，名稱會先填好這個資料夾。

## 簽出分支 {#checkout}

按兩下分支，或者在它上面按右鍵，選 :ui[branch.checkoutNamed]{1="feature/dark-mode"}。

遠端分支也可以按兩下：

- 已有本機分支追蹤它時，Spooky 簽出那個本機分支。
- 有同名的本機分支、但沒有追蹤它時，Spooky 先用 :ui[branch.trackExisting.title] 問一下。然後簽出那個分支，並讓它追蹤這個遠端分支。
- 都沒有時，Spooky 新增一個追蹤它的同名本機分支，再簽出它。

已追蹤的檔案有變更時，Spooky 會先問要不要儲藏，見 [自動儲藏](/guide/work/stash/#auto-stash)。

已在別的工作樹裡簽出的分支，不能在這裡再簽出。按兩下它，Spooky 會改為開啟那個工作樹。按住 <kbd>⌘</kbd> 按兩下，會在新標籤頁裡開啟。

### 簽出標籤或提交 {#checkout-revision}

按兩下標籤，就簽出它所在的提交。想簽出別的，選 :ui[workspace.title > rewrite.checkout.menu]（<kbd>⇧⌘B</kbd>），選好分支、標籤或提交，按一下 :ui[rewrite.checkout.button]。

選的不是本機分支時，對話框會提示 HEAD 將分離。HEAD 分離時，你在一個提交上，而不在分支上。在這裡做的提交想留下來，就從它們新增一個分支。

## 追蹤遠端分支 {#track}

本機分支可以追蹤遠端上的一個分支，這個分支就是它的上游。拉取和推送預設用上游。↑ 和 ↓ 的數字也是跟上游比出來的。

為遠端分支建一個本機分支：

1. 在遠端分支上按右鍵，選 :ui[branch.trackMenu]{1="origin/feature/station-map"}，或者把它拖到 :ui[branch.group] 上。
2. :ui[branch.remoteField] 顯示這個遠端分支。想換個名稱，改 :ui[reference.name]。
3. :ui[branch.track.checkout] 每次都是勾選的。想留在目前的分支，取消勾選。
4. 按一下 :ui[branch.track.submit]。

想改既有分支追蹤的對象，在它上面按右鍵，在 :ui[branch.tracking] 裡選一個分支。:ui[branch.tracking.remove] 讓它不再追蹤。對目前所在的分支，也可以按住 <kbd>⌥</kbd> 把遠端分支拖到它上面。

不是目前所在的分支落後於上游、又沒有自己的提交時，它的選單裡有 :ui[branch.fastForward]{1="main"}。這一項不用簽出，就能把分支往前移到上游的位置。

## 重新命名分支 {#rename}

在分支上按右鍵，選 :ui[reference.renameMenu]{1="feature/dark-mode"}。輸入新名稱，按一下 :ui[reference.rename]。

釘選、封存與父分支的設定會跟著分支走。重新命名遠端分支時，遠端上的分支也會重新命名。

想把分支移進資料夾，把它拖到資料夾上，見 [拖放](/guide/branches/merge-rebase/#drag-and-drop)。

## 刪除分支 {#delete}

在分支上按右鍵，選 :ui[reference.deleteMenu]{1="feature/dark-mode"}。也可以在側邊欄裡選取一個或幾個分支，按 <kbd>⌘⌫</kbd>，這時焦點要在側邊欄上。

Spooky 一定會先問一下。對話框裡有兩個選項：

- :ui[branch.forceDelete]：分支沒有完全合併也刪除。不勾選時，Spooky 會列出沒有完全合併的分支，再問一次。
- :ui[branch.deleteUpstream]：把它追蹤的遠端分支也刪掉。只刪一個分支、它追蹤的遠端分支也還在時，才有這一項。

目前所在的分支不能刪除，先簽出別的分支。

刪除遠端分支，就是在遠端上刪掉它。

想找回刪掉的本機分支，選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。勾選了 :ui[branch.deleteUpstream] 也能還原。只刪除遠端分支時不能還原，見 [還原與找回](/guide/work/undo/)。

## 釘選分支 {#pin}

釘選的分支會從 :ui[branch.group] 移到列表最上面的 :ui[sidebar.pinned] 裡。常回去的分支可以釘選。

在分支上按右鍵，選 :ui[branch.pinNamed]{1="feature/station-map"}，或者把它拖到 :ui[sidebar.pinned] 上。選取了幾個分支時，這一項是 :ui[branch.pinMultiple]{1="2"}。想放回去，改選 :ui[branch.unpinNamed]{1="feature/station-map"}。

## 封存分支 {#archive}

封存把分支放到一邊，但不刪除它。分支會從 :ui[branch.group] 移到 :ui[sidebar.archived]。用起來和之前一樣。

在分支上按右鍵，選 :ui[branch.archiveNamed]{1="feature/dark-mode"}，或者把它拖到 :ui[sidebar.archived] 上。想拿回來，改選 :ui[branch.unarchiveNamed]{1="feature/dark-mode"}。

Spooky 也能找出值得封存的分支，還能替你封存，見 [分支整理](/guide/branches/review/#archive-suggestions)。

:::note[伺服器儲存庫]
釘選、封存與父分支都儲存在儲存庫的 Git 設定裡。伺服器儲存庫的這些設定儲存在伺服器上。
:::

## 父分支 {#parent}

父分支是你的分支所依據、需要跟上的那個分支，例如 `feature/units-toggle` 的父分支是 `main`。

設定時，在分支上按右鍵，在 :ui[branch.parent] 裡選一個建議的分支。想選別的分支，選 :ui[branch.parent.setMenu]，在 :ui[branch.parent.field] 裡選好，按一下 :ui[branch.parent.set]。新增分支時也可以設定。:ui[branch.parent.remove] 會移除父分支。

分支有了父分支之後：

- 在歷史裡比較分支時，先拿父分支來比，見 [與另一個分支比較](/guide/history/browse/#compare-branches)。
- 父分支有你的分支沒有的提交時，這個分支的歷史上方會顯示 :ui[history.parentBanner.title]。分支選單裡的 :ui[branch.updateNamed]{1="feature/units-toggle"} 可以把這些提交併進來，見 [用父分支更新分支](/guide/branches/merge-rebase/#update)。
- 對目前所在的分支，選單裡的 :ui[branch.mergeWith]{1="main"} 與 :ui[branch.rebaseOn]{1="main"} 會開啟合併與變基對話框，並選好父分支。
- 父分支本身不會算作陳舊。

## 篩選與分組 {#filter}

在側邊欄底部的 :ui[sidebar.filter] 裡輸入，就只顯示符合的分支、標籤、遠端分支、子模組與工作樹。字母不用連在一起：輸入 `stm` 能找到 `station-map`。不區分大小寫和變音符號。篩選時資料夾會展開，按 <kbd>Esc</kbd> 清空輸入框。

按一下右下角的顯示設定按鈕，或者選 :ui[menu.view > sidebar.menu]，設定側邊欄顯示什麼。這些設定對所有視窗都有效。

- :ui[sidebar.groupRefs] 把帶 `/` 的名稱放進資料夾，一開始是展開的。:ui[sidebar.groupedRefsOnTop] 把資料夾排在其他分支前面。
- :ui[sidebar.showStaleInfo] 標出陳舊的分支。:ui[sidebar.staleInterval] 設定多久沒有提交算陳舊，一開始是 6 個月。
- :ui[sidebar.remoteFilter] 與 :ui[sidebar.tagsFilter] 用 :ui[sidebar.showNewest] 只列出最新的幾個。遠端分支按每個遠端分別計數。標籤還能用 :ui[sidebar.sortBy] 排序。篩選時會列出全部符合的項目。
- :ui[sidebar.autoArchive] 見 [分支整理](/guide/branches/review/#auto-archive)。

## 相關頁面

- [擷取、拉取與推送](/guide/branches/sync/)
- [合併與變基](/guide/branches/merge-rebase/)
- [分支整理](/guide/branches/review/)
- [工作樹](/guide/advanced/worktrees/)

---
title: "提交詳細資訊"
description: "檢視提交的詳細資訊、變更集、檔案樹與簽名狀態，比較版本，以及匯出檔案。"
---

在 [歷史](/guide/history/browse/) 裡選取一個提交，右邊一欄就顯示它的詳細資訊：誰在什麼時候提交的、完整的提交訊息，以及它變更的檔案。

## 標頭 {#header}

最上面一條寫著提交的短雜湊，右邊是 :ui[history.changeset] 與 :ui[history.tree] 兩個按鈕。短雜湊可以選取拷貝。這一條下面的標頭列出：

- :ui[history.author] 與 :ui[history.committer]，以及各自的日期。右邊的大頭貼是作者的；提交者另有其人時，提交者的大頭貼在它左邊。
- :ui[history.refs]：指向這個提交的分支與標籤
- :ui[history.hash]：完整雜湊
- :ui[history.parentHash]：每個父提交一行
- :ui[history.treeHash]
- 簽名，只有帶簽名的提交才有，見 [簽名](#signatures)

按一下右上角的箭頭，標頭就收合成作者、日期與參照三行。Spooky 會記住你的選擇。標頭下面是完整的提交訊息。

### 操作按鈕 {#actions}

把指標移到詳細資訊上，標頭與提交訊息之間的分隔線上會浮現一排按鈕：

- :ui[history.rollback] 開啟對話框，把目前的分支重設到這個提交，見 [重設到更早的提交](/guide/history/rewrite/#reset)。
- :ui[rewrite.revert.button] 開啟對話框，新增一個提交來抵銷這個提交，見 [反轉提交](/guide/history/rewrite/#revert)。
- :ui[history.diffTool] 用你的比較工具開啟這個提交的全部變更，見 [在其他 App 裡比較](/guide/work/diff/#external)。

列表顯示的是你所在的分支時，才有 :ui[history.rollback] 與 :ui[rewrite.revert.button]。

## 變更集 {#changeset}

:ui[history.changeset] 按路徑列出這個提交變更的檔案。列表上方一列寫著檔案數、新增與刪除的行數。

- 按一下檔案旁邊的箭頭，展開它的變更。想展開或收合所有檔案的變更，按一下列表上方那一列開頭的 :ui[history.expandAll] 或 :ui[history.collapseAll]，或者按 <kbd>⌃⌘→</kbd> 或 <kbd>⌃⌘←</kbd>。
- 按一下檔案就選取它。按住 <kbd>⇧</kbd> 或 <kbd>⌘</kbd> 再按，可以選取多個。<kbd>↑</kbd> <kbd>↓</kbd> 移動選取項目。

檔案一開始都是收合的。想讓它們自動展開，在 :ui[menu.view > history.diffs] 裡的 :ui[history.autoExpand.title] 下面選一個數。提交變更的檔案不超過這個數時，所有變更都會展開。:ui[history.autoExpand.always] 則每次都展開。

合併提交的變更集顯示什麼，由 :ui[app.name > settings.title] › :ui[settings.general] 裡的 :ui[history.mergeDiff] 決定：

- :ui[history.mergeDiff.firstParent]（預設）顯示這次合併給分支帶來的變更。
- :ui[history.mergeDiff.mergedFilePaths] 只顯示與每個父提交都不同的檔案。
- :ui[history.mergeDiff.off] 不顯示變更。

見 [歷史與 Diff](/guide/settings/general/#history)。

在檔案上按右鍵，可以：

- 拷貝它的路徑，或它在儲存庫裡的路徑
- 檢視檔案在這個提交時的原文、它的 Blame 或它的歷史，見 [檔案歷史與 Blame](/guide/history/file-views/)
- 用比較工具開啟它，與這個提交的第一父提交比較
- 在工作區裡把它回復成這個提交裡的版本，見 [從某個版本回復檔案](/guide/history/file-views/#restore)
- 把這個提交裡的版本存到 Mac 上

選取多個檔案時，可以一起用比較工具開啟、回復或匯出。

## 檔案樹 {#tree}

:ui[history.tree] 顯示這個提交時儲存庫裡的所有檔案，不只是變更過的。按一下資料夾旁邊的箭頭開啟它。

在檔案或資料夾上按右鍵，可以：

- 用預設的 App 或你選的 App 開啟檔案
- 檢視檔案的原文、Blame 或歷史
- 在工作區裡把它回復成這個提交裡的版本
- 匯出它，或者存成 zip 封存檔

開啟與檢視只適用於檔案。選取多個項目時，可以一起開啟、回復、匯出或封存。匯出的項目放進你選的資料夾。那裡已有同名項目時，Spooky 會先問你要不要覆寫。

## 整頁詳細資訊 {#full-page}

在列表裡按兩下提交，它的詳細資訊就佔滿整個視窗。左邊一欄是這個提交，下面是變更的檔案列表。右邊一欄顯示所選檔案的變更。

- 按一下左上角的短雜湊，可以換一個提交：在列表裡按兩下提交就換成它。
- 按兩下檔案，或者按 <kbd>Return</kbd>，用預設的 App 開啟這個提交裡的版本。

想回到歷史，選 :ui[menu.view > navigation.back]（<kbd>⌘[</kbd>），或者按一下工具列上的 :ui[toolbar.previous]。

## 多個提交 {#multiple}

選取不只一個提交時，右邊一欄顯示選取的個數，下面是這些按鈕：

- :ui[rewrite.cherryPick.button] 把這些提交套用到你所在的分支。列表顯示的就是這個分支時，按鈕換成 :ui[rewrite.revert.button]，見 [改寫歷史](/guide/history/rewrite/)。
- 剛好選取兩個提交時才有 :ui[compare.submit]，顯示從較早的提交到較新的提交改了什麼。按住 <kbd>⌥</kbd> 就反過來比較。

## 簽名 {#signatures}

詳細資訊會驗證所選提交的簽名。展開的標頭寫著金鑰與狀態，例如 :ui[signature.good]。

想在列表裡也看到簽名，在 [視圖選項](/guide/history/browse/#view-options) 裡開啟 :ui[signature.verify]。帶簽名的提交會在列尾多一個圓點：

- 綠色：簽名有效。
- 紅色：簽名無效。
- 黃色：其他狀態，例如金鑰已過期，或者 Spooky 無法驗證這個簽名。

按一下圓點可以看到金鑰與狀態。

## 比較兩個版本 {#compare}

想看任意兩個提交、分支或標籤之間改了什麼：

1. 在選單列裡選 :ui[menu.repository > compare.menu]。也可以在提交上按右鍵，選 :ui[compare.menuFrom]{1="e2dda2bc"}，從它開始比較。
2. 填好 :ui[compare.base] 與 :ui[compare.target]。選單裡列出本機分支、遠端分支與標籤，也可以輸入雜湊。
3. 按一下 :ui[compare.submit]。

右邊一欄顯示比較的結果。:ui[compare.commits] 列出第二個版本有、第一個版本沒有的提交。:ui[history.changeset] 顯示從第一個版本到第二個版本的變更。想關掉它，按一下右上角的 ×，或者選取別的提交。

選取兩個提交時，選單裡直接有 :ui[compare.menuPair]{1="e2dda2bc" 2="f6b437e0"}。

## 匯出檔案 {#export}

想把一個提交時的所有檔案原樣存下來：

1. 在提交上按右鍵，在選單裡選 :ui[export.menuFrom]{1="e2dda2bc"}。選單列裡的 :ui[menu.repository > export.menu] 從所選的提交開始。
2. 核對版本。想得到一個 zip 檔案，勾選 :ui[export.createArchive]。
3. 按一下 :ui[export.submit]，選好存放的位置。

不存成封存檔時，得到的是一個以儲存庫名稱和短雜湊命名的資料夾。

匯出會出現在 [活動視窗](/guide/advanced/queue-activity/) 裡，可以在那裡取消。

## 儲存修補檔 {#patch}

修補檔是一個寫著提交變更的文字檔。在別的儲存庫裡可以用 `git am` 套用它。

1. 在提交上按右鍵，在選單裡選 :ui[patch.menu]{1="e2dda2bc"}。選取多個提交時，這一項為每個提交各存一個修補檔。
2. 勾選 :ui[patch.omitPrefixes]，路徑前面就不帶 `a/` 與 `b/`。
3. 按一下 :ui[patch.save]，選一個資料夾。

每個提交一個檔案，從最早的提交開始編號，例如 `0001-Add-a-theme-toggle-to-the-header.patch`。存好以後，Finder 會開啟並選取這些檔案。儲存同樣會出現在活動視窗裡。

在選單裡按住 <kbd>⌥</kbd>，就能選 :ui[patch.quickMenu]{1="e2dda2bc"}。它直接存進儲存庫的資料夾，沿用你上次的 :ui[patch.omitPrefixes] 選擇。

:::note[伺服器儲存庫]
匯出的檔案和用 :ui[patch.save] 存的修補檔都放在你的 Mac 上。快速儲存的修補檔放在伺服器上的儲存庫資料夾裡。
:::

## 拷貝提交資訊 {#copy}

在提交上按右鍵，可以拷貝：

- :ui[history.copyHash]：完整雜湊
- :ui[history.copyInfo]：短雜湊與提交訊息的第一行

選取多個提交時，每個提交一行。

## 相關頁面

- [瀏覽歷史](/guide/history/browse/)
- [檔案歷史與 Blame](/guide/history/file-views/)
- [改寫歷史](/guide/history/rewrite/)

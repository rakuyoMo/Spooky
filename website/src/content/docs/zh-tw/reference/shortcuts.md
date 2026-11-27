---
title: "鍵盤快速鍵"
description: "查閱 Spooky 的全部鍵盤快速鍵。"
---

選單項目旁邊都寫著它的快速鍵。這一頁把它們都列了出來，還有只在某些地方有作用的按鍵，例如提交區、列表與對話框裡的。符號的含義見 [鍵盤快速鍵](/guide/#shortcuts)。

選單項目可用時，它的快速鍵才有作用。選單項目變灰時，按快速鍵沒有反應。

## 選單 {#menus}

### App 與視窗 {#app-windows}

| 快速鍵 | 選單項目 |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### 儲存庫 {#repositories}

| 快速鍵 | 選單項目 |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### 視圖 {#views}

| 快速鍵 | 選單項目 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### 編輯與尋找 {#edit}

| 快速鍵 | 選單項目 |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- :ui[menu.undo] 能還原哪些操作，見 [還原與重做](/guide/work/undo/#undo)。
- 在一些列表裡，:ui[menu.delete] 也會刪除所選的項目，見 [列表](#lists)。
- :ui[action.find] 與 :ui[action.search] 都把插入點放進工具列的搜尋欄位。見 [搜尋與篩選](/guide/history/browse/#search) 與 [搜尋檔案](/guide/work/working-copy/#search)。
- :ui[commit.reformatParagraph] 用在提交訊息裡，見 [寫提交訊息](/guide/work/commit/#write)。

### 分支與同步 {#sync}

| 快速鍵 | 選單項目 |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

帶 <kbd>⌥⇧⌘</kbd> 的是快速版本。開啟選單後按住 <kbd>⌥</kbd>，它們就取代上面那一項。它們不跳出對話框，直接執行。不開啟選單，快速鍵也能用。見 [擷取、拉取與推送](/guide/branches/sync/#quick) 與 [合併與重定基底](/guide/branches/merge-rebase/#quick) 裡的「快速版本」。

### 變更與提交 {#changes}

| 快速鍵 | 選單項目 |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## 按住 Option {#option}

按住 <kbd>⌥</kbd>，一些按鈕與選單會變樣。放開就變回來。

| 在哪裡 | 變成什麼 |
|---|---|
| 工具列裡擷取、拉取、推送的按鈕，以及加進工具列的同步、合併與重定基底按鈕 | 變成快速版本。見 [擷取、拉取與推送](/guide/branches/sync/#quick)。 |
| 提交區，前提是沒有在編輯任何訊息欄 | 切換到修補上一次提交。見 [修補上一次提交](/guide/work/commit/#amend)。 |
| 檔案列表上方的 :ui[working.stageAll]，前提是只暫存了一部分變更 | 變成 :ui[working.unstageAll]。見 [暫存整個檔案](/guide/work/diff/#stage-file)。 |
| 工作區裡檔案的選單 | 儲藏的幾項變成快速版本。見 [儲藏部分檔案](/guide/work/stash/#partial)。 |
| 子模組的選單 | 擷取與更新變成快速版本。見 [擷取與更新](/guide/advanced/submodules/#update)。 |
| 設了父分支的分支的選單 | 用父分支更新變成快速版本。見 [用父分支更新分支](/guide/branches/merge-rebase/#update)。 |
| 提交的選單 | 儲存修補檔變成快速版本。選取兩個提交時，比較的方向反過來。見 [儲存修補檔](/guide/history/commit-details/#patch)。 |
| 選取兩個提交時的 :ui[compare.submit] | 比較的方向反過來。見 [多個提交](/guide/history/commit-details/#multiple)。 |
| 拖放 | 見 [按住 Option 拖放](#drag)。 |

## 提交區 {#commit-area}

| 按鍵 | 作用 |
|---|---|
| 在標題裡按 <kbd>↩</kbd> 或 <kbd>Tab</kbd> | 移到內文 |
| 在內文裡按 <kbd>Tab</kbd> | 移到檔案列表 |
| 在內文裡按 <kbd>⇧Tab</kbd> | 回到標題 |
| 輸入提交訊息時按 <kbd>⌘↩</kbd> | 按下提交區的主按鈕，例如 :ui[working.commit]。數字鍵盤上的 <kbd>Enter</kbd> 也一樣。 |
| 沒有在編輯任何訊息欄時按 <kbd>⌥⌘↩</kbd> | 修補上一次提交。見 [修補上一次提交](/guide/work/commit/#amend)。 |
| 在自動補全列表裡按 <kbd>↑</kbd> <kbd>↓</kbd>、<kbd>↩</kbd>、<kbd>Esc</kbd> | 依序是選一個候選項目、插入它、關閉列表 |

見 [提交變更](/guide/work/commit/)。

## 檔案列表 {#file-list}

這些按鍵在工作區的檔案列表裡有作用：

| 按鍵 | 作用 |
|---|---|
| <kbd>空白鍵</kbd> | 暫存或取消暫存所選的檔案。:ui[files.spacebar] 設成 :ui[files.spacebar.quickLook] 時，改為用「快速查看」顯示它們。見 [檔案列表](/guide/settings/general/#file-list)。 |
| <kbd>⌘⌫</kbd> | 把所選的檔案丟到垃圾桶 |
| <kbd>⇧Tab</kbd> | 回到提交訊息的內文 |

## Diff 裡的行 {#diff-lines}

在工作區裡，按 <kbd>Tab</kbd>，直到某個區塊的行號得到鍵盤焦點。之後：

| 按鍵 | 作用 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 在能選的行之間移動 |
| <kbd>空白鍵</kbd> | 選取或取消選取這一行 |
| <kbd>Tab</kbd> 或 <kbd>⇧Tab</kbd> | 離開行號 |

用滑鼠時，按住 <kbd>⇧</kbd> 再按一下行號，會選取中間的每一行。見 [暫存行](/guide/work/diff/#lines)。

## 列表 {#lists}

| 在哪裡 | 按鍵 | 作用 |
|---|---|---|
| 歷史裡的提交列表 | <kbd>⌘C</kbd> | 拷貝所選提交的完整雜湊 |
| 提交的變更集 | <kbd>↑</kbd> <kbd>↓</kbd> | 移動選取項目 |
| 整頁詳細資訊裡變更的檔案 | <kbd>↩</kbd> | 用各自的預設 App 開啟所選的檔案 |
| 提交的檔案樹 | <kbd>↩</kbd> | 展開或收合所選的資料夾 |
| 檔案歷史 | <kbd>↩</kbd> | 在整頁詳細資訊裡開啟所選的提交 |
| 側邊欄 | <kbd>⌘⌫</kbd> | 先問，再刪除所選的分支、標籤、遠端或子模組 |
| 側邊欄的篩選欄位 | <kbd>Esc</kbd> | 清空輸入框 |
| 工具列的搜尋欄位 | <kbd>Esc</kbd> | 離開搜尋欄位，不清空輸入 |
| 儲藏 | <kbd>⌘⌫</kbd> | 先問，再刪除所選的儲藏 |
| 分支整理 | <kbd>⌘⌫</kbd> | 先問，再刪除所選的分支 |
| 儲存庫管理視窗 | <kbd>↩</kbd> | 替所選的一項重新命名 |
| 儲存庫管理視窗 | <kbd>⌫</kbd> 或 <kbd>⌦</kbd> | 刪除所選的項目。見 [刪除儲存庫](/guide/repositories/manager/#delete)。 |
| 啟動時顯示的視窗 | <kbd>↩</kbd> | 開啟所選的儲存庫。見 [回到上次離開的地方](/guide/repositories/navigation/#restore)。 |
| Pull Request 的討論 | <kbd>↩</kbd> | 開啟所選的提交 |
| Pull Request 的討論 | <kbd>⌘S</kbd> | 按下 :ui[pullRequests.addComment] |
| 設定裡的 :ui[settings.themes] | <kbd>↩</kbd> | 重新命名所選的主題 |
| 設定裡的 :ui[settings.appIcon.label] | 方向鍵、<kbd>空白鍵</kbd> | 在圖示之間移動，換成所在的那一個 |
| 設定裡的 :ui[settings.sshHosts] | <kbd>↩</kbd> | 編輯所選的別名 |

在能多選的列表裡，按住 <kbd>⇧</kbd> 再按一下會選取一段，按住 <kbd>⌘</kbd> 再按一下會加選或取消選取一項。在側邊欄裡，按住 <kbd>⌘</kbd> 再按一下分支與標籤，可以一起看它們的歷史。見 [開啟歷史](/guide/history/browse/#open)。

按住 <kbd>⌘</kbd> 按兩下一個已在別的工作樹裡簽出的分支，會在新標籤頁裡開啟那個工作樹。見 [簽出分支](/guide/branches/branches/#checkout)。

## 快速操作 {#quick-actions}

這些按鍵在 [快速操作](/guide/repositories/navigation/#quick-actions) 面板裡有作用：

| 按鍵 | 作用 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 移動選取的那一列 |
| <kbd>↩</kbd> | 對選取的項目執行預設操作 |
| <kbd>Tab</kbd>，或在文字末尾按 <kbd>→</kbd> | 列出選取項目的全部操作 |
| 沒有文字時按 <kbd>←</kbd>，或按 <kbd>⇧Tab</kbd> | 從操作列表返回 |
| <kbd>Esc</kbd> | 清空文字。沒有文字時，從操作列表返回或關閉面板。 |

## 對話框 {#dialogs}

在對話框裡，<kbd>↩</kbd> 按下醒目標示的按鈕，<kbd>Esc</kbd> 按下取消用的按鈕。對話框裡沒有這樣的按鈕時，<kbd>Esc</kbd> 也按下醒目標示的按鈕。

## 按住 Option 拖放 {#drag}

放開時按住 <kbd>⌥</kbd>，會換成另一個操作：

| 拖什麼 | 拖到哪裡 | 不按 <kbd>⌥</kbd> | 按住 <kbd>⌥</kbd> |
|---|---|---|---|
| 本機分支 | :ui[workspace.title] 或目前分支 | 合併對話框 | 重定基底對話框 |
| 遠端分支 | 目前分支 | 拉取對話框 | 它成為目前分支的上游 |
| 歷史裡的提交 | :ui[workspace.title] 或目前分支 | 摘取它們 | 反轉它們 |
| 歷史裡的提交 | 列表裡的另一個提交 | 把它們壓縮進去 | 改為 Fixup |

見 [拖放](/guide/branches/merge-rebase/#drag-and-drop) 與 [壓縮、Fixup、刪除與移動](/guide/history/rewrite/#interactive)。

## 相關頁面

- [視窗與導覽](/guide/repositories/navigation/)
- [提交變更](/guide/work/commit/)
- [檢視與挑選變更](/guide/work/diff/)
- [合併與重定基底](/guide/branches/merge-rebase/)

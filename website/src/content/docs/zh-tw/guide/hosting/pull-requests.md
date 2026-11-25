---
title: "Pull Request 與 Merge Request"
description: "列出、新增、討論、簽出、合併與關閉 GitHub 的 Pull Request 和 GitLab 的 Merge Request。"
---

Spooky 會列出儲存庫遠端上的 GitHub Pull Request 和 GitLab Merge Request。閱讀、討論、看 CI/CD 狀態、簽出、合併和新增，都不用離開儲存庫視窗。

這需要為遠端加入 [託管帳號](/guide/hosting/accounts/)。遠端在 GitLab 上時，側邊欄、選單和對話框裡的叫法都換成 Merge Request。

## 開啟列表 {#list}

按一下側邊欄的 :ui[pr.title]，或者選 :ui[menu.view > pr.show.menu]（<kbd>⌘4</kbd>）。

在列表頂部的選單裡選遠端。每一列寫著：

- 狀態圖示和標題。開啟著的請求圖示是綠色，草稿是灰色，已關閉是紅色，已合併是紫色。把指標停在圖示上，可以看到狀態的名稱。
- 編號、作者和開啟的時間
- 來源分支和要併入的分支。來自 Fork 的請求，來源分支前會寫出它所在的專案。
- 標籤，底色是標籤自己的顏色。把指標停在標籤上，可以看到它的說明。一行放不下的標籤不顯示。
- 有 [CI/CD 狀態](#checks) 時，右邊有一個表示狀態的圖示

捲到底部會接著讀取更多。想把列表重新讀一遍，按一下 :ui[action.refresh] 或按 <kbd>⌘R</kbd>。

列表一開始只列開啟著的請求。想連已關閉和已合併的一起看，按一下列表頂部的篩選按鈕，選 :ui[pullRequests.filter.all]。已關閉和已合併的請求不能再合併或關閉。下次開啟視窗時，列表回到 :ui[pullRequests.filter.open]。

列表讀取失敗時會說明原因，已經讀到的請求留在下面。帳號的權杖被拒絕或缺少權限範圍時，可以直接在那裡按一下 :ui[accounts.reauthenticate]。

列表不知道該用哪個帳號時，見 [遠端用哪個帳號](/guide/hosting/accounts/#remotes)。

## 檢視請求 {#details}

選取一個請求，右邊會顯示它。頂部可以在四個視圖間切換：

- :ui[pullRequests.conversation]：標題和狀態、標籤、描述、留言，以及按天分組的提交，按時間從早到晚排列。
- :ui[pullRequests.commits]：請求裡的提交。上方一欄列出參與者和提交的數量。
- :ui[pullRequests.changeset]：請求改了什麼，比較的是來源分支分出來的位置。
- :ui[pullRequests.checks]：請求的各項檢查或流水線裡的作業，見 [CI/CD 狀態](#checks)。

在討論裡按兩下一個提交，或者按 <kbd>Return</kbd>，可以開啟它。在提交上按右鍵可以拷貝它的雜湊。按一下內文裡的連結可以開啟它。

:ui[pullRequests.commits] 和 :ui[pullRequests.changeset] 需要請求的提交已經在你的儲存庫裡。還沒有時，按一下 :ui[pullRequests.fetch]。Spooky 會從遠端取回這些提交，不變更你的分支。

GitLab 在 Merge Request 關閉或合併 14 天後不再保留它的提交。這之後 :ui[pullRequests.fetch] 取不回來，Spooky 會說明提交已無法取回。只有你的儲存庫裡還沒有這些提交時才受影響。

## CI/CD 狀態 {#checks}

:ui[pullRequests.checks] 顯示請求最新的提交跑得怎麼樣：

- **GitHub**：這個提交上的檢查和提交狀態
- **GitLab**：請求最新一條流水線裡的作業

頂部是整體狀態，下面逐項列出每個檢查或作業和它的狀態。還有等待中或執行中的項目時，Spooky 會自己更新這個視圖。

列表裡，請求那一列的圖示是它的整體狀態，把指標停在上面，可以看到狀態的名稱。沒有檢查或流水線的請求沒有圖示。

有記錄的檢查或作業，那一列左邊有一個展開三角形。按一下它，記錄顯示在這一列下面。再按一下收起。

- **GitHub**：GitHub Actions 的作業結束後有記錄。被略過的作業、提交狀態和其他 App 寫的檢查沒有。
- **GitLab**：流水線裡的每個作業都能展開。作業還在執行時，記錄跟著狀態一起更新。

記錄裡不顯示時間戳記和顏色碼。文字可以選取拷貝。

## 新增請求 {#create}

來源分支必須已經在遠端上，要先推送它。然後任選一種方式：

- 按一下列表頂部的新增按鈕。
- 選 :ui[menu.repository > pr.create.menu]（<kbd>⌃⌘P</kbd>）。
- 在側邊欄裡對一個分支按右鍵，選 :ui[pr.forBranch.create]{1="feature/units-toggle"}。這個分支已經有開啟著的請求時，這一項換成 :ui[pr.forBranch.show]{1="feature/units-toggle"}。

在對話框裡：

1. 在 :ui[pullRequests.source] 和 :ui[pullRequests.target] 兩行各選一個遠端和它上面的分支。來源一開始是你按右鍵的分支或目前分支，目標是遠端的預設分支。只列出和帳號在同一個實例上的遠端。來源選了另一個專案，就是來自 Fork 的請求。
2. 標題一開始是來源分支的名稱。描述可以不填。
3. 按一下 :ui[pr.create.submit]。

來源和目標不能是同一個分支。

## 討論 {#discuss}

想發表留言，按一下討論末尾的 :ui[pullRequests.addComment]，或者按 <kbd>⌘S</kbd>。

想在留言裡提及某個人，輸入 `@`。Spooky 會列出參與這個請求的人和專案的成員，並隨著你繼續輸入使用者名稱或名字縮小範圍。按 <kbd>↑</kbd> 或 <kbd>↓</kbd> 選一項，按 <kbd>Return</kbd> 插入使用者名稱，按 <kbd>Esc</kbd> 關掉列表。

自己的留言，可以用留言上的 :ui[pullRequests.comment.edit] 和 :ui[pullRequests.comment.delete]，也可以在它上面按右鍵。按兩下自己的留言同樣會開啟編輯。刪除留言不能還原。

在 GitLab 上，還可以用 :ui[pullRequests.comment.reply] 回覆任何一則留言。回覆會放進 GitLab 上的同一個討論裡。

自己的請求，還可以：

- 修改描述：按一下描述旁邊的 :ui[pullRequests.edit]，或者在它上面按右鍵，選 :ui[pullRequests.editDescription.menu]。
- 修改標題、描述和目標分支：在列表裡按兩下這個請求，或者在它上面按右鍵，選 :ui[pr.edit.menu]{1="#12"}。來源和目標專案不能改。

## 編輯標籤 {#labels}

請求的標籤在 :ui[pullRequests.conversation] 裡，標題下面。

- 想移除一個標籤，按一下它名稱後面的 ×。
- 想加入標籤，按一下 :ui[pullRequests.labels.add]，在專案的標籤裡選一個。在頂部的輸入框裡打字可以篩選。
- 想新增標籤，按一下 :ui[pullRequests.labels.add]，再按 :ui[pullRequests.labels.new]。填名稱、選顏色，按一下 :ui[pullRequests.createLabel.title]。Spooky 會在專案裡建好這個標籤，並加到請求上。

改完後列表隨即更新。帳號沒有權限改標籤時，Spooky 會顯示服務給出的原因，標籤保持不變。

## 簽出請求 {#checkout}

想在本機處理請求的程式碼，按一下詳細資訊底部的 :ui[pullRequests.checkout]，或者在請求上按右鍵，選 :ui[pr.checkout.menu]{1="#12"}。

填本機分支的名稱，按一下 :ui[pullRequests.checkout]。名稱一開始是來源分支的名稱。來自 Fork 的請求是 `pullrequests/<author>/<branch>`。

Spooky 先取回請求的提交，再簽出分支：

- 已有同名的本機分支、又指向這些提交時，直接簽出它。
- 同名分支指向別處時，對話框會提示。換個名稱即可。
- 否則新增這個分支。同一個專案裡的請求，只要遠端上的來源分支在同一個提交上，新分支就追蹤它。

已追蹤的檔案有變更時，Spooky 會先問要不要儲藏，見 [自動儲藏](/guide/work/stash/#auto-stash)。

追蹤來源分支的本機分支有還沒推送的提交時，不能簽出。這個分支就是目前分支、而且已經在請求的提交上時，也不能簽出。

GitLab 不再保留提交的 Merge Request，只有你的儲存庫裡已經有這些提交時才能簽出。

## 合併請求 {#merge}

按一下詳細資訊底部的 :ui[pullRequests.merge]。合併在託管服務上進行，不能還原。

- **GitHub**：在儲存庫允許的方式裡選 :ui[pullRequests.mergeType]：:ui[pullRequests.method.merge]、:ui[pullRequests.method.rebase] 或 :ui[pullRequests.method.squash]。Spooky 會預先選好你上次用的方式。
- **GitLab**：對話框寫出專案的 :ui[pullRequests.mergeStrategy]。想壓縮就勾選 :ui[pullRequests.squash]。專案不允許壓縮時，沒有這一項。專案要求壓縮時，這一項一直勾著。

:ui[pullRequests.deleteBranch] 會刪除服務上的來源分支。一開始按專案的設定勾選。

請求不能合併時，對話框會說明原因，例如它是草稿、有衝突、你的帳號沒有合併權限，或者服務還在檢查。

合併之後，Spooky 會從這個遠端擷取一次，讓它的分支跟上合併的結果。

## 關閉請求 {#close}

按一下詳細資訊底部的 :ui[pullRequests.close] 並確認。想重新開啟，到託管服務上操作。

:::note[伺服器儲存庫]
列表、CI/CD 狀態和在服務上做的操作都從你的 Mac 送出。取回請求的提交、簽出請求和合併後的擷取在伺服器上執行。:ui[pullRequests.commits] 和 :ui[pullRequests.changeset] 的比較也在伺服器上進行。
:::

對服務的每一次請求都會出現在 :ui[activity.title] 視窗的 :ui[activity.service] 頁裡。CI/CD 狀態的自動更新不記在裡面。

## 相關頁面

- [託管帳號](/guide/hosting/accounts/)
- [分支](/guide/branches/branches/)
- [分支整理](/guide/branches/review/)

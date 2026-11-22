---
title: "擷取、拉取與推送"
description: "擷取、拉取與推送，首次發布分支，同步、安全強制推送與自動擷取。"
---

這幾個操作在你的儲存庫和 [遠端](/guide/branches/tags-remotes/#remotes) 之間交換提交：

- 擷取：從遠端下載新提交。你的分支和工作區保持原樣。
- 拉取：擷取一個遠端分支，再把它的提交併進目前所在的分支。
- 推送：把你的提交送到遠端分支上。

工具列上並排放著 :ui[sync.fetch]、:ui[sync.pull] 與 :ui[sync.push]，旁邊是 :ui[sync.sync]。:ui[menu.repository] 選單裡也有這些操作。

擷取、拉取、推送與同步不會記進還原記錄，所以還原不了。發布分支可以還原。

:::note[伺服器儲存庫]
遠端是從伺服器上存取的，用的是伺服器的網路和 SSH 金鑰。遠端要密碼時，Spooky 會來問你，見 [密碼與私鑰密語的詢問](/guide/server/connection/#prompts)。
:::

## 擷取 {#fetch}

1. 按一下工具列上的 :ui[sync.fetch]，或者選 :ui[menu.repository > sync.fetchMenu]（<kbd>⇧⌘F</kbd>）。只想擷取一個遠端，在側邊欄裡對它按右鍵，選 :ui[remote.fetchMenu]{1="origin"}。
2. 在 :ui[sync.remote] 裡選遠端，或者勾選 :ui[sync.allRemotes]。
3. 設定選項：
   - :ui[sync.prune]：去掉遠端上已經刪除的遠端分支。一開始是勾選的。
   - :ui[sync.fetchSubmodules]：同時擷取已簽出子模組的新提交。
   - :ui[sync.allTags]：同時擷取遠端上的全部標籤。
4. 按一下 :ui[sync.fetch]。

除了 :ui[sync.allTags]，Spooky 會記住這些選項。

擷取之後，側邊欄裡的遠端分支就是最新的了，本機分支上的 ↓ 是可以拉取的提交數。

:ui[menu.repository > sync.fetchAll] 不跳出對話框，直接擷取全部遠端。在 [遠端設定](/guide/branches/tags-remotes/#remote-settings) 裡勾選了 :ui[remote.skipFetchAll] 的遠端會略過。

## 拉取 {#pull}

1. 按一下工具列上的 :ui[sync.pull]，或者選 :ui[menu.repository > sync.pullMenu]（<kbd>⇧⌘P</kbd>）。想拉取某個遠端分支，在它上面按右鍵，選 :ui[branch.pullMenu]{1="origin/main"}。
2. 在 :ui[sync.remoteBranch] 裡選分支。一開始是目前分支的 [上游](/guide/branches/branches/#track)。
3. 勾選 :ui[sync.rebase]，你的提交會接在拉下來的提交後面，不再用一個合併提交把兩邊接起來。Spooky 會記住這個選擇。
4. 選項上方的預覽會告訴你拉取會不會遇到衝突，見 [預覽衝突](/guide/branches/merge-rebase/#preview)。
5. 設定選項：
   - :ui[merge.verify]：拉下來的提交沒有可信簽章時停下。Spooky 會記住它。
   - :ui[sync.skipHooks]：這一次不執行儲存庫的 Git 掛鉤。
6. 按一下 :ui[sync.pull]。

拉取時，已追蹤的檔案不能有變更。有變更的話，Spooky 會提議先把變更儲藏起來，見 [自動儲藏](/guide/work/stash/#auto-stash)。新檔案只有在拉取會覆寫它們時才會擋路。

拉取遇到衝突時，Spooky 會切到工作區並顯示一條橫幅，見 [解決衝突](/guide/work/conflicts/#banner)。

## 推送 {#push}

1. 按一下工具列上的 :ui[sync.push]，或者選 :ui[menu.repository > sync.pushMenu]（<kbd>⇧⌘U</kbd>）。
2. 在 :ui[sync.destination] 裡選遠端分支。一開始是目前分支的上游。
3. 設定選項：
   - :ui[sync.pushAllTags]：把全部本機標籤也推送上去。
   - :ui[sync.forcePush]：一般推送推不上去時覆寫遠端分支，見 [安全強制推送](#force-push)。
   - :ui[sync.pushSubmodules]：處理這次推送參照到的子模組提交，可以選 :ui[sync.pushSubmodules.onDemand] 或 :ui[sync.pushSubmodules.check]。
   - :ui[sync.skipHooks]：這一次不執行儲存庫的 Git 掛鉤。
4. 按一下 :ui[sync.pushHead]。

Spooky 會記住標籤與子模組這兩個選項。

目前分支還沒有追蹤遠端分支時，按一下 :ui[sync.push] 會改為開啟發布對話框，見 [發布分支](#publish)。儲存庫連一個遠端都沒有時，開啟的是發布儲存庫的對話框，見 [發布儲存庫](/guide/hosting/accounts/#publish)。

別人先推送到了這個遠端分支時，遠端會拒絕你的推送。先拉取他們的提交，再推送一次。

想推送不是目前所在的分支，在側邊欄裡把它拖到一個遠端分支上。:ui[sync.pushBranch] 對話框會把它推送到那裡。這是一次一般推送，沒有選項，也不會改變這個分支追蹤的對象。

## 發布分支 {#publish}

新分支在發布之前只存在於你的儲存庫裡。發布就是在遠端上建立這個分支。

1. 選 :ui[menu.repository > sync.publishMenu]，或者在分支上按右鍵，選 :ui[branch.publishMenu]{1="feature/station-map"}。也可以在側邊欄裡把分支拖到一個遠端上。
2. 核對 :ui[branch.local] 與 :ui[sync.remote]。:ui[branch.name] 是遠端上的名稱，一開始和本機的名稱一樣。
3. :ui[sync.setUpstream] 讓你的分支追蹤新的遠端分支，以後拉取和推送都對著它。一開始是勾選的。
4. 勾選 :ui[sync.skipHooks]，就不執行儲存庫的 Git 掛鉤。
5. 按一下 :ui[sync.publish]。

想收回，選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

## 同步 {#sync}

同步會對目前分支依序擷取、拉取、推送。

1. 按一下工具列上的 :ui[sync.sync]，或者選 :ui[menu.repository > sync.syncMenu]（<kbd>⇧⌘Y</kbd>）。
2. 在 :ui[sync.remoteBranch] 裡選分支。一開始是目前分支的上游。
3. 需要的話勾選 :ui[sync.rebase]。下方的預覽會告訴你拉取會不會遇到衝突。
4. 設定選項：:ui[merge.verify]、:ui[sync.pushAllTags]、:ui[sync.pushSubmodules] 與 :ui[sync.skipHooks] 的作用和拉取、推送時一樣。
5. 按一下 :ui[sync.syncHead]。

和拉取一樣，已追蹤的檔案有變更時，Spooky 會先提議儲藏。

某一步失敗時，Spooky 會停在那裡，告訴你停在了哪一步、哪些步驟已經完成。在 :ui[activity.title] 裡，拉取和推送各有一筆記錄。

## 推送到別處 {#push-to}

想把分支、標籤或提交推送到遠端上任意的分支或參照：

1. 選 :ui[menu.repository > sync.pushToMenu]，或者在一個分支上按右鍵，選 :ui[branch.pushToMenu]{1="main"}；標籤的選單裡是 :ui[tag.pushToMenu]{1="v0.4.0"}。
2. 在 :ui[sync.revision] 裡選要推送的內容，在 :ui[sync.remote] 裡選遠端。
3. 在 :ui[sync.refSpec] 裡填推送到哪裡：新的或既有的分支名稱，或者 `refs/tags/v0.4.0` 這樣的完整參照。
4. 按一下 :ui[sync.pushRevision]。

推送的是分支時，對話框一開始填的是它追蹤的遠端分支。推送的是標籤時，一開始填的是 `refs/tags/` 加上標籤名稱。

## 安全強制推送 {#force-push}

改寫了已經推送過的提交之後，例如修補或變基之後，一般推送會被拒絕：遠端分支上有你的分支已經沒有的提交。強制推送會用你的分支取代遠端分支。

Spooky 只做安全強制推送：只有遠端分支還停在你上次擷取時的位置，推送才會成功。這期間有人推送過的話，Git 會拒絕，什麼都不會被覆寫。Spooky 不會退回到沒有保護的強制推送。

1. 選 :ui[menu.repository > sync.forcePushMenu]（<kbd>⌃⌘U</kbd>），或者在一個本機分支上按右鍵，在選單裡選這一項。
2. 在 :ui[branch.target] 裡選本機分支，在 :ui[sync.destination] 裡選遠端分支。
3. 看一下下方的比對。它會說明推送後遠端分支新增幾個提交、有幾個提交被覆寫。接著：
   - 綠色的一行表示遠端分支正是你的分支改寫前的版本。通常都是這樣。
   - 黃色的一行表示遠端分支在別的位置，或者有你的分支從未有過的提交。確認一下是不是真的要覆寫它們。
   - 兩邊是同一個提交時，沒有可推送的內容。
4. 按一下 :ui[sync.forcePush]。

::screenshot[安全強制推送對話框。本機分支是 feature/units-toggle，遠端分支是 origin/feature/units-toggle。下方帶綠色勾號的一行說明遠端分支正是這個分支改寫前的版本。]{name="branches-force-push" frame="dialog" markers="16.4,67.5"}

1. 比對

推送對話框裡的 :ui[sync.forcePush] 選項用的是同樣的保護。

:::tip
可以用 :ui[menu.view > menu.customizeToolbar] 把 :ui[toolbar.forcePush] 與 :ui[toolbar.pushTo] 加到工具列上。
:::

## 快速版本 {#quick}

按住 <kbd>⌥</kbd>，工具列上的 :ui[sync.fetch]、:ui[sync.pull]、:ui[sync.push] 與 :ui[sync.sync] 會變成 :ui[sync.quickFetch]、:ui[sync.quickPull]、:ui[sync.quickPush] 與 :ui[sync.quickSync]。選單裡的項目也一樣會變，例如 :ui[sync.quickPushMenu]。

快速版本不跳出對話框，直接執行：

- 它對著目前分支的上游。
- 它用你上次在對話框裡選的選項。:ui[sync.skipHooks] 不會沿用。
- :ui[sync.quickFetch] 擷取目前分支追蹤的那個遠端。上次勾選了 :ui[sync.allRemotes]，或者目前分支沒有追蹤任何分支時，擷取全部遠端。
- 目前分支沒有追蹤遠端分支時，:ui[sync.quickPush] 與 :ui[sync.quickSync] 會告訴你這一點。

按右鍵開啟的選單裡也有快速版本，例如遠端的 :ui[sync.quickFetchNamed]{1="origin"}、遠端分支的 :ui[sync.quickPullNamed]{1="origin/main"}。

## 自動擷取 {#auto-fetch}

Spooky 可以在背景擷取，讓遠端分支和 ↓ 的數字保持最新。到 :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch] 裡選多久一次：:ui[settings.autoFetch.never]、每 5、10 或 30 分鐘，或者 :ui[settings.autoFetch.hour]。一開始是每 30 分鐘，見 [操作](/guide/settings/general/#operations)。

- 儲存庫開啟約 10 秒後，Spooky 會看一遍哪些遠端到期了，之後每隔幾分鐘看一次。從沒擷取過的遠端，或者距上次擷取已經過了設定間隔的遠端，就算到期。
- 只有視窗顯示著這個儲存庫、又沒有開啟對話框時才擷取。Spooky 在背景時照常進行。
- 只有儲存庫裡沒有別的操作在執行時才開始。它正在擷取時你發起了別的操作，它會停下，讓你的操作先執行。:ui[activity.title] 裡會寫明它為哪個操作停下。
- 它從不詢問密碼。失敗時，錯誤只出現在 :ui[activity.title] 裡。
- 它用你上次在擷取對話框裡選的清理與子模組選項，並略過勾選了 :ui[remote.skipFetchAll] 的遠端。
- 本機儲存庫裡，它會略過指向 Mac 上路徑的遠端，Mac 沒連上網路時也不擷取。

## 相關頁面

- [合併與變基](/guide/branches/merge-rebase/)
- [分支](/guide/branches/branches/)
- [操作排隊與活動](/guide/advanced/queue-activity/)
- [儲藏](/guide/work/stash/)

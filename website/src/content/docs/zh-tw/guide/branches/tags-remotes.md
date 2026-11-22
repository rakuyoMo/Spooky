---
title: "標籤與遠端"
description: "新增、發布與刪除標籤，加入、編輯、重新命名與移除遠端。"
---

標籤列在側邊欄的 :ui[sidebar.tags] 下，遠端列在 :ui[remote.group] 下。它們各有自己的選單：在其中一個上按右鍵，就能看到可以對它做什麼。

## 標籤 {#tags}

標籤給一個提交取一個固定的名稱，通常用來標示版本，例如 `v0.4.0`。和分支不同，提交時它不會跟著移動。

把指標停在標籤上，可以看到它指向的提交，有說明的話也會顯示出來。按兩下標籤就簽出它所在的提交，見 [簽出標籤或提交](/guide/branches/branches/#checkout-revision)。

和分支一樣，名稱裡帶 `/` 的標籤會放進資料夾。想只顯示最新的幾個，或者倒過來排序，見 [篩選與分組](/guide/branches/branches/#filter)。

### 新增標籤 {#create-tag}

1. 選 :ui[menu.repository > tag.createMenu]（<kbd>⇧⌘T</kbd>）。也可以按一下側邊欄底部的新增按鈕，在選單裡選它。想給某個分支或提交加上標籤，改為在它上面按右鍵，選 :ui[tag.createFrom]{1="main"}。
2. 在 :ui[reference.name] 裡輸入名稱。
3. :ui[tag.revision] 是要加上標籤的提交。一開始是目前所在的分支，或者你按右鍵的那一項。
4. 可以寫一段 :ui[tag.messageField]。不寫的話，標籤只是提交的一個名稱。寫了的話，Git 還會記下是誰、在什麼時候加的標籤。
5. 想簽署標籤，勾選 :ui[tag.sign]，在 :ui[tag.signingKey] 裡選一把金鑰。:ui[tag.signingKey.configured] 用 Git 裡設定好的金鑰。簽署的標籤必須有說明。Spooky 會記住是否簽署。
6. 按一下 :ui[tag.create.submit]。

也可以把提交或本機分支拖到 :ui[sidebar.tags] 或標籤資料夾上。

新標籤在發布之前只存在於這個儲存庫裡。想去掉它，選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

### 發布標籤 {#publish-tag}

1. 在標籤上按右鍵，選 :ui[tag.publishMenu]{1="v0.4.0"}，或者選 :ui[menu.repository > tag.publishMainMenu]。也可以把標籤拖到遠端上。
2. 核對 :ui[tag.local] 與 :ui[sync.remote]。遠端是目前分支追蹤的那個，把標籤拖到了別的遠端上時就是那個遠端。
3. 勾選 :ui[sync.skipHooks]，推送時就不執行儲存庫的 Git 掛鉤。
4. 按一下 :ui[tag.publish]。

發布標籤可以還原。還原時會把它從遠端上刪掉。

想一次把全部標籤推送到某個遠端，在這個遠端上按右鍵，選 :ui[tag.pushAll]{1="origin"}。推送對話框也能把全部標籤一起推送，見 [推送](/guide/branches/sync/#push)。

### 刪除標籤 {#delete-tag}

在標籤上按右鍵，選 :ui[reference.deleteMenu]{1="v0.1.0"}。也可以在側邊欄裡選取一個或幾個標籤，按 <kbd>⌘⌫</kbd>，這時焦點要在側邊欄上。

Spooky 一定會先問一下。想在遠端上也刪掉這個標籤，勾選 :ui[tag.deleteRemote]，在 :ui[sync.remote] 裡選好遠端。

只在這個儲存庫裡刪除標籤可以還原。在遠端上也刪除時，就還原不了了。

## 遠端 {#remotes}

遠端是儲存庫的另一份副本，你從它那裡擷取，也推送到它那裡，通常放在託管服務上。複製儲存庫時的來源一般叫 `origin`。

:ui[remote.group] 下，每個遠端列出自己的分支。把指標停在遠端上，可以看到它的擷取位址與推送位址。

在遠端上按右鍵會開啟它的選單：

- :ui[remote.fetchMenu]{1="origin"} 與 :ui[sync.prune] 開啟擷取這個遠端的對話框，見 [擷取](/guide/branches/sync/#fetch)。
- :ui[remote.viewInBrowser]{1="origin"} 開啟遠端的網頁。HTTP(S)、SSH 與 `git://` 位址都可以，本機路徑不行。
- 其餘幾項用來加入、編輯、重新命名與刪除遠端，下面分別介紹。

:::note[伺服器儲存庫]
遠端是從伺服器上存取的，用的是伺服器的網路和 SSH 金鑰。在 Mac 上能用的位址，在伺服器上不一定能用。
:::

### 加入遠端 {#add-remote}

1. 選 :ui[menu.repository > remote.addMainMenu]。也可以按一下側邊欄底部的新增按鈕，或者在 :ui[remote.group] 上按右鍵，在選單裡選 :ui[remote.addMenu]。
2. 在 :ui[reference.name] 裡輸入一個簡短的名稱，例如 `upstream`。
3. 在 :ui[remote.url] 裡貼上位址。
4. 按一下 :ui[remote.add.submit]。

加入之前，Spooky 會先檢查連線。連不上時，對話框不會關閉。寫錯了可以改了再試。遠端加入好以後，Spooky 會馬上擷取一次。

### 遠端設定 {#remote-settings}

按一下側邊欄裡的遠端，就開啟它的設定。頂部的切換按鈕有兩頁：

- :ui[remote.page.general] 顯示 Git 怎樣和這個遠端打交道。
- :ui[remote.page.branches] 列出這個遠端的分支，以及每個分支指向的提交。

在 :ui[remote.page.general] 裡把指標停在某一行上，會顯示這一行的按鈕。

| 設定 | 作用 |
|---|---|
| :ui[remote.field.fetchURL] | 從哪裡擷取。在遠端上按右鍵、選 :ui[remote.editConnection] 也能修改它 |
| :ui[remote.skipFetchAll] | 自動擷取與 :ui[sync.fetchAll] 時不包括這個遠端 |
| :ui[remote.field.fetchRefspecs] | 擷取哪些分支，存到哪裡 |
| :ui[remote.field.pushURL] | 推送到哪裡。沒有設定時用擷取位址，以灰色顯示。:ui[remote.action.unset] 會改回擷取位址 |
| :ui[remote.field.pushRefspecs] | 推送哪些分支，推送到哪裡 |

Refspec 是一條規則，把一邊的分支名稱對應到另一邊的名稱。大多數遠端只要 Git 預設設好的那一條就夠了。想加一條，按一下 :ui[remote.group.fetch] 或 :ui[remote.group.push] 旁邊的 :ui[remote.action.addRefspec]。

新位址儲存之前，Spooky 會先檢查一下。對遠端設定的修改可以還原。

### 重新命名或移除遠端 {#rename-remote}

在遠端上按右鍵，選 :ui[reference.renameMenu]{1="origin"} 或 :ui[reference.deleteMenu]{1="origin"}。

移除遠端，會把它和它的遠端分支從這個儲存庫裡去掉。它指向的那個儲存庫不受影響。重新命名和移除都可以還原。

## 相關頁面

- [分支](/guide/branches/branches/)
- [擷取、拉取與推送](/guide/branches/sync/)
- [還原與找回](/guide/work/undo/)

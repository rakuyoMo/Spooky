---
title: "加入伺服器儲存庫"
description: "逐項填寫「加入伺服器儲存庫」對話框，看懂連線檢查的結果，在伺服器上複製與尋找儲存庫。"
---

加入伺服器儲存庫後，它會加進儲存庫管理的列表並開啟。Spooky 會先檢查連線，缺了什麼，對話框會告訴你該怎麼補。

開始之前，先確認終端機能連上伺服器，而且什麼都不問，見 [準備 SSH](/guide/server/prepare-ssh/)。

開啟對話框：在 :ui[menu.file] 選單裡選 :ui[action.addRemote]，或者在儲存庫管理視窗加入按鈕的選單裡選它。

## 填寫對話框 {#dialog}

::screenshot[加入伺服器儲存庫對話框。主機別名是 spooky-test。儲存庫路徑是 /srv/git/driftwood，旁邊有「瀏覽」按鈕。掛載到本機選的是「不掛載」。按鈕是「取消」與「開啟」。]{name="add-server" frame="dialog"}

| 這一項 | 填什麼 |
|---|---|
| :ui[remote.host] | `~/.ssh/config` 裡 `Host` 那一行的名稱，例如 `driftwood-server`。只填別名，不帶使用者名稱和連接埠。 |
| :ui[remote.path] | 儲存庫在伺服器上的完整路徑，以 `/` 開頭，例如 `/srv/git/driftwood` |
| :ui[remote.mount] | 可以不選。選了之後，儲存庫資料夾在這台 Mac 上也能看到，Finder 就能顯示它，見 [加入時掛載](/guide/server/local-location/#when-adding)。 |

不知道路徑的話，填好主機別名後按一下 :ui[clone.browse]。Spooky 會列出伺服器上的資料夾，從你填的路徑開始，沒填時從你在伺服器上的個人資料夾開始。Git 儲存庫標著 :ui[browse.repository]，讀不了的資料夾顯示成灰色。按兩下資料夾進入它，再按一下 :ui[bookmarks.create.choosePrompt]。

也可以選儲存庫裡面的某個資料夾，Spooky 會開啟它所在的儲存庫。

填好主機別名，路徑以 `/` 開頭，:ui[action.open] 就可以按了。

## 連線檢查 {#check}

按一下 :ui[action.open] 後，對話框底部顯示 :ui[remote.checking]，Spooky 依序檢查：

1. SSH 能用這個主機別名登入。
2. 伺服器上有 Git，版本不低於 2.41.0。
3. 資料夾存在，你能開啟、讀取它。
4. 資料夾在一個 Git 儲存庫裡，Git 能讀出它的狀態。

檢查期間，各項都不能改。按一下 :ui[action.cancel] 會停止檢查，關閉對話框。

全部通過後，Spooky 在伺服器上放好輔助指令碼，把儲存庫加進儲存庫管理的列表，然後開啟它。

## 檢查沒通過時 {#results}

對話框不關，填過的內容也都留著。底部先寫該怎麼改，下面是 SSH 或 Git 的原始輸出。改好之後，再按一次 :ui[action.open]。

| 出了什麼問題 | 怎麼辦 |
|---|---|
| 主機別名不對 | 只填 `Host` 那一行的別名，不帶空格、`@`、`:` 或 `/`。 |
| 不認識伺服器的指紋 | 先在終端機裡連一次，核對指紋，見 [先連一次](/guide/server/prepare-ssh/#fingerprint)。Spooky 從不替你接受指紋。 |
| 伺服器的指紋變了 | 先別連。和伺服器管理者確認指紋為什麼變了。 |
| SSH 登入不了 | 伺服器不接受你的金鑰，或者 Mac 解不開它，見 [按 Spooky 的方式測試](/guide/server/prepare-ssh/#test)。 |
| 連不上伺服器 | 檢查主機別名和網路，再試一次。 |
| 找不到 Git | 在伺服器上安裝 Git 2.41.0 或以上版本。已經裝了的話，就是 SSH 登入時找不到它。輸出裡列著伺服器用的 `PATH`，在伺服器的 shell 啟動檔裡把 Git 所在的資料夾加進去。 |
| Git 版本太舊 | 把伺服器上的 Git 更新到 2.41.0 或以上版本。 |
| 資料夾不存在 | 檢查路徑。想在那裡新增儲存庫，按一下 :ui[bookmarks.noRepository.create]。 |
| 沒有資料夾的權限 | 你在伺服器上的使用者要能開啟、讀取這個資料夾。 |
| 伺服器的 macOS 擋住了這個資料夾 | 伺服器是一台 Mac，儲存庫放在「文件」這類受保護的資料夾裡。照 [用一台 Mac 當伺服器](/guide/server/prepare-ssh/#mac-server) 開啟遠端使用者的完整磁碟取用權限，或者把儲存庫挪個地方。 |
| 資料夾不是 Git 儲存庫 | 選儲存庫所在的資料夾，或者按一下 :ui[bookmarks.noRepository.create] 把這個資料夾變成儲存庫。Git 的輸出提到擁有者（ownership）時，表示資料夾屬於伺服器上的另一個使用者。 |
| Git 讀不出狀態 | 下面 Git 的輸出寫著原因。 |
| 建不起伺服器上的工作階段 | 伺服器的 SSH 要允許 Unix socket 轉送。伺服器上還要有 `/usr/bin/perl`，你要能寫入那裡的 `~/.spooky/bin` 與 `/tmp`，見 [系統需求](/reference/requirements/#servers)。 |

::screenshot[加入伺服器儲存庫對話框，主機別名是 spooky-test，路徑是 /srv/git/driftwood。輸入框下面是一則警告，請你確認這個絕對路徑在所選的伺服器上存在，下面附著原文「Directory does not exist」。按鈕是「取消」「新增儲存庫」與「開啟」。]{name="server-add-error" frame="dialog"}

:ui[bookmarks.noRepository.create] 會在那個資料夾裡執行 `git init`，資料夾不存在時先建好它。然後 Spooky 重新檢查連線，開啟新儲存庫。

不加入儲存庫，也能看伺服器用的 `PATH` 與 Git：開啟 :ui[app.name > settings.title] › :ui[settings.environment]，在底部填上主機別名，按一下 :ui[settings.environment.server.check]，見 [檢查伺服器](/guide/settings/general/#server-check)。

## 伺服器上的 Git 環境變數 {#environment}

檢查之後，Spooky 可能會顯示 :ui[remote.environment.title]。這表示伺服器的非互動式 shell 設定了名稱以 `GIT_` 開頭的變數。Spooky 在那裡執行的每條 Git 指令，尋找儲存庫與讀取設定的方式都會受它們影響。

按一下 :ui[action.close]，儲存庫就會開啟。之後 Git 在這個儲存庫裡表現異常的話，從伺服器的 shell 啟動檔裡去掉這些變數。

## 在伺服器上複製與尋找 {#clone-scan}

還有兩種辦法把伺服器上的儲存庫加進列表：

- **複製**：在複製對話框的 :ui[clone.to] 裡選一台伺服器。Git 在伺服器上複製儲存庫，Spooky 把它作為伺服器儲存庫加進列表，見 [複製儲存庫](/guide/repositories/manager/#clone)。
- **尋找**：在加入按鈕的選單裡選 :ui[scan.menu]，在 :ui[scan.in] 裡選一台伺服器。Spooky 在伺服器上的那個資料夾裡尋找，列出找到的儲存庫，見 [尋找儲存庫](/guide/repositories/manager/#scan)。

## 相關頁面

- [準備 SSH](/guide/server/prepare-ssh/)
- [連線狀態與重新連線](/guide/server/connection/)
- [本機位置](/guide/server/local-location/)

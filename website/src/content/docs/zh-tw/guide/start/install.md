---
title: "安裝 Spooky"
description: "查看系統需求、下載並第一次開啟 Spooky、保持更新、選擇介面語言和解除安裝。"
---

這一頁從下載 Spooky 講到第一次開啟它。後面幾節講自動更新、介面語言和解除安裝。

## 系統需求 {#requirements}

- macOS 26 或以上版本
- Git 2.41 或以上版本

Spooky 預設用 `/usr/bin/git`。想換成別的 Git，開啟 :ui[app.name > settings.title]（<kbd>⌘,</kbd>），按一下 :ui[settings.gitConfig]，在 :ui[settings.gitProgram] 選單裡選一個。選單裡列的是 Spooky 找到的、版本夠新的 Git。Git 裝在別處的話，選 :ui[settings.gitProgram.choose] 自己挑。選單下方寫著最低需求的版本。見 [Git 程式](/guide/settings/identity/#git-program)。

:::note[伺服器儲存庫]
伺服器上也要裝 Git 2.41 或以上版本。Spooky 經 SSH 連伺服器，用的是 `~/.ssh/config` 裡的主機別名。設定裡選的 Git 只管這台 Mac 上的儲存庫，伺服器儲存庫用伺服器上的 Git。詳見 [系統需求](/reference/requirements/) 與 [準備 SSH](/guide/server/prepare-ssh/)。
:::

## 下載 {#download}

1. 開啟 GitHub 上的 [Spooky 發行頁面](https://github.com/rakuyoMo/Spooky/releases)。
2. 找到最新的穩定版，它的名稱是 `v` 加版本號碼。名稱以「(beta)」或「(development)」結尾的是測試用的版本。
3. 下載名為 `Spooky-` 加版本號碼的 zip 檔。
4. 按兩下下載的 zip 檔，把它解壓縮。
5. 把 Spooky 拖進 **應用程式** 資料夾。

## 第一次開啟 {#first-launch}

Spooky 沒有經過 Apple 公證。第一次開啟時，macOS 會攔下它，跳出一則警告。這樣放行：

1. 在 **應用程式** 資料夾裡按兩下 Spooky。出現警告後，關掉它。
2. 選 **蘋果選單 › 系統設定**，然後按一下側邊欄中的 **隱私權與安全性**。可能需要向下捲動。
3. 前往 **安全性**，然後按一下 **強制打開**。這個按鈕在你嘗試開啟 Spooky 後的大約一小時內可用。
4. 輸入登入密碼，然後按一下 **好**。

macOS 會記住這次選擇，之後 Spooky 就能正常開啟。它啟動後先顯示儲存庫管理視窗，那裡有什麼見 [介面導覽](/guide/start/tour/)。

## 保持更新 {#updates}

Spooky 預設會自己檢查更新。想馬上檢查，選 :ui[app.name > updates.check]。

每個更新都有簽章。Spooky 安裝前會先核對簽章。沒通過核對的更新，不會取代你現有的 Spooky。

想改更新方式，開啟 :ui[app.name > settings.title]，按一下 :ui[settings.updates]：

| 設定 | 作用 |
|---|---|
| :ui[updates.channel] | 收到哪些版本，見 [更新頻道](#channels) |
| :ui[updates.automaticChecks] | 在背景檢查更新。預設開啟 |
| :ui[updates.automaticDownloads] | 在背景下載更新，結束 Spooky 時安裝。預設關閉。要先開啟自動檢查，Spooky 所在的資料夾也要能寫入，才能開啟這一項 |
| :ui[updates.interval] | 多久檢查一次：:ui[updates.interval.hourly]、:ui[updates.interval.daily] 或 :ui[updates.interval.weekly]，預設每天。開啟了自動檢查才能選 |

最後一行 :ui[updates.lastCheck] 寫著 Spooky 上次檢查的時間。還沒檢查過的話，寫的是 :ui[updates.never]。

### 更新頻道 {#channels}

| 頻道 | 收到的版本 |
|---|---|
| :ui[updates.channel.stable] | 穩定版。這是預設的頻道 |
| :ui[updates.channel.beta] | 穩定版與測試版 |
| :ui[updates.channel.development] | 全部版本，包括開發版 |

### 新版本有什麼變化 {#whats-new}

第一次啟動新版本的 Spooky 時，儲存庫視窗的側邊欄底部會出現 :ui[whatsNew.card.title]。按一下 :ui[whatsNew.card.learnMore] 看這一版改了什麼，不想看就關掉這張卡片。

之後想再看，選 :ui[menu.help > help.whatsNew]。:ui[menu.help > help.releaseNotes] 會開啟 GitHub 上的發行頁面。

## 選擇介面語言 {#language}

Spooky 有英文、簡體中文、繁體中文、日文、韓文、德文、法文與西班牙文八種語言。它按你在 macOS 裡設定的語言順序顯示。你的語言都不在其中時，顯示英文。

只替 Spooky 換一種語言：

1. 選 **蘋果選單 › 系統設定**，然後按一下側邊欄中的 **一般**。
2. 按一下 **語言與地區**，然後前往 **應用程式**。
3. 按一下 **加入** 按鈕，選 Spooky 和一種語言，然後按一下 **加入**。
4. Spooky 正開著的話，結束後重新開啟。

想換回系統語言，在同一個列表裡選取 Spooky，按一下 **移除** 按鈕。

## 解除安裝 {#uninstall}

1. 選 :ui[app.name > menu.quit]（<kbd>⌘Q</kbd>）結束 Spooky。
2. 把 Spooky 從 **應用程式** 資料夾移到 **垃圾桶**。

設定與資料還留在 Mac 上。想一起刪掉：

- 設定：在 **終端機** 裡執行 `defaults delete com.rakuyo.spooky`。
- 主題、活動記錄等其他資料：刪除資料夾 `~/Library/Application Support/Spooky/`。
- 快取：刪除資料夾 `~/Library/Caches/com.rakuyo.spooky/`，以及 `~/Library/HTTPStorages/` 裡名稱以 `com.rakuyo.spooky` 開頭的項目。
- Spooky 儲存的密碼與權杖：刪除鑰匙圈裡名稱以 `com.rakuyo.spooky.` 開頭的項目。
- 用過的每台伺服器：刪除那裡個人資料夾下的 `~/.spooky/`。

儲存庫的 Git 設定裡還留著 Spooky 寫入的 `branch.<name>.spooky-*` 項目。Spooky 存了哪些資料、存在哪裡，見 [資料與隱私權](/reference/data-privacy/)。

## 相關頁面

- [介面導覽](/guide/start/tour/)
- [系統需求](/reference/requirements/)
- [資料與隱私權](/reference/data-privacy/)

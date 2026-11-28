---
title: "資料與隱私權"
description: "了解 Spooky 把什麼存在哪裡、會連到哪些網路位址，以及當機報告與診斷報告裡有什麼。"
---

Spooky 沒有自己的帳號，也不收集使用資料。這一頁列出它存了什麼、存在哪裡，以及會連到哪些位址。

## 在你的 Mac 上 {#mac}

| 內容 | 位置 |
|---|---|
| 設定、儲存庫列表、身分設定檔、託管帳號的列表、伺服器儲存庫在這台 Mac 上的位置，以及工具列按鈕與它們的腳本 | Spooky 的偏好設定 `com.rakuyo.spooky` |
| 主題，每個主題一個 `.spookytheme` 檔案 | `~/Library/Application Support/Spooky/Themes/` |
| 讓伺服器儲存庫能出現在最近使用過的項目裡的 `.spookyrepo` 小資料夾 | `~/Library/Application Support/Spooky/Locations/` |
| :ui[activity.title] 裡擷取、拉取、推送等遠端操作的記錄，保留 7 天 | `~/Library/Application Support/Spooky/Activity/` |
| :ui[activity.title] 統計增減時用來比較的內容，每個儲存庫一個檔案 | `~/Library/Application Support/Spooky/Baselines/` |
| 你給伺服器上的 Git 存下的使用者名稱與密碼 | 鑰匙圈裡名為 `com.rakuyo.spooky.remote.<host alias>` 的項目 |
| 託管帳號的權杖 | 鑰匙圈裡名為 `com.rakuyo.spooky.hosting.<address>` 的項目 |
| macOS 為 Spooky 的網路請求留下的快取與 Cookie | `~/Library/Caches/com.rakuyo.spooky/`，以及 `~/Library/HTTPStorages/` 裡名稱以 `com.rakuyo.spooky` 開頭的項目 |
| 伺服器儲存庫的連線檔案 | `/tmp/spooky-*` 資料夾，連線關閉時刪除 |
| 用「快速查看」或別的 App 開啟的檔案副本 | 名為 `spooky-files-*` 的暫存資料夾，儲存庫關閉時刪除 |

用使用者名稱與密碼登入自行架設的 GitLab 時，Spooky 存下換來的權杖，不存密碼。

想把這些全刪掉，見 [解除安裝](/guide/start/install/#uninstall)。

在 :ui[app.name > settings.title] › :ui[settings.sshHosts] 裡加入的主機別名儲存在 `~/.ssh/config`，也就是 SSH 自己讀的那個檔案。它不是 Spooky 的檔案，解除安裝 Spooky 不會動它。見 [加入主機別名](/guide/server/prepare-ssh/#alias)。

## 在伺服器上 {#servers}

除了儲存庫本身，Spooky 只在伺服器上寫兩個地方：

- 個人資料夾下的 `~/.spooky/bin/`：Spooky 經 SSH 執行的一個小指令碼，以及詢問與簽署時用的指向它的連結。它會留著，下次連線還用。每次安裝時，Spooky 會刪掉 30 天內沒用過的舊版本。想刪掉的話，刪除這個資料夾。
- `/tmp/spooky-*`：本次連線的檔案，連線關閉時刪除。

Spooky 尋找儲存庫 [在這台 Mac 上的位置](/guide/server/local-location/#automatic) 時，會在儲存庫的 Git 資料夾裡暫時放一個空檔案，核對完馬上刪掉。

伺服器上的 Git 要密碼時，Spooky 從 Mac 經 SSH 連線把回答交給提問的那條 Git 指令，不給別的指令。伺服器上的 Git 不會存下它，因為 Spooky 給自己的指令關掉了 Git 的憑證輔助程式。

## 在儲存庫裡 {#repositories}

Spooky 在儲存庫自己的 Git 設定裡存幾樣東西，寫成 `branch.<name>.spooky-*` 項目：

- 哪些分支釘選了、封存了
- 每個分支的父分支
- 自動封存用的標記

重新命名分支時，這些項目跟著分支走；刪除分支時，它們一起刪掉。在儲存庫的 :ui[repositorySettings.title] 裡改的 Git 設定，例如簽署，也寫進同一份設定，見 [儲存庫設定](/guide/settings/identity/#repository)。

Git 設定不會被推送，所以這些都不會到遠端。伺服器儲存庫的這些內容存在伺服器上。

## 網路連線 {#network}

| Spooky 連到的位址 | 什麼時候 |
|---|---|
| 你的伺服器，經 SSH | 開啟伺服器儲存庫期間。用的是 `~/.ssh/config` 裡的主機別名。SMB 掛載還會連到伺服器的檔案共享。 |
| 儲存庫的 Git 遠端 | 擷取、拉取、推送、複製時，以及自動擷取時。伺服器儲存庫由伺服器上的 Git 去連遠端，不經過 Mac。 |
| `github.com` 與 `api.github.com`，或者你的 GitLab 位址 | 加入或重新認證託管帳號時，以及用到帳號的功能時：Pull Request 與 Merge Request、Issue 編號的自動補全、分支整理裡的狀態、發布儲存庫。這些請求從 Mac 送出，見 [請求送往哪裡](/guide/hosting/accounts/#network)。 |
| `gravatar.com` | 顯示提交作者的大頭貼 |
| `github.com` 上 Spooky 的發布頁 | 檢查更新 |

自動擷取預設每 30 分鐘一次。想改的話，開啟 :ui[app.name > settings.title]，按一下 :ui[settings.general]，在 :ui[settings.autoFetch] 旁邊選一項。選 :ui[settings.autoFetch.never]，就只在你自己操作時擷取。見 [操作](/guide/settings/general/#operations)。

取提交作者的大頭貼時，Gravatar 拿到的是作者電子郵件的雜湊值，不是電子郵件本身。下載過的大頭貼只留在記憶體裡，結束 Spooky 就沒有了。GitHub 與 GitLab 使用者的大頭貼來自這兩個服務。設定裡沒有關掉大頭貼的選項。

Spooky 預設每天檢查一次更新。想停掉的話，在 :ui[app.name > settings.title] › :ui[settings.updates] 裡關掉 :ui[updates.automaticChecks]。見 [保持更新](/guide/start/install/#updates)。

:ui[menu.help] 選單裡的 :ui[help.help]、:ui[help.support] 等項目，會在瀏覽器裡開啟網頁。

## 當機報告 {#crash-reports}

Spooky 上次意外結束的話，會讀取 macOS 存在這台 Mac 上的當機報告。下次啟動時，它會問你：:ui[crash.title]。

- 按一下 :ui[crash.report] 會在瀏覽器裡開啟 GitHub 的新問題頁，裡面填好了當機的摘要。
- 按一下 :ui[crash.dontReport] 就略過。這次當機 Spooky 不會再問。

摘要裡有 Spooky 的版本與版號、macOS 版本、當機的類型，以及當機執行緒最多 30 行的呼叫堆疊。離開 Mac 之前，Spooky 會把你的個人資料夾、使用者名稱、電子郵件、IP 位址、權杖，以及網址裡的密碼換成替代文字。

摘要就在新問題頁的網址裡，頁面一開啟，GitHub 就會收到它。要等你在瀏覽器裡提交，問題才會建出來。提交前可以先改文字，也可以直接關掉頁面。

下次不想再被問，在對話框裡勾選 :ui[settings.crashReports.always]。之後 Spooky 會直接開啟新問題頁。同一個選項也在 :ui[app.name > settings.title] › :ui[settings.integration] 裡。

## 診斷報告 {#diagnostic-reports}

回報問題時，附一份診斷報告能幫忙看清發生了什麼。選 :ui[menu.help > help.diagnosticReport]，再選一個存放位置。Spooky 存下一個純文字檔，並在 Finder 裡顯示它。報告不會被傳送到任何地方。

報告裡有：

- Spooky 的版本與版號、macOS 版本，以及你排在最前面的三種語言
- 這台 Mac 上的 Git 程式與它的版本
- 影響 Spooky 執行方式的設定，例如外觀、更新頻道、終端機程式、Diff 與合併工具、SSH Agent、Git 程式，以及是否向登入 shell 請求環境變數
- 本機儲存庫與伺服器儲存庫各有幾個
- 最近 20 個操作的名稱、時間與結果
- 本次執行最近一小時的 Spooky 日誌，最多 500 行

報告裡沒有儲存庫路徑、主機別名、密碼，也沒有環境變數的值。Spooky 會像處理當機報告一樣，把個人資料夾、使用者名稱、電子郵件、IP 位址與權杖換成替代文字。分享之前，先開啟檔案看一遍。

Spooky 的日誌記的是連線的變化，以及操作的開始、結束與失敗，不記指令的參數與輸出、提交訊息、密碼與權杖。

## 相關頁面

- [安裝 Spooky](/guide/start/install/)
- [伺服器儲存庫如何運作](/guide/server/overview/)
- [託管帳號](/guide/hosting/accounts/)
- [系統需求](/reference/requirements/)

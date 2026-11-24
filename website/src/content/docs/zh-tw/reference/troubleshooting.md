---
title: "疑難排解"
description: "排除常見問題：連不上、Git 版本太舊、權限、伺服器上的 PATH，以及怎樣回報問題。"
---

下面每個問題先寫你會看到什麼，再寫原因與做法。Spooky 的很多錯誤還附著 Git 或 SSH 的原始輸出，往往直接寫明了問題出在哪裡。

## 連不上伺服器 {#connect}

連線出問題時，會出現在這幾個地方之一：

- :ui[remote.form.title] 對話框不關，並寫著該怎麼改。各種情況見 [檢查沒通過時](/guide/server/add/#results)。
- 開啟伺服器儲存庫時顯示 :ui[missing.unreachable.title]{1="driftwood-server"}，見 [連不上的時候](/guide/server/connection/#offline)。
- 已經開啟的伺服器儲存庫裡，列表頂部的橫條變成黃色，並寫出原因，見 [連線狀態](/guide/server/connection/#status)。

先在 Spooky 之外用同樣的方式登入一次。在終端機裡執行這條指令，主機別名換成你自己的：

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

這條指令失敗的話，問題出在 Mac 和伺服器之間。各種輸出的含義見 [按 Spooky 的方式測試](/guide/server/prepare-ssh/#test)。終端機裡能通過，Spooky 卻還是登入不了的話，可能是 Spooky 用的 SSH agent 與終端機不同，見 [SSH agent](/guide/settings/integration/#ssh-agent)。

Spooky 寫出的原因能告訴你該往哪裡查：

| 原因 | 怎麼辦 |
|---|---|
| :ui[remoteError.authentication] | 伺服器不接受你的金鑰，或者 Mac 解不開它。重新啟動 Mac 之後，照 [重新啟動 Mac 之後](/guide/server/prepare-ssh/#after-restart) 重新載入金鑰。只能用密碼登入的帳號用不了。 |
| :ui[remoteError.unknownHostKey] | Mac 還不認識這台伺服器。先在終端機裡連一次，核對指紋，見 [先連一次](/guide/server/prepare-ssh/#fingerprint)。Spooky 從不替你接受指紋。 |
| :ui[remoteError.changedHostKey] | 先別連。和伺服器管理者確認指紋為什麼變了。 |
| :ui[remoteError.unavailable] | 檢查主機別名和網路。每次嘗試失敗後，Spooky 過 5 秒會再試。想馬上重試，按一下橫條裡的 :ui[action.reconnect]。見 [斷線與重新連線](/guide/server/connection/#reconnect)。 |
| :ui[remoteError.deployment] | 伺服器上缺了 Spooky 需要的東西：Unix socket 轉送、`/usr/bin/perl`，或者 `~/.spooky/bin` 與 `/tmp` 的寫入權限。見 [伺服器](/reference/requirements/#servers)。 |

伺服器上的 Git 找不到或者太舊時，接著往下看。

## Git 版本太舊 {#git-version}

Spooky 需要 Git 2.41.0 或以上版本，Mac 上和伺服器上都一樣。

### 在 Mac 上 {#mac-git}

開啟本機儲存庫時，Spooky 可能顯示下面兩種錯誤之一：

- :ui[error.version]，下面附著 Git 的輸出。Spooky 用的 Git 程式低於 2.41.0。在 :ui[app.name > settings.title] › :ui[settings.gitConfig] 的 :ui[settings.gitProgram] 旁邊換一個新一些的，或者更新 Xcode 或 Command Line Tools。
- :ui[error.gitProgram]，下面附著路徑。你選的 Git 程式已經不在了，例如被解除安裝了。在同一個地方換一個。

選單裡只列出版本夠新的 Git 程式，見 [Git 程式](/guide/settings/identity/#git-program)。

### 在伺服器上 {#server-git}

連線失敗，顯示 :ui[remoteError.gitVersion]。把伺服器上的 Git 更新到 2.41.0 或以上版本。

伺服器上已經裝了新版本的話，就是 SSH 登入時先找到了舊的那個。照 [伺服器上找不到 Git](#server-path) 裡的做法，把新版本 Git 所在的資料夾放到 `PATH` 的最前面。

## 伺服器上找不到 Git {#server-path}

連線失敗，顯示 :ui[remoteError.gitUnavailable]。或者在 :ui[app.name > settings.title] › :ui[settings.environment] 裡檢查這台伺服器時，結果是 :ui[settings.environment.server.noGit]。

伺服器上沒裝 Git 的話，裝上 Git 2.41.0 或以上版本。已經裝了的話，原因通常在 `PATH`。Spooky 經 SSH 在伺服器上執行指令，用的不是互動式 shell。這種 shell 讀的啟動檔少一些，你在 `~/.zshrc` 或 `~/.bash_profile` 裡設定的 `PATH` 可能沒有作用。

解決辦法：

1. 在終端機裡登入伺服器，執行 `command -v git`。它會印出 Git 在哪裡，例如 `/opt/homebrew/bin/git`。
2. 與 Spooky 拿到的 `PATH` 對照一下。錯誤的輸出裡列著它，[檢查伺服器](/guide/settings/general/#server-check) 的結果裡也有。
3. 在非互動式 shell 會讀的啟動檔裡，把 Git 所在的資料夾加進 `PATH`。在伺服器上執行 `echo $SHELL`，就能看到你用的是哪種 shell。
   - zsh：`~/.zshenv`
   - bash：`~/.bashrc`，寫在「不是互動式 shell 就提前返回」的那一行之前

   例如：

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. 再按一次 :ui[settings.environment.server.check]，或者執行 [連不上伺服器](#connect) 裡的測試指令。然後重新連線。

伺服器上的 Git LFS，以及掛鉤呼叫的程式，也是按同一個 `PATH` 找的。它們在終端機裡能用、經 Spooky 卻不行的話（例如命令失敗並提示 :ui[hostError.lfsUnavailable]），用同樣的辦法把它們的資料夾加進去。

## 權限問題 {#permissions}

| 看到什麼 | 原因與做法 |
|---|---|
| :ui[remoteError.pathPermission] | 你在伺服器上的使用者打不開、讀不了儲存庫的資料夾。請伺服器管理者給你權限，或者換一個你自己的資料夾。 |
| :ui[remoteError.diskAccess] | 伺服器是一台 Mac，儲存庫放在「文件」這類受 macOS 保護的資料夾裡。照 [用一台 Mac 當伺服器](/guide/server/prepare-ssh/#mac-server) 開啟遠端使用者的完整磁碟取用權限，或者把儲存庫挪個地方。 |
| :ui[error.ownership] | 這台 Mac 上的儲存庫資料夾屬於另一個使用者，Git 拒絕在裡面工作。把資料夾的擁有者改成你自己。信任它的擁有者的話，也可以執行 Git 輸出裡建議的 `git config --global --add safe.directory` 指令。 |
| :ui[error.terminal] | 標題下面的詳細資訊寫著出了什麼問題。常見的是 :ui[settings.terminal] 裡選的終端機已經解除安裝了，或者你沒有允許 Spooky 控制「終端機」或 iTerm。見 [終端機](/guide/settings/integration/#terminal)。 |
| :ui[appIcon.writeFailed] | Spooky 把圖示存進 `Spooky.app`，你的使用者要能寫入它。在 Finder 裡選取 Spooky，選 **檔案 › 取得資訊**，看看 **共享與權限** 裡你是不是 **讀取與寫入**。 |

:::note[伺服器儲存庫]
在伺服器上，資料夾屬於另一個使用者時，連線會失敗並顯示 :ui[remoteError.notWorkingTree]，Git 的輸出裡提到擁有者（ownership）。請伺服器管理者處理，或者在伺服器上執行 `safe.directory` 那條指令。
:::

## 回報問題 {#report}

選 :ui[menu.help > help.support]，開啟 Spooky 在 GitHub 上的問題列表。先在那裡找找有沒有同樣的問題，沒有就新增一個。寫清楚你做了什麼、想要什麼結果、實際發生了什麼。Spooky 顯示過錯誤的話，附上它的標題與原始輸出。

附一份診斷報告能幫忙看清發生了什麼。選 :ui[menu.help > help.diagnosticReport]，再選一個存放位置。Spooky 存下一個純文字檔，並在 Finder 裡顯示它。報告不會被傳送到任何地方。分享之前，先開啟檔案看一遍。報告裡有什麼，見 [診斷報告](/reference/data-privacy/#diagnostic-reports)。

Spooky 上次意外結束的話，下次啟動時會問你：:ui[crash.title]。按一下 :ui[crash.report] 會在瀏覽器裡開啟 GitHub 的新問題頁，裡面填好了當機的摘要。要等你在瀏覽器裡提交，問題才會建出來。見 [當機報告](/reference/data-privacy/#crash-reports)。

## 相關頁面

- [準備 SSH](/guide/server/prepare-ssh/)
- [連線狀態與重新連線](/guide/server/connection/)
- [系統需求](/reference/requirements/)
- [資料與隱私權](/reference/data-privacy/)

---
title: "準備 SSH"
description: "準備 SSH 金鑰與 ~/.ssh/config 裡的主機別名，先在終端機裡連通，再加入伺服器儲存庫。"
---

Spooky 用 SSH 登入伺服器，方式和終端機一樣。它沒辦法替你輸入密碼，所以要有一把 SSH 金鑰。這一頁帶你準備金鑰和伺服器的簡短名稱，再確認終端機能連上、而且什麼都不問。終端機連得上，Spooky 也就連得上。

如果 `ssh` 已經能不輸入密碼登入伺服器，直接跳到 [按 Spooky 的方式測試](#test)。

## 需要準備什麼 {#before}

- 伺服器上一個能用 SSH 登入的帳號。拿不準的話，問問伺服器的管理者。
- 伺服器上裝有 Git 2.41.0 或以上版本。
- Mac 上的 **終端機** App。

這一頁的指令都在終端機裡執行。輸入或貼上一條，按 Return 鍵。

## 看看有沒有金鑰 {#key-check}

SSH 金鑰是一對檔案。私密金鑰留在 Mac 上，公開金鑰以 `.pub` 結尾，要放到伺服器上。

```sh
ls ~/.ssh
```

列表裡有 `id_ed25519` 和 `id_ed25519.pub`，表示已經有金鑰了，跳到 [加入主機別名](#alias)。別的金鑰對也能用，例如 `id_rsa` 和 `id_rsa.pub`，下面的步驟裡把 `id_ed25519` 換成它的名字就行。

看到「No such file or directory」，或者列表裡沒有成對的金鑰，就新增一把。

## 新增金鑰 {#create-key}

```sh
ssh-keygen -t ed25519 -C "alex@example.com"
```

引號裡換成你自己的電子郵件。它只是個標籤，方便你認出這把金鑰。

1. 問儲存在哪裡時，按 Return 鍵，用它建議的位置。
2. 輸入一個密語，再輸入一遍。輸入時螢幕上什麼都不顯示。有人拷貝了金鑰檔案時，密語能保護它。

完成後，`~/.ssh` 裡會有 `id_ed25519` 和 `id_ed25519.pub`。

## 加入主機別名 {#alias}

主機別名是伺服器的簡短名稱。在終端機和 Spooky 裡都用它，代替伺服器的位址和你的使用者名稱。別名儲存在 `~/.ssh/config` 這個檔案裡，在 Spooky 的設定裡加入。

1. 選 :ui[app.name > settings.title] › :ui[settings.sshHosts]。
2. 按一下列表下方的加入按鈕。
3. 填好各項，換成你自己的資訊。
4. 按一下 :ui[sshHosts.create.submit]。

::screenshot[加入主機別名對話框。別名是 driftwood-server，伺服器位址是 203.0.113.10，使用者名稱是 alex，連接埠空著，私密金鑰路徑是 ~/.ssh/id_ed25519。按鈕是「取消」與「加入」。]{name="settings-ssh-hosts-add" frame="dialog"}

| 這一項 | 填什麼 |
|---|---|
| :ui[sshHosts.alias] | 別名。用一個詞，不帶空格、`@`、`:`、`/`、`*` 或 `?`，也不要以 `-` 或 `!` 開頭。 |
| :ui[sshHosts.hostName] | 伺服器的位址或名稱，例如 `203.0.113.10` 或 `server.example.com` |
| :ui[sshHosts.user] | 你在伺服器上的使用者名稱 |
| :ui[sshHosts.port] | 連接埠。伺服器的 SSH 用的不是 22 連接埠時才填 |
| :ui[sshHosts.identityFile] | 上面新增或找到的私密金鑰，例如 `~/.ssh/id_ed25519` |

只有 :ui[sshHosts.alias] 必須填。Spooky 把別名和填了的各項寫進 `~/.ssh/config`：

```
Host driftwood-server
    HostName 203.0.113.10
    User alex
    IdentityFile ~/.ssh/id_ed25519
```

檔案裡有帶萬用字元的項目（例如 `Host *`）或 `Match` 項目時，新的幾行寫在第一個這樣的項目上面，不會被它蓋掉。沒有這樣的項目，就寫在檔案末尾。

### 修改或刪除別名 {#manage-aliases}

:ui[settings.sshHosts] 頁列出 `~/.ssh/config` 裡的別名，用文字編輯器加的也在裡面。

::screenshot[設定視窗的 SSH 主機頁。列表有別名、伺服器位址、使用者名稱、連接埠與私密金鑰路徑五欄，裡面是 staging、backup-nas 與 driftwood-server 三個別名，選取的是 driftwood-server。列表下方有加入與移除按鈕，右邊是「編輯…」按鈕。]{name="settings-ssh-hosts" frame="window"}

- 想修改別名，選取它，按一下 :ui[sshHosts.edit]。Spooky 只改你動過的那幾項對應的行。這台伺服器別的 SSH 選項、別的伺服器和註解都保持原樣。
- 想刪除別名，選取它，按一下列表下方的移除按鈕，再確認。Spooky 刪掉它的 `Host` 行和下面的選項。

帶幾個名稱或萬用字元的項目（例如 `Host *`）不在列表裡，Spooky 也不會更動它們。這些項目用文字編輯器改。

每次回到 Spooky，它都會重新讀一遍這個檔案。對話框開著的時候別的程式改了檔案，Spooky 不會儲存你的修改。列表換成檔案現在的內容，你再改一次。

## 讓 Mac 解鎖金鑰 {#keychain}

Spooky 登入時從不詢問金鑰的密語，得由 Mac 替它解鎖。在 `~/.ssh/config` 裡加兩行，對所有伺服器都管用。金鑰沒有密語的話，跳過這一步。

1. 用文字編輯開啟這個檔案：

   ```sh
   open -e ~/.ssh/config
   ```

2. 在檔案末尾加上這幾行：

   ```
   Host *
       AddKeysToAgent yes
       UseKeychain yes
   ```

3. 儲存檔案，關掉文字編輯。

第一次輸入私鑰密語後，Mac 會把它存進鑰匙圈，之後 SSH 解鎖金鑰時不再詢問。

## 先連一次 {#fingerprint}

第一次連線一台伺服器時，SSH 會請你確認伺服器的指紋。Spooky 從不替你接受指紋，所以這一步要先在終端機裡做。

```sh
ssh driftwood-server
```

1. SSH 顯示伺服器的指紋，也就是以 `SHA256:` 開頭的一串字元，問你要不要繼續。
2. 和伺服器管理者給你的指紋對一下。在伺服器上，這條指令能印出指紋：

   ```sh
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. 對得上，就輸入 `yes`，按 Return 鍵。Mac 會記住這台伺服器，以後不再問。

接下來會怎樣，要看伺服器：

- SSH 問金鑰的密語時，輸入它。Mac 會把密語存進鑰匙圈。
- 已經登入進去了，表示金鑰已經在伺服器上。輸入 `exit` 登出，跳到 [按 Spooky 的方式測試](#test)。
- SSH 問你在伺服器上的密碼時，先按 <kbd>⌃C</kbd> 離開。下一步會把金鑰放到伺服器上。

:::caution
SSH 警告遠端主機的識別變了（remote host identification has changed）時，不要繼續。先問伺服器管理者，伺服器是不是重灌或換過了。
:::

## 把公開金鑰放到伺服器上 {#copy-key}

伺服器能用密碼登入的話，這條指令會把公開金鑰拷貝過去。問密碼時，輸入你在伺服器上的密碼。

```sh
ssh-copy-id -i ~/.ssh/id_ed25519.pub driftwood-server
```

伺服器不接受密碼登入時，把公開金鑰傳給伺服器管理者。這條指令會把公開金鑰拷貝到剪貼簿：

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

請對方把它加進你在伺服器上的個人資料夾裡的 `~/.ssh/authorized_keys`。公開金鑰可以放心給別人。不帶 `.pub` 的那個檔案，絕不要傳出去。

## 按 Spooky 的方式測試 {#test}

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

這條指令的登入方式和 Spooky 一樣，什麼都不問。馬上印出 2.41.0 或更高的版本，例如 `git version 2.47.1`，就算成功了。接著就可以 [加入伺服器儲存庫](/guide/server/add/)。

印出別的內容時：

| 看到什麼 | 怎麼辦 |
|---|---|
| `Permission denied` | 伺服器還不接受你的金鑰，或者 Mac 解不開它。看看 [讓 Mac 解鎖金鑰](#keychain)、[把公開金鑰放到伺服器上](#copy-key) 與 [重新啟動 Mac 之後](#after-restart)。 |
| `Host key verification failed` | Mac 還不認識這台伺服器，見 [先連一次](#fingerprint)。 |
| `Could not resolve hostname`、`Connection refused` 或 `Operation timed out` | 在 :ui[app.name > settings.title] › :ui[settings.sshHosts] 裡檢查這個別名的 :ui[sshHosts.hostName] 與 :ui[sshHosts.port]，確認伺服器開著、連得上。 |
| 含有 `command not found` 的提示 | 伺服器上沒裝 Git，或者 SSH 登入時找不到它。問問伺服器管理者。 |
| 版本低於 2.41.0 | 請伺服器管理者更新 Git。 |

## 重新啟動 Mac 之後 {#after-restart}

測試原來能通過，重新啟動 Mac 後卻回報 `Permission denied` 的話，重新載入金鑰。密語已經存進鑰匙圈的金鑰，用這條指令載入：

```sh
ssh-add --apple-load-keychain
```

## 改用別的 SSH agent {#agent}

SSH agent 替 SSH 保管已經解鎖的金鑰。Spooky 用的是系統的 agent，也就是 macOS 替你啟動的那一個。金鑰放在別的 agent 裡時，例如密碼管理工具附帶的 agent，把 `SSH_AUTH_SOCK` 設成那個 agent 的 socket。可以在 :ui[app.name > settings.title] › :ui[settings.environment] 裡把它加成自訂變數，也可以寫在登入 shell 裡。之後 Spooky 登入伺服器就用這個 agent，見 [SSH agent](/guide/settings/integration/#ssh-agent)。

## 用一台 Mac 當伺服器 {#mac-server}

另一台 Mac 也可以當伺服器。在那台 Mac 上：

1. 選 **蘋果選單 › 系統設定**，按一下 **一般**，再按一下 **共享**。
2. 開啟 **遠端登入**。
3. 儲存庫放在「文件」「桌面」這類受保護的資料夾裡時，按一下 **遠端登入** 旁邊的資訊按鈕，開啟 **允許遠端使用者取用完整磁碟**。

然後回到你自己的 Mac，照這一頁做一遍，:ui[sshHosts.hostName] 填那台 Mac 的位址。

## 相關頁面

- [伺服器儲存庫如何運作](/guide/server/overview/)
- [加入伺服器儲存庫](/guide/server/add/)
- [系統需求](/reference/requirements/#servers)

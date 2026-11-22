---
title: "伺服器儲存庫如何運作"
description: "了解哪些事在伺服器上發生、哪些在本機發生，Spooky 在伺服器上放了什麼，以及伺服器儲存庫與本機儲存庫的差別。"
---

伺服器儲存庫是另一台機器上的 Git 儲存庫，Spooky 經 SSH 開啟它。檔案留在伺服器上，Git 也在那裡執行，不用先複製到 Mac。這一頁講兩邊各做什麼、Spooky 在伺服器上留下了什麼，以及它和這台 Mac 上的儲存庫有哪些不同。

想開始用，先看 [準備 SSH](/guide/server/prepare-ssh/)，再看 [加入伺服器儲存庫](/guide/server/add/)。

## 什麼在哪裡發生 {#where}

Spooky 用 macOS 內建的 SSH 連線伺服器。它用的是 `~/.ssh/config` 檔案裡的主機別名，登入方式和在終端機裡執行 `ssh` 一樣。

在伺服器上：

- Git 執行所有指令，用的是伺服器自己的 Git 與環境。
- Spooky 經 SFTP 讀寫檔案。SFTP 是 SSH 裡傳檔案的那一部分。
- 刪掉的檔案和捨棄的新檔案，會移進伺服器的垃圾桶，前提是伺服器上有垃圾桶。
- 擷取、拉取與推送從伺服器連到 GitHub 這類遠端，用的是伺服器的網路和伺服器上的 SSH 金鑰。

在 Mac 上：

- 你操作的視窗、列表與差異。
- 到伺服器的 SSH 連線。每個開啟的儲存庫有一條自己的連線，所有指令都從這條連線走。
- 伺服器上的 Git 提出的詢問，例如密碼或私鑰密語，見 [密碼與私鑰密語的詢問](/guide/server/connection/#prompts)。
- 向 GitHub 與 GitLab 發出的請求，例如登入帳號、讀取 Pull Request。
- 用快速查看或別的 App 開啟的檔案副本。

:::note
經 SSH 連線的遠端，伺服器上要已經有它的主機金鑰。還沒有的話，先登入伺服器，在那裡連一次這個遠端。
:::

## Spooky 在伺服器上放了什麼 {#on-server}

Spooky 不需要管理者權限，也不安裝常駐服務。它在伺服器上只留下兩樣東西：

- **`~/.spooky/bin/` 裡的一個輔助指令碼**，在你伺服器上的個人資料夾裡。它負責把 Git 的詢問轉回 Mac。Spooky 連線時把它放進去，留給以後的連線用。這個資料夾裡以 `-askpass`、`-gpg` 等結尾的其他名字，都是指向同一個檔案的連結。
- **`/tmp/spooky-*` 裡的暫存檔**，儲存庫開啟期間才有。關閉儲存庫時，Spooky 會刪掉它們。

輔助指令碼用 `/usr/bin/perl` 執行，大多數 macOS 與 Linux 伺服器都內建。完整的需求見 [系統需求](/reference/requirements/#servers)。

`~/.spooky` 隨時可以刪。Spooky 下次連線時會重新放好輔助指令碼。

## 伺服器儲存庫有哪些不同 {#differences}

伺服器儲存庫開啟後，視窗和這台 Mac 上的儲存庫一樣，大多數視圖與指令的用法也相同。從這幾處能看出儲存庫在伺服器上：

::screenshot[一個伺服器儲存庫的視窗。標題是 spooky-test:driftwood，下面是目前的視圖與分支。工具列上顯示主機別名 spooky-test。中間一欄頂部的橫條寫著「spooky-test: 已連線」，下面是提交區與變更的檔案列表。右邊一欄顯示所選檔案的變更。]{name="hero" frame="window" markers="45.8,3.3 64.4,7.2 40,8.9"}

1. 視窗標題以主機別名開頭，例如 `driftwood-server:driftwood`。儲存庫管理視窗裡的名稱也這樣寫。
2. 工具列上的 :ui[toolbar.host] 一項顯示主機別名。
3. 工作區、歷史等列表的頂部顯示連線狀態，見 [連線狀態與重新連線](/guide/server/connection/)。

有些地方用起來不一樣：

| 哪裡 | 伺服器儲存庫裡 |
|---|---|
| 伺服器上的變更 | 儲存庫視窗在最前面時，Spooky 每 2 秒查一次伺服器上的變化，其餘時候每 10 秒查一次。伺服器回得慢時，會查得少一些。 |
| 連線中斷 | 仍然可以檢視 Spooky 上次讀到的內容，但重新連上之前不能做任何變更。 |
| :ui[action.revealFinder] | Finder 要在 Mac 上有一個能看到伺服器檔案的資料夾，見 [本機位置](/guide/server/local-location/)。 |
| :ui[action.openTerminal] | 終端機用 `ssh` 登入伺服器，進入儲存庫所在的資料夾。 |
| :ui[action.copyPath] | 拷貝的路徑以主機別名開頭，例如 `driftwood-server:/srv/git/driftwood`。 |
| 用別的 App 開啟檔案 | 大多數 App 拿到的是檔案副本。儲存後，Spooky 把變更寫回伺服器，見 [終端機與其他 App](/guide/server/local-location/#terminal)。 |
| 捨棄或刪除檔案 | 捨棄變更會覆寫伺服器上的檔案，Spooky 會先確認。刪掉的檔案和捨棄的新檔案移進伺服器的垃圾桶。伺服器上沒有垃圾桶時，Spooky 先確認，再永久刪除。 |
| :ui[settings.environment] 設定 | 只對這台 Mac 上的 Git 有效。伺服器上的 Git 用伺服器自己的環境，見 [環境](/guide/settings/general/#environment)。 |

捨棄變更、永久刪除與回復檔案前的確認，可以在 :ui[app.name > settings.title] › :ui[settings.general] 裡關掉，見 [確認](/guide/settings/general/#confirmations)。

## 相關頁面

- [準備 SSH](/guide/server/prepare-ssh/)
- [加入伺服器儲存庫](/guide/server/add/)
- [系統需求](/reference/requirements/)

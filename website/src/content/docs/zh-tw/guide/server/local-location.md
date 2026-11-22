---
title: "本機位置"
description: "透過自動尋找、SMB 掛載、sshfs 掛載或指定資料夾，給伺服器儲存庫一個本機位置，讓「顯示於 Finder」、終端機與外部編輯器能開啟它。"
---

Finder 只能顯示 Mac 上的資料夾，伺服器儲存庫的檔案卻在伺服器上。要在 Finder 裡看到它們，Spooky 需要 Mac 上有一個能看到伺服器檔案的資料夾，通常是掛載的網路卷宗。這個資料夾就是儲存庫的本機位置。

這一頁講 Spooky 怎樣找到或掛載這個資料夾，以及終端機和別的 App 怎樣開啟伺服器儲存庫。

## 顯示於 Finder {#show-in-finder}

在伺服器儲存庫裡，:ui[action.revealFinder] 一直可以按。它在這些地方：

- :ui[menu.file] 選單
- 工具列上的 :ui[toolbar.finder]。要把它加進工具列，選 :ui[menu.view > menu.customizeToolbar]，把它拖上去。
- 在側邊欄的 :ui[workspace.title] 一列上按右鍵
- [快速操作](/guide/repositories/navigation/#quick-actions)
- 在儲存庫管理視窗裡對伺服器儲存庫按右鍵
- 在工作區裡對檔案按右鍵，Finder 會選取這些檔案。

已經知道本機位置、資料夾也在時，Finder 直接開啟。不然的話，Spooky 會跳出一個面板，按這幾步走：

1. 儲存庫沒連上的話，先連線。
2. 尋找資料夾；方式是 SMB 或 sshfs 時，先掛載。
3. 還是找不到資料夾，面板就換成設定本機位置的表單，頂部寫著原因，見 [設定本機位置](#set)。

按一下 :ui[action.cancel] 關掉面板，設定不會變。

## 設定本機位置 {#set}

1. 在側邊欄的 :ui[workspace.group] 下，按一下 :ui[repositorySettings.title]。
2. 在 :ui[repositorySettings.general] 頁找到 :ui[repositorySettings.localLocation]。這一列寫著方式與資料夾，或者沒有資料夾的原因，例如 :ui[localLocation.notMounted]。
3. 把指標移到這一列上，出現 :ui[localLocation.change] 後按一下它。儲存庫要先連上。
4. 在 :ui[localLocation.title] 對話框裡，從 :ui[localLocation.method] 選一種方式。
5. 掛載的方式按一下 :ui[localLocation.mount]，其餘的方式按一下 :ui[localLocation.save]。

Spooky 掛載或核對資料夾期間，表單不能改。按一下 :ui[action.cancel] 可以停下，原來的設定保持不變。

本機位置按伺服器儲存庫分別存在這台 Mac 上，不會寫進儲存庫，也不會寫到伺服器上。

SMB 或 sshfs 掛載的卷宗被退出後，這一列會出現 :ui[localLocation.mountAgain]，按一下它重新掛載。

## 方式 {#methods}

:ui[localLocation.method] 選單只列出現在能用的方式，目前用的方式總會列出。

### 自動尋找 {#automatic}

預設是 :ui[localLocation.method.automatic]。Spooky 在 Mac 已經掛載的網路卷宗裡找，例如 SMB、NFS、AFP、WebDAV 與 sshfs 卷宗，不管是哪個 App 掛上的。卷宗所在的伺服器和主機別名是同一個位址，才算數。

接著 Spooky 在卷宗裡找儲存庫資料夾。為了確認是同一個儲存庫，Spooky 會在伺服器上儲存庫的 Git 資料夾裡暫時放一個空檔案，看卷宗裡能不能看到它，然後刪掉。

### SMB 掛載 {#smb}

:ui[localLocation.method.smbMount] 用 SMB 掛載伺服器上的共享資料夾。SMB 是 macOS 用來共享檔案的通訊協定。伺服器 2 秒內在 SMB 連接埠上有回應，選單裡才會列出這一項。

1. 選 :ui[localLocation.method.smbMount]，按一下 :ui[localLocation.mount]。
2. macOS 顯示伺服器上的共享資料夾，或者先請你登入。選含有這個儲存庫的那個共享。

Spooky 會記住這個共享，下次直接掛載，不再詢問。選的共享裡沒有這個儲存庫時，表單會寫 :ui[localLocation.notInShare]換一個共享再試。

伺服器是一台 Mac 的話，在那台 Mac 的 **蘋果選單 › 系統設定 › 一般 › 共享** 裡開啟 **檔案共享**。

### sshfs 掛載 {#sshfs}

:ui[localLocation.method.sshfsMount] 經 SSH 掛載儲存庫資料夾，用的是和 Spooky 相同的主機別名。這台 Mac 上要裝有 sshfs，以及 macFUSE 或 FUSE-T。Spooky 會在 `/opt/homebrew/bin`、`/usr/local/bin` 與你的 `PATH` 裡找 `sshfs`。沒裝的話，選單裡不會有這一項。

1. 選 :ui[localLocation.method.sshfsMount]。
2. 按一下 :ui[localLocation.mountAt] 旁邊的 :ui[localLocation.choose]，選 Mac 上的一個空資料夾。伺服器上的檔案會出現在這裡。
3. 按一下 :ui[localLocation.mount]。

### 指定資料夾 {#chosen-folder}

:ui[localLocation.method.chosenFolder] 讓你自己選資料夾，例如你用別的辦法掛上的資料夾。

1. 選 :ui[localLocation.method.chosenFolder]。
2. 按一下 :ui[localLocation.folder] 旁邊的 :ui[localLocation.choose]，選儲存庫資料夾。
3. 按一下 :ui[localLocation.save]。Spooky 會先核對這個資料夾，再儲存。

Spooky 從不退出它掛載的卷宗。之後再開啟這個儲存庫時，Spooky 會在背景重新掛載，什麼都不問。

## 加入時掛載 {#when-adding}

[加入伺服器儲存庫](/guide/server/add/) 時，:ui[remote.mount] 可以順手設好本機位置。它一開始是 :ui[remote.mount.none]。填好主機別名後，能用的話，選單會列出 :ui[remote.mount.smb] 與 :ui[remote.mount.sshfs]。兩個都不能用時，顯示 :ui[remote.mount.unavailable]。

- **SMB**：儲存庫開啟後，macOS 顯示伺服器上的共享資料夾或登入視窗。取消的話，儲存庫照常開啟，儲存庫設定裡的 :ui[repositorySettings.localLocation] 會寫出沒掛上的原因。
- **sshfs**：多出一列 :ui[localLocation.mountAt]，選一個空資料夾。儲存庫開啟後，Spooky 把它掛到那裡。

改了主機別名，選單會回到 :ui[remote.mount.none]。

## 終端機與其他 App {#terminal}

下面這些在伺服器儲存庫裡不需要本機位置也能用：

- **:ui[action.openTerminal]** 開啟 :ui[app.name > settings.title] › :ui[settings.general] 裡選的終端機 App，用 `ssh -t` 和主機別名登入，進入儲存庫資料夾。伺服器不允許終端機的話，Spooky 會不帶終端機再連一次。指令照樣能執行，只是沒有行編輯，也用不了全螢幕程式。它在 :ui[menu.file] 選單裡，也是工具列上的 :ui[toolbar.terminal]；在工作區或儲存庫管理視窗裡的儲存庫上按右鍵也能找到。終端機 App 的選擇見 [終端機](/guide/settings/integration/#terminal)。
- **:ui[action.copyPath]** 拷貝的路徑前面帶著主機別名，例如 `driftwood-server:/srv/git/driftwood`。
- 工作區裡的 **:ui[files.open] 與 :ui[files.openWith]** 用別的 App 開啟檔案。裝了 Remote SSH 延伸模組的 Visual Studio Code、Visual Studio Code Insiders 與 Cursor 會直接開啟伺服器上的檔案。別的 App 拿到的是 Mac 上的副本，儲存後 Spooky 把副本寫回伺服器。

在這期間伺服器上的檔案也被改過的話，Spooky 寫回前會先問你：:ui[externalTool.fileChanged]。按一下 :ui[externalTool.overwrite]，用你的副本取代它。關閉儲存庫時，Spooky 會刪掉這些副本。

快速查看和外部的 Diff 與合併工具，用的也是副本。合併工具完成後，Spooky 把結果寫回伺服器並暫存。

## 相關頁面

- [伺服器儲存庫如何運作](/guide/server/overview/)
- [加入伺服器儲存庫](/guide/server/add/)
- [整合](/guide/settings/integration/)

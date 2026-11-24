---
title: "身分設定檔與 Git 設定"
description: "管理身分設定檔與 Git 設定，以及單一儲存庫的儲存庫設定。"
---

Git 在每個提交裡記下姓名與電子郵件，還可以用金鑰為它簽署。Spooky 有三個地方設定這些：

- :ui[app.name > settings.title] 裡的 :ui[settings.profiles] 存著幾個可以來回切換的身分。
- :ui[app.name > settings.title] 裡的 :ui[settings.gitConfig] 設定 Git 程式，以及全域的身分與簽署。
- 單一儲存庫的設定在這個儲存庫裡覆寫全域的設定。

## 身分設定檔 {#profiles}

身分設定檔是一組姓名、電子郵件與可選的簽署金鑰，存在一個標題下，例如「工作」。設定檔存在這台 Mac 上，本機儲存庫與伺服器儲存庫都能用。

加入設定檔：

1. 選 :ui[app.name > settings.title] › :ui[settings.profiles]。
2. 按一下列表下方的加入按鈕。
3. 填好 :ui[profiles.title]、:ui[profiles.userName] 與 :ui[profiles.email]。也可以從這台 Mac 上找到的金鑰裡選一個 :ui[profiles.signingKey]。
4. 按一下 :ui[profiles.create.submit]。

標題、使用者名稱與電子郵件都必須填。兩個設定檔的標題不能相同，使用者名稱與電子郵件也不能同時相同。

想修改設定檔，選取它，按一下 :ui[profiles.edit]。想刪除，選取它，按一下移除按鈕。刪除設定檔不會變更任何 Git 設定。

正在用的身分還不是設定檔時，從它的選單裡選 :ui[profiles.addCurrent]{1="alex@example.com"}，填一個標題，按一下 :ui[profiles.add.submit]。

### 使用設定檔 {#use-profile}

按一下身分旁邊的大頭貼，就能看到你的設定檔，正在用的那個前面有勾號。選一個設定檔會變更什麼，要看在哪裡選：

| 在哪裡選 | 變更什麼 | 先問嗎 |
|---|---|---|
| 提交區，或 [儲存庫設定](#repository) 裡的 :ui[bookmarks.detail.identity] | 這個儲存庫自己的 Git 設定。見 [選擇提交者](/guide/work/commit/#identity)。 | 先問 |
| 設定裡的 :ui[settings.gitConfig] | 這台 Mac 上全域的 Git 設定 | 不問 |

設定檔裡的姓名與電子郵件寫進 `user.name` 與 `user.email`。帶簽署金鑰的設定檔還會設定 `user.signingkey` 與 `gpg.format`。

[快速操作](/guide/repositories/navigation/#quick-actions) 裡也列出了你的設定檔。:ui[quickActions.setCommitter] 的效果與提交區相同。:ui[quickActions.setGlobalUser] 先問，再把姓名與電子郵件寫進儲存庫所在機器上全域的 Git 設定。

:::note[伺服器儲存庫]
替伺服器儲存庫選設定檔，變更的是伺服器上這個儲存庫的設定。在那裡提交的其他工具也會用這個身分。在伺服器儲存庫裡執行 :ui[quickActions.setGlobalUser]，寫的是你在伺服器上的全域設定。
:::

## Git 設定 {#git-config}

:ui[settings.gitConfig] 頁分四部分：Git 程式、身分、簽署與外部工具。外部工具見 [整合](/guide/settings/integration/#diff-merge-tools)。

::screenshot[設定視窗的 Git 設定頁，有 Git 程式、全域的姓名與電子郵件、簽署設定，以及比較與合併工具。]{name="settings-git-config" frame="window" markers="20,16.8 20,29.8 20,44.6 20,82.5"}

1. Git 程式
2. 身分
3. 簽署
4. 外部工具

### Git 程式 {#git-program}

:ui[settings.gitProgram] 列出這台 Mac 上版本夠新的 Git 程式及其版本。Spooky 會在常見的位置找：`/usr/bin/git`（標為系統的那個，起初用它）、Command Line Tools、Xcode、Homebrew 與 MacPorts。

想用沒列出來的 Git，選 :ui[settings.gitProgram.choose]，再選取那個程式。如果它不是 Git，或者版本太舊，Spooky 會說明原因，仍用原來那個。選單下面一行寫著 Spooky 接受的最低版本。

:::note[伺服器儲存庫]
這項設定只作用於本機儲存庫。伺服器儲存庫用伺服器上的 Git，見 [系統需求](/reference/requirements/#servers)。
:::

### 全域身分 {#global-identity}

:ui[gitConfig.userName] 與 :ui[gitConfig.email] 就是 Git 全域的 `user.name` 與 `user.email`。這台 Mac 上的儲存庫沒有自己的身分時，都用它們。

按 <kbd>Return</kbd> 或離開輸入框時儲存。清空輸入框就刪掉這項設定。下面一行寫著它們存在哪個檔案裡，通常是 `~/.gitconfig`。

按一下右邊的大頭貼，可以選用 [設定檔](#use-profile) 或管理設定檔。

### 簽署 {#signing}

這台 Mac 上的儲存庫沒有自己的簽署設定時，Git 按這裡的設定為提交簽署。

| 設定 | 作用 |
|---|---|
| :ui[gitConfig.sshProgram] | 用 SSH 金鑰簽署的程式。起初用 :ui[gitConfig.sshProgram.system]。裝了 1Password 時，也會列出它的簽署程式。 |
| :ui[gitConfig.gpgProgram] | 用於 OpenPGP 金鑰的 GnuPG 程式。列出這台 Mac 上版本夠新的幾個。選 :ui[gitConfig.gpgProgram.select] 可以換成別的。 |
| :ui[gitConfig.signingKey] | 用哪把金鑰簽署：GnuPG 金鑰圈裡的私密金鑰，或 SSH agent 裡載入的金鑰。選好金鑰後，Git 也就知道該用 OpenPGP 還是 SSH 簽署。 |
| :ui[gitConfig.allowedSigners] | 列出你信任哪些 SSH 簽署的檔案，Git 核對簽署時用。可以選 `~/.ssh/allowed_signers`，選別的檔案，或者選 :ui[gitConfig.allowedSigners.none]。 |
| :ui[gitConfig.signCommits] | 每個提交都簽署 |
| :ui[gitConfig.ensureEmailMatch] | OpenPGP 金鑰的電子郵件與全域電子郵件不同時提示。起初是開啟的。 |

有需要留意的問題時，例如簽署程式無法執行，設定旁邊會出現黃色的警告按鈕。按一下它可以看到問題出在哪裡。

簽署過的提交與私鑰密語的詢問，見 [為提交簽署](/guide/work/commit/#signing)。

## 儲存庫設定 {#repository}

每個儲存庫都有自己的設定。按一下側邊欄 :ui[workspace.group] 下的 :ui[repositorySettings.title] 就能看到。頂部的按鈕在四個部分之間切換。

變更寫進這個儲存庫自己的 Git 設定，與這個儲存庫的其他操作一起排隊執行。儲存庫沒有設定的項目，沿用全域的設定。

::screenshot[主視窗裡的儲存庫設定，停在一般分段，有儲存庫的名稱、路徑、描述、身分與簽署設定。]{name="settings-repository" frame="window" markers="78.4,9.8 60,38.8"}

1. 切換各部分的按鈕
2. :ui[bookmarks.detail.identity]

### 一般 {#repository-general}

| 項目 | 顯示什麼 |
|---|---|
| :ui[repositorySettings.name] 與 :ui[repositorySettings.path] | 儲存庫在哪裡 |
| :ui[repositorySettings.localLocation] | 伺服器儲存庫的資料夾在這台 Mac 上的位置。見 [設定位置](/guide/server/local-location/#set)。 |
| :ui[bookmarks.detail.description] | 儲存庫的描述，[儲存庫管理視窗](/guide/repositories/manager/) 裡也會顯示。按一下 :ui[bookmarks.detail.edit] 修改。 |
| :ui[bookmarks.detail.identity] | 這個儲存庫提交時用的姓名與電子郵件。按一下大頭貼選用 [設定檔](#use-profile)，或者按一下 :ui[bookmarks.detail.edit]，輸入只給這個儲存庫用的姓名與電子郵件。 |

:ui[repositorySettings.signing] 一組裡的 :ui[repositorySettings.signCommits]、:ui[repositorySettings.signingKey] 與 :ui[repositorySettings.allowedSigners]，作用與 [全域的設定](#signing) 相同，只是只管這個儲存庫。

### Git LFS、忽略與排除 {#repository-files}

- :ui[repositorySettings.lfs] 顯示 Git LFS 的版本與 :ui[repositorySettings.lfs.patterns]。見 [Git LFS](/guide/advanced/lfs/)。
- :ui[repositorySettings.ignores] 列出儲存庫最上層 `.gitignore` 裡的規則。提交這個檔案，就能把規則分享給別人。
- :ui[repositorySettings.excludes] 列出 Git 的 `info/exclude` 裡的規則。它們只對這一份儲存庫生效。

想修改規則，按一下 :ui[repositorySettings.openInEditor]。檔案會用這台 Mac 上開啟它的預設 App 開啟。檔案還不存在時，Spooky 先建一個。

:::note[伺服器儲存庫]
這些設定在伺服器上讀寫，只有連著的時候才能修改。:ui[repositorySettings.openInEditor] 開啟檔案的方式，與工作區開啟伺服器上的檔案相同，見 [終端機與其他 App](/guide/server/local-location/#terminal)。
:::

## 相關頁面

- [提交變更](/guide/work/commit/)
- [一般、更新與環境](/guide/settings/general/)
- [整合](/guide/settings/integration/)
- [系統需求](/reference/requirements/)

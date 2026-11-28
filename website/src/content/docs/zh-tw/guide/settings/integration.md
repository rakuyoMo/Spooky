---
title: "整合"
description: "選擇外部比較與合併工具、編輯器和終端機，設定與 Finder 的整合。"
---

Spooky 能與 Mac 上的其他 App 搭配：瀏覽器、比較與合併 App、編輯器、終端機，以及 Finder。這一頁說明各自在哪裡設定。

## 整合頁 {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration] 裡有四項設定。

### 來自 github.com 的連結 {#github-links}

在 github.com 上，儲存庫頁面裡那個用桌面 App 開啟儲存庫的按鈕，會給你的 Mac 傳一個連結。:ui[settings.github] 決定由哪個 App 接收它。選單裡列出這台 Mac 上能開啟這種連結的 App。

選 Spooky，這些連結就會開啟複製對話框。見 [複製儲存庫](/guide/repositories/navigation/#link-clone)。

### SSH agent {#ssh-agent}

SSH agent 存著已經解鎖的金鑰。Spooky 經 SSH 登入伺服器和遠端、用 SSH 金鑰為提交簽署時，都用它。

:ui[settings.sshAgent] 只有一個選項：:ui[settings.sshAgent.system]。Spooky 按下面的順序找它：

1. :ui[settings.environment] 頁裡你自己加的 `SSH_AUTH_SOCK`（見 [本機的變數](/guide/settings/general/#local-variables)）
2. 從登入 shell 讀到的 `SSH_AUTH_SOCK`，前提是那裡開啟了讀取
3. macOS 替你啟動的 agent

想用別的 agent，例如密碼管理工具附帶的那個，就在 :ui[settings.environment] 頁或登入 shell 裡設定 `SSH_AUTH_SOCK`。

agent 沒在執行時，選單旁邊會出現黃色的警告按鈕。按一下它可以看到該怎麼辦。

:::note[伺服器儲存庫]
Spooky 從不把你的 agent 轉送到伺服器。伺服器上的 Git 用那台機器自己的 agent 與金鑰。
:::

### 當機報告 {#crash-reports}

Spooky 上次意外結束時，下次啟動會問要不要回報這次當機。勾選 :ui[settings.crashReports.always]，就不再問，直接開啟問題頁。起初是關閉的。

報告裡有什麼，見 [當機報告](/reference/data-privacy/#crash-reports)。

### 工具列按鈕 {#toolbar-buttons}

工具列按鈕按一下就執行你自己寫的腳本。:ui[toolbarButtons.title] 列出你建立的按鈕。

- 想建立一個，按一下加入按鈕，選個圖示，取個名稱，再寫上腳本。
- 想修改一個，按兩下它，或選取它再按一下 :ui[toolbarButtons.edit]。
- 想刪除一個，選取它再按一下移除按鈕。每個視窗的工具列裡都不會再有它。

想把按鈕放進工具列，選 :ui[menu.view > menu.customizeToolbar]，把它拖到想放的位置。名稱太長時，工具列只顯示前面一段，末尾加上 “…”。把指標停在按鈕上，可以看到完整的名稱。

按一下按鈕時：

- 腳本在這台 Mac 上執行，工作目錄是儲存庫資料夾。
- 腳本交給 zsh 執行。第一行以 `#!` 開頭時，改由這一行選程式，例如 `#!/usr/bin/env python3`。想執行現有的腳本檔，就寫一條執行它的指令，例如 `sh ~/bin/deploy.sh`。
- 腳本拿到的變數與本機的 Git 相同，見 [本機的變數](/guide/settings/general/#local-variables)。
- 成功時什麼也不顯示。失敗時，Spooky 會顯示腳本的輸出與結束狀態。

腳本還會拿到下面這些描述儲存庫的變數。沒有值的變數不設定。

| 變數 | 值 |
|---|---|
| `SPOOKY_REPOSITORY_PATH` | 儲存庫資料夾。伺服器儲存庫是它在伺服器上的路徑。 |
| `SPOOKY_REPOSITORY_NAME` | 這個資料夾的名稱 |
| `SPOOKY_SSH_HOST` | 伺服器儲存庫的主機別名 |
| `SPOOKY_BRANCH` | 目前的分支。HEAD 分離時不設定。 |
| `SPOOKY_HEAD` | HEAD 指向的提交的完整雜湊 |
| `SPOOKY_UPSTREAM` | 目前分支的上游，例如 `origin/main` |
| `SPOOKY_REMOTE` | 上游所在的遠端。沒有遠端上的上游時是 `origin`。 |
| `SPOOKY_REMOTE_URL` | 這個遠端的擷取位址 |

:::note[伺服器儲存庫]
腳本同樣在這台 Mac 上執行，工作目錄是個人資料夾。想在伺服器上執行指令，就用 ssh 加上上面的變數。例如：

```sh
ssh "$SPOOKY_SSH_HOST" "cd '$SPOOKY_REPOSITORY_PATH' && make deploy"
```
:::

## 比較與合併工具 {#diff-merge-tools}

這些工具在 :ui[settings.gitConfig] 頁設定。

| 設定 | 作用 |
|---|---|
| :ui[externalTool.diffTool] | 用來比較檔案的 App。起初是 :ui[externalTool.noneSelected]。 |
| :ui[externalTool.directoryDiff] | 比較多個檔案時，在一個視窗裡把它們當作兩個資料夾開啟。只有 Kaleidoscope 支援。別的 App 一次開啟一個檔案。起初是開啟的。 |
| :ui[externalTool.mergeTool] | 用來解決衝突的 App。起初是 :ui[externalTool.noneSelected]。 |
| :ui[externalTool.keepBackups] | 在檔案旁邊留一份合併前的樣子，檔名末尾加 `.orig`。起初是關閉的。 |

Spooky 支援這些 App：

| App | 比較 | 合併 |
|---|---|---|
| Araxis Merge | 支援 | 支援 |
| BBEdit | 支援 | 不支援 |
| Beyond Compare | 支援 | 支援 |
| DeltaWalker | 支援 | 支援 |
| FileMerge | 支援 | 支援 |
| Kaleidoscope | 支援 | 支援 |
| P4Merge | 支援 | 支援 |
| TextMate | 支援 | 不支援 |
| Visual Studio Code | 支援 | 支援 |

選單裡也會列出沒安裝的 App，但選不了。還沒選工具就用到它時，Spooky 會問用哪個 App。

怎樣使用，見 [在其他 App 裡比較](/guide/work/diff/#external) 與 [在其他 App 裡合併](/guide/work/conflicts/#merge-tool)。

## 編輯器 {#editors}

Spooky 沒有單獨的編輯器設定。想用別的 App 開啟檔案，在工作區裡對它按右鍵，選 :ui[files.open] 或 :ui[files.openWith]。:ui[files.openWith] 子選單列出能開啟這個檔案的 App，預設的那個排在最前。提交的檔案樹與衝突精靈裡也有同樣的子選單。

在伺服器儲存庫裡，Visual Studio Code、Visual Studio Code Insiders 與 Cursor 裝了 Remote SSH 延伸模組時，會直接開啟伺服器上的檔案。別的 App 拿到的是一份副本，儲存時 Spooky 把變更寫回伺服器。見 [終端機與其他 App](/guide/server/local-location/#terminal)。

## 終端機 {#terminal}

:ui[settings.general] 頁的 :ui[settings.terminal] 決定 :ui[action.openTerminal] 用哪個 App。Spooky 支援 Terminal、iTerm、Warp、Ghostty、WezTerm 與 Otty，選單裡只列出已安裝的。起初用 Terminal。

這些地方有 :ui[action.openTerminal]：

- :ui[menu.file] 選單
- 工具列裡的 :ui[toolbar.terminal]
- 側邊欄裡工作區的選單
- 工作區檔案列表裡檔案或資料夾的選單。終端機開啟在那個資料夾，或者檔案所在的資料夾。
- 儲存庫管理視窗裡儲存庫的選單，以及最近複製的選單
- 側邊欄裡工作樹的選單
- [快速操作](/guide/repositories/navigation/#quick-actions)

本機儲存庫的終端機開啟在這台 Mac 上的資料夾裡。伺服器儲存庫則經 SSH 登入，進入伺服器上的資料夾。見 [終端機與其他 App](/guide/server/local-location/#terminal)。

Spooky 第一次開啟 Terminal 或 iTerm 時，macOS 會問是否允許 Spooky 控制它。不允許的話，Spooky 會顯示 :ui[error.terminal]。之後想允許，選 **蘋果選單 › 系統設定 › 隱私權與安全性 › 自動化**，在 Spooky 下面開啟那個 App。

## Finder {#finder}

- **顯示資料夾**：:ui[action.revealFinder] 在 Finder 裡顯示儲存庫資料夾或檔案。伺服器儲存庫需要有在這台 Mac 上的位置，見 [顯示於 Finder](/guide/server/local-location/#show-in-finder)。
- **加入儲存庫**：把儲存庫資料夾從 Finder 拖進儲存庫管理視窗。見 [加入儲存庫](/guide/repositories/manager/#add)。
- **Dock**：把資料夾拖到 Spooky 的圖示上，開啟它所在的儲存庫。在圖示上按右鍵，可以選一個最近的儲存庫，伺服器儲存庫也在裡面。見 [最近的儲存庫與 Dock](/guide/repositories/navigation/#recent)。
- **主題**：在 Finder 裡開啟 `.spookytheme` 檔案，就能加入主題。見 [分享主題](/guide/settings/appearance/#share-themes)。

## 相關頁面

- [一般、更新與環境](/guide/settings/general/)
- [身分設定檔與 Git 設定](/guide/settings/identity/)
- [在這台 Mac 上的位置](/guide/server/local-location/)
- [準備 SSH](/guide/server/prepare-ssh/)

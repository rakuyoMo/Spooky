---
title: "使用手冊"
description: "了解這份手冊怎樣編排、從哪裡開始讀。"
---

這份手冊說明怎樣在 Spooky 裡做日常的 Git 工作。儲存庫可以在這台 Mac 上，也可以留在另一台機器上、經 SSH 存取。每頁講一類任務，開頭先說這頁能幫你做什麼。

第一次用 Spooky，按順序讀「開始使用」的幾頁。儲存庫放在伺服器上的，接著讀「伺服器儲存庫」。

在 Spooky 裡選 :ui[menu.help > help.help]（<kbd>⌘?</kbd>）會開啟這個網站。很多對話框裡還有輔助說明按鈕，按一下它會開啟手冊裡講這個對話框的那一節。

## 手冊的結構 {#organization}

| 分組 | 內容 |
|---|---|
| [開始使用](/guide/start/install/) | 安裝與更新 Spooky，認識視窗的各個部分，完成第一次提交與推送 |
| [管理儲存庫](/guide/repositories/manager/) | 管理你的儲存庫，視窗與標籤頁，上一頁與下一頁，快速操作 |
| [伺服器儲存庫](/guide/server/overview/) | Spooky 怎樣處理伺服器上的儲存庫，準備 SSH，加入伺服器儲存庫，連線，本機位置 |
| [日常工作](/guide/work/working-copy/) | 工作區，檢視與暫存變更，提交，儲藏，衝突，還原 |
| [歷史](/guide/history/browse/) | 瀏覽歷史，提交詳細資訊，檔案歷史與 Blame，改寫歷史 |
| [分支與同步](/guide/branches/branches/) | 分支，標籤與遠端，擷取、拉取與推送，合併與重定基底，整理分支 |
| [協作](/guide/hosting/accounts/) | 託管帳號，Pull Request 與 Merge Request |
| [更多儲存庫功能](/guide/advanced/submodules/) | 子模組，工作樹，Git LFS，操作怎樣排隊 |
| [設定與整合](/guide/settings/general/) | 設定，外觀與主題，身分設定檔與 Git 設定，與其他 App 搭配 |
| [參考](/reference/shortcuts/) | 鍵盤快速鍵，系統需求，資料與隱私權，常見問題與排解 |

## 慣例 {#conventions}

### 介面上的名稱 {#names}

按鈕、選單、選項與視窗的名稱用粗體，例如 :ui[working.commit]。這些名稱直接取自 Spooky。Spooky 用這一頁的語言執行時，你在螢幕上看到的就是這些字。

:ui[menu.file > action.openLocal] 這樣的選單路徑，意思是先按選單列裡的第一個名稱，再在展開的選單裡選下一個。

少數幾頁還會提到 macOS 的介面，例如 **系統設定**。這些名稱照 macOS 顯示的寫。

### 鍵盤快速鍵 {#shortcuts}

快速鍵寫成鍵帽的樣子，例如 <kbd>⇧⌘A</kbd>。按住前面的變更鍵，再按最後一個鍵。符號和 macOS 選單裡顯示的一樣。

| 符號 | 按鍵 |
|---|---|
| <kbd>⌘</kbd> | Command |
| <kbd>⇧</kbd> | Shift |
| <kbd>⌥</kbd> | Option |
| <kbd>⌃</kbd> | Control |
| <kbd>↩</kbd> | Return |
| <kbd>⌫</kbd> | Delete |

全部快速鍵列在 [鍵盤快速鍵](/reference/shortcuts/) 裡。

### 關於伺服器儲存庫的提示 {#server-notes}

伺服器儲存庫留在另一台機器上，Spooky 經 SSH 開啟它。大多數操作在那裡的做法一樣。有不同的地方，頁面會用下面這樣的提示框寫出來：

:::note[伺服器儲存庫]
標題是「伺服器儲存庫」的提示框，寫的是伺服器儲存庫裡有什麼不同。只用這台 Mac 上的儲存庫，可以略過這些提示框。
:::

## 相關頁面

- [安裝 Spooky](/guide/start/install/)
- [介面導覽](/guide/start/tour/)
- [伺服器儲存庫如何運作](/guide/server/overview/)

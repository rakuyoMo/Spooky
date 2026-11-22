---
title: "連線狀態與重新連線"
description: "了解連線狀態、密碼與私鑰密語的詢問、斷線與重新連線，以及連不上時仍能看到什麼。"
---

伺服器儲存庫離不開它的 SSH 連線。這一頁講怎樣看出連沒連上、伺服器提出的詢問是什麼意思，以及斷線之後會怎樣。

## 連線狀態 {#status}

在伺服器儲存庫裡，每個列表的頂部都有一個橫條，寫著主機別名與連線狀態。工作區、歷史、儲藏、Reflog、檔案歷史，以及提交的檔案列表裡都有。

| 狀態 | 意思 |
|---|---|
| :ui[connection.connecting] | Spooky 正在建立連線。 |
| :ui[connection.connected] | 連線正常。 |
| :ui[connection.reconnecting] | 連線斷了，Spooky 正在重試。 |
| :ui[connection.unavailable] | 上一次嘗試失敗了，5 秒後 Spooky 會再試。 |

沒連上的時候，橫條變成黃色，還會多出幾樣：

- 一行說明：正在顯示上次成功讀取的狀態，連線恢復前不能寫入。
- 原因，例如 :ui[remoteError.unavailable]。按一下它可以看到 SSH 的原始輸出。
- 狀態是 :ui[connection.unavailable] 時，還有一個 :ui[action.reconnect] 按鈕。

::screenshot[一個連線中斷的伺服器儲存庫，工作區頂部的特寫。橫條寫著「spooky-test: 無法使用」，旁邊是「重新連線」按鈕。下面的說明寫著正在顯示上次成功讀取的狀態、連線恢復前禁止寫入，再下面是收合起來的「伺服器連線無法使用」。]{name="server-unavailable" frame="closeup"}

## 密碼與私鑰密語的詢問 {#prompts}

Spooky 登入伺服器時什麼都不問。不過伺服器上的 Git 有時要你回答，例如經 HTTPS 推送到遠端時要密碼。Spooky 把詢問轉到 Mac 上，用對話框問你：

| 對話框 | 什麼時候出現 |
|---|---|
| :ui[callback.username.title]、:ui[callback.password.title] | 遠端要知道你是誰，經 HTTPS 連線的遠端常會這樣。 |
| :ui[callback.privateKey.title] | 伺服器連遠端用的 SSH 金鑰設了密語。 |
| :ui[signing.unlock] | 替提交或標籤簽署時，Git 要伺服器上簽署金鑰的密語。 |
| :ui[callback.editor] | Git 要你編輯一段文字，例如一則說明。 |

對話框的第一行寫著是哪台伺服器。問私鑰密語時，下一行是私密金鑰在伺服器上的路徑。

問使用者名稱或密碼時，勾選 :ui[callback.saveKeychain] 就能把回答存下來。下次這台伺服器上的 Git 再問，Spooky 直接用鑰匙圈裡的回答。加入過 GitHub 或 GitLab 帳號的話，Spooky 先用帳號來回答，見 [託管帳號](/guide/hosting/accounts/)。

還有幾點：

- 每個對話框等 2 分鐘。到時沒回答，Git 拿不到答案，指令就會失敗。
- 自動擷取從不詢問。它只用帳號與鑰匙圈裡存過的回答，不夠用時就取消。
- 伺服器上的 Git 要詢問私鑰密語，伺服器的 OpenSSH 要 8.4 或以上版本。

## 斷線與重新連線 {#reconnect}

連線斷了，Spooky 會自己重新連線。每次嘗試失敗後，狀態顯示 :ui[connection.unavailable]，過 5 秒再試。想馬上重試，按一下 :ui[action.reconnect]。連上之後，Spooky 會重新讀取整個儲存庫。

斷線之後，你做過的操作不會被重複執行：

- 儲存庫佇列裡還在等待的操作會被取消，重新連線後不會執行。還需要的話，重新發起。
- 斷線時正在執行的操作不會重試。重新連上後，Spooky 會核對分支、變更的數量、暫存區鎖定，以及有沒有進行中的合併或變基。

核對的結果顯示在 :ui[recovery.title] 對話框裡，寫著操作到底有沒有開始、目前的提交有沒有變。看過結果，再決定要不要重試。

## 連不上的時候 {#offline}

Spooky 上次讀到的內容仍然可以看：各個列表、選取的檔案和它的變更。所有會變更儲存庫的操作都不能用，等連線恢復才行。

開啟儲存庫時連不上伺服器，視窗會顯示 :ui[missing.unreachable.title]{1="driftwood-server"}，附上 SSH 的輸出。按一下 :ui[action.refresh] 再試一次，或者按一下 :ui[action.close] 回到儲存庫管理視窗。

:::tip
在終端機裡執行 `ssh -o BatchMode=yes driftwood-server git --version`，主機別名換成你自己的。這條指令失敗的話，問題出在 Mac 和伺服器之間，不在 Spooky，見 [按 Spooky 的方式測試](/guide/server/prepare-ssh/#test)。
:::

## 相關頁面

- [準備 SSH](/guide/server/prepare-ssh/)
- [加入伺服器儲存庫](/guide/server/add/)
- [伺服器儲存庫如何運作](/guide/server/overview/)

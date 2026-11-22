---
title: "託管帳號"
description: "連接 GitHub、GitLab.com 與自行架設的 GitLab 帳號，了解權杖存在哪裡、用在哪裡。"
---

加入 GitHub 或 GitLab 帳號之後，就能在 Spooky 裡處理 Pull Request 和 Merge Request。Git 存取這個服務上的 HTTPS 遠端時也用這個帳號登入，不再問你使用者名稱和密碼。

## 加入帳號 {#add}

開啟 :ui[app.name > settings.title]，按一下 :ui[settings.accounts]。按一下列表下方的加入按鈕，選帳號所在的地方：

| 選擇 | 用於 | 登入方式 |
|---|---|---|
| :ui[accounts.add.github] | github.com | 在瀏覽器裡授權，或個人存取權杖 |
| :ui[accounts.add.gitlab] | GitLab.com | 個人存取權杖 |
| :ui[accounts.add.gitlabSelfManaged] | 你自己伺服器上的 GitLab | 個人存取權杖，或使用者名稱與密碼 |

::screenshot[加入自行架設 GitLab 帳號的對話框。主機位址是 https://gitlab.example.com，認證方式是使用者名稱與密碼。]{name="hosting-add-account" frame="dialog" markers="79.2,57.4 83.3,48.2"}

1. 主機位址
2. 認證方式

Spooky 驗證帳號時，對話框底部寫著 :ui[accounts.validating]。按一下 :ui[action.cancel] 會停止驗證，對話框留著，方便你改填的內容。驗證失敗時會跳出提示說明原因，填過的內容都還在。

加入好的帳號列在表格裡，寫著服務、實例和使用者名稱。同一個服務上可以加入多個帳號。

### GitHub {#github}

:ui[accounts.authentication] 選 :ui[accounts.authentication.oauth] 時，按一下 :ui[accounts.add.submit]：

1. Spooky 顯示一個一次性驗證碼，把它拷貝好，並在瀏覽器裡開啟 GitHub。
2. 在網頁上貼上驗證碼，授權 Spooky。中途拷貝過別的東西的話，按一下 :ui[accounts.copyCode] 再拷貝一次。
3. 授權之後，對話框關閉，帳號出現在列表裡。

驗證碼過期，或者你在瀏覽器裡拒絕了授權，就重新開始，拿一個新的驗證碼。

想改用權杖，在 :ui[accounts.authentication] 裡選 :ui[accounts.authentication.token]。權杖需要 `repo` 和 `read:org` 兩個權限範圍。

### GitLab.com {#gitlab-com}

貼上一個帶 `api` 權限範圍的個人存取權杖。

### 自行架設的 GitLab {#self-managed}

在 :ui[accounts.host] 裡填 GitLab 伺服器的位址，有連接埠和路徑的一起寫上，例如 `https://example.com:8443/gitlab`。然後選登入方式：

- :ui[accounts.authentication.token]：帶 `api` 權限範圍的權杖。
- :ui[accounts.authentication.password]：Spooky 只用密碼換一個權杖，不儲存密碼。

使用者名稱與密碼只有在下面幾條都滿足時才能登入：

- 伺服器上是 GitLab 18.11 或更早的版本。GitLab 19.0 起不再用密碼換權杖。
- 伺服器不要求 OAuth 應用程式憑證。GitLab 13.9 一定要求，GitLab 17.8 起可以設定成要求。
- 伺服器允許用密碼經 HTTPS 存取 Git。
- 你的帳號有 GitLab 或 LDAP 密碼，沒有開啟雙重驗證，也不是只能經單一登入登入。

這樣換來的權杖會過期，Spooky 會自己續期。GitLab 不再給續期時，帳號會被標成需要重新認證。

Spooky 需要 GitLab 9.0 或更新的版本。伺服器要能從你的 Mac 連上，它的憑證也要受這台 Mac 信任；不受信任時，在 **鑰匙圈存取** 裡信任這個憑證。

## 管理帳號 {#manage}

所有視窗共用同一組帳號。在 :ui[app.name > settings.title] › :ui[settings.accounts] 裡：

- 想重新認證帳號，選取它，按一下列表下方的 :ui[accounts.reauthenticate]，重新登入或填一個新權杖。必須還是同一個使用者；想用別的使用者登入，就加入一個新帳號。
- 想移除帳號，選取它，按一下列表下方的移除按鈕並確認。Spooky 會把它的權杖從鑰匙圈裡刪掉。

標著 :ui[accounts.needsReauthentication] 的帳號，權杖已經不被服務接受，例如過期了或被撤銷了。重新認證之後才能接著用。

變更馬上生效。開啟著的 Pull Request 或 Merge Request 列表會重新讀取，不用重開視窗。

## 帳號用在哪裡 {#uses}

帳號作用於它所在服務上的遠端：

- [Pull Request 與 Merge Request](/guide/hosting/pull-requests/) 列表
- 提交訊息裡 `#` 後面的 Issue 編號，見 [自動補全](/guide/work/commit/#autocomplete)。
- [分支整理](/guide/branches/review/) 裡 Pull Request 和 Merge Request 的狀態
- 把儲存庫 [發布](#publish) 到這個服務上
- [登入 HTTPS 遠端](#git)

## 遠端用哪個帳號 {#remotes}

Spooky 拿每個遠端的位址和每個帳號的實例對照：github.com、GitLab.com，或者你自己的 GitLab 伺服器。

- **這個實例上有一個帳號**：就用它。
- **這個實例上有幾個帳號**：Pull Request 列表會請你選一個。Spooky 會為這個遠端記住你的選擇。
- **還沒有帳號**：遠端在 github.com 或 GitLab.com 上時，列表會說明，並提供 :ui[pullRequests.openAccounts]。
- **位址對不上**：例如遠端寫的是 `~/.ssh/config` 裡的主機別名。列表頂部會出現說明和 :ui[pullRequests.associate]。遠端確實屬於你的某個帳號時，按一下它，選好帳號和專案。

同一個專案的 HTTPS 位址和 SSH 位址對應到同一個帳號。

## 登入 HTTPS 遠端 {#git}

HTTPS 遠端屬於你的某個帳號時，Git 用這個帳號的權杖登入。複製、擷取、拉取、推送和自動擷取都是這樣。

- SSH 遠端照舊用你的 SSH 金鑰，帳號不影響它們。
- 在這些位址上，Spooky 代替你給 Git 設定的憑證輔助程式回答，例如 macOS 的鑰匙圈輔助程式。這些輔助程式看不到權杖，也存不走權杖。
- 同一個實例上有幾個帳號、又沒有為這個遠端選過帳號時，Git 照常問你使用者名稱和密碼。

Git 拒絕了權杖時，這一次的指令會失敗。之後 Git 存取這個帳號的遠端時會問你使用者名稱和密碼，對話框裡寫明這個帳號的權杖沒有被接受。重新認證帳號之後，就又用它登入了。

:::note[伺服器儲存庫]
伺服器上的 Git 同樣用權杖登入。每次需要時，它從你 Mac 上的 Spooky 取權杖，權杖不會存到伺服器上。
:::

## 權杖存在哪裡 {#storage}

- 帳號列表存在 Spooky 的偏好設定裡，不含權杖。
- 權杖存在鑰匙圈裡，項目名稱是 `com.rakuyo.spooky.hosting.<address>`。
- 用使用者名稱與密碼登入自行架設的 GitLab 時，Spooky 存下換來的權杖，不存密碼。

權杖不會寫進 :ui[activity.title] 的記錄和 Spooky 的日誌。

## 請求送往哪裡 {#network}

Spooky 從你的 Mac 連到託管服務，伺服器儲存庫也一樣：

- GitHub：在瀏覽器裡授權時連到 `github.com`，其餘都連到 `api.github.com`。
- GitLab：`gitlab.com`，或者你自己的 GitLab 的位址。

加入或重新認證帳號時會連過去，用到帳號的功能時也會：Pull Request 和 Merge Request 列表以及在那裡做的操作、`#` 後面的 Issue 編號、分支整理裡的狀態，以及發布儲存庫。用使用者名稱與密碼登入的帳號還會去那裡續期權杖。

這些請求每一個都會出現在 :ui[activity.title] 視窗的 :ui[activity.service] 頁裡。

GitHub 和 GitLab 使用者的大頭貼來自這些服務給出的位址。下載過的大頭貼只留在記憶體裡，結束 Spooky 就沒有了。

Git 本身從儲存庫所在的地方連接遠端，伺服器儲存庫就是從伺服器上連接。見 [資料與隱私權](/reference/data-privacy/#network)。

## 發布儲存庫 {#publish}

想用開啟著的儲存庫在 GitHub 或 GitLab 上新增一個儲存庫，選 :ui[menu.repository > publish.menu]，或者在側邊欄裡對 :ui[workspace.title] 按右鍵，選 :ui[workspace.publishMenu]。儲存庫還沒有遠端時，:ui[sync.push] 也會開啟這個對話框。至少要有一個帳號。

| 欄位 | 作用 |
|---|---|
| :ui[publish.remote] | 新遠端的名稱。一開始是 `origin`，儲存庫裡已經有 `origin` 時是 `origin-2`。 |
| :ui[pullRequests.account] | 儲存庫建在哪裡：你自己的使用者下，或者你所在的某個組織或群組 |
| :ui[publish.name] | 在服務上的名稱，一開始是儲存庫資料夾的名稱。 |
| :ui[pullRequests.description] | 可以不填 |
| :ui[publish.visibility] | :ui[publish.visibility.private] 或 :ui[publish.visibility.public]。GitLab 另有 :ui[publish.visibility.internal]。 |
| :ui[publish.target] | 新遠端會用的 HTTPS 位址 |

按一下 :ui[publish.submit] 之後，Spooky 會：

1. 在服務上新增一個空儲存庫。
2. 用 HTTPS 位址把它加入為遠端。
3. 把全部本機分支和標籤推送過去。沒有上游的分支改為追蹤新遠端上的同名分支，已經有上游的不變。

同名的儲存庫已經存在時，Spooky 會提示，不會覆寫它，換個名稱即可。推送失敗時，新加的遠端和服務上新增的儲存庫都會保留，你可以再推送一次。

發布儲存庫不能用 <kbd>⌘Z</kbd> 還原，在它之前的操作也不能再還原。

## 相關頁面

- [Pull Request 與 Merge Request](/guide/hosting/pull-requests/)
- [密碼與私鑰密語的詢問](/guide/server/connection/#prompts)
- [資料與隱私權](/reference/data-privacy/)

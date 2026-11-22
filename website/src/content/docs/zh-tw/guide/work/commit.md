---
title: "提交變更"
description: "寫提交的標題與內文，使用自動補全，修補上一次提交，選擇提交的身分與簽署。"
---

提交把已暫存的變更連同一段說明存進儲存庫的歷史。先按 [檢視與挑選變更](/guide/work/diff/) 暫存變更，再在工作區頂端的提交區裡寫提交訊息。

## 寫提交訊息 {#write}

提交訊息分兩部分：

- :ui[working.subject] 是一行簡短的概括。按 <kbd>Return</kbd> 或 <kbd>Tab</kbd> 就到了內文。
- :ui[working.body] 可以不寫，用來說明改了什麼、為什麼改。

::screenshot[展開的提交區。標題是 Add a units toggle，下面是兩行內文。內文底部有圖釘和換行兩個按鈕。再往下是「修補最近提交」和「署名」兩個註記框，右邊是作者的姓名、電子郵件和大頭貼。最下面是「全部暫存」與「提交」兩個按鈕。]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. 圖釘按鈕與換行按鈕
3. 作者的大頭貼

在任一個框裡輸入時，提交區會展開；內文裡有文字時，它一直保持展開。想讓它始終展開，按一下內文框底部的圖釘按鈕。拖移內文框的下邊緣，可以調整它的高度。

開始輸入以後，標題框末尾的數字顯示還能輸入幾個字。超出上限的字會標上底色。

內文框底部的另一個按鈕在兩種換行方式之間切換：

- :ui[editor.softWrap] 在框的邊緣換行。
- :ui[editor.hardWrap] 使用等寬字型，不自動換行。一條參考線標出字數上限，超長的行會標上底色。想把插入點所在的段落按上限斷行，選 :ui[menu.edit > commit.reformatParagraph]（<kbd>⇧⌘W</kbd>）。

這些選項在 :ui[app.name > settings.title] › :ui[settings.editor] 裡：

| 設定 | 預設 |
|---|---|
| :ui[editor.showsCounter] | 開啟 |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72。選了 :ui[editor.hardWrap] 時可以修改 |
| :ui[editor.showsGuide] | 開啟。用於 :ui[editor.hardWrap] |
| :ui[editor.warnsComments] | 開啟。見 [提交訊息裡的註解](#comments) |
| :ui[editor.stripsComments] | 關閉。提示關閉時可用 |
| :ui[editor.completesIssues] | 開啟。見 [自動補全](#autocomplete) |

見 [編輯器](/guide/settings/appearance/#editor)。

## 提交 {#commit}

訊息寫好以後，按一下 :ui[working.commit]，或者在輸入訊息時按 <kbd>⌘↩</kbd>。標題裡有文字、並且暫存了變更以後，這個按鈕才能按。

不管焦點在視窗的哪裡，選 :ui[workspace.title > working.commitMenu]（<kbd>⇧⌘C</kbd>）都能跳到標題框。

內文下面有兩個註記框，會改變這次提交：

- :ui[commit.signOff] 在訊息末尾加一行 `Signed-off-by`，寫上你的姓名與電子郵件。勾選與否會保持下去，所有儲存庫都一樣。
- :ui[commit.skipHooks] 提交時不執行儲存庫的 `pre-commit` 與 `commit-msg` 掛鉤。只有儲存庫裡有這些掛鉤時才顯示，每次提交以後自動取消勾選。

提交失敗時，寫好的訊息仍留在提交區裡。想收回剛做的提交，選 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。見 [還原與找回](/guide/work/undo/)。

### 提交訊息裡的註解 {#comments}

在 Git 裡，以 `#` 開頭的行算作註解，除非你改過註解字元。Spooky 按你寫的原樣提交，所以訊息裡有這樣的行時，它會先問：:ui[commit.comments]

- :ui[commit.removeComments] 去掉這些行再提交。
- :ui[commit.keepComments] 原樣提交。

勾選 :ui[commit.doNotAskAgain]，下次就按這次的選擇處理。想恢復這個提問，在 :ui[app.name > settings.title] › :ui[settings.editor] 裡開啟 :ui[editor.warnsComments]，見 [編輯器](/guide/settings/appearance/#editor)。

訊息裡只有註解時，Spooky 會問 :ui[commit.commentsOnly]按一下 :ui[commit.keepCommentsAndCommit] 照樣提交。

## 自動補全 {#autocomplete}

在標題或內文裡輸入下面的內容，Spooky 會隨著你繼續輸入列出符合的項目：

| 輸入 | 插入 |
|---|---|
| `c:` | 最近 100 個提交之一的短雜湊。可以輸入雜湊、標題或作者的一部分 |
| `\` | 一個已暫存檔案的路徑 |
| `#` | GitHub 或 GitLab 上一個開啟中的 Issue 的編號 |
| 標題開頭的 `fixup!` 或 `squash!` | 之前某個提交的標題，表示這個提交是對它的修正 |

::screenshot[在提交標題裡輸入 c: 之後的樣子。下面的列表列出最近的提交，每一項寫著作者、日期、短雜湊和標題，第一項已選取。]{name="work-commit-completion" frame="closeup"}

按 <kbd>↑</kbd> 或 <kbd>↓</kbd> 選一項，按 <kbd>Return</kbd> 插入，按 <kbd>Esc</kbd> 關掉列表。

補全 Issue 編號需要儲存庫的遠端有對應的 [託管帳號](/guide/hosting/accounts/)，並且在 :ui[app.name > settings.title] › :ui[settings.editor] 裡開啟了 :ui[editor.completesIssues]，見 [編輯器](/guide/settings/appearance/#editor)。標了 `fixup!` 或 `squash!` 的提交，之後可以併進它修正的那個提交，見 [改寫歷史](/guide/history/rewrite/)。

## 修補上一次提交 {#amend}

修補就是用一個新的提交取代上一次提交。可以用它改提交訊息，或者補上忘了加的變更。

1. 勾選內文下面的 :ui[working.amend]。Spooky 填入上一次提交的訊息，註記框上顯示那個提交的短雜湊。
2. 修改訊息，把要補上的變更暫存好。
3. 按一下 :ui[working.amend]。

取消勾選，就回到之前正在寫的訊息。

想快速修補，在沒有編輯任何訊息框時按住 <kbd>⌥</kbd>。放開之前，提交區都處在修補上一次提交的狀態。按住的同時按一下 :ui[working.amend]，或者按 <kbd>⌥⌘↩</kbd>，提交會保留原來的訊息，並加入已暫存的變更。

:::caution
上一次提交已經推送過的話，修補以後它就和遠端上的那個不一樣了，推送時需要強制推送。見 [安全強制推送](/guide/branches/sync/#force-push)。
:::

想修改更早的提交，見 [改寫歷史](/guide/history/rewrite/)。

## 選擇提交者 {#identity}

註記框右邊的姓名與電子郵件會作為作者記進提交。它們來自 Git 的 `user.name` 與 `user.email` 設定。旁邊的大頭貼按電子郵件位址查找，見 [資料與隱私權](/reference/data-privacy/)。

想換個身分提交，例如用工作信箱，可以用身分設定檔：

1. 按一下大頭貼。選單裡列出你的身分設定檔，正在用的那個前面有勾號。
2. 選一個設定檔。
3. 看一下 Spooky 將要寫入哪些設定，按一下 :ui[profiles.apply.submit]。

設定檔裡的姓名、電子郵件與簽署金鑰寫進這個儲存庫自己的 Git 設定，不影響別的儲存庫。

目前的身分還不是設定檔時，選單裡有 :ui[profiles.addCurrent]{1="alex@example.com"}，可以把它存成設定檔。想管理設定檔，在同一個選單裡選 :ui[profiles.manage]。見 [身分設定檔](/guide/settings/identity/#profiles)。

:::note[伺服器儲存庫]
設定檔寫進伺服器上這個儲存庫的設定。伺服器上在這個儲存庫裡提交的其他工具也會用它。
:::

## 為提交簽署 {#signing}

簽署過的提交能證明它出自某把金鑰的主人。Spooky 支援 SSH 與 OpenPGP 金鑰。

把指標停在提交區的大頭貼上，可以看到下一個提交會不會簽署，用的是哪把金鑰。

- **所有儲存庫**：在 :ui[app.name > settings.title] › :ui[settings.gitConfig] 裡開啟 :ui[gitConfig.signCommits]，選好 :ui[gitConfig.signingKey]，見 [簽署](/guide/settings/identity/#signing)。
- **單一儲存庫**：按一下側邊欄裡的 :ui[repositorySettings.title]，在 :ui[repositorySettings.signing] 一組裡設定 :ui[repositorySettings.signCommits] 與 :ui[repositorySettings.signingKey]，見 [儲存庫設定](/guide/settings/identity/#repository)。

金鑰需要密語時，Spooky 會跳出 :ui[signing.unlock] 對話框來問。

## 相關頁面

- [檢視與挑選變更](/guide/work/diff/)
- [還原與找回](/guide/work/undo/)
- [身分設定檔與 Git 設定](/guide/settings/identity/)

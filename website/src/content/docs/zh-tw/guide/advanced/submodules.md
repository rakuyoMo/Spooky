---
title: "子模組"
description: "開啟、更新、擷取、初始化、同步、移動、重新命名與刪除子模組。"
---

子模組是放在你儲存庫某個資料夾裡的另一個 Git 儲存庫。你的儲存庫記著要用它的哪個提交。Spooky 把這筆記錄叫作子模組指標。

## 在側邊欄裡 {#sidebar}

子模組列在側邊欄的 :ui[submodule.group] 下，按路徑排序。把指標停在一個子模組上，可以看到它的名稱和 URL。

- 灰色的一列是還沒簽出的子模組。
- 警告圖示表示它的設定不完整，或者它的 URL 需要同步。
- 數字是它裡面變更了多少個檔案。
- ↑ 和 ↓ 表示簽出的提交比指標領先或落後多少。

按一下子模組可以檢視它的詳細資訊。按兩下已簽出的子模組，會在同一個視窗裡把它當作儲存庫開啟。開啟期間，按一下工具列的 :ui[toolbar.parentRepository] 就能回去。

在工作區的檔案列表裡按兩下已簽出的子模組，也會這樣開啟。想讓按兩下像別的檔案一樣開啟它，在 :ui[app.name > settings.title] › :ui[settings.general] 裡關掉 :ui[files.openSubmodules]，見 [檔案列表](/guide/settings/general/#file-list)。

## 詳細資訊 {#details}

詳細資訊有三頁，在頂端切換：

- :ui[submodule.page.general]：名稱、路徑、狀態、本機變更、簽出的提交、指標，以及生效的設定。子模組還沒初始化，或者 `.gitmodules` 裡它的 URL 變了時，頂端會有一則提示，帶著修好它的按鈕。
- :ui[submodule.page.shared]：`.gitmodules` 裡的設定。複製這個儲存庫的人都會拿到。這裡的變更會出現在工作區裡。像別的變更一樣提交它們。
- :ui[submodule.page.local]：這個儲存庫自己設定裡的設定。它們只在這裡生效，優先於 `.gitmodules`。

在兩個設定頁上，可以給子模組重新命名、移動它、改它的 URL，還能設定三個選項。:ui[submodule.useDefault] 會去掉這個選項。之後用 Git 的預設值。

- :ui[submodule.field.fetchMode]：擷取父儲存庫時要不要也擷取這個子模組。可選 :ui[submodule.fetchMode.always]、:ui[submodule.fetchMode.onDemand]（只在擷取到的提交變更了它的指標時，預設）或 :ui[submodule.fetchMode.never]。
- :ui[submodule.field.ignoreMode]：父儲存庫的工作區忽略子模組裡的哪些變更。可選 :ui[submodule.ignoreMode.none]（預設）、:ui[submodule.ignoreMode.untracked]、:ui[submodule.ignoreMode.dirty]（只看簽出的是不是另一個提交）或 :ui[submodule.ignoreMode.all]。
- :ui[submodule.field.updateStrategy]：更新時怎樣把子模組帶到指標上。可選 :ui[submodule.updateStrategy.checkout]（預設）、在它目前的分支上 :ui[submodule.updateStrategy.rebase] 或 :ui[submodule.updateStrategy.merge]，或者 :ui[submodule.updateStrategy.none]。

## 加入子模組 {#add}

1. 選 :ui[menu.repository > menu.addSubmodule]。也可以按一下側邊欄底部的加入按鈕，或者在 :ui[submodule.group] 上按右鍵，在選單裡選 :ui[submodule.add.menu]。
2. 填子模組儲存庫的 URL。
3. 在 :ui[submodule.path] 一欄按一下 :ui[submodule.path.select]，選你儲存庫裡的一個空資料夾。
4. 按一下 :ui[submodule.add.submit]。

儲存庫裡已經有同名子模組的 Git 目錄時，例如來自你刪掉的子模組，Spooky 會問你怎麼處理。:ui[submodule.forceAdd.reuse] 會接著用它。:ui[submodule.forceAdd.overwrite] 會刪掉它再重新複製。

## 擷取與更新 {#update}

- **擷取** 從子模組的遠端下載新的提交，不改變簽出的內容。
- **更新** 簽出指標記著的提交。還沒初始化的子模組會先初始化。

在子模組上按右鍵，選 :ui[submodule.fetch.menu]{1="vendor/charts"} 或 :ui[submodule.update.menu]{1="vendor/charts"}。:ui[menu.repository] 選單裡也有這兩項，另外還有一次處理所有子模組的項目。

對話框裡有這些選項：

- 擷取時的 :ui[sync.prune]
- 更新時的 :ui[submodule.update.recursive]。它會連子模組裡面的子模組一起更新。這些子模組的遠端必須用已經設定好的憑證就能存取。Spooky 無法在中途問你要憑證。

在右鍵選單裡按住 <kbd>⌥</kbd>，會出現 :ui[submodule.quickFetch]{1="vendor/charts"} 和 :ui[submodule.quickUpdate]{1="vendor/charts"}。它們略過對話框，用上次的選項。選單列裡的 :ui[menu.fetchAllSubmodules] 和 :ui[menu.updateAllSubmodules] 也是這樣。

只有需要更新時才能更新：子模組還沒簽出，或者簽出的是另一個提交。

### 在別的操作之後更新 {#auto-update}

簽出、拉取、合併等操作可能變更已簽出子模組的指標。操作完成後，Spooky 會問要不要更新這些子模組。勾選 :ui[submodule.autoUpdate.always]，以後就直接更新。想關掉，到 :ui[app.name > settings.title] › :ui[settings.general] 裡關掉 :ui[settings.autoUpdateSubmodules]，見 [操作](/guide/settings/general/#operations)。

### 初始化與同步 {#initialize}

- **初始化** 把子模組在 `.gitmodules` 裡的設定拷貝到你儲存庫的設定裡。之後再更新它，才會簽出。
- **同步** 用在 `.gitmodules` 裡的 URL 變了的時候。它把你儲存庫設定裡的 URL 和子模組自己儲存庫裡的 URL 都換成新的。

這兩項都在右鍵選單裡，需要時 :ui[submodule.page.general] 頁的提示裡也有。

## 簽出別的版本 {#checkout}

在已簽出的子模組上按右鍵，在 :ui[submodule.checkoutRevision] 裡選子模組的一個分支或標籤。目前的版本打著勾。

子模組裡的變更擋住簽出時，簽出會失敗。Spooky 不會提議儲藏它們。你儲存庫的儲藏管不到子模組。

在你提交子模組的新提交之前，你儲存庫裡的指標不會動。

## 移動、重新命名與刪除 {#manage}

這三項都在右鍵選單裡：

- **移動** 改變子模組的路徑。勾選 :ui[submodule.move.rename]，名稱也一起改成新路徑。
- **重新命名** 改變它的名稱。`.gitmodules` 和你的設定都用這個名稱指稱它。資料夾留在原處。
- **刪除** 把子模組從你的儲存庫裡去掉。勾選 :ui[submodule.delete.keepWorkingTree]，就只去掉它的設定，留下它的檔案。它裡面有變更時，Spooky 會先問你，再用 :ui[submodule.forceDelete.submit] 照樣刪除。

這些操作會變更 `.gitmodules` 和你儲存庫的暫存區。提交它們，別人才會拿到。

刪除之後，子模組的 Git 目錄還留在你儲存庫的 `.git` 資料夾裡。再次加入時可以接著用。

### 修復子模組 {#repair}

子模組的設定不完整時，它的詳細資訊寫著 :ui[submodule.invalid]，並帶著兩個按鈕。:ui[submodule.repair.submit] 會補上缺的部分：`.gitmodules` 裡的條目、指標，或者簽出的儲存庫。Spooky 哪裡都找不到子模組的 URL 時，就刪掉它再重新加入。

## 還原 {#undo}

加入、移動、重新命名和刪除子模組，在子模組裡簽出別的版本，以及改它的 URL 或選項，都可以還原。見 [還原與找回](/guide/work/undo/)。

初始化、同步和修復無法還原。做過其中一項之後，在它之前的操作也無法再還原。

擷取和更新跟儲存庫的擷取、拉取一樣，不記進還原記錄。在它們之前的操作照樣可以還原。

:::note[伺服器儲存庫]
這些都在伺服器上執行。加入子模組時，你選的是伺服器上的資料夾。
:::

## 相關頁面

- [擷取、拉取與推送](/guide/branches/sync/)
- [工作樹](/guide/advanced/worktrees/)
- [還原與找回](/guide/work/undo/)

---
title: "解決衝突"
description: "用衝突精靈或外部合併工具解決合併、重定基底等進行中操作的衝突，然後繼續或中止。"
---

兩邊改了檔案的同一處，Git 判斷不了該留哪一個，就產生了衝突。合併、重定基底、摘取、反轉會停在這裡，套用儲藏也一樣。你來決定每個檔案裡留下什麼，再把操作做完。

::screenshot[把「feature/units-toggle」合併到「main」時的工作區。中間一欄頂端的橫幅寫著 1 個未解決衝突（已解決 0 個），帶一個「中止」按鈕。檔案列表裡的 src/units.ts 標著衝突。右邊兩張卡片是兩個分支上的 units.ts，箭頭指向下方空著的結果框，結果框下面是「選擇合併工具」按鈕。]{name="conflict" frame="window" markers="24,18 47,55 76,37 76,73 84,86"}

1. 橫幅顯示正在進行的操作，還剩幾個衝突。
2. 一個有衝突的檔案。選取它，就開啟衝突精靈。
3. 檔案的兩個版本，兩邊各一個。
4. 結果：檔案最後的樣子。
5. 解決這個檔案或開啟合併工具的按鈕。

## 進行中的操作 {#banner}

合併、重定基底、摘取或反轉進行期間，工作區頂端有一條橫幅：

- 標題寫著正在做什麼，例如 :ui[conflict.title.merge]{1="feature/units-toggle" 2="main"}。
- 下面是未解決衝突的個數。操作在衝突上停下過以後，括號裡還會寫已解決幾個。
- 一句提示告訴你下一步做什麼。重定基底或一連串提交的操作進行時，進度列顯示到了第幾步。
- :ui[working.onlyConflicts] 讓檔案列表只留下這次衝突的檔案，已解決的也留著。Spooky 會記住這個選擇，所有儲存庫都一樣。
- :ui[working.abort] 取消這次操作。見 [繼續或中止](#continue)。

衝突全部解決之前，提交區是隱藏的。

## 使用衝突精靈 {#wizard}

在工作區裡選取一個有衝突的檔案，右邊就開啟衝突精靈。兩邊各有一張卡片，例如 :ui[conflict.version]{1="main"}。卡片上寫著檔案、這一邊對它做了什麼（例如 :ui[conflict.change.modified]），以及它來自哪個提交。

想留下其中一邊：

1. 按一下這一邊的卡片，結果框裡就顯示這個版本。
2. 按一下 :ui[conflict.resolveUsing]{1="main"}。

Spooky 把這個版本寫進檔案並暫存，檔案就算解決了。如果這一邊刪掉了檔案，檔案就會被刪除。

想把兩邊合在一起，兩張卡片都按一下，再按結果框下面的按鈕。它會開啟合併工具，見 [在其他 App 裡合併](#merge-tool)。

如果你已經自己改過檔案，例如在文字編輯器裡，結果框會顯示 :ui[conflict.result]。按一下 :ui[conflict.resolveCurrent]，按檔案現在的樣子暫存。回到 Spooky 時，精靈會重新讀取檔案。

卡片上的「…」按鈕開啟這個版本的選單：

- :ui[conflict.open]{1="main"}，或者用其他 App 開啟
- :ui[conflict.export]{1="main"}
- :ui[conflict.compareOther]{1="feature/units-toggle"}
- :ui[conflict.compareBase]

## 在其他 App 裡合併 {#merge-tool}

合併工具把兩個版本並排顯示，可以一行一行挑變更。它一次處理一個檔案，兩邊都有這個檔案時才能用。

1. 在衝突精靈裡按一下 :ui[externalTool.chooseMergeTool]，選一個 App。以後這個按鈕就是 :ui[externalTool.mergeIn]{1="FileMerge"}。
2. 在那個 App 裡合併檔案，儲存結果，然後結束它。

Spooky 把結果寫進檔案，標記為已解決。App 沒有儲存結果的話，Spooky 會提示 :ui[externalTool.noResult]，衝突仍然留著。

FileMerge 稍有不同。它開啟期間，Spooky 顯示 :ui[externalTool.finishMerge]{1="FileMerge"}。在 FileMerge 裡儲存結果，再按一下 :ui[externalTool.done]。

Spooky 支援 Araxis Merge、Beyond Compare、DeltaWalker、FileMerge、Kaleidoscope、P4Merge 與 Visual Studio Code。想換一個，改 :ui[app.name > settings.title] › :ui[settings.gitConfig] 裡的 :ui[externalTool.mergeTool]。在同一處開啟 :ui[externalTool.keepBackups]，合併前的檔案會留下來，例如存成 `src/units.ts.orig`。見 [比較與合併工具](/guide/settings/integration/#diff-merge-tools)。

合併期間檔案在別處被改過的話，Spooky 會先問，再覆寫它。

:::note[伺服器儲存庫]
合併工具拿到的是各個版本的副本，放在這台 Mac 上的一個暫存資料夾裡。Spooky 把結果寫回伺服器，再標記為已解決。關閉儲存庫時，這個資料夾會被刪掉。
:::

## 其他解決方法 {#other-ways}

在一個或幾個有衝突的檔案上按右鍵：

- :ui[conflict.menu.resolve]
  - :ui[conflict.markResolved.one]{1="src/units.ts"} 按檔案現在的樣子暫存。勾選檔案的註記框也一樣。
  - :ui[conflict.resolveUsingVersion]{1="main"} 留下其中一邊，和精靈裡一樣。
- :ui[conflict.menu.restore]
  - :ui[conflict.restoreUnmerged.one]{1="src/units.ts"} 讓衝突重新出現，已經解決的檔案也可以。
  - :ui[conflict.restoreVersion]{1="main"} 與 :ui[conflict.restoreAncestor] 把一個版本放進檔案，檔案仍然是未解決的。

:::caution
回復會直接覆寫工作區裡的檔案，不會先問。你對它做的修改都會丟掉。
:::

套用儲藏或修補檔時停在衝突上，沒有可以繼續或中止的操作，也沒有橫幅。精靈把套用進來的一邊叫作 :ui[conflict.version.applied]。檔案都解決以後，這些變更就和別的變更一樣留在工作區裡。

## 繼續或中止 {#continue}

衝突全部解決以後，提交區重新出現，裡面是 Git 為這次操作準備好的提交訊息。

- **合併，或者只摘取、反轉一個提交**：檢查訊息，按一下 :ui[working.commit]。
- **重定基底，或者摘取、反轉好幾個提交**：檢查訊息，按一下 :ui[working.continue]。Spooky 提交這一步，接著做下一步。下一步也可能再停在衝突上。
- **重定基底停下來編輯某個提交**：做好你的提交，再按一下橫幅上的 :ui[working.endEditing]。

有時已經沒有可提交的變更，例如你留下的正是原來的版本。這時按一下 :ui[working.commit] 或 :ui[working.continue]，Spooky 會問 :ui[commit.empty.title]按一下 :ui[commit.empty.use] 就做一個空提交。另一個按鈕會中止合併；在重定基底或一連串提交裡，是略過這一步。重定基底或一連串提交裡，也可以按一下橫幅上的 :ui[working.skip]。

想放棄，按一下橫幅上的 :ui[working.abort]。儲存庫會回到操作開始之前的樣子。

:::caution
中止會立刻執行，不會先問，也無法還原。已經解決的衝突都會丟掉。
:::

## 相關頁面

- [檢視與挑選變更](/guide/work/diff/)
- [儲藏](/guide/work/stash/)
- [還原與找回](/guide/work/undo/)

---
title: "外觀與主題"
description: "選擇外觀，使用內建主題或新增、匯入、匯出自己的主題，設定文字與編輯器，以及選擇應用程式圖示。"
---

:ui[app.name > settings.title] 裡有四頁決定 Spooky 的樣子：:ui[settings.appearance] 管整個 App，:ui[settings.themes] 管 Diff 與檔案的配色，:ui[settings.text] 管文字怎樣顯示，:ui[settings.editor] 管提交訊息。

## 外觀 {#appearance}

在 :ui[settings.appearance.label] 一列按一下一張圖，整個 App 就換成那種外觀：

- :ui[appearance.system] 跟隨 macOS。這是預設的選擇。
- :ui[appearance.light] 與 :ui[appearance.dark] 不隨 macOS 變化。

在儲存庫視窗裡，也可以用 [快速操作](/guide/repositories/navigation/#quick-actions) 切換：找到那種外觀，執行 :ui[quickActions.setAppearance]。

## 應用程式圖示 {#app-icon}

外觀下面的 :ui[settings.appIcon.label] 一列列出可選的圖示，分兩個系列：

| 系列 | 圖示 |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise]（預設）、:ui[appIcon.front]、:ui[appIcon.hide]、:ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight]、:ui[appIcon.perch]、:ui[appIcon.cherryPick]、:ui[appIcon.armful] |

指標移到一枚圖示上，左邊就顯示它的大圖。大圖下面是它在 Dock 裡的四種樣子：原樣、連著伺服器、深色、深色且連著伺服器。按一下圖示就換成它。圖示區有鍵盤焦點時，方向鍵在圖示之間移動，按 <kbd>空白鍵</kbd> 換成所在的那一枚。

新圖示會出現在 Dock、App 切換器（<kbd>⌘Tab</kbd>）與 Finder 裡，Spooky 沒在執行時也一樣。還有幾點：

- 有伺服器儲存庫連著時，圖示會亮起來。:ui[appIcon.series.hideAndSeek] 系列裡伺服器的指示燈亮起，:ui[appIcon.series.cherryPick] 系列裡幽靈的眼睛變成發光的星星。
- **系統設定 › 外觀** 裡的圖像與小工具樣式選深色，或者選自動而 Spooky 正是深色時，顯示深色的一版。選透明或染色樣式時，圖示不會亮起來。
- 換到 :ui[appIcon.rise] 或從它換走時，Dock 會重新啟動一次。不然固定在 Dock 裡的 Spooky 還是舊圖示。
- 其他圖示會存進 `Spooky.app`。寫不進去時，頁面上會寫出原因，圖示不變。

## 主題 {#themes}

主題決定 Diff 與檔案內容用的字型和顏色。Spooky 內建兩個：淺色外觀用的 Default，深色外觀用的 Default (Dark)。

列表裡選取的主題，就是目前外觀在用的主題。淺色與深色各記各的。想替另一種外觀選主題，先換到那種外觀。快速操作裡的 :ui[quickActions.applyTheme] 也能切換主題。

::screenshot[設定視窗的主題頁。左邊的列表裡有 Default 與 Default (Dark)，選取的是 Default，列表底部有加入與移除按鈕。右邊是一個顯示 Menlo-Regular 11.0 的字型框，一個按各自顏色列出純文字、關鍵字、字串、註解等文字類別的列表，以及標著字型顏色、背景、選取範圍、新增、刪除的幾個色塊。最下面是一小段 Diff 預覽，有未變更、刪除與新增的行。]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 66.7,56.9 61.1,82.7"}

1. 主題列表
2. :ui[themes.add] 與 :ui[themes.remove]
3. 字型
4. 語法著色區分的各類文字
5. 色塊
6. 用這個主題顯示的 Diff 預覽

### 新增與編輯主題 {#edit-theme}

1. 按一下列表下方的加入按鈕。Spooky 按目前外觀的內建主題配色加入 :ui[themes.newName]，並選取它的名稱。
2. 輸入名稱，按 <kbd>Return</kbd>。
3. 按一下字型框，在字型面板裡選字型和字級。
4. 在列表裡選一類文字，按一下 :ui[themes.text] 改它的顏色。:ui[themes.background]、:ui[themes.selection]、:ui[themes.added] 與 :ui[themes.deleted] 設定文字周圍的顏色。

變更立即儲存，預覽也跟著變。之後想重新命名，選取主題按 <kbd>Return</kbd>。

內建的兩個主題可以編輯，但不能重新命名或刪除。刪除別的主題時，選取它並按一下移除按鈕。Spooky 會先問一下，刪除之後不能還原。用著這個主題的外觀會回到它的內建主題。

### 分享主題 {#share-themes}

每個主題是一個 `.spookytheme` 檔案。

- **匯出**：把主題從列表拖到 Finder 裡的資料夾。
- **匯入**：把 `.spookytheme` 檔案拖到列表上。也可以在 Finder 裡開啟它們，或者拖到 Dock 裡 Spooky 的圖示上。

已有同名主題時，Spooky 會問要不要取代。不是有效主題的檔案會略過，並給出提示。

主題存放在 `~/Library/Application Support/Spooky/Themes/`。見 [資料與隱私權](/reference/data-privacy/#mac)。

## 文字 {#text}

:ui[settings.text] 頁設定 Diff 與檔案內容裡的文字怎樣顯示。顏色來自主題。

| 設定 | 預設 | 作用 |
|---|---|---|
| :ui[text.enableSyntaxColoring] | 開啟 | 按程式碼的語言著色 |
| :ui[text.syntaxColoringInDiffs] | 關閉 | Diff 裡也用語法著色。需要先開啟語法著色。 |
| :ui[text.showInvisibles] | 關閉 | 用符號標出空格、Tab 與換行 |
| :ui[text.tabWidth] | 4 | 一個 Tab 佔幾個空格，1 到 100 |

## 編輯器 {#editor}

:ui[settings.editor] 頁設定提交訊息的輸入框。它們怎樣運作，見 [寫提交訊息](/guide/work/commit/#write)。

| 設定 | 預設 | 作用 |
|---|---|---|
| :ui[editor.showsCounter] | 開啟 | 顯示標題還能輸入幾個字元 |
| :ui[editor.subjectLimit] | 50 | 標題的字元數上限。可以從選單裡選，也可以輸入 1 到 1000 之間的數。 |
| :ui[editor.wrapping] | :ui[editor.softWrap] | 也可以選 :ui[editor.hardWrap]：使用等寬字型，不自動換行 |
| :ui[editor.bodyLimit] | 72 | :ui[editor.hardWrap] 時每行的字元數上限 |
| :ui[editor.showsGuide] | 開啟 | :ui[editor.hardWrap] 時在上限處畫一條參考線 |
| :ui[editor.warnsComments] | 開啟 | 提示 Git 會當作註解的行。見 [提交訊息裡的註解](/guide/work/commit/#comments)。 |
| :ui[editor.stripsComments] | 關閉 | 提交時刪掉這些行。關閉提示後才能開啟。 |
| :ui[editor.completesIssues] | 開啟 | 在 `#` 後面補全 Issue 編號。見 [自動補全](/guide/work/commit/#autocomplete)。 |

## 相關頁面

- [一般、更新與環境](/guide/settings/general/)
- [檢視與挑選變更](/guide/work/diff/)
- [提交變更](/guide/work/commit/)
- [視窗與導覽](/guide/repositories/navigation/)

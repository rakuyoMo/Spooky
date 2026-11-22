---
title: "キーボードショートカット"
description: "Spooky のすべてのキーボードショートカットを調べられます。"
---

メニュー項目の横には、そのショートカットが表示されます。このページでは、それらをすべてまとめ、コミットエリア、一覧、ダイアログなど、特定の場所で使えるキーも紹介します。記号の意味は [キーボードショートカット](/guide/#shortcuts) で説明しています。

ショートカットは、そのメニュー項目が使えるときだけ働きます。項目が淡色表示のときは、ショートカットを押しても何も起きません。

## メニュー {#menus}

### アプリケーションとウインドウ {#app-windows}

| ショートカット | メニュー項目 |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### リポジトリ {#repositories}

| ショートカット | メニュー項目 |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### 表示 {#views}

| ショートカット | メニュー項目 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### 編集と検索 {#edit}

| ショートカット | メニュー項目 |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- :ui[menu.undo] で取り消せる操作は、[取り消しとやり直し](/guide/work/undo/#undo) を参照してください。
- :ui[menu.delete] は、一部の一覧で選択中の項目も削除します。[一覧](#lists) を参照してください。
- :ui[action.find] と :ui[action.search] は、どちらもツールバーの検索フィールドにカーソルを置きます。[検索と絞り込み](/guide/history/browse/#search) と [ファイルを探す](/guide/work/working-copy/#search) を参照してください。
- :ui[commit.reformatParagraph] は、コミットメッセージの中で使えます。[メッセージを書く](/guide/work/commit/#write) を参照してください。

### ブランチと同期 {#sync}

| ショートカット | メニュー項目 |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

<kbd>⌥⇧⌘</kbd> の付いた項目はクイック版です。メニューを開いた状態で <kbd>⌥</kbd> を押している間、1 つ上の項目と入れ替わります。ダイアログを出さずにすぐ実行されます。ショートカットは、メニューを開かなくても使えます。[フェッチ、プル、プッシュ](/guide/branches/sync/#quick) と [マージとリベース](/guide/branches/merge-rebase/#quick) のクイック版を参照してください。

### 変更とコミット {#changes}

| ショートカット | メニュー項目 |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## Option キーを押したまま {#option}

<kbd>⌥</kbd> を押している間、一部のボタンとメニューが変わります。放すと元に戻ります。

| 場所 | 変わるもの |
|---|---|
| ツールバーのフェッチ、プル、プッシュ、同期、マージ、リベースのボタン | クイック版に変わります。[フェッチ、プル、プッシュ](/guide/branches/sync/#quick) を参照してください。 |
| コミットエリア（どちらのメッセージ欄も編集していないとき） | 直前のコミットの修正に切り替わります。[直前のコミットを修正する](/guide/work/commit/#amend) を参照してください。 |
| ファイル一覧の上の :ui[working.stageAll]（一部の変更だけがステージされているとき） | :ui[working.unstageAll] に変わります。[ファイル全体をステージする](/guide/work/diff/#stage-file) を参照してください。 |
| 作業コピーのファイルのメニュー | スタッシュの項目がクイック版に変わります。[一部のファイルをスタッシュする](/guide/work/stash/#partial) を参照してください。 |
| サブモジュールのメニュー | フェッチと更新がクイック版に変わります。[フェッチと更新](/guide/advanced/submodules/#update) を参照してください。 |
| 親ブランチのあるブランチのメニュー | 親からの更新がクイック版に変わります。[親からブランチを更新する](/guide/branches/merge-rebase/#update) を参照してください。 |
| コミットのメニュー | パッチの保存がクイック版に変わります。2 つのコミットを選択しているときは、比較の向きが逆になります。[パッチを保存する](/guide/history/commit-details/#patch) を参照してください。 |
| 2 つのコミットを選択しているときの :ui[compare.submit] | 逆向きに比較します。[複数のコミット](/guide/history/commit-details/#multiple) を参照してください。 |
| ドラッグ | [Option キーを押しながらドラッグする](#drag) を参照してください。 |

## コミットエリア {#commit-area}

| キー | 働き |
|---|---|
| 件名で <kbd>↩</kbd> または <kbd>Tab</kbd> | 説明に移動します |
| 説明で <kbd>Tab</kbd> | ファイル一覧に移動します |
| 説明で <kbd>⇧Tab</kbd> | 件名に戻ります |
| メッセージの入力中に <kbd>⌘↩</kbd> | :ui[working.commit] など、コミットエリアのメインのボタンをクリックします。テンキーの <kbd>Enter</kbd> でも同じです。 |
| どちらのメッセージ欄も編集していないときに <kbd>⌥⌘↩</kbd> | 直前のコミットを修正します。[直前のコミットを修正する](/guide/work/commit/#amend) を参照してください。 |
| 自動補完の一覧で <kbd>↑</kbd> <kbd>↓</kbd>、<kbd>↩</kbd>、<kbd>Esc</kbd> | 候補を選び、挿入し、一覧を閉じます |

[変更をコミットする](/guide/work/commit/) を参照してください。

## ファイル一覧 {#file-list}

次のキーは、作業コピーのファイル一覧で使えます。

| キー | 働き |
|---|---|
| <kbd>スペース</kbd> | 選択したファイルをステージまたはステージ解除します。:ui[files.spacebar] を :ui[files.spacebar.quickLook] にしていると、代わりにクイックルックで表示します。[ファイル一覧](/guide/settings/general/#file-list) を参照してください。 |
| <kbd>⌘⌫</kbd> | 選択したファイルをゴミ箱に入れます |
| <kbd>⇧Tab</kbd> | コミットメッセージの説明に戻ります |

## diff の行 {#diff-lines}

作業コピーで、ブロックの行番号にキーボードフォーカスが移るまで <kbd>Tab</kbd> を押します。そのあと、次のキーを使います。

| キー | 働き |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 選択できる行の間を移動します |
| <kbd>スペース</kbd> | 行を選択または選択解除します |
| <kbd>Tab</kbd> または <kbd>⇧Tab</kbd> | 行番号から離れます |

マウスでは、<kbd>⇧</kbd> を押しながら行番号をクリックすると、間にあるすべての行が選択されます。[行をステージする](/guide/work/diff/#lines) を参照してください。

## 一覧 {#lists}

| 場所 | キー | 働き |
|---|---|---|
| 履歴のコミット一覧 | <kbd>⌘C</kbd> | 選択したコミットの完全なハッシュをコピーします |
| コミットの変更セット | <kbd>↑</kbd> <kbd>↓</kbd> | 選択を移動します |
| ウインドウ全体に表示した詳細の、変更されたファイル | <kbd>↩</kbd> | 選択したファイルをデフォルトのアプリケーションで開きます |
| コミットのファイルツリー | <kbd>↩</kbd> | 選択したフォルダを開閉します |
| ファイル履歴 | <kbd>↩</kbd> | 選択したコミットの詳細をウインドウ全体に表示します |
| サイドバー | <kbd>⌘⌫</kbd> | 確認のあと、選択したブランチ、タグ、リモート、サブモジュールを削除します |
| サイドバーのフィルタフィールド | <kbd>Esc</kbd> | フィールドを空にします |
| スタッシュ | <kbd>⌘⌫</kbd> | 確認のあと、選択したスタッシュを削除します |
| ブランチの整理 | <kbd>⌘⌫</kbd> | 確認のあと、選択したブランチを削除します |
| リポジトリウインドウ | <kbd>↩</kbd> | 選択したリポジトリを開きます |
| リポジトリウインドウ | <kbd>⌫</kbd> または <kbd>⌦</kbd> | 選択した項目を取り除きます。[リポジトリを削除する](/guide/repositories/manager/#delete) を参照してください。 |
| 起動時に表示されるウインドウ | <kbd>↩</kbd> | 選択したリポジトリを開きます。[前回の続きから始める](/guide/repositories/navigation/#restore) を参照してください。 |
| プルリクエストの会話 | <kbd>↩</kbd> | 選択したコミットを開きます |
| プルリクエストの会話 | <kbd>⌘S</kbd> | :ui[pullRequests.addComment] をクリックします |
| 設定の :ui[settings.themes] | <kbd>↩</kbd> | 選択したテーマの名前を変更します |
| 設定の :ui[settings.appIcon.label] | 矢印キー、<kbd>スペース</kbd> | アイコンの間を移動し、いまのアイコンを使います |

複数の項目を選択できる一覧では、<kbd>⇧</kbd> を押しながらクリックすると範囲を選択します。<kbd>⌘</kbd> を押しながらクリックすると、項目を 1 つずつ追加または解除します。サイドバーでは、<kbd>⌘</kbd> を押しながらブランチやタグをクリックすると、それらの履歴をまとめて表示できます。[履歴を開く](/guide/history/browse/#open) を参照してください。

別のワークツリーでチェックアウトされているブランチを、<kbd>⌘</kbd> を押しながらダブルクリックすると、そのワークツリーが新しいタブで開きます。[ブランチをチェックアウトする](/guide/branches/branches/#checkout) を参照してください。

## クイックアクション {#quick-actions}

次のキーは、[クイックアクション](/guide/repositories/navigation/#quick-actions) のパネルで使えます。

| キー | 働き |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 選択を移動します |
| <kbd>↩</kbd> | 選択した項目のデフォルトのアクションを実行します |
| <kbd>Tab</kbd>、またはテキストの末尾で <kbd>→</kbd> | 選択した項目のすべてのアクションを一覧にします |
| テキストがないときに <kbd>←</kbd>、または <kbd>⇧Tab</kbd> | アクションの一覧から戻ります |
| <kbd>Esc</kbd> | テキストを消します。テキストがないときは、アクションの一覧から戻るか、パネルを閉じます。 |

## ダイアログ {#dialogs}

ダイアログでは、<kbd>↩</kbd> が強調表示されたボタンをクリックします。<kbd>Esc</kbd> はキャンセルのボタンをクリックします。ダイアログにそのようなボタンがなければ、<kbd>Esc</kbd> も強調表示されたボタンをクリックします。

## Option キーを押しながらドラッグする {#drag}

ドロップするときに <kbd>⌥</kbd> を押していると、別の操作になります。

| ドラッグするもの | ドロップ先 | <kbd>⌥</kbd> なし | <kbd>⌥</kbd> あり |
|---|---|---|---|
| ローカルブランチ | :ui[workspace.title] または現在のブランチ | マージのダイアログ | リベースのダイアログ |
| リモートブランチ | 現在のブランチ | プルのダイアログ | 自分のブランチの上流になります。 |
| 履歴のコミット | :ui[workspace.title] または現在のブランチ | チェリーピックします | リバートします |
| 履歴のコミット | 一覧の別のコミット | そのコミットにスカッシュします | 代わりに fixup します |

[ドラッグ＆ドロップ](/guide/branches/merge-rebase/#drag-and-drop) と [スカッシュ、Fixup、削除、移動](/guide/history/rewrite/#interactive) を参照してください。

## 関連ページ

- [ウインドウとナビゲーション](/guide/repositories/navigation/)
- [変更をコミットする](/guide/work/commit/)
- [変更を確認してステージする](/guide/work/diff/)
- [マージとリベース](/guide/branches/merge-rebase/)

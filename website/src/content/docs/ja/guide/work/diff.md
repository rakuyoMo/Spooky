---
title: "変更を確認してステージする"
description: "ファイルの変更の読み方、差分の表示の調整、ファイル単位・ブロック単位・行単位でのステージと破棄について説明します。"
---

作業コピーでファイルを選択すると、右のカラムにその差分が表示されます。何が変わったかを 1 行ずつ確認できます。ここで、次のコミットに入れる部分だけをステージし、残りを破棄できます。

## 差分を読む {#read}

差分はブロックに分かれています。ブロックは、変更された行と、その前後にある変更のない数行をまとめたものです。見出しの行は、そのブロックがファイルのどこにあるかを示します。

- 追加された行は緑、削除された行は赤で表示されます。2 列の行番号は、ファイルの古いバージョンと新しいバージョンのものです。
- ファイルにステージ済みの変更と未ステージの変更の両方があるときは、カラムの上部にある :ui[working.unstaged] と :ui[working.staged] で切り替えます。変更のない側は淡く表示されます。
- 差分の下のバーには、ブロックの数と、追加された行数、削除された行数が表示されます。
- 画像の場合は、古い画像と新しい画像が表示されます。:ui[diff.twoUp] は 2 つを並べて表示します。:ui[diff.oneUp] は 1 つずつ表示し、:ui[diff.old] と :ui[diff.new] で切り替えます。

とても大きな差分はウインドウの動作を遅くすることがあるため、Spooky は先に確認を求めます：:ui[working.largeDiff] 表示するには :ui[working.showDiff] をクリックします。サイズの上限は、:ui[app.name > settings.title] › :ui[settings.general] の :ui[working.diffThreshold] です。デフォルトは 20,000 kB です。[履歴と差分](/guide/settings/general/#history) を参照してください。

## 差分のオプション {#options}

差分の下のバーには、よく変更するオプションがあります。

- 左端には 2 つのボタンがあります。ポインタを合わせると名前が表示されます。
  - :ui[diff.ignoreWhitespace] は、スペースとタブだけの変更を除外します。ファイルにそれ以外の変更がない場合、差分には :ui[diff.onlyWhitespace] と表示されます。
  - :ui[diff.showEntireFile] は、変更を反映した状態でファイル全体を表示します。いま見ている差分にだけ適用されます。
- 右端の :ui[diff.context] では、それぞれの変更の前後に表示する変更のない行の数を設定します。デフォルトは 3 です。:ui[menu.view > diff.contextMenu] からも選べます。

空白とコンテキストの設定は、すべてのリポジトリ、作業コピー、履歴のどこにでも適用されます。

そのほかのオプションは :ui[app.name > settings.title] › :ui[settings.text] にあります。

| 設定 | 動作 |
|---|---|
| :ui[text.enableSyntaxColoring] | コードを言語に合わせて色分けします。デフォルトでオンです。 |
| :ui[text.syntaxColoringInDiffs] | 差分でもシンタックスカラーを使います。デフォルトでオフです。 |
| :ui[text.showInvisibles] | スペース、タブ、行末を記号で表示します |
| :ui[text.tabWidth] | タブの幅をスペースの数で指定します |

これらの設定について詳しくは、[テキスト](/guide/settings/appearance/#text) を参照してください。色はテーマで決まります。[テーマ](/guide/settings/appearance/#themes) を参照してください。

## ファイル全体をステージする {#stage-file}

ステージとは、次のコミットに入れる変更を選ぶことです。ファイル全体をステージするには、次のいずれかの操作をします。

- ファイルの前にあるチェックボックスを選択します。そのファイルが選択されている場合は、選択中のすべてのファイルがステージされます。
- ファイルを選択して <kbd>スペース</kbd> を押します。選択中のファイルに未ステージの変更があればステージし、なければステージを解除します。
- 一覧の上の :ui[working.stageAll] をクリックするか、:ui[workspace.title > working.stageAllMenu]（<kbd>⇧⌘E</kbd>）を選びます。

ステージを解除するには、チェックボックスの選択を解除するか、もう一度 <kbd>スペース</kbd> を押すか、:ui[workspace.title > working.unstageAllMenu]（<kbd>⌥⇧⌘E</kbd>）を選びます。すべてがステージされると、:ui[working.stageAll] ボタンは :ui[working.unstageAll] に変わります。一部の変更だけがステージされている間は、<kbd>⌥</kbd> を押したままにすると切り替わります。

## ブロックをステージする {#chunks}

それぞれのブロックには、見出しの行の右端にボタンがあります。

- :ui[working.unstaged] 側：:ui[working.discardChunk] と :ui[working.stageChunk]
- :ui[working.staged] 側：:ui[working.unstageChunk]

ブロックはすぐに反対側へ移動します。ファイルの残りの部分はそのままです。

## 行をステージする {#lines}

1 つのブロックに別々のコミットに入れたい変更が混ざっているときは、一部の行だけをステージします。

1. 変更された行の行番号をクリックして選択します。もう一度クリックすると選択が解除されます。
2. さらに行を選択するには、その行番号もクリックします。行番号の上をドラッグすると連続した行を選択でき、<kbd>⇧</kbd> を押しながらクリックすると間にあるすべての行を選択できます。
3. ブロックの見出しにある :ui[working.stageLines] をクリックします。

::screenshot[src/readings.ts の差分にあるブロック。5 つの行が行番号で選択されていて、ブロックの見出しに「選択行を破棄」ボタンと「選択行をステージ」ボタンが表示されています。]{name="staging" frame="closeup"}

選択できるのは変更された行だけです。選択はブロックごとに独立していて、ボタンはそのブロックで選択した行に対して働きます。:ui[working.staged] 側では、ボタンは :ui[working.unstageLines] になります。

## 変更を破棄する {#discard}

破棄すると、残しておきたくない変更が捨てられます。

- **1 つのファイル**：ファイルを右クリックしてメニューから :ui[working.discard.menu] を選ぶか、:ui[workspace.title > working.discardMenu]（<kbd>⇧⌘⌫</kbd>）を選びます。
- **すべて**：メニューバーから :ui[workspace.title > working.discardAllMenu] を選びます。
- **ブロックまたは一部の行**：ブロックの見出しにある :ui[working.discardChunk] または :ui[working.discardLines] をクリックします。

ファイルの場合、Spooky は先に確認を求めます。追跡中のファイルは、ステージ済みの変更も含めて、最後のコミットの状態に戻ります。新しいファイルはゴミ箱に入ります。実行するには、:ui[working.discard] または :ui[working.discardAll.submit] をクリックします。

ブロックと行の場合、Spooky は :ui[working.discardContent.title] と尋ねます。次回から確認を省くには、:ui[dialog.doNotAskAgain] を選択します。もう一度確認されるようにするには、:ui[app.name > settings.title] › :ui[settings.general] で :ui[settings.warnDiscardingChunks] をオンにします。[確認](/guide/settings/general/#confirmations) を参照してください。

:::caution
破棄した変更は、どのコミットにも入っていません。元に戻す方法は :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）だけで、それもリポジトリが次に変更されるまでです。新しいファイルは、ゴミ箱に残っている間は元に戻せます。
:::

:::note[サーバリポジトリ]
破棄すると、サーバ上のファイルが上書きされます。新しいファイルはサーバのゴミ箱に入ります。サーバにゴミ箱がない場合は、完全に削除されます。確認のダイアログには :ui[dialog.doNotAskAgain] があります。もう一度確認されるようにするには、:ui[settings.general] で :ui[settings.warnDiscardingOnServer] をオンにします。
:::

## ほかのアプリケーションで比較する {#external}

FileMerge や Kaleidoscope などの比較ツールで変更を確認するには、次のようにします。

- 右のカラムの上部にあるファイル名にポインタを合わせ、:ui[externalTool.action.diffTool] をクリックします。いま見ている側が比較されます。
- または、ファイルを右クリックして :ui[externalTool.compare] サブメニューから :ui[externalTool.compare.workingTreeToBase]、:ui[externalTool.compare.workingTreeToIndex]、:ui[externalTool.compare.indexToBase] のいずれかを選びます。

初回は、どのアプリケーションを使うかを Spooky が尋ねます。あとで変更するには、:ui[app.name > settings.title] › :ui[settings.gitConfig] の :ui[externalTool.diffTool] を使います。Spooky は Araxis Merge、BBEdit、Beyond Compare、DeltaWalker、FileMerge、Kaleidoscope、P4Merge、TextMate、Visual Studio Code に対応しています。[比較ツールとマージツール](/guide/settings/integration/#diff-merge-tools) を参照してください。

:::note[サーバリポジトリ]
比較ツールには、Mac 上の一時フォルダにあるファイルのコピーが渡されます。このフォルダは、リポジトリを閉じると削除されます。
:::

## 関連ページ

- [作業コピー](/guide/work/working-copy/)
- [変更をコミットする](/guide/work/commit/)
- [取り消しと復元](/guide/work/undo/)

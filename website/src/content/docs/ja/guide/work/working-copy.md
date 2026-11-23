---
title: "作業コピー"
description: "変更したファイルの状態の見方、リスト表示とツリー表示、並べ替えと検索、未追跡のファイルと無視されたファイルの扱い、ファイルの操作とクイックルックについて説明します。"
---

作業コピーには、最後のコミットのあとに変更した内容が表示されます。ここで次のコミットに入れる変更を選び、ファイルの中身を確認し、Git に追跡させたくないファイルを除外します。

開くには、サイドバーのいちばん上にある :ui[workspace.title] をクリックするか、:ui[menu.view > menu.showWorkingCopy]（<kbd>⌘1</kbd>）を選びます。中央のカラムの上部にコミットエリアがあり、その下に変更されたファイルが並びます。コミットエリアについては [変更をコミットする](/guide/work/commit/) を参照してください。

## 状態の見方 {#status}

変更されたファイルは 1 行ずつ表示され、チェックボックス、2 つの状態バッジ、ファイル名が並びます。

- チェックボックスは、変更がステージされているかどうかを示します。ダッシュは、ファイルの一部だけがステージされていることを表します。
- 左のバッジはステージ済みの変更、右のバッジはまだステージされていない変更です。
- 文字は Git の状態コードです。M は変更、A は追加、D は削除、R は名前変更を表します。Git がまだ追跡していない新しいファイルには ?、無視されたファイルには ! が表示されます。
- 競合のあるファイルには、U U のように 2 つの競合コードが表示されます。[競合を解決する](/guide/work/conflicts/) を参照してください。

バッジにポインタを合わせると、状態が言葉で表示されます。

一覧の上の行には、現在のブランチと、それが追跡しているリモートブランチが表示されます。追跡先がないときは :ui[branch.noTracking] と表示されます。

ファイルが変更されると、Spooky は一覧を自動で更新します。すべてを読み込み直すには、:ui[action.refresh] をクリックするか <kbd>⌘R</kbd> を押します。

:::note[サーバリポジトリ]
Spooky は、リポジトリのウインドウが最前面にある間は 2 秒ごと、それ以外は 10 秒ごとにサーバ上の変更を確認します。サーバの応答が遅いときは、確認の間隔が長くなります。サーバ上で行った変更は、表示されるまでにそのぶん時間がかかることがあります。[サーバリポジトリの違い](/guide/server/overview/#differences) を参照してください。
:::

## リスト表示とツリー表示 {#view}

:ui[menu.view > files.statusMenu] メニューで、一覧に表示する内容を切り替えます。ブランチの行の右端にあるボタンにも同じ項目があります。

| 項目 | 動作 |
|---|---|
| :ui[working.list]（<kbd>⌃⌘L</kbd>） | 1 ファイルを 1 行で、フルパス付きで表示します |
| :ui[working.tree]（<kbd>⌃⌘T</kbd>） | ファイルをフォルダごとにまとめて表示します。フォルダをダブルクリックすると、開いたり閉じたりできます。 |
| :ui[files.showNonModified]（<kbd>⌃⌘M</kbd>） | 変更されたファイルだけでなく、リポジトリ内のすべてのファイルを表示します。ツリー表示で使えます。 |
| :ui[files.showIgnored]（<kbd>⌃⌘I</kbd>） | Git が無視しているファイルを表示します |
| :ui[files.showAssumeUnchanged] | assume-unchanged に設定されたファイルを表示します。[未追跡のファイルと無視されたファイル](#untracked-ignored) を参照してください。 |

リスト表示かツリー表示かは、リポジトリごとに記憶されます。最初はリスト表示です。そのほかの項目は、すべてのリポジトリに適用されます。

## 並べ替え {#sort}

:ui[status.filename] または :ui[status.column] の列見出しをクリックすると、その列で並べ替えます。もう一度クリックすると、順序が逆になります。並び順は、すべてのリポジトリとウインドウで共通です。

:ui[status.column] を最初にクリックすると、ステージ済みのファイルが先頭に来ます。続いてそのほかの変更、新しいファイル、最後に変更のないファイルと無視されたファイルが並びます。

## ファイルを探す {#search}

1. <kbd>⌘F</kbd> を押すか、ツールバーの検索フィールドをクリックします。フィールドには :ui[history.search.forFile] と表示されています。
2. ファイルのパスの一部を入力します。入力した文字を同じ順序で含むファイルが候補に表示されます。
3. ファイルを選ぶと、そのパスだけが表示されます。最後の候補を選ぶと、入力した文字列をパスに含むすべてのファイルが表示されます。

検索フィールドを空にすると、すべてのファイルの表示に戻ります。

## 未追跡のファイルと無視されたファイル {#untracked-ignored}

新しいファイルは、ステージしてコミットするまで未追跡のままです。未追跡のファイルには ? が表示され、ほかの変更と一緒に並びます。次のコミットに入れるには、ほかの変更と同じようにステージします。

ビルドの出力や手元のメモのように、決してコミットしたくないファイルもあります。Git に表示させないようにするには、ファイルを右クリックしてルールを選びます。

- :ui[files.ignore] は、リポジトリのルートにある `.gitignore` ファイルにルールを追加します。`.gitignore` をコミットすると、このリポジトリを使う全員にルールが適用されます。
- :ui[files.exclude] は、Git フォルダ内の `info/exclude` にルールを追加します。ルールはこのリポジトリのコピーだけに適用され、コミットされることはありません。

どちらのサブメニューでも、この項目だけ、同じ名前のすべての項目、同じ拡張子のすべての項目、または自分で入力したパターンを無視できます。

無視ルールは、Git がすでに追跡しているファイルには適用されません。追跡中のファイルを無視しようとすると、Spooky は追跡もやめるかどうかを尋ねます。追跡をやめるには :ui[files.untrack]、追跡を続けるには :ui[files.untrackIgnored.skip] をクリックします。どちらの場合も、ファイルはフォルダに残ります。

無視ルールを追加せずにファイルの追跡をやめるには、ファイルを右クリックして :ui[files.untrack] を選びます。次のコミットでリポジトリから削除されますが、ファイルはフォルダに残ります。

:ui[files.mark > files.assumeUnchanged.set] を選ぶと、追跡中のファイルに加えたローカルの変更を Git が無視するようになります。自分の Mac でだけ編集する設定ファイルなどに使います。ファイルは一覧から消えます。もう一度表示するには、:ui[files.showAssumeUnchanged] をオンにしてから、:ui[files.mark > files.assumeUnchanged.unset] を選びます。

## ファイルの操作 {#file-actions}

ファイルを右クリックすると、操作のメニューが表示されます。選択範囲内の行を右クリックすると、選択中のすべてのファイルが操作の対象になります。選択範囲の外では、クリックした行だけが対象になります。

::screenshot[作業コピーで src/readings.ts を右クリックしたときのコンテキストメニュー。上から順に、ファイルを開く項目とパスのコピー、クイックルック、ステージとゴミ箱への移動、競合、破棄とスタッシュ、Blame とファイル履歴、無視、比較の項目が並んでいます。]{name="work-file-menu" frame="closeup"}

| 目的 | 選ぶ項目 |
|---|---|
| ファイルを開く | :ui[files.open]、または :ui[files.openWith] からアプリケーションを選びます。ファイルをダブルクリックしても開けます。 |
| パスをコピーする | :ui[workspace.copyPathMenu] または :ui[working.copyRelative] |
| Finder またはターミナルで表示する | :ui[action.revealFinder] または :ui[action.openTerminal] |
| 移動する、名前を変える | :ui[files.move.menu] |
| ゴミ箱に入れる | :ui[files.trash]、または <kbd>⌘⌫</kbd> を押します |
| 変更を捨てる | :ui[working.discard.menu]（[変更を破棄する](/guide/work/diff/#discard) を参照） |
| スタッシュに入れる | [一部のファイルをスタッシュする](/guide/work/stash/#partial) を参照してください。 |
| 以前のバージョンに戻す | :ui[files.revert.menu] |
| 履歴を見る | :ui[quickActions.showFileHistory] または :ui[quickActions.showBlame]（[ファイル履歴と Blame](/guide/history/file-views/) を参照） |
| ほかのアプリケーションで比較する | :ui[externalTool.compare]（[ほかのアプリケーションで比較する](/guide/work/diff/#external) を参照） |

:ui[files.trash] は確認なしで実行されます。追跡中のファイルをゴミ箱に入れると、ステージ済みの削除として表示されます。元に戻すには、:ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）を選びます。

:::note[サーバリポジトリ]
:ui[files.trash] は、ファイルをサーバのゴミ箱に入れます。サーバにゴミ箱がない場合、項目名は :ui[files.delete] になり、Spooky はファイルを完全に削除する前に確認を求めます。ほとんどのアプリケーションにはファイルのコピーが渡され、保存すると Spooky が変更をサーバに書き戻します。[ターミナルとほかのアプリケーション](/guide/server/local-location/#terminal) を参照してください。
:::

## クイックルック {#quick-look}

アプリケーションを開かずにファイルをプレビューするには、ファイルを右クリックして :ui[files.quickLook.single]{1="README.md"} を選びます。

クイックルックをよく使うなら、スペースバーで開くように設定できます。:ui[app.name > settings.title] › :ui[settings.general] を選び、:ui[files.spacebar] を :ui[files.spacebar.quickLook] に設定します。デフォルトでは、スペースバーは選択したファイルをステージまたはステージ解除します。[ファイル一覧](/guide/settings/general/#file-list) を参照してください。

:::note[サーバリポジトリ]
Spooky は、まずファイルを Mac 上の一時フォルダにダウンロードします。このフォルダは、リポジトリを閉じると削除されます。
:::

## ファイル一覧の設定 {#settings}

以下の設定は :ui[app.name > settings.title] › :ui[settings.general] にあります。

| 設定 | 選択肢 |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile]（デフォルト）または :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging]（デフォルト）または :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] または :ui[files.fontSize.medium]（デフォルト） |
| :ui[files.truncation] | :ui[files.truncation.beginning]（デフォルト）または :ui[files.truncation.middle] |

[ファイル一覧](/guide/settings/general/#file-list) を参照してください。

## 関連ページ

- [変更を確認してステージする](/guide/work/diff/)
- [変更をコミットする](/guide/work/commit/)
- [ファイル履歴と Blame](/guide/history/file-views/)

---
title: "外観とテーマ"
description: "外観の選択、内蔵テーマの利用と独自テーマの作成・読み込み・書き出し、テキストとエディタのオプション、アプリケーションアイコンの選択について説明します。"
---

:ui[app.name > settings.title] の 4 つのページで、Spooky の見た目を決めます。:ui[settings.appearance] はアプリケーション全体、:ui[settings.themes] は差分とファイルの色、:ui[settings.text] はテキストの表示方法、:ui[settings.editor] はコミットメッセージの設定です。

## 外観 {#appearance}

:ui[settings.appearance.label] の行の絵をクリックすると、アプリケーション全体が切り替わります。

- :ui[appearance.system] は macOS に従います。これがデフォルトです。
- :ui[appearance.light] と :ui[appearance.dark] は、macOS の設定にかかわらず変わりません。

リポジトリのウインドウでは、[クイックアクション](/guide/repositories/navigation/#quick-actions) からも切り替えられます。外観を探して、:ui[quickActions.setAppearance] を実行します。

## アプリケーションアイコン {#app-icon}

外観の下の :ui[settings.appIcon.label] には、選べるアイコンが 2 つのシリーズに分かれて並びます。

| シリーズ | アイコン |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise]（デフォルト）、:ui[appIcon.front]、:ui[appIcon.hide]、:ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight]、:ui[appIcon.perch]、:ui[appIcon.cherryPick]、:ui[appIcon.armful] |

アイコンにポインタを合わせると、左側に大きく表示されます。その下には、Dock での 4 通りの見え方が並びます。そのまま、サーバーに接続中、ダーク、ダークで接続中です。アイコンをクリックすると、そのアイコンを使います。アイコンにキーボードフォーカスがあるときは、矢印キーでアイコンの間を移動でき、<kbd>スペース</kbd> でいまのアイコンを使います。

新しいアイコンは、Dock、アプリケーションスイッチャー（<kbd>⌘Tab</kbd>）、Finder に表示されます。Spooky が起動していない間も同じです。知っておくとよい点がいくつかあります。

- サーバーリポジトリが接続されている間、アイコンが光ります。:ui[appIcon.series.hideAndSeek] のアイコンでは、サーバーのランプが点きます。:ui[appIcon.series.cherryPick] のアイコンでは、幽霊の目が光る星に変わります。
- ダーク版が表示されるのは、**システム設定 › 外観** のアイコンとウィジェットのスタイルがダークのとき、または自動で Spooky がダークのときです。クリアまたは色合い調整のスタイルでは、アイコンは光りません。
- :ui[appIcon.rise] との間で切り替えるときは、Dock が一度再起動します。そうしないと、Dock に追加してある Spooky が古いアイコンのままになります。
- ほかのアイコンは、Spooky が `Spooky.app` の中に保存します。そこに書き込めないときは、ページに理由が表示され、アイコンは変わりません。

## テーマ {#themes}

テーマは、差分とファイルの内容に使うフォントと色を決めます。Spooky には 2 つのテーマが付属しています。ライトの外観用の Default と、ダークの外観用の Default (Dark) です。

一覧で選択されているテーマが、現在の外観で使われるテーマです。ライトとダークは、それぞれ自分のテーマを覚えています。もう一方の外観のテーマを設定するには、先にその外観に切り替えます。クイックアクションでも、:ui[quickActions.applyTheme] でテーマを切り替えられます。

::screenshot[設定ウインドウの「テーマ」ページ。左の一覧には Default と Default (Dark) があり、Default が選択されています。一覧の下部には追加と削除のボタンがあります。右側には、Menlo-Regular 11.0 と表示されたフォントのフィールド、プレーンテキスト、キーワード、文字列、コメントなどテキストの種類がそれぞれの色で並ぶ一覧、「フォントカラー」「背景」「選択範囲」「追加」「削除」のカラーウェルがあります。その下には、変更なし、削除、追加の行がある短い差分のプレビューがあります。]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 66.7,56.9 61.1,82.7"}

1. テーマの一覧
2. :ui[themes.add] と :ui[themes.remove]
3. フォント
4. シンタックスカラーリングが区別するテキストの種類
5. カラーウェル
6. このテーマでの差分のプレビュー

### テーマを作成して編集する {#edit-theme}

1. 一覧の下の追加ボタンをクリックします。Spooky が :ui[themes.newName] を追加し、名前を選択した状態にします。色は、現在の外観の内蔵テーマと同じです。
2. 名前を入力して <kbd>Return</kbd> を押します。
3. フォントのフィールドをクリックして、フォントパネルでフォントとサイズを選びます。
4. 一覧でテキストの種類を選択し、:ui[themes.text] をクリックして色を変更します。:ui[themes.background]、:ui[themes.selection]、:ui[themes.added]、:ui[themes.deleted] は、テキストのまわりの色を設定します。

変更はすぐに保存されます。プレビューにもその場で反映されます。あとでテーマの名前を変更するには、選択して <kbd>Return</kbd> を押します。

内蔵テーマは編集できますが、名前の変更と削除はできません。ほかのテーマを削除するには、選択して削除ボタンをクリックします。取り消せないので、Spooky が先に確認します。そのテーマを使っていた外観は、内蔵テーマに戻ります。

### テーマを共有する {#share-themes}

各テーマは 1 つの `.spookytheme` ファイルです。

- **書き出し**：一覧から Finder のフォルダにテーマをドラッグします。
- **読み込み**：`.spookytheme` ファイルを一覧にドラッグします。Finder から開くことも、Dock の Spooky のアイコンにドロップすることもできます。

同じ名前のテーマがあるときは、置き換えるかどうかを Spooky が尋ねます。有効なテーマではないファイルは、メッセージを表示してスキップします。

Spooky はテーマを `~/Library/Application Support/Spooky/Themes/` に保存します。[データとプライバシー](/reference/data-privacy/#mac) を参照してください。

## テキスト {#text}

:ui[settings.text] ページでは、差分とファイルの内容でのテキストの見え方を設定します。色はテーマから取ります。

| 設定 | デフォルト | 内容 |
|---|---|---|
| :ui[text.enableSyntaxColoring] | オン | コードを言語に合わせて色分けします |
| :ui[text.syntaxColoringInDiffs] | オフ | 差分でもシンタックスカラーを使います。シンタックスカラーリングがオンである必要があります。 |
| :ui[text.showInvisibles] | オフ | スペース、タブ、行末を記号で表示します |
| :ui[text.tabWidth] | 4 | タブの幅。スペース 1〜100 個分 |

## エディタ {#editor}

:ui[settings.editor] ページでは、コミットメッセージのフィールドを設定します。フィールドの動作は [メッセージを書く](/guide/work/commit/#write) を参照してください。

| 設定 | デフォルト | 内容 |
|---|---|---|
| :ui[editor.showsCounter] | オン | 件名の残りの文字数をカウントダウンします |
| :ui[editor.subjectLimit] | 50 | 件名の長さの目安（文字数）。値を選ぶか、1〜1,000 の値を入力します。 |
| :ui[editor.wrapping] | :ui[editor.softWrap] | または :ui[editor.hardWrap]。等幅フォントで、自動では折り返しません |
| :ui[editor.bodyLimit] | 72 | :ui[editor.hardWrap] での 1 行の上限 |
| :ui[editor.showsGuide] | オン | :ui[editor.hardWrap] のとき、その上限の位置に線を引きます |
| :ui[editor.warnsComments] | オン | Git がコメントとして扱う行を警告します。[メッセージ内のコメント](/guide/work/commit/#comments) を参照してください。 |
| :ui[editor.stripsComments] | オフ | コミット時にそれらの行を取り除きます。警告がオフのときに使えます。 |
| :ui[editor.completesIssues] | オン | `#` のあとに Issue 番号を補完します。[自動補完](/guide/work/commit/#autocomplete) を参照してください。 |

## 関連ページ

- [一般、アップデート、環境](/guide/settings/general/)
- [変更を確認してステージする](/guide/work/diff/)
- [変更をコミットする](/guide/work/commit/)
- [ウインドウとナビゲーション](/guide/repositories/navigation/)

---
title: "Spooky の画面構成"
description: "リポジトリウインドウと各リポジトリのウインドウ（サイドバー、ツールバー、3 つのカラム、クイックアクション）を紹介します。"
---

Spooky のウインドウが表示するものは 2 種類あります。「リポジトリ」ビューはリポジトリの一覧です。リポジトリのウインドウは実際の作業をする場所です。このページでは両方の各部分の名前を紹介します。ガイドのほかのページでもこの名前を使います。

## リポジトリウインドウ {#repositories-window}

Spooky を初めて開くと、「リポジトリ」ビューが表示されます。サイドバーの :ui[repositories.title] の下にリポジトリが並びます。リポジトリはグループに分けて整理できます。

- リポジトリを選択すると、右側に詳細が表示されます。場所、最後に開いた日時、最後のコミット、現在のブランチと変更、リモートです。
- グループを選択するか何も選択しないと、:ui[bookmarks.dropZone.title] と書かれた領域が表示され、:ui[bookmarks.dropZone.add]、:ui[action.addRemote]、:ui[bookmarks.dropZone.create]、:ui[bookmarks.dropZone.clone] のボタンが並びます。
- サイドバー下部の追加ボタンで、グループやリポジトリを追加できます。

リポジトリをダブルクリックすると開きます。同じウインドウの中で、「リポジトリ」ビューに代わって表示されます。一覧に戻るには、サイドバー上部の :ui[toolbar.bookmarks] をクリックします。一覧について詳しくは [リポジトリウインドウ](/guide/repositories/manager/) を参照してください。

## リポジトリのウインドウ {#repository-window}

リポジトリを開くと、ウインドウのタイトルにその名前が表示されます。名前の下には、現在のビューと、ブランチや変更されたファイルの数などの短い要約が表示されます。

::screenshot[リポジトリのウインドウ。左のサイドバーにはリポジトリのビュー、ブランチ、タグ、リモートが並びます。上部にはツールバーがあります。中央のカラムにはコミットエリアと、その下に変更されたファイルの一覧が表示され、右のカラムには選択したファイルの変更が表示されています。]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. サイドバー
2. ツールバー
3. 中央のカラム：現在のビューの一覧
4. 右のカラム：中央のカラムで選択したものの詳細

:::note[サーバリポジトリ]
ウインドウのタイトルは `alias:name` のようにホストエイリアスで始まります。ツールバーの :ui[toolbar.host] 項目にもホストエイリアスが表示されます。接続が切れたときのウインドウの表示は [接続状態と再接続](/guide/server/connection/) で説明しています。
:::

### サイドバー {#sidebar}

いちばん上の :ui[workspace.group] セクションで、リポジトリのビューを切り替えます。

| ビュー | 表示される内容 |
|---|---|
| :ui[workspace.title] | まだコミットしていない変更。横の数字は変更されたファイルの数です。 |
| :ui[history.title] | コミット |
| :ui[stash.title] | 退避しておいた変更 |
| :ui[pr.title] | ホスティングサービスのプルリクエストまたはマージリクエスト |
| :ui[review.title] | ブランチの一覧。整理できるブランチを見つけられます。 |
| :ui[reflog.title] | HEAD がたどってきた位置。:ui[sidebar.viewSettings] で :ui[sidebar.showReflog] をオンにすると表示されます。 |
| :ui[repositorySettings.title] | このリポジトリの設定。[リポジトリの設定](/guide/settings/identity/#repository) を参照してください。 |

その下に、:ui[sidebar.pinned]（ブランチをピン留めすると表示されます）、:ui[branch.group]、:ui[sidebar.archived]、:ui[sidebar.tags]、:ui[remote.group]、:ui[submodule.group]、:ui[worktree.group] が続きます。:ui[branch.group] では、現在のブランチに HEAD バッジが付きます。↑3 のような矢印と数字は、まだプッシュしていないコミットの数です。

サイドバー下部のバーには、:ui[sidebar.filter] フィールド、ブランチなどの参照を作成する :ui[reference.addMenu] ボタン、サイドバーに表示する内容を選ぶ :ui[sidebar.viewSettings] があります。

### ツールバー {#toolbar}

ツールバーには、左から順に次のボタンがあります。

- :ui[toolbar.bookmarks]：「リポジトリ」ビューに戻ります
- :ui[toolbar.previous] と :ui[toolbar.next]：表示したビューの間を戻ったり進んだりします
- :ui[toolbar.finder] と :ui[toolbar.terminal]：リポジトリのフォルダを Finder に表示するか、ターミナルで開きます
- :ui[sync.fetch]、:ui[sync.pull]、:ui[sync.push]：リモートとコミットをやり取りします
- :ui[toolbar.forcePush]：コミットを書き換えたあと、リモートブランチを自分のブランチで置き換えます
- :ui[toolbar.applyStash] と :ui[toolbar.saveStash]：退避しておいた変更を戻すか、現在の変更を退避します
- :ui[toolbar.createBranch]：新しいブランチを作ります
- :ui[action.refresh]：リポジトリを読み込み直します
- :ui[action.search]：現在のビューの一覧を絞り込みます

<kbd>⌥</kbd> を押している間、:ui[sync.fetch]、:ui[sync.pull]、:ui[sync.push] は :ui[sync.quickPush] のようなクイック版に変わります。クイック版はダイアログを開かずに、すぐ追跡ブランチに対して実行します。

:ui[toolbar.clone] は、最近のクローンがある間だけ表示されます。[リポジトリウインドウ](/guide/repositories/manager/) を参照してください。ボタンを追加または削除するには、:ui[menu.view > menu.customizeToolbar] を選びます。上のボタンのほかに、:ui[toolbar.quickActions]、:ui[toolbar.synchronize]、:ui[sync.merge] と :ui[sync.rebaseHead]、:ui[toolbar.pushTo] を追加できます。

### 3 つのカラム {#columns}

左のカラムはサイドバーです。中央のカラムには、選んだビューの一覧が表示されます。:ui[workspace.title] ではコミットエリアと変更されたファイル、:ui[history.title] ではコミットです。

右のカラムには、中央で選択したものの詳細が表示されます。:ui[workspace.title] では、選択したファイルの変更です。ファイルにステージ済みの変更と未ステージの変更の両方があるときは、上部の :ui[working.staged] と :ui[working.unstaged] で切り替えます。何も選択していないときは :ui[detail.empty.title] と表示されます。

### 狭いウインドウ {#narrow-window}

ウインドウが狭くなって 3 つのカラムが収まらなくなると、狭いウインドウ用のレイアウトに切り替わります。ウインドウを広げると 3 つのカラムに戻り、幅も元のままです。

::screenshot[狭いリポジトリのウインドウ。ツールバーの下の行でビューを切り替えます。コミットエリアと変更されたファイルの一覧が上に、選択したファイルの変更が下に表示されています。]{name="tour-narrow-window" frame="window" markers="75,9 75,40 75,84"}

1. ビューを切り替える行：サイドバーの代わり
2. 現在のビューの一覧
3. 一覧で選択したものの詳細

- ビューを切り替える行には :ui[workspace.title]、:ui[history.title]、:ui[stash.title] があります。ブランチ、タグ、リモート、ほかのビューを使うときは、行の先頭の :ui[sidebar.menu] をクリックします。サイドバーがビューの上に重なって開きます。もう一度 :ui[sidebar.menu] をクリックするか、サイドバーの外をクリックすると閉じます。
- 一覧が上、詳細が下に並びます。間の線をドラッグすると、それぞれの高さを変えられます。
- ツールバーに収まらないボタンは、末尾の » メニューに入ります。:ui[sync.fetch]、:ui[sync.pull]、:ui[sync.push] はツールバーに残ります。

レイアウトが切り替わっても、表示しているビュー、選択、書きかけのコミットメッセージはそのままです。

### クイックアクション {#quick-actions}

:ui[menu.file > quickActions.menu] を選ぶか <kbd>⇧⌘A</kbd> を押すと、パネルが開きます。入力してビュー、ブランチ、ファイル、コミットを探し、キーボードから手を離さずにアクションを実行できます。何が見つかるか、どのキーを使うかは [ウインドウとナビゲーション](/guide/repositories/navigation/) で説明しています。

## 関連ページ

- [最初のリポジトリ](/guide/start/first-repository/)
- [リポジトリウインドウ](/guide/repositories/manager/)
- [ウインドウとナビゲーション](/guide/repositories/navigation/)

---
title: "ウインドウとナビゲーション"
description: "ウインドウとタブ、戻ると進む、クイックアクション、ウインドウの復元、Dock メニュー、spooky:// リンクについて説明します。"
---

このページでは、Spooky の中を移動する方法を説明します。複数のリポジトリを開いたままにする、ビューの間を移動する、クイックアクションで目的の場所に移動する、前回の続きから始める、といった方法です。

## ウインドウとタブ {#windows}

各ウインドウまたはタブには、「リポジトリ」ビューか 1 つのリポジトリが表示されます。

- :ui[menu.file > menu.newTab]（<kbd>⌘T</kbd>）は、「リポジトリ」ビューの新しいタブを開きます。タブバーの末尾の追加ボタンも同じです。
- :ui[menu.file > menu.newWindow]（<kbd>⌘N</kbd>）は、「リポジトリ」ビューの新しいウインドウを開きます。
- :ui[menu.view > menu.showRepositories]（<kbd>⌃⌘R</kbd>）は、現在のウインドウに「リポジトリ」ビューを表示します。

リポジトリがすでに開いているときは、もう一度開くと、それを表示しているウインドウに切り替わります。それでも 2 つ目のウインドウで開くには、「リポジトリ」の一覧で右クリックして :ui[bookmarks.openNewWindow]{1="driftwood"} を選びます。

### ビューを切り替える {#views}

:ui[menu.view] メニューで、リポジトリのビューを切り替えます。

| ショートカット | メニュー項目 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title]（<kbd>⌃⌘0</kbd>）は、アクティビティウインドウを開きます。Spooky が実行した操作と実行中の操作が並びます。[操作のキューとアクティビティ](/guide/advanced/queue-activity/) を参照してください。

## 戻ると進む {#back-forward}

各ウインドウは、表示したビューとリポジトリを覚えています。「リポジトリ」ビューも含まれます。たどり直すには、次のようにします。

- :ui[menu.view > navigation.back]（<kbd>⌘[</kbd>）またはツールバーの :ui[toolbar.previous]
- :ui[menu.view > navigation.forward]（<kbd>⌘]</kbd>）またはツールバーの :ui[toolbar.next]

戻ったあとで新しいものを開くと、進めるはずだった場所は破棄されます。

## クイックアクション {#quick-actions}

クイックアクションでは、入力して目的のものを探し、キーボードから手を離さずに操作できます。リポジトリを表示している間に使えます。:ui[menu.file > quickActions.menu]（<kbd>⇧⌘A</kbd>）を選ぶか、ツールバーの :ui[toolbar.quickActions] をクリックします。

::screenshot[リポジトリのウインドウの上に開いたクイックアクション。「dark」と入力されています。最初の結果であるブランチ feature/dark-mode が選択されていて、デフォルトのアクションと、ほかのアクションを表示するためのヒントが表示されています。その下に、リモートブランチ origin/feature/dark-mode、ダークの外観、Default (Dark) テーマ、メッセージに dark を含む 2 つのコミットが並んでいます。]{name="quick-actions" frame="window"}

何も入力していないとき、パネルにはリポジトリのビューが並び、続いてブランチ（現在のブランチが先頭）、ワークツリー、リモート、サブモジュール、リモートブランチ、タグ、スタッシュ、ユーザプロファイル、外観とテーマが並びます。入力すると、一覧が絞り込まれます。Spooky は次のものも探します。

- 現在のブランチにある、名前が一致するファイル
- コミット。ハッシュのうち 5〜64 文字の 16 進数を入力したとき
- 現在のブランチにある、メッセージにそのテキストを含むコミット。最大 100 個

ファイルとコミットは、入力を止めて少しすると、一覧の末尾に表示されます。

パネルでは次のキーを使います。

| キー | 内容 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 選択を移動します |
| <kbd>↩</kbd> | 選択した項目のデフォルトのアクションを実行します |
| <kbd>Tab</kbd>、またはテキストの末尾で <kbd>→</kbd> | 選択した項目のすべてのアクションを表示します |
| テキストがないときの <kbd>←</kbd>、または <kbd>⇧Tab</kbd> | アクションの一覧から戻ります |
| <kbd>Esc</kbd> | テキストを消去します。テキストがないときは、アクションの一覧から戻るか、パネルを閉じます |

表示されるのは、いま実行できるアクションだけです。

## 前回の続きから始める {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration] で、Spooky の起動時に表示するものを決めます。

| 選択肢 | Spooky の起動時 |
|---|---|
| :ui[settings.windowRestoration.always] | ウインドウとタブを開き直します。それぞれ、終了時に表示していたリポジトリとビューが表示されます。 |
| :ui[settings.windowRestoration.never] | リポジトリウインドウだけを表示します |
| :ui[settings.windowRestoration.system] | アプリケーションの終了時にウインドウを保持するかどうかの macOS の設定に従います。これがデフォルトです。 |

復元したリポジトリが見つからなくなっているときは、ウインドウにその旨が表示されます。[見つからないリポジトリ](/guide/repositories/manager/#missing) を参照してください。

:ui[settings.showLaunchWindow] をオンにすると、起動時に最近使ったリポジトリを並べたウインドウが表示されます。リポジトリをダブルクリックするか、選択して <kbd>↩</kbd> を押すと開きます。リポジトリのウインドウが手前に表示されると、このウインドウは自動的に閉じます。どちらの設定も [ウインドウとリポジトリ一覧](/guide/settings/general/#windows) を参照してください。

:::note[サーバーリポジトリ]
復元したサーバーリポジトリは、Spooky の起動時にサーバーにもう一度接続します。
:::

## 最近使ったリポジトリと Dock {#recent}

:ui[menu.file > menu.openRecent] には、この Mac 上とサーバー上の、最近開いたリポジトリが並びます。いちばん下の :ui[menu.clearRecent] は一覧を空にします。リポジトリウインドウのブックマークはそのまま残ります。

**Dock** の Spooky のアイコンを右クリックすると、:ui[menu.newWindow] と最近使ったリポジトリのメニューが表示されます。リポジトリを選ぶと開きます。Spooky がまだ起動していなくても使えます。

Dock の Spooky のアイコンにフォルダをドロップして、そのフォルダがあるリポジトリを開くこともできます。フォルダが Git リポジトリの中にないときは、Spooky がリポジトリの作成を提案します。

## リンクから Spooky を開く {#links}

`spooky://` で始まるリンクは、リポジトリまたはクローンを開きます。こうしたリンクは、ほかのアプリケーション、スクリプト、メモに入れておけます。

### リポジトリを開く {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository` は必須です。この Mac 上のリポジトリの絶対パス、またはサーバーリポジトリの `alias:path` を、URL エンコードして指定します。
- `view` は省略できます。省略すると、リポジトリは最後に表示していたビューで開きます。
- `view` の代わりに使える短い書き方が 2 つあります。`branch=<name>` はそのブランチの履歴を開き、`commit=<hash>` はそのコミットを開きます。

| `view` | 開くもの | 追加のパラメータ |
|---|---|---|
| `workingCopy` | 作業コピー | |
| `history` | 履歴 | `ref=<reference>`。`refs/heads/main` のような完全な参照名で、繰り返し指定できます |
| `commit` | コミット | `commit=<hash>` |
| `stashes` | スタッシュ | |
| `reflog` | reflog | |
| `pullRequests` | プルリクエストまたはマージリクエスト | |
| `branchesReview` | ブランチの整理 | |
| `settings` | リポジトリの設定 | |
| `remote` | リモート | `remote=<name>` |
| `submodule` | サブモジュール | `path=<path>` |
| `worktree` | ワークツリー | `path=<path>` |
| `fileHistory` | ファイルの履歴 | `path=<path>` |
| `file` | ファイル | `path=<path>`。必要に応じて `revision=<revision>` と、`mode=blame` または `mode=raw` |

たとえば次のリンクは、`/Volumes/Projects/driftwood` にあるリポジトリで、ブランチ `main` の履歴を開きます。

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### リポジトリをクローンする {#link-clone}

```
spooky://clone?url=<address>
```

アドレスが入力された状態で、クローンのダイアログが開きます。保存先を選んで :ui[clone.submit] をクリックするまで、クローンは始まりません。[リポジトリをクローンする](/guide/repositories/manager/#clone) を参照してください。

:ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github] を Spooky に設定すると、github.com にある、リポジトリをデスクトップアプリケーションで開くリンクも、このクローンのダイアログを開きます。[github.com からのリンク](/guide/settings/integration/#github-links) を参照してください。

使えないリンクもあります。たとえば、不明なビューを指定したリンクや、相対パスを指定したリンクです。この場合、Spooky は :ui[link.invalid.title] と表示するだけで、ほかには何もしません。

## 関連ページ

- [Spooky の画面構成](/guide/start/tour/)
- [リポジトリウインドウ](/guide/repositories/manager/)
- [キーボードショートカット](/reference/shortcuts/)

---
title: "リポジトリウインドウ"
description: "リポジトリのブックマーク、グループ分け、オープン、クローン、作成、検索、削除と、見つからなくなったリポジトリの確認について説明します。"
---

リポジトリウインドウには、この Mac 上とサーバ上の、作業に使うリポジトリが一覧で並びます。各項目はリポジトリを指すブックマークです。ブックマークを削除しても、リポジトリのフォルダはそのまま残ります。フォルダをゴミ箱に入れるかどうかは別に選びます。このページでは、リポジトリの追加、整理、オープン、削除を説明します。

リポジトリから一覧に移動するには、ツールバーの :ui[toolbar.bookmarks] をクリックするか、:ui[menu.view > menu.showRepositories]（<kbd>⌃⌘R</kbd>）を選びます。

::screenshot[リポジトリウインドウ。サイドバーには Driftwood Labs と Notes の 2 つのグループがあり、その中にリポジトリが並んでいます。そのうち 1 つはサーバリポジトリで、名前がホストエイリアスで始まっています。右側には、選択したリポジトリ driftwood の詳細が表示されています。場所、最後に開いた日時、最後のコミット、説明、コミッタの ID、現在のブランチ、変更されたファイルの数、リモートです。]{name="repositories" frame="window"}

## リポジトリを追加する {#add}

サイドバー下部の追加ボタンには、一覧に追加するためのメニューがあります。

| メニュー項目 | 内容 |
|---|---|
| :ui[bookmarks.newGroup] | 選択している項目の下にグループを追加します。そのまま名前を入力できます。 |
| :ui[bookmarks.add] | すでに Mac 上にあるリポジトリを追加します。複数のフォルダを一度に選択できます。 |
| :ui[action.addRemote] | サーバ上のリポジトリを追加します。[サーバリポジトリを追加する](/guide/server/add/) を参照してください。 |
| :ui[bookmarks.create] | 空のリポジトリを作成します。[リポジトリを作成する](#create) を参照してください。 |
| :ui[clone.menu] | リモートからリポジトリをコピーします。[リポジトリをクローンする](#clone) を参照してください。 |
| :ui[scan.menu] | フォルダの中にあるリポジトリを探します。[リポジトリを検索する](#scan) を参照してください。 |

新しい項目は、選択しているグループに入ります。Finder からリポジトリのフォルダを一覧にドラッグすることもできます。:ui[menu.file > action.openLocal] で開いたリポジトリがまだ一覧にないときは、末尾に追加されます。

### リポジトリを作成する {#create}

1. 追加ボタンのメニューから :ui[bookmarks.create] を選びます。
2. :ui[bookmarks.create.name] に新しいリポジトリの名前を入力します。これがフォルダの名前にもなります。
3. :ui[bookmarks.create.location] の横の :ui[bookmarks.create.choose] をクリックして、作成先のフォルダを選びます。最初はホームフォルダになっています。
4. :ui[bookmarks.create.submit] をクリックします。

Spooky がフォルダを作成して空の Git リポジトリにし、選択しているグループに追加して開きます。

### リポジトリをクローンする {#clone}

クローンは、リポジトリとその履歴をリモートから新しいフォルダにコピーします。

1. 追加ボタンのメニューから :ui[clone.menu] を選ぶか、<kbd>⌃⌘C</kbd> を押します。
2. :ui[clone.url] にリポジトリのアドレスを入力します。たとえば `https://` や `git@` で始まるアドレスです。
3. :ui[clone.to] で :ui[clone.machine.local] またはサーバを選びます。すでに使っているサーバは一覧に並んでいます。ほかのサーバを使うときは、:ui[clone.machine.other] を選んで :ui[remote.host] を入力します。
4. :ui[clone.directory] でクローン先のフォルダを選びます。Spooky はその中に、リポジトリと同じ名前のフォルダを作成します。
5. リポジトリのサブモジュールもチェックアウトするときは、:ui[clone.submodules] を選択したままにします。リポジトリが大きなファイルを Git LFS で管理しているときは、:ui[clone.lfs] を選択します。
6. :ui[clone.submit] をクリックします。

Spooky はまず、リモートにアクセスできるかを確認します。できないときは、ダイアログが開いたまま理由が表示されます。アドレスを直してもう一度試してください。アクセスできたときは、ダイアログが閉じ、クローンがバックグラウンドで進みます。進行状況は、一覧のそのリポジトリの行に表示されます。クローンが終わると、Spooky が :ui[clone.notification.title] の通知を出します。

この Mac 上では、フォルダは最初ホームフォルダになっています。:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory] でフォルダを設定していれば、そのフォルダになります。[クローンとターミナル](/guide/settings/general/#cloning) を参照してください。

最近のクローンがある間は、ツールバーに :ui[toolbar.clone] が表示されます。クリックすると :ui[clone.recent.title] が表示されます。ここでは、実行中のクローンを停止したり、失敗またはキャンセルしたクローンを :ui[clone.retry] でやり直したり、:ui[clone.remove] で一覧から取り除いたりできます。完了したクローンはダブルクリックで開けます。:ui[clone.recent.clear] は一覧を空にします。

:::note[サーバリポジトリ]
サーバにクローンするときは、Spooky が接続を確認し、サーバ上でクローンを実行します。新しいリポジトリはサーバリポジトリとして追加されます。フォルダは、サーバ上の絶対パスを入力するか、:ui[clone.browse] をクリックして選びます。Spooky は、サーバごとに最後に使ったフォルダを覚えています。
:::

リポジトリのアドレスを一覧にドラッグしてクローンを始めることもできます。リンクから始めることもできます。[ウインドウとナビゲーション](/guide/repositories/navigation/) を参照してください。

### リポジトリを検索する {#scan}

1. 追加ボタンのメニューから :ui[scan.menu] を選びます。
2. :ui[scan.in] で :ui[clone.machine.local] またはサーバを選び、検索するフォルダを選びます。
3. :ui[scan.start] をクリックします。Spooky が見つけたリポジトリから順に表示されます。止めるには :ui[scan.stop] をクリックします。
4. 見つかったリポジトリはすべて選択されています。不要なものの選択を解除して、:ui[scan.add] をクリックします。

すでに一覧にあるリポジトリは表示されません。複数のフォルダやサーバを続けて検索できます。結果は足されていきます。

## 一覧を整理する {#organize}

- グループを追加するには、追加ボタンのメニューから :ui[bookmarks.newGroup] を選び、名前を入力します。
- 項目を並べ替えたり別のグループに移したりするには、ドラッグします。
- 項目の名前を変更するには、選択して <kbd>↩</kbd> を押すか、右クリックして :ui[bookmarks.rename] を選びます。一覧でリポジトリの名前を変更しても、フォルダの名前は変わりません。
- 名前順に並べ替えるには、右クリックして、グループの中の項目を並べ替える :ui[bookmarks.sortChildren] か、項目が入っているグループを並べ替える :ui[bookmarks.sortParent] を選びます。

:ui[app.name > settings.title] › :ui[settings.general] の 2 つのオプションで、一覧に表示する内容を変えられます。

- :ui[settings.showWorktreesInRepositoryList]：ほかのワークツリーがあるリポジトリを展開して、ワークツリーを表示できます。ワークツリーはリポジトリと同じ方法で開けます。デフォルトでオフです。
- :ui[settings.showHostAliasesInRepositoryList]：サーバリポジトリの名前がホストエイリアスで始まります。デフォルトでオンです。

[ウインドウとリポジトリ一覧](/guide/settings/general/#windows) を参照してください。

## リポジトリを開く {#open}

リポジトリをダブルクリックします。同じウインドウの中で、一覧に代わって表示されます。リポジトリがすでに別のウインドウで開いているときは、そのウインドウが手前に表示されます。

リポジトリを右クリックすると、ほかの操作も選べます。

- :ui[bookmarks.open]{1="driftwood"} と :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder]、:ui[action.copyPath]、:ui[action.openTerminal]

右側の詳細にも :ui[action.open] と :ui[bookmarks.multiple.delete] のボタンがあります。そこで :ui[bookmarks.detail.edit] をクリックすると、:ui[bookmarks.detail.description] と :ui[bookmarks.detail.identity] を変更できます。:ui[bookmarks.detail.unset] は、このリポジトリだけに設定した情報を取り除きます。各リモートの横の :ui[bookmarks.detail.viewInBrowser] は、その Web ページを開きます。説明とコミッタの ID は、[リポジトリの設定](/guide/settings/identity/#repository) に表示されるものと同じです。

:::note[サーバリポジトリ]
:ui[action.copyPath] は、`alias:/path/to/repository` のように、先頭にホストエイリアスを付けたパスをコピーします。Spooky がサーバリポジトリの詳細を読み込むのは、選択したときだけです。選択すると、サーバに接続することがあります。
:::

## 見つからないリポジトリ {#missing}

リポジトリのフォルダが移動、名称変更、または削除されると、一覧の名前がグレーになり、警告マークが付きます。詳細には :ui[bookmarks.detail.missing] と表示されます。Spooky は、一覧が表示されるたびに Mac 上のリポジトリを確認します。

見つからないリポジトリを開くと、ウインドウに :ui[missing.title] と表示されます。ディスクを接続し直したあとなどは、:ui[action.refresh] をクリックするともう一度確認します。:ui[action.close] をクリックすると一覧に戻ります。

項目を直すには、いったん削除して、いまの場所からリポジトリを追加し直します。

:::note[サーバリポジトリ]
Spooky がサーバリポジトリを確認するのは、選択したときと開いたときだけです。サーバにアクセスできないときは、ウインドウに :ui[missing.unreachable.title]{1="alias"} と表示され、SSH が報告した内容も表示されます。[接続状態と再接続](/guide/server/connection/) を参照してください。
:::

## リポジトリを削除する {#delete}

1 つ以上の項目を選択して、次のいずれかを行います。

- <kbd>⌫</kbd> を押します。
- 右クリックして :ui[bookmarks.delete]{1="driftwood"} を選びます。グループの場合は :ui[bookmarks.deleteFolder]、複数の項目の場合は :ui[bookmarks.deleteMultiple]{1="2"} です。
- 詳細の :ui[bookmarks.multiple.delete] をクリックします。

リポジトリのフォルダがまだあるときは、Spooky が先に :ui[bookmarks.delete.title]{1="driftwood"} と確認します。削除されるのはブックマークだけです。フォルダはそのまま残ります。フォルダもゴミ箱に入れるには、:ui[bookmarks.delete.trash] を選択します。:ui[bookmarks.delete.submit] をクリックして確定します。

空のグループと、フォルダがなくなっている項目は、確認なしですぐに削除されます。

:::caution
ゴミ箱に入れると、まだコミットしていない変更も含めて、リポジトリのフォルダ全体が移動します。ゴミ箱を空にするまでは元に戻せます。ゴミ箱のチェックボックスは、ダイアログを開くたびに選択が解除されます。
:::

フォルダを移動できなかったときは、Spooky が :ui[bookmarks.trashFailed.title] と表示し、残ったフォルダを一覧にします。ホームフォルダ、ホームフォルダを含むフォルダ、ディスクの最上位を Spooky がゴミ箱に入れることはありません。

:::note[サーバリポジトリ]
サーバリポジトリを削除するときは、Spooky が必ず確認します。フォルダは Mac ではなく、そのサーバのゴミ箱に入ります。フォルダがすでにサーバにないときは、ゴミ箱のチェックボックスは選択できず、ブックマークだけが取り除かれます。
:::

## 関連ページ

- [ウインドウとナビゲーション](/guide/repositories/navigation/)
- [サーバリポジトリを追加する](/guide/server/add/)
- [ワークツリー](/guide/advanced/worktrees/)

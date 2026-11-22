---
title: "ブランチ"
description: "ブランチの作成、チェックアウト、追跡、名前の変更、削除、ピン留め、アーカイブ、親ブランチの設定と、サイドバーでのブランチのフィルタとグループ化。"
---

ローカルブランチはサイドバーの :ui[branch.group] の下に並びます。ブランチの操作はたいていここから始めます。右クリックしてメニューを開くか、別の場所へドラッグします。

::screenshot[サイドバーの下半分。ブランチの下では、main に HEAD バッジと ↑3 が付き、feature フォルダに dark-mode、station-map、units-toggle が入っています。アーカイブ済みブランチは空です。タグには v0.1.0 から v0.4.0 が並んでいます。リモートの下では、origin に家のアイコンが付いた main と、閉じた feature フォルダがあります。下端のバーは左がフィルタフィールド、右が追加ボタンと表示設定ボタンです。]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. 現在のブランチ。HEAD バッジと、まだプッシュしていないコミットの数が付きます
2. 名前が `feature/` で始まるブランチをまとめたフォルダ
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. 追加ボタンと表示設定ボタン

## サイドバーで {#sidebar}

ブランチをクリックすると、そのコミットが履歴に表示されます。ダブルクリックするとチェックアウトします。

リモートブランチを追跡しているブランチには、両者の差が表示されます。↑ はリモートにまだない自分のコミットの数です。↓ は自分がまだ持っていないリモートのコミットの数です。ブランチにポインタを合わせると、何を追跡しているかがわかります。

しばらく新しいコミットがないブランチは、古いブランチです。名前が薄くなり、時計と経過した期間が後ろに付きます。`main`、`master`、`trunk`、`dev`、`develop`、`next` と、ほかのブランチの親になっているブランチは、古いブランチになりません。

:ui[remote.group] の下では、家のアイコンが各リモートのデフォルトブランチを示します。

## ブランチを作成する {#create}

1. :ui[menu.repository > branch.createMenu]（<kbd>⌘B</kbd>）を選びます。サイドバー下部の追加ボタンをクリックするか、:ui[branch.group] を右クリックして、メニューから選ぶこともできます。
2. :ui[reference.name] に名前を入力します。
3. :ui[branch.start] でブランチの開始位置を選びます。最初は現在のブランチか、ここへ来るときに右クリックした項目になっています。
4. オプションを設定します。
   - :ui[branch.trackStart] は、新しいブランチに開始位置を追跡させます。開始位置がブランチのときだけ使えます。
   - :ui[branch.pin] は、新しいブランチを :ui[sidebar.pinned] の下に置きます。
   - :ui[branch.checkoutCreated] は、すぐに新しいブランチへ切り替えます。Spooky はこの選択を覚えています。
   - :ui[branch.parentOption] は、開始位置を新しいブランチの [親](#parent) に設定します。
5. :ui[branch.create] をクリックします。

特定のブランチ、タグ、コミットからブランチを始めるには、それを右クリックしてメニューから :ui[branch.createFromMenu]{1="main"} を選びます。:ui[branch.group] へドラッグすることもできます。

入力している間、Spooky は名前を Git に合わせて直します。スペースと Git が受け付けない文字は `-` に変わるか、取り除かれます。入力したとおりの名前にするには、:ui[app.name > settings.title] › :ui[settings.general] で :ui[branch.cleanNames] をオフにします。[操作](/guide/settings/general/#operations) を参照してください。

名前に `/` があると、ブランチはフォルダに入ります。たとえば `feature/units-toggle` は `feature` に入ります。フォルダを右クリックしてメニューから :ui[branch.createMenu] を選ぶと、名前の先頭にそのフォルダが入った状態で始まります。

## ブランチをチェックアウトする {#checkout}

ブランチをダブルクリックするか、右クリックしてメニューから :ui[branch.checkoutNamed]{1="feature/dark-mode"} を選びます。

リモートブランチもダブルクリックできます。

- すでに追跡しているローカルブランチがあれば、Spooky はそのブランチをチェックアウトします。
- 同じ名前のローカルブランチがあり、それがリモートブランチを追跡していなければ、Spooky は先に :ui[branch.trackExisting.title] で確認します。そのあと、そのブランチをチェックアウトして、リモートブランチを追跡させます。
- どちらでもなければ、Spooky はリモートブランチを追跡する同じ名前のローカルブランチを作成します。そのあと、そのブランチをチェックアウトします。

追跡中のファイルに変更があると、Spooky は先にスタッシュするかどうかを尋ねます。[自動スタッシュ](/guide/work/stash/#auto-stash) を参照してください。

別のワークツリーでチェックアウトされているブランチは、ここではチェックアウトできません。ダブルクリックすると、Spooky は代わりにそのワークツリーを開きます。<kbd>⌘</kbd> を押しながらダブルクリックすると、新しいタブで開きます。

### タグやコミットをチェックアウトする {#checkout-revision}

タグをダブルクリックすると、そのコミットをチェックアウトします。それ以外をチェックアウトするには、:ui[workspace.title > rewrite.checkout.menu]（<kbd>⇧⌘B</kbd>）を選び、ブランチ、タグ、コミットのどれかを選んで、:ui[rewrite.checkout.button] をクリックします。

選んだものがローカルブランチでないときは、HEAD が分離されることをダイアログが警告します。分離した HEAD とは、ブランチではなくコミットの上にいる状態です。そこで作ったコミットを残すには、そこからブランチを作成します。

## リモートブランチを追跡する {#track}

ローカルブランチは、リモートのブランチを追跡できます。これが上流です。プルとプッシュは、ほかを選ばない限り上流を使います。↑ と ↓ の数は上流と比べたものです。

リモートブランチに対応するローカルブランチを用意するには、次のようにします。

1. リモートブランチを右クリックしてメニューから :ui[branch.trackMenu]{1="origin/feature/station-map"} を選ぶか、:ui[branch.group] へドラッグします。
2. :ui[branch.remoteField] にリモートブランチが表示されます。必要なら :ui[reference.name] で名前を変えます。
3. :ui[branch.track.checkout] は毎回選択されています。現在のブランチに留まるには、選択を解除します。
4. :ui[branch.track.submit] をクリックします。

既存のブランチの追跡先を変えるには、右クリックして :ui[branch.tracking] の下でブランチを選びます。:ui[branch.tracking.remove] は追跡をやめます。現在のブランチなら、<kbd>⌥</kbd> を押しながらリモートブランチをその上へドラッグすることもできます。

現在のブランチ以外のブランチが上流より遅れていて、独自のコミットがないときは、メニューに :ui[branch.fastForward]{1="main"} があります。チェックアウトせずに、ブランチを上流の位置まで進めます。

## ブランチの名前を変更する {#rename}

ブランチを右クリックしてメニューから :ui[reference.renameMenu]{1="feature/dark-mode"} を選びます。新しい名前を入力して、:ui[reference.rename] をクリックします。

ピン留め、アーカイブ、親ブランチの設定はブランチに付いていきます。リモートブランチの名前を変更すると、リモート上で名前が変わります。

ブランチをフォルダに移すには、フォルダへドラッグします。[ドラッグ＆ドロップ](/guide/branches/merge-rebase/#drag-and-drop) を参照してください。

## ブランチを削除する {#delete}

ブランチを右クリックしてメニューから :ui[reference.deleteMenu]{1="feature/dark-mode"} を選びます。サイドバーにフォーカスがある状態で、1 つ以上のブランチを選択して <kbd>⌘⌫</kbd> を押すこともできます。

Spooky は必ず先に確認します。ダイアログには 2 つのオプションがあります。

- :ui[branch.forceDelete] は、完全にマージされていないブランチでも削除します。これを選ばない場合、Spooky は完全にマージされていないブランチを一覧にして、もう一度確認します。
- :ui[branch.deleteUpstream] は、追跡しているリモートブランチも削除します。リモートブランチがまだ存在するブランチを 1 つだけ削除するときに表示されます。

現在のブランチは削除できません。先に別のブランチをチェックアウトしてください。

リモートブランチを削除すると、リモート上で削除されます。

削除したローカルブランチを取り戻すには、:ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）を選びます。:ui[branch.deleteUpstream] を選択していた場合でも使えます。リモートブランチだけを削除した場合は取り消せません。[取り消しと復元](/guide/work/undo/) を参照してください。

## ブランチをピン留めする {#pin}

ピン留めしたブランチは、:ui[branch.group] から一覧の先頭にある :ui[sidebar.pinned] へ移ります。よく戻ってくるブランチに使います。

ブランチを右クリックしてメニューから :ui[branch.pinNamed]{1="feature/station-map"} を選ぶか、:ui[sidebar.pinned] へドラッグします。複数のブランチを選択しているときは、項目が :ui[branch.pinMultiple]{1="2"} になります。ブランチを元に戻すには、代わりに :ui[branch.unpinNamed]{1="feature/station-map"} を選びます。

## ブランチをアーカイブする {#archive}

アーカイブは、ブランチを削除せずに脇へよけます。ブランチは :ui[branch.group] から :ui[sidebar.archived] へ移ります。これまでどおり使えます。

ブランチを右クリックしてメニューから :ui[branch.archiveNamed]{1="feature/dark-mode"} を選ぶか、:ui[sidebar.archived] へドラッグします。元に戻すには、代わりに :ui[branch.unarchiveNamed]{1="feature/dark-mode"} を選びます。

Spooky はアーカイブしたほうがよいブランチを見つけて、自動でアーカイブすることもできます。[ブランチの整理](/guide/branches/review/#archive-suggestions) を参照してください。

:::note[サーバーリポジトリ]
ピン留め、アーカイブ、親ブランチは、リポジトリの Git 設定に保存されます。サーバーリポジトリでは、サーバー上に保存されます。
:::

## 親ブランチ {#parent}

親ブランチは、自分のブランチの元になっていて、追従していくべきブランチです。たとえば `feature/units-toggle` に対する `main` です。

設定するには、ブランチを右クリックして :ui[branch.parent] の下で候補のブランチを選びます。それ以外のブランチにするには、:ui[branch.parent.setMenu] を選び、:ui[branch.parent.field] でブランチを選んで、:ui[branch.parent.set] をクリックします。ブランチを作成するときに設定することもできます。:ui[branch.parent.remove] は設定を消します。

ブランチに親があると、次のようになります。

- 履歴でのブランチの比較は、親から始まります。[別のブランチと比較する](/guide/history/browse/#compare-branches) を参照してください。
- 自分のブランチにないコミットが親にあると、自分のブランチの履歴に :ui[history.parentBanner.title] が表示されます。ブランチのメニューには、それを取り込む :ui[branch.updateNamed]{1="feature/units-toggle"} があります。[親からブランチを更新する](/guide/branches/merge-rebase/#update) を参照してください。
- 現在のブランチでは、メニューの :ui[branch.mergeWith]{1="main"} と :ui[branch.rebaseOn]{1="main"} が、親を選んだ状態でマージとリベースのダイアログを開きます。
- 親そのものは古いブランチになりません。

## フィルタとグループ化 {#filter}

サイドバー下部の :ui[sidebar.filter] に入力すると、一致するブランチ、タグ、リモートブランチ、サブモジュール、ワークツリーだけが表示されます。文字は隣り合っていなくてもかまいません。`stm` で `station-map` が見つかります。大文字と小文字、アクセント記号は区別しません。フィルタ中はフォルダが開き、<kbd>Esc</kbd> でフィールドが空になります。

右下の表示設定ボタンをクリックするか、:ui[menu.view > sidebar.menu] を選ぶと、サイドバーに表示するものを設定できます。設定はすべてのウインドウに適用されます。

- :ui[sidebar.groupRefs] は、`/` を含む名前をフォルダに入れます。最初はオンです。:ui[sidebar.groupedRefsOnTop] は、フォルダをほかのブランチより前に並べます。
- :ui[sidebar.showStaleInfo] は、どのブランチが古いかを表示します。:ui[sidebar.staleInterval] は、コミットがないまま過ごせる期間を設定します。最初は 6 か月です。
- :ui[sidebar.remoteFilter] と :ui[sidebar.tagsFilter] は、:ui[sidebar.showNewest] の下で、一覧を新しいものから数件に絞ります。件数はリモートごとに別々に数えます。タグは :ui[sidebar.sortBy] の下で並べ替えることもできます。フィルタ中は、一致したものがすべて表示されます。
- :ui[sidebar.autoArchive] は [ブランチの整理](/guide/branches/review/#auto-archive) で説明しています。

## 関連ページ

- [フェッチ、プル、プッシュ](/guide/branches/sync/)
- [マージとリベース](/guide/branches/merge-rebase/)
- [ブランチの整理](/guide/branches/review/)
- [ワークツリー](/guide/advanced/worktrees/)

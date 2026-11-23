---
title: "マージとリベース"
description: "ブランチのマージとリベース、始める前の競合のプレビュー、親からのブランチの更新、サイドバーでのブランチのドラッグ＆ドロップ。"
---

マージとリベースは、どちらも別のブランチのコミットを現在のブランチに取り込みます。

- マージは、2 つの履歴をつなぎます。たいていマージコミットができます。
- リベースは、自分のコミットを別のブランチのコミットの後ろへ移します。履歴は一直線のままですが、自分のコミットは書き換えられます。

どちらも :ui[workspace.title] メニューから始めます。:ui[sync.merge] と :ui[sync.rebaseHead] をツールバーに置くには、:ui[menu.view > menu.customizeToolbar] を選んでツールバーにドラッグします。

## マージ {#merge}

1. :ui[workspace.title > sync.mergeMenu]（<kbd>⇧⌘M</kbd>）を選びます。サイドバーで現在のブランチを右クリックしてメニューから :ui[workspace.mergeMenu] を選ぶか、別のブランチをその上へドラッグすることもできます。
2. :ui[branch.target] でマージするものを選びます。ローカルブランチ、リモートブランチ、タグのどれかです。最初は現在のブランチの上流になっています。
3. コミットのしかたを選びます。
   - :ui[merge.squash] は、すべての変更をステージして、自分の 1 つのコミットにまとめられるようにします。マージコミットは作りません。
   - :ui[merge.alwaysCommit] は、Git がブランチを先へ進めるだけで済む場合でも、マージコミットを作成します。
   - :ui[merge.autoCommit] は、マージをすぐにコミットします。選択を外せるのは、:ui[merge.alwaysCommit] を選択している間だけです。外すと、マージした変更はコミットされるまで作業コピーに残ります。
4. マージで競合が起きる場合は、下の行がそれを知らせます。[競合をプレビューする](#preview) を参照してください。
5. オプションを設定します。
   - :ui[merge.verify] は、マージするコミットに信頼できる署名がなければマージを止めます。
   - :ui[sync.skipHooks] は、今回だけリポジトリの Git フックを飛ばします。
6. :ui[sync.merge] をクリックします。

Spooky は :ui[merge.alwaysCommit]、:ui[merge.autoCommit]、:ui[merge.verify] を覚えています。

マージが競合で止まると、Spooky は作業コピーに切り替えてバナーを表示します。[競合を解決する](/guide/work/conflicts/#banner) を参照してください。

<kbd>⌘Z</kbd> でマージを取り消せます。マージが競合で止まっている場合は、取り消すとマージが中止されます。

## リベース {#rebase}

1. :ui[workspace.title > sync.rebaseMenu]（<kbd>⇧⌘R</kbd>）を選びます。現在のブランチを右クリックしてメニューから :ui[workspace.rebaseMenu] を選ぶこともできます。
2. :ui[branch.target] でリベース先のブランチを選びます。最初は現在のブランチの上流になっています。
3. プレビューを確かめて、必要なら :ui[sync.skipHooks] を選択します。
4. :ui[sync.rebaseHead] をクリックします。

完了したリベースは <kbd>⌘Z</kbd> で取り消せます。競合で止まったリベースは取り消せません。競合を解決して続行するか、バナーから中止してください。

コミットの一部だけを別のベースへ移すには、[コミットを別のベースへリベースする](/guide/history/rewrite/#rebase-onto) を参照してください。

:::caution
リベースは自分のコミットを書き換えます。すでにプッシュしていた場合、次のプッシュは [強制プッシュ](/guide/branches/sync/#force-push) にする必要があります。
:::

## ローカルの変更 {#local-changes}

マージするには、追跡中のファイルに変更がない状態でなければなりません。新しいファイルが妨げになるのは、マージがそれを上書きしてしまうときだけです。

リベースと、親からのブランチの更新には、変更がまったくない作業コピーが必要です。新しいファイルもあってはいけません。

ローカルの変更がこれらの妨げになると、Spooky は先に変更をスタッシュすることを提案します。[自動スタッシュ](/guide/work/stash/#auto-stash) を参照してください。

## 競合をプレビューする {#preview}

マージ、リベース、プル、同期のダイアログは、始める前にブランチどうしが競合するかどうかを調べて、結果をダイアログに表示します。

- Spooky が比較している間は :ui[merge.checking]。
- 競合するファイルの数。その行にポインタを合わせると、どのファイルかがわかります。
- :ui[merge.clean] または :ui[merge.unchanged]。
- 調べられなかったときは :ui[merge.unavailable]。その行にポインタを合わせると、理由がわかります。

マージのダイアログは :ui[merge.clean] と :ui[merge.unchanged] を表示しません。ほかのダイアログはすべての結果を表示します。

## クイック版 {#quick}

<kbd>⌥</kbd> を押している間、ツールバーに追加した :ui[sync.merge] と :ui[sync.rebaseHead] は :ui[sync.quickMerge] と :ui[sync.quickRebase] に変わります。ダイアログを出さずにすぐ実行されます。

- :ui[sync.quickMerge] は、現在のブランチの上流をマージします。
- :ui[sync.quickRebase] は、現在のブランチをその上流へリベースします。

クイックマージは、マージのダイアログで最後に選んだコミットと署名のオプションを使います。どちらも、ダイアログと同じように、ローカルの変更をスタッシュすることを提案します。

サイドバーのメニューの項目も同じように変わります。たとえば :ui[workspace.mergeMenu] は :ui[sync.quickMergeInto]{1="origin/main" 2="main"} になります。

## 親からブランチを更新する {#update}

ブランチに [親ブランチ](/guide/branches/branches/#parent) があると、更新で親の新しいコミットを取り込めます。

1. ブランチを右クリックしてメニューから :ui[branch.updateNamed]{1="feature/units-toggle"} を選びます。ブランチの履歴を表示していて、親に新しいコミットがあるときは、:ui[history.parentBanner.title] のバナーにも :ui[review.updateBranch.menu] ボタンがあります。
2. :ui[review.update.branch] を確かめます。その下の行に、親から取り込まれるコミットの数が書かれています。
3. :ui[review.update.strategy] で :ui[review.update.merge] か :ui[review.update.rebase] を選びます。:ui[review.update.merge] では、:ui[merge.alwaysCommit] も選択できます。
4. プレビューを確かめます。:ui[review.update.conflicts]、:ui[review.update.clean]、:ui[review.update.noChanges] のどれかです。
5. オプションを設定します。:ui[merge.verify]（マージのときだけ）と :ui[sync.skipHooks] です。
6. :ui[review.update.button] をクリックします。

Spooky は先にそのブランチをチェックアウトしてから、マージまたはリベースします。更新が使えるのは、ブランチにないコミットが親にあり、ほかの操作が進行中でないときだけです。

現在のブランチでは、サイドバーのメニューの :ui[branch.mergeWith]{1="main"} と :ui[branch.rebaseOn]{1="main"} が、親を選んだ状態でマージとリベースのダイアログを開きます。

:::tip
メニューが開いている間に <kbd>⌥</kbd> を押すと、:ui[branch.updateNamed]{1="feature/units-toggle"} は :ui[branch.quickUpdateNamed]{1="feature/units-toggle"} に変わります。ダイアログを出さずに、すぐ親をマージします。
:::

## ドラッグ＆ドロップ {#drag-and-drop}

ブランチの操作の多くは、サイドバーでのドラッグから始められます。ドラッグ中は、ポインタの横のラベルが何が起きるかを示します。閉じたフォルダやリモートの上で少し止まると、それが開きます。

| ドラッグするもの | ドロップ先 | 起きること |
|---|---|---|
| ローカルブランチ | :ui[workspace.title] または現在のブランチ | マージのダイアログ。<kbd>⌥</kbd> を押しているとリベースのダイアログ。 |
| リモートブランチ | :ui[workspace.title] または現在のブランチ | プルのダイアログ |
| リモートブランチ（<kbd>⌥</kbd> を押しながら） | 現在のブランチ | 自分のブランチの上流になります。 |
| ローカルブランチ、タグ、コミット | :ui[branch.group] | そこからブランチを作成するダイアログ |
| リモートブランチ | :ui[branch.group] | それを追跡するダイアログ |
| ローカルブランチ | リモート | 公開のダイアログ |
| ローカルブランチ | リモートブランチ | :ui[sync.pushBranch] ダイアログ |
| ローカルブランチまたはコミット | :ui[sidebar.tags] またはタグのフォルダ | タグを作成するダイアログ |
| タグ | リモート | タグを公開するダイアログ |
| ローカルブランチ | :ui[sidebar.pinned] または :ui[sidebar.archived] | ブランチがピン留めまたはアーカイブされます。 |
| ローカルブランチ | :ui[worktree.group] | そのブランチのワークツリーを作成するダイアログ |

ブランチをフォルダに入れるには、フォルダの上へドラッグします。ブランチの名前は、フォルダ名に元の名前の最後の部分を付けたものに変わります。ダイアログは出ません。リモートブランチは、同じリモートのフォルダにしか移せません。ブランチをフォルダから出すには、一覧の上端か下端へドラッグします。名前の変更は <kbd>⌘Z</kbd> で取り消せます。

履歴のコミットを :ui[workspace.title] や現在のブランチへドラッグして、チェリーピックすることもできます。<kbd>⌥</kbd> を押していると、代わりにリバートします。[コミットをチェリーピックする](/guide/history/rewrite/#cherry-pick) を参照してください。コミットの変更セットからファイルを 1 つそこへドラッグすると、そのファイルの変更だけが作業コピーに適用されます。ステージはされません。

## 関連ページ

- [競合を解決する](/guide/work/conflicts/)
- [履歴を書き換える](/guide/history/rewrite/)
- [フェッチ、プル、プッシュ](/guide/branches/sync/)
- [ブランチ](/guide/branches/branches/)

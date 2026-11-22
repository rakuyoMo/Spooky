---
title: "スタッシュ"
description: "スタッシュの保存、適用、確認のしかたと、自動スタッシュの使い方を説明します。"
---

スタッシュは、ローカルの変更をコミットせずに脇へ置いておくものです。ブランチの切り替えやプルなどで一時的にクリーンな作業コピーが必要で、あとで変更を戻したいときに使います。

スタッシュはリポジトリに属します。リモートにはプッシュされません。

## スタッシュを保存する {#save}

1. :ui[workspace.title > stash.saveMenu]（<kbd>⇧⌘S</kbd>）を選ぶか、ツールバーの :ui[toolbar.saveStash] をクリックします。
2. 必要に応じて、あとでスタッシュを見つけやすいように、:ui[stash.message] に変更の説明を入力します。
3. 新しいファイルも一緒に置いておくには、:ui[stash.includeUntracked] を選択します。この選択は記憶されます。
4. :ui[stash.save] をクリックします。

すべての変更がスタッシュに入り、作業コピーは再びクリーンになります。保存するものがない場合、Spooky は :ui[stash.error.noChanges] と表示します。新しいファイルは、:ui[stash.includeUntracked] を選択しているときだけ対象になります。

変更のコピーを保存しつつ作業を続けるには、代わりに :ui[workspace.title > stash.snapshotMenu]（<kbd>⌃⇧⌘S</kbd>）を選びます。ダイアログは同じで、作業コピーはそのまま残ります。

## 一部のファイルをスタッシュする {#partial}

一部のファイルだけを置いておくには、作業コピーでファイルを選択して右クリックし、メニューから :ui[stash.stashFile]{1="README.md"} または :ui[stash.stashItems]{1="3"} を選びます。その下にあるスナップショットの項目は、ファイルをそのまま残します。

ファイルをサイドバーの :ui[stash.title] にドラッグすることもできます。

選択した新しいファイルは、:ui[stash.includeUntracked] を選択しているかどうかに関係なく、必ずスタッシュに入ります。

:::tip
メニューが開いている間に <kbd>⌥</kbd> を押したままにすると、項目が :ui[stash.quickStashFile]{1="README.md"} のようなクイック版に変わります。ダイアログを表示せず、Git が書くメッセージですぐに保存されます。
:::

## スタッシュを見る {#view}

サイドバーの :ui[stash.title] をクリックするか、:ui[menu.view > stash.show]（<kbd>⌘3</kbd>）を選びます。

左の一覧には、新しいスタッシュから順に表示されます。それぞれの行には、:ui[stash.basedOn] とスタッシュを保存したときのブランチ、日付、メッセージが表示されます。一覧を絞り込むには、ツールバーの検索フィールドに入力します。

::screenshot[スタッシュのビュー。左の一覧に 3 つのスタッシュが並び、Halfway through the units toggle が選択されています。右側にはその詳細があり、コミット情報の下に適用、削除、比較ツールのボタンが表示されています。]{name="work-stashes" frame="window" markers="33,36 82.5,35.5"}

1. スタッシュの一覧
2. :ui[stash.applyButton]、:ui[stash.deleteButton]、:ui[history.diffTool]

スタッシュを選択すると、その変更が右側に表示されます。レイアウトはコミットの詳細と同じです。詳細にポインタを合わせると、:ui[stash.applyButton]、:ui[stash.deleteButton]、:ui[history.diffTool] のボタンが表示されます。:ui[history.diffTool] は、スタッシュを比較ツールで開きます。

## スタッシュを適用する {#apply}

適用すると、スタッシュの変更が作業コピーに戻ります。

1. :ui[workspace.title > stash.applyMenu]（<kbd>⌥⇧⌘S</kbd>）を選ぶか、ツールバーの :ui[toolbar.applyStash] をクリックします。スタッシュをサイドバーの :ui[workspace.title] または現在のブランチにドラッグすることもできます。
2. :ui[stash.picker] でスタッシュを選びます。スタッシュのビューでは、選択中のスタッシュがすでに選ばれています。
3. オプションを設定します。
   - :ui[stash.deleteAfterApply] は、変更が戻ったらスタッシュを削除します。
   - :ui[stash.restoreIndex] は、スタッシュを保存したときにステージされていたものを再びステージします。
4. :ui[stash.apply] をクリックします。

どちらのオプションも、次回のために記憶されます。

変更が作業コピーのいまの内容とぶつかる場合、Spooky は :ui[stash.error.conflicts] と表示します。:ui[stash.deleteAfterApply] を選択していても、スタッシュは残ります。[競合を解決する](/guide/work/conflicts/) の説明に従って競合を解決します。

1 つのファイルだけを戻すには、スタッシュを開き、その詳細からファイルをサイドバーの :ui[workspace.title] にドラッグします。

## スタッシュを削除する {#delete}

スタッシュのビューでスタッシュを右クリックし、メニューから :ui[stash.deleteNamed]{1="Halfway through the units toggle"} を選びます。複数のスタッシュを選択している場合、項目は :ui[stash.deleteMultiple]{1="2"} になります。<kbd>⌘⌫</kbd> を押すこともできます。

Spooky は必ず先に確認を求めます。削除したスタッシュを戻すには、:ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）を選びます。

## 自動スタッシュ {#auto-stash}

ブランチの切り替え、プル、マージなど、ローカルの変更があると実行できない操作があります。そうした操作が妨げられると、Spooky は先に変更をスタッシュするかどうかを尋ねます。

::screenshot[操作を妨げているローカルの変更をスタッシュするかどうかを尋ねるダイアログ。任意のメッセージを入力する欄、操作の完了後に変更を再適用するチェックボックス、「中止」「スタッシュしない」「変更をスタッシュ」のボタンがあります。]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm] は、変更をスタッシュしてから操作を実行します。
- :ui[stash.autoStash.skip] は、スタッシュせずに操作を実行します。変更がまだ操作を妨げる場合は、そのまま失敗します。
- :ui[stash.autoStash.abort] は、操作を取りやめます。

操作が終わったらすぐに変更を戻すには、:ui[stash.autoStash.reapply] を選択します。選択しない場合、スタッシュは一覧に残り、あとで自分で適用できます。この選択は記憶されます。

追跡中のファイルに変更がある状態でブランチを切り替えるときは、変更が妨げにならない場合でも、Spooky は始める前に尋ねます。

途中で問題が起きた場合、変更はスタッシュに残り、Spooky が何が起きたかを知らせます。

確認されないようにするには、:ui[app.name > settings.title] › :ui[settings.general] で :ui[stash.offerAutoStash] をオフにします。[操作](/guide/settings/general/#operations) を参照してください。

## 関連ページ

- [作業コピー](/guide/work/working-copy/)
- [競合を解決する](/guide/work/conflicts/)
- [ブランチ](/guide/branches/branches/)

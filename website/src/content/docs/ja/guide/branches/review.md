---
title: "ブランチの整理"
description: "ローカルブランチをベースブランチと比較して、片付けられるブランチを見つけ、アーカイブの提案に従い、ブランチを自動でアーカイブします。"
---

ブランチの整理は、ローカルブランチを一覧にして、それぞれをベースブランチと比較します。マージできるブランチ、競合するブランチ、古いブランチ、リモートブランチがなくなったブランチがわかります。何をマージし、アーカイブし、削除するかを決めるのに役立ちます。

開くには、サイドバーの上部にある :ui[review.title] をクリックするか、:ui[menu.view > review.show]（<kbd>⌘5</kbd>）を選びます。

::screenshot[ブランチの整理のウインドウ。ベースブランチは main です。一覧には feature/csv-export から spike/radar-overlay までの 6 つのブランチが並び、それぞれにマージの状態、進んでいるコミットと遅れているコミットの数、追跡しているブランチが表示されています。feature/units-toggle が選択されていて、右側の詳細にはそのコミットと競合のボタンが表示されています。]{name="branches-review" frame="window" markers="41.8,9 47.3,9 22,52 76,9"}

1. ベースブランチ
2. フィルタボタン
3. ブランチをきれいにマージできるかどうか
4. 競合のボタン

## 一覧 {#list}

一覧の上部にある :ui[review.compareTo] でベースブランチを選びます。最初は `next`、`develop`、`dev`、`main`、`master` のうち、リポジトリにある最初のものです。どれもなければ現在のブランチです。

ブランチごとに 1 行が表示されます。

- 左のアイコンは、ブランチをベースへきれいにマージできるか、競合が起きるかを示します。ポインタを合わせると詳細がわかります。
- 右には、ブランチがベースよりどれだけ進んでいて、どれだけ遅れているかがコミットの数で表示されます。Spooky が比較している間は :ui[review.comparing] と表示されます。
- 2 行目には、追跡しているリモートブランチか、:ui[review.noTracking] が表示されます。リモートブランチがなくなっていると、名前が赤くなります。
- ブランチが最後に更新された時期と、そのブランチの最新のプルリクエストまたはマージリクエスト。番号と、状態を表す色が付きます。

## フィルタと並べ替え {#filter}

右上のフィルタボタンで、一部のブランチだけを表示できます。

- :ui[review.filter.stale] と :ui[review.filter.active] は、古いかどうかでブランチを分けます。古いとは、サイドバーの [表示設定](/guide/branches/branches/#filter) で決めた期間、新しいコミットがないことです。最初は 6 か月です。
- :ui[review.filter.trackingError] は、リモートブランチがなくなったブランチを表示します。
- :ui[review.filter.mergeable] と :ui[review.filter.conflicts] は、ベースへマージしたときの結果で分けます。
- :ui[pr.filter.with] と :ui[pr.filter.without] は、オープンなプルリクエストまたはマージリクエストの有無で分けます。リモートの [ホスティングアカウント](/guide/hosting/accounts/) が必要です。ない場合は、一覧がそのことを知らせます。
- :ui[review.filter.none] は、すべてのブランチをまた表示します。

隣の表示設定ボタンは、一覧を :ui[review.sort.name] または :ui[review.sort.date] で、:ui[review.sort.ascending] または :ui[review.sort.descending] に並べ替えます。Spooky はフィルタと並び順の両方を覚えています。

名前でブランチを探すには、ツールバーの検索フィールドに入力します。

## 詳細 {#details}

ブランチを選択すると、ベースとの比較が右側に表示されます。上部にはブランチとベースが表示されます。マージで競合が起きる場合は、そこにあるボタンでファイルの一覧を見られます。

:ui[compare.commits] には、ブランチがベースから分かれたあとに作ったコミットが並びます。:ui[history.changeset] は、それらのコミットが変更した内容を表示します。両方の上にある概要には、:ui[review.summary.contributors]、:ui[review.summary.updated]、:ui[review.summary.tracking]、:ui[review.summary.mergeStatus] が表示されます。

複数のブランチを一度に選択できます。たとえば、まとめてアーカイブまたは削除するときに使います。

## ブランチを操作する {#actions}

ブランチを右クリックすると、サイドバーと同じメニューが開きます。複数のブランチを選択しているときは、メニューはそのすべてに適用されます。

ブランチがベースと競合する場合は、メニューに :ui[review.resolveConflicts] も表示されます。Spooky はそのブランチをチェックアウトして、ベースをマージします。そのあと、ブランチの上で競合を解決します。[競合を解決する](/guide/work/conflicts/) を参照してください。

ブランチを削除するには、選択して <kbd>⌘⌫</kbd> を押すか、行を左へスワイプして :ui[review.delete] をクリックします。サイドバーと同じように、Spooky は先に確認します。

## アーカイブの提案 {#archive-suggestions}

Spooky は、次の場合にローカルブランチの [アーカイブ](/guide/branches/branches/#archive) を提案します。

- 古いブランチである場合
- プルリクエストまたはマージリクエストがマージされ、そのあとブランチに新しいコミットがない場合

ピン留めしたブランチとアーカイブ済みのブランチは提案されません。`main`、`master`、`trunk`、`dev`、`develop`、`next` と、ほかのブランチの親になっているブランチも同じです。

提案があり、自動アーカイブがオフのときは、ブランチの数が付いたボタンがサイドバー下部に現れます。クリックすると :ui[review.archive.title] が開きます。

1. アーカイブするブランチを選択するか、:ui[menu.selectAll] を選択します。最初は何も選択されていません。各ブランチには、提案された理由が表示されます。:ui[pr.archive.merged] か :ui[review.filter.stale] です。
2. :ui[review.archive.submit] をクリックします。

::screenshot[ブランチをアーカイブするダイアログ。3 つのブランチが並び、どれにも「古い」と表示されていて、1 つが選択されています。下端には、ブランチを自動でアーカイブするスイッチがあります。]{name="branches-archive" frame="dialog"}

そのあと、サイドバー下部に、アーカイブしたブランチの数を知らせるメモが :ui[review.archived.undo] ボタンと一緒に表示されます。<kbd>⌘Z</kbd> も使えます。:ui[activity.title] には、各ブランチがアーカイブされた理由が記録されます。

## 自動でアーカイブする {#auto-archive}

Spooky は、アーカイブするブランチがないかを 1 日に 1 回調べられます。次のどれでもオンにできます。どれも同じ設定です。

- :ui[review.archive.title] ダイアログの :ui[review.archive.auto]
- サイドバーの表示設定の :ui[sidebar.autoArchive]
- :ui[app.name > settings.title] › :ui[settings.general] の :ui[settings.autoArchive]（[操作](/guide/settings/general/#operations) を参照）

最初はオフです。

Spooky は、リポジトリごとに 1 日に 1 回、そのウインドウで作業している間に提案を探します。提案があれば、同じダイアログを開きます。そこでアーカイブするブランチを選びます。アーカイブしてもしなくても、次に調べるのは 1 日後です。

ブランチを対象から外すには、ブランチを右クリックして、メニューのアーカイブの項目の下にある :ui[review.skipAutoArchive] を選択します。

この方法でブランチがアーカイブされると、次のようになります。

- 通知に :ui[review.archived.notification] と表示されます。:ui[activity.title] の記録の名前は :ui[review.autoArchive] です。
- サイドバーの :ui[sidebar.archived] の横の点は、まだ見ていないブランチがあることを示します。そのブランチをクリックすると、少ししてマークが消えます。すべて消すには、:ui[sidebar.archived] を右クリックして :ui[sidebar.markAllReviewed] を選びます。

## 関連ページ

- [ブランチ](/guide/branches/branches/)
- [マージとリベース](/guide/branches/merge-rebase/)
- [プルリクエストとマージリクエスト](/guide/hosting/pull-requests/)
- [ホスティングアカウント](/guide/hosting/accounts/)

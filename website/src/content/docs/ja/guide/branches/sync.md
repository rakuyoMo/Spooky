---
title: "フェッチ、プル、プッシュ"
description: "フェッチ、プル、プッシュ、ブランチの初回公開、同期、強制プッシュ、自動フェッチ。"
---

これらの操作は、[リモート](/guide/branches/tags-remotes/#remotes) とコミットをやり取りします。

- フェッチは、リモートから新しいコミットをダウンロードします。ブランチと作業コピーはそのままです。
- プルは、リモートブランチをフェッチして、そのコミットを現在のブランチに取り込みます。
- プッシュは、自分のコミットをリモートブランチへ送ります。

ツールバーには :ui[sync.fetch]、:ui[sync.pull]、:ui[sync.push] が並び、その隣に :ui[sync.sync] があります。同じ操作は :ui[menu.repository] メニューにもあります。

フェッチ、プル、プッシュ、同期は取り消し履歴に記録されないので、取り消せません。ブランチの公開は取り消せます。

:::note[サーバーリポジトリ]
リモートへは、サーバーのネットワークと SSH 鍵を使って、サーバーから接続します。リモートがパスワードを求めると、Spooky が尋ねます。[パスワードとパスフレーズの入力](/guide/server/connection/#prompts) を参照してください。
:::

## フェッチ {#fetch}

1. ツールバーの :ui[sync.fetch] をクリックするか、:ui[menu.repository > sync.fetchMenu]（<kbd>⇧⌘F</kbd>）を選びます。リモートを 1 つだけフェッチするには、サイドバーでそのリモートを右クリックしてメニューから :ui[remote.fetchMenu]{1="origin"} を選びます。
2. :ui[sync.remote] でリモートを選ぶか、:ui[sync.allRemotes] を選択します。
3. オプションを設定します。
   - :ui[sync.prune] は、リモート上で削除されたリモートブランチを取り除きます。最初はオンです。
   - :ui[sync.fetchSubmodules] は、チェックアウト済みのサブモジュールの新しいコミットもフェッチします。
   - :ui[sync.allTags] は、リモートにあるすべてのタグもフェッチします。
4. :ui[sync.fetch] をクリックします。

Spooky は :ui[sync.allTags] 以外のオプションをすべて覚えています。

フェッチのあと、サイドバーのリモートブランチは最新になり、ローカルブランチの ↓ はプルできるコミットの数を示します。

:ui[menu.repository > sync.fetchAll] は、ダイアログを出さずに、すべてのリモートをすぐにフェッチします。[設定](/guide/branches/tags-remotes/#remote-settings) で :ui[remote.skipFetchAll] にしたリモートは飛ばします。

## プル {#pull}

1. ツールバーの :ui[sync.pull] をクリックするか、:ui[menu.repository > sync.pullMenu]（<kbd>⇧⌘P</kbd>）を選びます。特定のリモートブランチをプルするには、それを右クリックしてメニューから :ui[branch.pullMenu]{1="origin/main"} を選びます。
2. :ui[sync.remoteBranch] でブランチを選びます。最初は現在のブランチの [上流](/guide/branches/branches/#track) になっています。
3. :ui[sync.rebase] を選択すると、マージコミットで 2 つをつなぐ代わりに、プルしたコミットの上に自分のコミットを載せます。Spooky はこの選択を覚えています。
4. オプションの下のプレビューは、プルで競合が起きるかどうかを示します。[競合をプレビューする](/guide/branches/merge-rebase/#preview) を参照してください。
5. オプションを設定します。
   - :ui[merge.verify] は、プルするコミットに信頼できる署名がなければプルを止めます。Spooky はこれを覚えています。
   - :ui[sync.skipHooks] は、今回だけリポジトリの Git フックを飛ばします。
6. :ui[sync.pull] をクリックします。

プルするには、追跡中のファイルに変更がない状態でなければなりません。変更があると、Spooky は先にスタッシュすることを提案します。[自動スタッシュ](/guide/work/stash/#auto-stash) を参照してください。新しいファイルが妨げになるのは、プルがそれを上書きしてしまうときだけです。

プルで競合が起きると、Spooky は作業コピーに切り替えてバナーを表示します。[競合を解決する](/guide/work/conflicts/#banner) を参照してください。

## プッシュ {#push}

1. ツールバーの :ui[sync.push] をクリックするか、:ui[menu.repository > sync.pushMenu]（<kbd>⇧⌘U</kbd>）を選びます。
2. :ui[sync.destination] でリモートブランチを選びます。最初は現在のブランチの上流になっています。
3. オプションを設定します。
   - :ui[sync.pushAllTags] は、すべてのローカルタグもプッシュします。
   - :ui[sync.forcePush] は、通常のプッシュができないときにリモートブランチを上書きします。[強制プッシュ](#force-push) を参照してください。
   - :ui[sync.pushSubmodules] は、このプッシュが参照するサブモジュールのコミットを扱います。:ui[sync.pushSubmodules.onDemand] か :ui[sync.pushSubmodules.check] を選びます。
   - :ui[sync.skipHooks] は、今回だけリポジトリの Git フックを飛ばします。
4. :ui[sync.pushHead] をクリックします。

Spooky はタグとサブモジュールのオプションを覚えています。

現在のブランチがまだリモートブランチを追跡していないと、:ui[sync.push] は代わりに公開のダイアログを開きます。[ブランチを公開する](#publish) を参照してください。リポジトリにリモートが 1 つもないと、リポジトリを公開するダイアログを開きます。[リポジトリを公開する](/guide/hosting/accounts/#publish) を参照してください。

ほかの人が先にリモートブランチへプッシュしていると、リモートはプッシュを拒否します。その人のコミットをプルしてから、もう一度プッシュしてください。

現在のブランチ以外のブランチをプッシュするには、サイドバーでリモートブランチへドラッグします。:ui[sync.pushBranch] ダイアログがそこへプッシュします。オプションのない単純なプッシュで、ブランチの追跡先は変わりません。

## ブランチを公開する {#publish}

新しいブランチは、公開するまで自分のリポジトリにしかありません。公開すると、リモートにブランチが作成されます。

1. :ui[menu.repository > sync.publishMenu] を選ぶか、ブランチを右クリックしてメニューから :ui[branch.publishMenu]{1="feature/station-map"} を選びます。サイドバーでブランチをリモートへドラッグすることもできます。
2. :ui[branch.local] と :ui[sync.remote] を確認します。:ui[branch.name] はリモート上の名前で、最初はローカルの名前と同じです。
3. :ui[sync.setUpstream] は、自分のブランチに新しいリモートブランチを追跡させます。以後のプルとプッシュはそこが相手になります。最初はオンです。
4. リポジトリの Git フックを飛ばすには、:ui[sync.skipHooks] を選択します。
5. :ui[sync.publish] をクリックします。

元に戻すには、:ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）を選びます。

## 同期 {#sync}

同期は、現在のブランチのフェッチ、プル、プッシュを順に行います。

1. ツールバーの :ui[sync.sync] をクリックするか、:ui[menu.repository > sync.syncMenu]（<kbd>⇧⌘Y</kbd>）を選びます。
2. :ui[sync.remoteBranch] でブランチを選びます。最初は現在のブランチの上流になっています。
3. 必要なら :ui[sync.rebase] を選択します。下のプレビューは、プルで競合が起きるかどうかを示します。
4. オプションを設定します：:ui[merge.verify]、:ui[sync.pushAllTags]、:ui[sync.pushSubmodules]、:ui[sync.skipHooks] は、プルとプッシュのときと同じように働きます。
5. :ui[sync.syncHead] をクリックします。

プルと同じく、Spooky は追跡中のファイルの変更を先にスタッシュすることを提案します。

どこかのステップが失敗すると、Spooky はそこで止まり、どのステップで止まったか、どのステップが済んだかを知らせます。:ui[activity.title] には、プルとプッシュがそれぞれ 1 件の記録として残ります。

## 別の場所へプッシュする {#push-to}

ブランチ、タグ、コミットを、リモート上の任意のブランチや参照へプッシュするには、次のようにします。

1. :ui[menu.repository > sync.pushToMenu] を選ぶか、ブランチを右クリックしてメニューから :ui[branch.pushToMenu]{1="main"} を選びます。タグのメニューにも :ui[tag.pushToMenu]{1="v0.4.0"} があります。
2. :ui[sync.revision] でプッシュするものを、:ui[sync.remote] でリモートを選びます。
3. :ui[sync.refSpec] に行き先を入力します。新しいブランチ名か既存のブランチ名、または `refs/tags/v0.4.0` のような完全な参照です。
4. :ui[sync.pushRevision] をクリックします。

ブランチの場合、ダイアログには最初、追跡しているリモートブランチが入っています。タグの場合は、`refs/tags/` とタグの名前が入っています。

## 強制プッシュ {#force-push}

コミットの修正やリベースなどで、プッシュ済みのコミットを書き換えると、通常のプッシュは拒否されます。自分のブランチにもうないコミットが、リモートブランチにあるからです。強制プッシュは、リモートブランチを自分のブランチで置き換えます。

Spooky の強制プッシュは、必ずリース付きです。プッシュが通るのは、リモートブランチが最後にフェッチしたときの位置のままである場合だけです。その間に誰かがプッシュしていれば、Git が拒否し、何も上書きされません。Spooky が保護のない強制プッシュに切り替えることはありません。

1. :ui[menu.repository > sync.forcePushMenu]（<kbd>⌃⌘U</kbd>）を選ぶか、ローカルブランチを右クリックしてメニューから選びます。
2. :ui[branch.target] でローカルブランチを、:ui[sync.destination] でリモートブランチを選びます。
3. その下の比較を読みます。プッシュでリモートブランチに加わるコミットの数と、上書きされるコミットの数が書かれています。そのうえで、次の点を確認します。
   - 緑の行は、リモートブランチが、書き換える前の自分のブランチと同じバージョンにあることを意味します。通常はこうなります。
   - 黄色の行は、リモートブランチが別の位置にあるか、自分のブランチに一度もなかったコミットを持っていることを意味します。本当に上書きしてよいか確かめてください。
   - 両方のブランチが同じコミットにあれば、プッシュするものはありません。
4. :ui[sync.forcePush] をクリックします。

::screenshot[リース付き強制プッシュのダイアログ。ローカルブランチは feature/units-toggle、リモートブランチは origin/feature/units-toggle です。その下の緑のチェックマークが付いた行は、リモートブランチが、書き換える前のこのブランチと同じバージョンにあることを伝えています。]{name="branches-force-push" frame="dialog" markers="16.4,65.9"}

1. 比較

プッシュのダイアログにある :ui[sync.forcePush] オプションも、同じ保護を使います。

:::tip
:ui[menu.view > menu.customizeToolbar] を選ぶと、:ui[toolbar.forcePush] と :ui[toolbar.pushTo] をツールバーに追加できます。
:::

## クイック版 {#quick}

<kbd>⌥</kbd> を押している間、ツールバーの :ui[sync.fetch]、:ui[sync.pull]、:ui[sync.push]、:ui[sync.sync] は :ui[sync.quickFetch]、:ui[sync.quickPull]、:ui[sync.quickPush]、:ui[sync.quickSync] に変わります。メニュー項目も同じように変わります。たとえば :ui[sync.quickPushMenu] です。

クイック版は、ダイアログを出さずにすぐ実行されます。

- 現在のブランチの上流を相手にします。
- ダイアログで最後に選んだオプションを使います。:ui[sync.skipHooks] は引き継がれません。
- :ui[sync.quickFetch] は、現在のブランチが追跡しているリモートをフェッチします。最後に :ui[sync.allRemotes] を選んでいた場合と、ブランチが何も追跡していない場合は、すべてのリモートをフェッチします。
- 現在のブランチがリモートブランチを追跡していないと、:ui[sync.quickPush] と :ui[sync.quickSync] はそのことを知らせます。

右クリックのメニューにもクイック版があります。リモートには :ui[sync.quickFetchNamed]{1="origin"}、リモートブランチには :ui[sync.quickPullNamed]{1="origin/main"} などです。

## 自動でフェッチする {#auto-fetch}

Spooky はバックグラウンドでフェッチして、リモートブランチと ↓ の数を最新に保てます。頻度は :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch] で選びます。:ui[settings.autoFetch.never]、5 分ごと、10 分ごと、30 分ごと、:ui[settings.autoFetch.hour] があります。最初は 30 分ごとです。[操作](/guide/settings/general/#operations) を参照してください。

- Spooky は、リポジトリを開いてから約 10 秒後と、そのあと数分ごとに、フェッチの時期が来たリモートを探します。一度もフェッチしていないリモートと、最後のフェッチから設定した間隔が過ぎたリモートが対象です。
- フェッチするのは、ウインドウがそのリポジトリを表示していて、ダイアログが開いていない間だけです。Spooky がバックグラウンドにあっても続けます。
- リポジトリでほかに何も実行されていないときだけ始めます。フェッチ中に別の操作を始めると、フェッチは止まり、その操作を先に通します。:ui[activity.title] には、どの操作のために止まったかが記録されます。
- パスワードを尋ねることはありません。失敗した場合、エラーは :ui[activity.title] にだけ表示されます。
- フェッチのダイアログで最後に選んだ整理とサブモジュールのオプションを使い、:ui[remote.skipFetchAll] にしたリモートは飛ばします。
- ローカルのリポジトリでは、Mac 上のパスを指すリモートは飛ばし、Mac がオフラインの間はフェッチしません。

## 関連ページ

- [マージとリベース](/guide/branches/merge-rebase/)
- [ブランチ](/guide/branches/branches/)
- [操作のキューとアクティビティ](/guide/advanced/queue-activity/)
- [スタッシュ](/guide/work/stash/)

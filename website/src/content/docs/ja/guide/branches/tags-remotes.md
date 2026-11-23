---
title: "タグとリモート"
description: "タグの作成、公開、削除と、リモートの追加、編集、名前の変更、削除。"
---

タグはサイドバーの :ui[sidebar.tags] の下に、リモートは :ui[remote.group] の下に並びます。どちらにも専用のメニューがあります。右クリックすると、できることがわかります。

## タグ {#tags}

タグは、コミットに動かない名前を付けます。たいてい `v0.4.0` のようなリリースに使います。ブランチと違って、コミットしても動きません。

タグにポインタを合わせると、タグが指しているコミットと、メッセージがあればそのメッセージがわかります。タグをダブルクリックすると、そのコミットをチェックアウトします。[タグやコミットをチェックアウトする](/guide/branches/branches/#checkout-revision) を参照してください。

ブランチと同じように、名前に `/` を含むタグはフォルダに入ります。新しいものから数件だけを表示したり、並び順を逆にしたりするには、[フィルタとグループ化](/guide/branches/branches/#filter) を参照してください。

### タグを作成する {#create-tag}

1. :ui[menu.repository > tag.createMenu]（<kbd>⇧⌘T</kbd>）を選びます。サイドバー下部の追加ボタンをクリックして、メニューから選ぶこともできます。特定のブランチやコミットにタグを付けるには、代わりにそれを右クリックしてメニューから :ui[tag.createFrom]{1="main"} を選びます。
2. :ui[reference.name] に名前を入力します。
3. :ui[tag.revision] は、タグを付けるコミットです。最初は現在のブランチか、右クリックした項目になっています。
4. 必要なら :ui[tag.messageField] を書きます。メッセージがなければ、タグはコミットの名前にすぎません。メッセージがあれば、Git はタグを誰がいつ作ったかも保存します。
5. タグに署名するには、:ui[tag.sign] を選択して、:ui[tag.signingKey] で鍵を選びます。:ui[tag.signingKey.configured] は、Git に設定されている鍵を使います。署名付きのタグにはメッセージが必要です。Spooky は署名するかどうかを覚えています。
6. :ui[tag.create.submit] をクリックします。

コミットやローカルブランチを :ui[sidebar.tags] またはタグのフォルダへドラッグすることもできます。

新しいタグは、公開するまでこのリポジトリにしかありません。作成を取り消すには、:ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）を選びます。

### タグを公開する {#publish-tag}

1. タグを右クリックしてメニューから :ui[tag.publishMenu]{1="v0.4.0"} を選ぶか、メニューバーで :ui[menu.repository > tag.publishMainMenu] を選びます。タグをリモートへドラッグすることもできます。
2. :ui[tag.local] と :ui[sync.remote] を確かめます。リモートは、現在のブランチが追跡しているリモートです。タグを別のリモートへドラッグした場合は、そのリモートになります。
3. リポジトリの Git フックを実行せずにプッシュするには、:ui[sync.skipHooks] を選択します。
4. :ui[tag.publish] をクリックします。

タグの公開は取り消せます。取り消すと、リモート上のタグがまた削除されます。

すべてのタグを一度にリモートへプッシュするには、リモートを右クリックしてメニューから :ui[tag.pushAll]{1="origin"} を選びます。プッシュのダイアログでも、すべてのタグを一緒に送れます。[プッシュ](/guide/branches/sync/#push) を参照してください。

### タグを削除する {#delete-tag}

タグを右クリックしてメニューから :ui[reference.deleteMenu]{1="v0.1.0"} を選びます。サイドバーにフォーカスがある状態で、1 つ以上のタグを選択して <kbd>⌘⌫</kbd> を押すこともできます。

Spooky は必ず先に確認します。リモート上のタグも削除するには、:ui[tag.deleteRemote] を選択して、:ui[sync.remote] でリモートを選びます。

このリポジトリだけでのタグの削除は取り消せます。リモート上での削除は取り消せません。

## リモート {#remotes}

リモートは、フェッチとプッシュの相手になる、リポジトリのもう 1 つのコピーです。多くはホスティングサービス上にあります。クローン元のリモートは、たいてい `origin` という名前です。

:ui[remote.group] の下では、各リモートにそのブランチが並びます。リモートにポインタを合わせると、フェッチとプッシュの URL がわかります。

リモートを右クリックするとメニューが開きます。

- :ui[remote.fetchMenu]{1="origin"} と :ui[sync.prune] は、このリモートのフェッチのダイアログを開きます。[フェッチ](/guide/branches/sync/#fetch) を参照してください。
- :ui[remote.viewInBrowser]{1="origin"} は、リモートの Web ページを開きます。HTTP(S)、SSH、`git://` の URL で使えます。ローカルのパスでは使えません。
- ほかの項目は、以下で説明するように、リモートの追加、編集、名前の変更、削除を行います。

:::note[サーバリポジトリ]
リモートへは、サーバのネットワークと SSH 鍵を使って、サーバから接続します。Mac で使える URL が、サーバからは使えないことがあります。
:::

### リモートを追加する {#add-remote}

1. メニューバーで :ui[menu.repository > remote.addMainMenu] を選びます。サイドバー下部の追加ボタンをクリックするか、:ui[remote.group] を右クリックして、メニューから :ui[remote.addMenu] を選ぶこともできます。
2. :ui[reference.name] に `upstream` のような短い名前を入力します。
3. :ui[remote.url] にアドレスをペーストします。
4. :ui[remote.add.submit] をクリックします。

Spooky は、リモートを追加する前に接続を確かめます。接続できなければ、ダイアログは開いたままです。入力の誤りを直して、もう一度試せます。リモートが追加されると、Spooky はすぐにフェッチします。

### リモートの設定 {#remote-settings}

サイドバーでリモートをクリックすると、その設定が開きます。上部の切り替えには 2 つのページがあります。

- :ui[remote.page.general] は、Git がリモートとどうやり取りするかを表示します。
- :ui[remote.page.branches] は、リモートのブランチと、それぞれが指しているコミットを一覧にします。

:ui[remote.page.general] の行にポインタを合わせると、その行のボタンが表示されます。

| 設定 | 働き |
|---|---|
| :ui[remote.field.fetchURL] | Spooky がフェッチする場所。リモートを右クリックして :ui[remote.editConnection] を選んでも編集できます。 |
| :ui[remote.skipFetchAll] | このリモートを自動フェッチと :ui[sync.fetchAll] の対象から外します。 |
| :ui[remote.field.fetchRefspecs] | どのブランチをフェッチして、どこに置くか。 |
| :ui[remote.field.pushURL] | Spooky がプッシュする場所。設定するまでは、プッシュにはフェッチの URL が使われ、グレーで表示されます。:ui[remote.action.unset] でその状態に戻ります。 |
| :ui[remote.field.pushRefspecs] | どのブランチを、どこへプッシュするか。 |

refspec は、一方の側のブランチ名をもう一方の側の名前に対応させる規則です。ほとんどのリモートでは、Git が設定する 1 つだけで足ります。追加するには、:ui[remote.group.fetch] または :ui[remote.group.push] の横の :ui[remote.action.addRefspec] をクリックします。

Spooky は、新しい URL を保存する前に確かめます。リモートの設定の変更は取り消せます。

### リモートの名前を変更する、削除する {#rename-remote}

リモートを右クリックしてメニューから :ui[reference.renameMenu]{1="origin"} または :ui[reference.deleteMenu]{1="origin"} を選びます。

リモートを削除すると、そのリモートとリモートブランチがこのリポジトリから削除されます。リモートが指しているリポジトリは変わりません。名前の変更と削除は、どちらも取り消せます。

## 関連ページ

- [ブランチ](/guide/branches/branches/)
- [フェッチ、プル、プッシュ](/guide/branches/sync/)
- [取り消しと復元](/guide/work/undo/)

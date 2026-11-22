---
title: "Git LFS"
description: "Git LFS の有効化、ファイルとパターンの追跡、LFS コンテンツのフェッチ、プル、プッシュについて説明します。"
---

Git LFS は、大きなファイルをリポジトリの履歴の外に置きます。リポジトリには、ファイルごとに小さなポインタファイルが保存されます。中身は、リモートの LFS ストアに送られます。

Spooky は、リポジトリのあるマシンで Git LFS を実行します。

## 必要なもの {#requirements}

Git LFS 2.9.0 以降が、リポジトリのあるマシンで Git が使う `PATH` に入っている必要があります。

確認するには、サイドバーの :ui[workspace.group] の下にある :ui[repositorySettings.title] をクリックします。:ui[repositorySettings.lfs] セクションに、Git LFS の :ui[lfs.version] が表示されます。[Git LFS、無視、除外](/guide/settings/identity/#repository-files) を参照してください。

Git LFS が見つからない場合や古すぎる場合は、そこに表示される注記に対処方法が書かれています。

- **Mac の場合**：Git LFS をインストールまたはアップデートします。インストール済みなのに見つからない場合は、:ui[app.name > settings.title] › :ui[settings.environment] を開きます。:ui[settings.environment.loginShell] を選択するか、`PATH` をカスタム変数として追加します。[この Mac 上の変数](/guide/settings/general/#local-variables) を参照してください。
- **サーバーの場合**：サーバーに Git LFS をインストールまたはアップデートします。そのフォルダを、`~/.zshenv` などで、非対話の SSH セッションの `PATH` に追加します。

Git LFS がない間は、そのセクションのボタンのうち Git LFS が必要なものは使えません。

## Git LFS を有効にする {#enable}

リポジトリの設定の :ui[repositorySettings.lfs] セクションで、:ui[lfs.enable] をクリックします。Git LFS がこのリポジトリだけに設定されます。グローバルの Git 設定は変更されません。[Git LFS、無視、除外](/guide/settings/identity/#repository-files) を参照してください。

Git に Git LFS のフィルタが設定されていて、リポジトリに Git LFS のフックがあるとき、Spooky はそのリポジトリが Git LFS を使っているものとして扱います。それまでは、セクションには :ui[lfs.enable] だけが表示されます。LFS のメニュー項目も使えません。

Git LFS を使っているリポジトリをクローンするときは、:ui[clone.lfs] を選択します。[リポジトリをクローンする](/guide/repositories/manager/#clone) を参照してください。

Git LFS をアップデートしたあとは、メニューバーで :ui[menu.repository > lfs.menu > lfs.menu.update] を選んで、リポジトリの Git LFS のフックを更新します。

## ファイルを追跡する {#track}

追跡パターンに一致するファイルは、Git LFS で保存されます。パターンは、リポジトリのルートにある `.gitattributes` に書き込まれます。このリポジトリを使う全員に適用されます。`.gitattributes` の変更は作業コピーに表示されます。ほかの変更と同じようにコミットします。

パターンを追加するには、リポジトリの設定の :ui[lfs.createPattern] をクリックするか、メニューバーで :ui[menu.repository > lfs.menu > lfs.menu.track] を選びます。`*.psd` のようなパターンを入力し、:ui[files.pattern.save] をクリックします。

::screenshot[リポジトリの設定の Git LFS セクション。インストールされている Git LFS のバージョンと、*.psd と *.mp4 の 2 つの追跡パターンが表示されています。*.psd の行には、パターンにポインタを合わせると現れる削除ボタンが表示されています。]{name="advanced-lfs-settings" frame="window" markers="33,24 91.6,35.6 48.8,34.4"}

1. インストールされている Git LFS のバージョン
2. パターンを削除するボタン
3. :ui[lfs.createPattern]

作業コピーでファイルを右クリックして、:ui[lfs.menu] から選ぶこともできます。

- :ui[lfs.trackFile]：選択したファイルだけを、そのとおりのパスで追跡します。ファイルが複数の場合は、その数が表示されます。
- :ui[lfs.trackType.single]{1="psd"}：同じ拡張子のすべてのファイルを追跡します。ファイルが複数の場合は :ui[lfs.trackType] になり、それぞれの拡張子が対象になります。
- :ui[lfs.createPattern.menu]：選択した最初のファイルのパスをもとに、パターンを自分で入力します。

フォルダの場合は、:ui[lfs.createPattern.menu] だけが使えます。

### パターンの追跡をやめる {#untrack}

リポジトリの設定で、パターンの横の :ui[lfs.remove] をクリックし、確定します。パターンが `.gitattributes` から取り除かれます。すでに Git LFS で保存されているファイルは、そのまま残ります。

Git LFS がパターンを削除できない場合、Spooky は残っているパターンを知らせます。:ui[repositorySettings.lfs.patterns] の横にある :ui[repositorySettings.openInEditor] を使って、手作業で削除します。[Git LFS、無視、除外](/guide/settings/identity/#repository-files) を参照してください。

## LFS コンテンツをフェッチ、プル、プッシュする {#transfer}

Git LFS が設定されていると、Git は通常、ファイルをチェックアウトするときに LFS コンテンツをダウンロードし、プッシュするときにアップロードします。自分で実行するには、メニューバーの :ui[menu.repository > lfs.menu] から選びます。

| 項目 | 動作 |
|---|---|
| :ui[lfs.menu.fetch] | 現在のチェックアウトに必要な LFS コンテンツをダウンロードします。作業コピーは変わりません。 |
| :ui[lfs.menu.pull] | ダウンロードしてから、作業コピーのポインタファイルを中身に置き換えます。 |
| :ui[lfs.menu.push] | すべてのローカルブランチとタグで使われている LFS コンテンツのうち、リモートにまだないものをアップロードします。 |

ダイアログでリモートを選びます。最初は、現在のブランチの上流のリモートが選ばれていて、上流がない場合は最初のリモートが選ばれています。進行状況は、サイドバー下部にある [アクティビティエリア](/guide/advanced/queue-activity/#activity-area) に表示されます。

## 取り消し {#undo}

Git LFS の有効化、追跡パターンの追加、追跡パターンの削除は取り消せます。[取り消しと復元](/guide/work/undo/) を参照してください。

フックの更新は取り消せません。それより前の操作も取り消せなくなります。

LFS コンテンツのフェッチ、プル、プッシュは、リポジトリのフェッチ、プル、プッシュと同じく記録されません。それより前の操作は、引き続き取り消せます。

:::note[サーバーリポジトリ]
Git LFS はサーバー上で実行されます。LFS コンテンツは、サーバーとリモートの間でやり取りされます。サーバーリポジトリでは、Mac に Git LFS は必要ありません。
:::

## 関連ページ

- [システム要件](/reference/requirements/#optional)
- [サブモジュール](/guide/advanced/submodules/)
- [リポジトリウインドウ](/guide/repositories/manager/)

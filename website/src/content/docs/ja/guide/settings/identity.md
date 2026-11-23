---
title: "ユーザプロファイルと Git 設定"
description: "ユーザプロファイルと Git 設定を管理し、1 つのリポジトリだけの設定を調整します。"
---

Git はすべてのコミットに名前とメールアドレスを記録し、鍵で署名することもできます。Spooky では、これらを 3 つの場所で設定できます。

- :ui[app.name > settings.title] の :ui[settings.profiles] には、切り替えて使うユーザ情報を保存します。
- :ui[app.name > settings.title] の :ui[settings.gitConfig] では、Git プログラムと、グローバルのユーザ情報と署名を設定します。
- 1 つのリポジトリの設定は、そのリポジトリでグローバルの設定より優先されます。

## ユーザプロファイル {#profiles}

ユーザプロファイルは、名前、メールアドレス、省略可能な署名鍵を、「仕事」のようなタイトルを付けて保存したものです。Spooky はプロファイルをこの Mac に保存します。ローカルのリポジトリでもサーバリポジトリでも使えます。

プロファイルを追加するには、次のようにします。

1. :ui[app.name > settings.title] › :ui[settings.profiles] を選びます。
2. 一覧の下の追加ボタンをクリックします。
3. :ui[profiles.title]、:ui[profiles.userName]、:ui[profiles.email] のフィールドに入力します。必要に応じて、この Mac で見つかった鍵から :ui[profiles.signingKey] を選びます。
4. :ui[profiles.create.submit] をクリックします。

タイトル、ユーザ名、メールアドレスは必須です。2 つのプロファイルに同じタイトルを付けることはできません。ユーザ名とメールアドレスの両方が同じプロファイルも作れません。

プロファイルを変更するには、選択して :ui[profiles.edit] をクリックします。削除するには、選択して削除ボタンをクリックします。プロファイルを削除しても、Git の設定は変わりません。

いま使っているユーザ情報がまだプロファイルになっていないときは、そのメニューから :ui[profiles.addCurrent]{1="alex@example.com"} を選びます。タイトルを入力して、:ui[profiles.add.submit] をクリックします。

### プロファイルを使う {#use-profile}

ユーザ情報の横の画像をクリックすると、プロファイルが表示されます。使用中のプロファイルにはチェックマークが付いています。プロファイルを選んだときに何が変わるかは、選ぶ場所によって違います。

| 場所 | 変わるもの | 先に確認するか |
|---|---|---|
| コミットエリア、または [リポジトリの設定](#repository) の :ui[bookmarks.detail.identity] | このリポジトリ自身の Git 設定。[コミットする人を選ぶ](/guide/work/commit/#identity) を参照してください。 | はい |
| 設定の :ui[settings.gitConfig] | この Mac のグローバルの Git 設定 | いいえ |

プロファイルの名前とメールアドレスは、`user.name` と `user.email` に書き込まれます。署名鍵のあるプロファイルは、`user.signingkey` と `gpg.format` も設定します。

[クイックアクション](/guide/repositories/navigation/#quick-actions) にもプロファイルが並びます。:ui[quickActions.setCommitter] は、コミットエリアと同じように働きます。:ui[quickActions.setGlobalUser] は、確認したうえで、リポジトリがあるマシンのグローバルの Git 設定に名前とメールアドレスを設定します。

:::note[サーバリポジトリ]
サーバリポジトリでプロファイルを選ぶと、サーバ上のリポジトリの設定が変わります。そこでコミットするほかのツールも、同じユーザ情報を使います。サーバリポジトリでの :ui[quickActions.setGlobalUser] は、サーバ上のグローバル設定に書き込みます。
:::

## Git 設定 {#git-config}

:ui[settings.gitConfig] ページは 4 つの部分に分かれています。Git プログラム、ユーザ情報、署名、外部ツールです。ツールについては [連携](/guide/settings/integration/#diff-merge-tools) で説明しています。

::screenshot[設定ウインドウの「Git 設定」ページ。Git プログラム、グローバルの名前とメールアドレス、署名の設定、比較ツールとマージツールがあります。]{name="settings-git-config" frame="window" markers="20,16.7 20,29.4 20,46 20,83.4"}

1. Git プログラム
2. ユーザ情報
3. 署名
4. 外部ツール

### Git プログラム {#git-program}

:ui[settings.gitProgram] には、この Mac にある十分に新しい Git プログラムが、バージョンとともに並びます。Spooky は一般的な場所を探します。`/usr/bin/git`（システムのものと表示され、最初に使われます）、Command Line Tools、Xcode、Homebrew、MacPorts です。

一覧にない Git を使うには、:ui[settings.gitProgram.choose] を選んでプログラムを選択します。ファイルが Git でないか、バージョンが古すぎるときは、Spooky が理由を表示し、それまでのプログラムをそのまま使います。メニューの下の行には、Spooky が受け付ける最低バージョンが表示されます。

:::note[サーバリポジトリ]
この設定は、ローカルのリポジトリにだけ適用されます。サーバリポジトリは、サーバの Git を使います。[システム要件](/reference/requirements/#servers) を参照してください。
:::

### グローバルのユーザ情報 {#global-identity}

:ui[gitConfig.userName] と :ui[gitConfig.email] は、Git のグローバルの `user.name` と `user.email` です。この Mac 上のリポジトリは、独自の設定がない限り、すべてこれを使います。

変更は、<kbd>Return</kbd> を押すか、フィールドを離れたときに保存されます。フィールドを空にすると、設定が削除されます。下の行には、保存先のファイルが表示されます。通常は `~/.gitconfig` です。

右側の画像をクリックすると、[プロファイル](#use-profile) を選んだり管理したりできます。

### 署名 {#signing}

これらの設定は、この Mac 上の、独自の設定がないすべてのリポジトリで、Git がコミットに署名する方法を決めます。

| 設定 | 内容 |
|---|---|
| :ui[gitConfig.sshProgram] | SSH 鍵で署名するプログラム。最初は :ui[gitConfig.sshProgram.system] が使われます。1Password がインストールされていれば、その署名プログラムも表示されます。 |
| :ui[gitConfig.gpgProgram] | OpenPGP 鍵用の GnuPG プログラム。この Mac にある十分に新しいバージョンが並びます。別のものを選ぶには、:ui[gitConfig.gpgProgram.select] を選びます。 |
| :ui[gitConfig.signingKey] | 署名に使う鍵。GnuPG のキーリングにある秘密鍵、または SSH エージェントに読み込まれた鍵です。鍵を選ぶと、OpenPGP と SSH のどちらで署名するかも Git に伝わります。 |
| :ui[gitConfig.allowedSigners] | 署名を信頼する SSH 鍵のファイル。Git が署名を検証するときに使います。`~/.ssh/allowed_signers` を選ぶか、別のファイルを選ぶか、:ui[gitConfig.allowedSigners.none] を選びます。 |
| :ui[gitConfig.signCommits] | すべてのコミットに署名します |
| :ui[gitConfig.ensureEmailMatch] | OpenPGP 鍵のメールアドレスがグローバルのメールアドレスと違うときに警告します。最初はオンです。 |

実行できない署名プログラムなど、対応が必要なことがあると、設定の横に黄色の警告ボタンが表示されます。クリックすると、問題の内容が表示されます。

署名付きコミットとパスフレーズの入力については、[コミットに署名する](/guide/work/commit/#signing) で説明しています。

## リポジトリの設定 {#repository}

リポジトリごとに独自の設定があります。表示するには、サイドバーの :ui[workspace.group] の下にある :ui[repositorySettings.title] をクリックします。上部のボタンで、4 つのセクションを切り替えます。

変更はリポジトリ自身の Git 設定に書き込まれ、リポジトリのほかの操作と一緒に順番を待ちます。リポジトリで設定していないものは、グローバルの設定から取ります。

::screenshot[メインウインドウに表示されたリポジトリの設定。「一般」タブに、リポジトリの名前、パス、説明、ユーザ情報、署名の設定があります。]{name="settings-repository" frame="window" markers="78.8,9.8 60,38.8"}

1. セクションを切り替えるボタン
2. :ui[bookmarks.detail.identity]

### 一般 {#repository-general}

| 項目 | 表示される内容 |
|---|---|
| :ui[repositorySettings.name] と :ui[repositorySettings.path] | リポジトリのある場所 |
| :ui[repositorySettings.localLocation] | サーバリポジトリの場合、リポジトリのフォルダがこの Mac のどこにあるか。[場所を設定する](/guide/server/local-location/#set) を参照してください。 |
| :ui[bookmarks.detail.description] | リポジトリの説明。[リポジトリウインドウ](/guide/repositories/manager/) にも表示されます。変更するには :ui[bookmarks.detail.edit] をクリックします。 |
| :ui[bookmarks.detail.identity] | このリポジトリがコミットに使う名前とメールアドレス。画像をクリックすると [プロファイル](#use-profile) を使えます。:ui[bookmarks.detail.edit] をクリックすると、このリポジトリだけの名前とメールアドレスを入力できます。 |

:ui[repositorySettings.signing] の下の :ui[repositorySettings.signCommits]、:ui[repositorySettings.signingKey]、:ui[repositorySettings.allowedSigners] は、[グローバルの設定](#signing) と同じように働きます。ただし、このリポジトリだけが対象です。

### Git LFS、無視、除外 {#repository-files}

- :ui[repositorySettings.lfs] には、Git LFS のバージョンと :ui[repositorySettings.lfs.patterns] が表示されます。[Git LFS](/guide/advanced/lfs/) を参照してください。
- :ui[repositorySettings.ignores] には、リポジトリの最上位にある `.gitignore` のルールが並びます。このファイルをコミットすると、ルールをほかの人と共有できます。
- :ui[repositorySettings.excludes] には、Git の `info/exclude` のルールが並びます。リポジトリのこのコピーにだけ適用されます。

ルールを変更するには、:ui[repositorySettings.openInEditor] をクリックします。ファイルは、Mac がそのファイルに使うアプリケーションで開きます。ファイルがまだないときは、Spooky が先に作成します。

:::note[サーバリポジトリ]
設定はサーバ上で読み書きされます。変更できるのは、リポジトリが接続されている間だけです。:ui[repositorySettings.openInEditor] は、作業コピーがサーバ上のファイルを開くのと同じ方法でファイルを開きます。[ターミナルとほかのアプリケーション](/guide/server/local-location/#terminal) を参照してください。
:::

## 関連ページ

- [変更をコミットする](/guide/work/commit/)
- [一般、アップデート、環境](/guide/settings/general/)
- [連携](/guide/settings/integration/)
- [システム要件](/reference/requirements/)

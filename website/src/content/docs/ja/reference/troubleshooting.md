---
title: "トラブルシューティング"
description: "接続の失敗、古い Git、アクセス権、サーバーの PATH といったよくある問題を解決します。問題を報告する方法も説明します。"
---

以下の各問題は、まず目にする表示を挙げ、そのあと原因と対処を説明します。Spooky のエラーの多くは、Git や SSH の元の出力も表示します。そこに正確な原因が書かれていることがよくあります。

## サーバーに接続できない {#connect}

接続の問題は、次のどこかに現れます。

- :ui[remote.form.title] ダイアログが開いたままになり、直すべき点を知らせます。それぞれの場合については、[チェックに失敗したとき](/guide/server/add/#results) を参照してください。
- サーバーリポジトリを開くと、:ui[missing.unreachable.title]{1="driftwood-server"} と表示されます。[切断中](/guide/server/connection/#offline) を参照してください。
- 開いているサーバーリポジトリで、一覧の上部の帯が黄色になり、理由を表示します。[接続状態](/guide/server/connection/#status) を参照してください。

まず、同じログインを Spooky の外で試します。ターミナルで、自分のホストエイリアスを使って次を実行します。

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

失敗する場合、問題は Mac とサーバーの間にあります。出力の種類ごとの意味は、[Spooky と同じ方法で接続を試す](/guide/server/prepare-ssh/#test) を参照してください。ターミナルでは成功するのに Spooky がログインできない場合、Spooky が別の SSH エージェントを使っている可能性があります。[SSH エージェント](/guide/settings/integration/#ssh-agent) を参照してください。

Spooky が表示する理由から、どこを調べればよいかがわかります。

| 理由 | 対処 |
|---|---|
| :ui[remoteError.authentication] | サーバーが鍵を受け付けていないか、Mac が鍵のロックを解除できません。再起動のあとは、[Mac を再起動したあと](/guide/server/prepare-ssh/#after-restart) のとおりに鍵をもう一度読み込みます。パスワードでしかログインできないアカウントは使えません。 |
| :ui[remoteError.unknownHostKey] | Mac がまだそのサーバーを知りません。[一度接続する](/guide/server/prepare-ssh/#fingerprint) のとおりに、ターミナルで一度接続してフィンガープリントを確かめます。Spooky が代わりにフィンガープリントを受け入れることはありません。 |
| :ui[remoteError.changedHostKey] | まだ接続しないでください。先に、サーバーの所有者に変更を確認します。 |
| :ui[remoteError.unavailable] | ホストエイリアスとネットワークを確かめます。Spooky は、試行が失敗するたびに 5 秒後にもう一度試します。すぐに試すには、帯の :ui[action.reconnect] をクリックします。[切断と再接続](/guide/server/connection/#reconnect) を参照してください。 |
| :ui[remoteError.deployment] | Spooky に必要なものがサーバーにありません。Unix ソケットの転送、`/usr/bin/perl`、`~/.spooky/bin` と `/tmp` への書き込み権限のどれかです。[サーバー](/reference/requirements/#servers) を参照してください。 |

サーバー上の Git が見つからないか古すぎる場合は、この先を読んでください。

## Git が古すぎる {#git-version}

Spooky には、Mac とサーバーの両方で Git 2.41.0 以降が必要です。

### Mac 上 {#mac-git}

ローカルのリポジトリを開くと、Spooky が次のどちらかを表示することがあります。

- :ui[error.version]。その下に Git の出力が表示されます。Spooky が使っている Git プログラムが 2.41.0 より古い状態です。:ui[app.name > settings.title] › :ui[settings.gitConfig] の :ui[settings.gitProgram] の横で新しいものを選ぶか、Xcode または Command Line Tools をアップデートします。
- :ui[error.gitProgram]。その下にパスが表示されます。選んでいた Git プログラムが、アンインストールなどでなくなっています。同じ場所で別のものを選びます。

メニューには、十分に新しい Git プログラムだけが並びます。[Git プログラム](/guide/settings/identity/#git-program) を参照してください。

### サーバー上 {#server-git}

接続が :ui[remoteError.gitVersion] で失敗します。サーバー上の Git を 2.41.0 以降にアップデートします。

新しい Git がすでにインストールされている場合は、SSH ログインが古いほうを先に見つけています。[サーバーで Git が見つからない](#server-path) のとおりに、新しい Git のフォルダを `PATH` でほかより前に置きます。

## サーバーで Git が見つからない {#server-path}

接続が :ui[remoteError.gitUnavailable] で失敗します。または、:ui[app.name > settings.title] › :ui[settings.environment] でサーバーを確認すると、:ui[settings.environment.server.noGit] と表示されます。

サーバーに Git がインストールされていない場合は、Git 2.41.0 以降をインストールします。インストールされている場合、原因はたいてい `PATH` です。Spooky は、対話シェルを使わずに、SSH 経由でサーバー上のコマンドを実行します。そのシェルが読み込む起動ファイルは少なくなります。`~/.zshrc` や `~/.bash_profile` で設定した `PATH` は、適用されないことがあります。

直すには、次のようにします。

1. ターミナルでサーバーにログインして、`command -v git` を実行します。`/opt/homebrew/bin/git` のように、Git の場所が表示されます。
2. それを Spooky が受け取る `PATH` と比べます。これはエラーの出力に書かれています。[サーバーを確認する](/guide/settings/general/#server-check) の確認でも表示されます。
3. 非対話シェルが読み込む起動ファイルで、Git のフォルダを `PATH` に追加します。使っているシェルを調べるには、サーバーで `echo $SHELL` を実行します。
   - zsh：`~/.zshenv`
   - bash：`~/.bashrc`。シェルが対話的でないときに途中で終了する行があれば、それより上に書きます

   例：

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. もう一度 :ui[settings.environment.server.check] をクリックするか、[サーバーに接続できない](#connect) のテストを実行します。そのあと、再接続します。

Git LFS と、フックが実行するプログラムも、同じ `PATH` で探されます。ターミナルでは動くのに Spooky からは動かない場合は、同じ方法でそれらのフォルダを追加します。

## アクセス権の問題 {#permissions}

| 表示 | 原因と対処 |
|---|---|
| :ui[remoteError.pathPermission] | サーバー上の自分のユーザが、リポジトリのフォルダを開けないか読めません。サーバーの所有者にアクセス権を頼むか、自分が所有するフォルダを選びます。 |
| :ui[remoteError.diskAccess] | サーバーが Mac で、リポジトリが「書類」のような macOS が保護するフォルダにあります。[Mac をサーバーとして使う](/guide/server/prepare-ssh/#mac-server) のとおりに、リモートユーザのフルディスクアクセスをオンにするか、リポジトリを移動します。 |
| :ui[error.ownership] | この Mac 上のリポジトリのフォルダが、別のユーザのものです。Git はその中での作業を拒否します。フォルダの所有者を自分に変更します。所有者を信頼できる場合は、代わりに、Git の出力が提案する `git config --global --add safe.directory` コマンドを実行することもできます。 |
| :ui[error.terminal] | タイトルの下の詳細に、何がうまくいかなかったかが書かれています。多くは、:ui[settings.terminal] の横で選んだターミナルアプリケーションがもうインストールされていないか、Spooky にターミナルや iTerm の制御を許可していないことが原因です。[ターミナル](/guide/settings/integration/#terminal) を参照してください。 |
| :ui[appIcon.writeFailed] | Spooky はアイコンを `Spooky.app` の中に保存します。自分のユーザがそこに書き込めなければなりません。Finder で Spooky を選択し、**ファイル › 情報を見る**を選んで、**共有とアクセス権**で自分が**読み/書き**になっていることを確かめます。 |

:::note[サーバーリポジトリ]
サーバーでは、別のユーザのフォルダは :ui[remoteError.notWorkingTree] で失敗し、Git の出力が所有権に触れます。サーバーの所有者に頼むか、サーバーで `safe.directory` コマンドを実行します。
:::

## 問題を報告する {#report}

:ui[menu.help > help.support] を選ぶと、GitHub にある Spooky の Issue が開きます。そこで同じ問題を探すか、新しい Issue を作成します。何をしたか、何を期待したか、何が起きたかを書いてください。Spooky がエラーを表示した場合は、そのタイトルと元の出力も含めます。

診断レポートがあると、何が起きたかを伝えやすくなります。:ui[menu.help > help.diagnosticReport] を選んで、保存先を選びます。Spooky はテキストファイルを保存して、Finder に表示します。レポートをどこかへ送ることはありません。共有する前に、ファイルを開いて読んでください。含まれる内容は、[診断レポート](/reference/data-privacy/#diagnostic-reports) を参照してください。

前回 Spooky が予期せず終了していた場合は、次に起動したときに :ui[crash.title] と尋ねます。:ui[crash.report] をクリックすると、GitHub の新しい Issue のページがブラウザで開きます。クラッシュの概要が入力済みです。Issue が作成されるのは、ブラウザで送信したときだけです。[クラッシュレポート](/reference/data-privacy/#crash-reports) を参照してください。

## 関連ページ

- [SSH を準備する](/guide/server/prepare-ssh/)
- [接続状態と再接続](/guide/server/connection/)
- [システム要件](/reference/requirements/)
- [データとプライバシー](/reference/data-privacy/)

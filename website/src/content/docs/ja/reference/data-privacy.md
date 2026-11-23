---
title: "データとプライバシー"
description: "Spooky が何をどこに保存するか、どのネットワークアドレスに接続するか、クラッシュレポートと診断レポートに何が含まれるかを説明します。"
---

Spooky にはアカウントがなく、利用状況のデータも収集しません。このページでは、何を保存するか、どこに保存するか、どのアドレスに接続するかをまとめます。

## Mac 上 {#mac}

| 内容 | 場所 |
|---|---|
| 設定、リポジトリの一覧、ユーザプロファイル、ホスティングアカウントの一覧、サーバリポジトリのこの Mac 上の場所 | Spooky の設定、`com.rakuyo.spooky` |
| テーマ。1 つにつき `.spookytheme` ファイルが 1 つ | `~/Library/Application Support/Spooky/Themes/` |
| サーバリポジトリを最近使った書類に表示するための、小さな `.spookyrepo` フォルダ | `~/Library/Application Support/Spooky/Locations/` |
| :ui[activity.title] にある、フェッチ、プル、プッシュなどのリモート操作の記録。7 日間保存されます | `~/Library/Application Support/Spooky/Activity/` |
| :ui[activity.title] が変更を数えるときの比較対象。リポジトリごとに 1 ファイル | `~/Library/Application Support/Spooky/Baselines/` |
| サーバ上の Git 用に保存したユーザ名とパスワード | キーチェーン。項目の名前は `com.rakuyo.spooky.remote.<host alias>` |
| ホスティングアカウントのトークン | キーチェーン。項目の名前は `com.rakuyo.spooky.hosting.<address>` |
| macOS が Spooky のネットワークリクエストのために保存するキャッシュと Cookie | `~/Library/Caches/com.rakuyo.spooky/` と、`~/Library/HTTPStorages/` にある名前が `com.rakuyo.spooky` で始まる項目 |
| サーバリポジトリの接続用ファイル | `/tmp/spooky-*` フォルダ。接続が閉じると削除されます |
| クイックルックやほかのアプリケーションで開いたファイルのコピー | 一時的な `spooky-files-*` フォルダ。リポジトリを閉じると削除されます |

セルフマネージドの GitLab にユーザ名とパスワードでサインインした場合、Spooky は引き換えに受け取ったトークンを保管します。パスワードは保管しません。

これらをすべて削除するには、[アンインストール](/guide/start/install/#uninstall) を参照してください。

## サーバ上 {#servers}

リポジトリそのもののほかに、Spooky はサーバ上の 2 か所に書き込みます。

- ホームフォルダの `~/.spooky/bin/`：Spooky が SSH 経由で実行する小さなスクリプトと、入力の要求と署名のための、そのスクリプトへのリンク。次の接続のために残ります。削除するには、フォルダを削除します。
- `/tmp/spooky-*`：現在の接続のためのファイル。接続が閉じると削除されます。

Spooky は、リポジトリの [この Mac 上の場所](/guide/server/local-location/#automatic) を探すとき、リポジトリの Git フォルダに空のファイルを少しの間だけ置きます。確認が済むとすぐに削除します。

サーバ上の Git がパスワードを求めると、Spooky は Mac から SSH 接続を通して、求めた Git コマンドにだけ答えを送ります。サーバ上の Git はそれを保存しません。Spooky が、自分の実行するコマンドでは Git の資格情報ヘルパーをオフにしているからです。

## リポジトリ内 {#repositories}

Spooky は、いくつかの情報をリポジトリ自身の Git 設定に `branch.<name>.spooky-*` というエントリとして保存します。

- どのブランチがピン留めまたはアーカイブされているか
- 各ブランチの親ブランチ
- 自動アーカイブに使うマーク

これらのエントリは、ブランチの名前を変更すると一緒に移り、ブランチを削除するとなくなります。署名など、リポジトリの :ui[repositorySettings.title] で変更した Git の設定も、同じ設定に保存されます。[リポジトリの設定](/guide/settings/identity/#repository) を参照してください。

Git の設定はプッシュされないので、これらがリモートに届くことはありません。サーバリポジトリでは、サーバ上に保存されます。

## ネットワーク接続 {#network}

| Spooky の接続先 | タイミング |
|---|---|
| 自分のサーバ（SSH 経由） | サーバリポジトリを開いている間。Spooky は `~/.ssh/config` のホストエイリアスを使います。SMB マウントは、サーバのファイル共有にも接続します。 |
| Git のリモート | フェッチ、プル、プッシュ、クローンをするときと、自動フェッチのとき。サーバリポジトリでは、Git は Mac からではなくサーバから接続します。 |
| `github.com` と `api.github.com`、または自分の GitLab のアドレス | ホスティングアカウントを追加または再認証するときと、アカウントが必要な機能を使うとき。プルリクエストとマージリクエスト、Issue 番号の補完、ブランチの整理での状態、リポジトリの公開です。これらのリクエストは Mac から送られます。[リクエストの送り先](/guide/hosting/accounts/#network) を参照してください。 |
| `gravatar.com` | コミットの作成者の画像を表示するため |
| `github.com`（Spooky のリリース） | アップデートを確認するため |

自動フェッチは、デフォルトでは 30 分ごとに実行されます。変更するには、:ui[app.name > settings.title] を開いて :ui[settings.general] をクリックし、:ui[settings.autoFetch] の横でオプションを選びます。自分で操作したときだけフェッチするには、:ui[settings.autoFetch.never] を選びます。[操作](/guide/settings/general/#operations) を参照してください。

コミットの作成者の画像を取得するとき、Gravatar が受け取るのは作成者のメールアドレスのハッシュで、アドレスそのものではありません。ダウンロードした画像はメモリにだけ置かれ、Spooky を終了すると消えます。GitHub と GitLab のユーザの画像は、それらのサービスから取得します。画像をオフにする設定はありません。

Spooky は、デフォルトでは 1 日に 1 回アップデートを確認します。止めるには、:ui[app.name > settings.title] › :ui[settings.updates] で :ui[updates.automaticChecks] をオフにします。[Spooky を最新の状態に保つ](/guide/start/install/#updates) を参照してください。

:ui[help.help] や :ui[help.support] など、:ui[menu.help] メニューの項目は、ブラウザで Web ページを開きます。

## クラッシュレポート {#crash-reports}

前回 Spooky が予期せず終了していた場合、Spooky は macOS が Mac に保存したクラッシュレポートを読みます。次に起動したときに、:ui[crash.title] と尋ねます。

- :ui[crash.report] をクリックすると、GitHub の新しい Issue のページがブラウザで開きます。クラッシュの概要が入力済みです。
- :ui[crash.dontReport] をクリックすると、報告しません。Spooky はそのクラッシュについてもう尋ねません。

概要には、Spooky のバージョンとビルド、macOS のバージョン、クラッシュの種類、クラッシュしたスレッドのコールスタックの最大 30 行が含まれます。Mac から送り出す前に、Spooky はホームフォルダ、ユーザ名、メールアドレス、IP アドレス、トークン、Web アドレス内のパスワードをプレースホルダに置き換えます。

概要は、ページの Web アドレスの一部になっています。ページが開いた時点で GitHub に届きます。Issue が作成されるのは、ブラウザで送信したときだけです。その前に本文を編集することも、ページを閉じることもできます。

次回から確認を省くには、ダイアログで :ui[settings.crashReports.always] を選択します。以降、Spooky はすぐに Issue のページを開きます。同じオプションは :ui[app.name > settings.title] › :ui[settings.integration] にもあります。

## 診断レポート {#diagnostic-reports}

問題を報告するとき、診断レポートがあると何が起きたかを伝えやすくなります。:ui[menu.help > help.diagnosticReport] を選んで、保存先を選びます。Spooky はテキストファイルを保存して、Finder に表示します。レポートをどこかへ送ることはありません。

レポートには次の内容が含まれます。

- Spooky のバージョンとビルド、macOS のバージョン、優先する言語の上位 3 つ
- この Mac の Git プログラムとそのバージョン
- Spooky の動作に影響する設定。外観、アップデートチャンネル、ターミナルアプリケーション、比較ツールとマージツール、SSH エージェント、Git プログラム、ログインシェルから環境変数を読み込むかどうかなどです
- ローカルのリポジトリとサーバリポジトリの数
- 直近 20 件の操作の名前、時刻、結果
- 今回の起動での直近 1 時間分の Spooky のログ。最大 500 行

リポジトリのパス、ホストエイリアス、パスワード、環境変数の値は含まれません。Spooky は、クラッシュレポートと同じ方法で、ホームフォルダ、ユーザ名、メールアドレス、IP アドレス、トークンをプレースホルダに置き換えます。共有する前に、ファイルを開いて読んでください。

Spooky のログには、接続の変化と、操作の開始、完了、失敗が記録されます。コマンドの引数や出力、コミットメッセージ、パスワード、トークンは記録されません。

## 関連ページ

- [Spooky をインストールする](/guide/start/install/)
- [サーバリポジトリの仕組み](/guide/server/overview/)
- [ホスティングアカウント](/guide/hosting/accounts/)
- [システム要件](/reference/requirements/)

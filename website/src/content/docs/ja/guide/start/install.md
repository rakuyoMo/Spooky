---
title: "Spooky をインストールする"
description: "システム要件の確認、Spooky のダウンロード、初回の起動、アップデート、表示言語の選択、アンインストールについて説明します。"
---

このページでは、Spooky をダウンロードしてから初めて開くまでの手順を説明します。アップデート、表示言語、Spooky の削除方法も取り上げます。

## システム要件 {#requirements}

- macOS 26 以降
- Git 2.41 以降

別の Git を選ばない限り、Spooky は `/usr/bin/git` の Git を使います。変更するには、:ui[app.name > settings.title]（<kbd>⌘,</kbd>）を開いて :ui[settings.gitConfig] をクリックし、:ui[settings.gitProgram] メニューからプログラムを選びます。メニューには、Spooky が見つけた Git のうちバージョンが十分に新しいものが並びます。ほかの場所にある Git を使うときは :ui[settings.gitProgram.choose] を選びます。最低バージョンはメニューの下に表示されます。[Git プログラム](/guide/settings/identity/#git-program) を参照してください。

:::note[サーバーリポジトリ]
サーバーにも Git 2.41 以降が必要です。Spooky は `~/.ssh/config` のホストエイリアスを使って SSH でサーバーに接続します。設定で選んだ Git が使われるのは、この Mac 上のリポジトリだけです。サーバーリポジトリではサーバーの Git を使います。[システム要件](/reference/requirements/) と [SSH を準備する](/guide/server/prepare-ssh/) を参照してください。
:::

## ダウンロード {#download}

1. GitHub の [Spooky のリリースページ](https://github.com/rakuyoMo/Spooky/releases) を開きます。
2. 最新の安定版を探します。名前は `v` にバージョン番号を続けたものです。名前が「(beta)」や「(development)」で終わるものはテスト用のビルドです。
3. `Spooky-` にバージョン番号を続けた名前の zip ファイルをダウンロードします。
4. ダウンロードした zip ファイルをダブルクリックして展開します。
5. Spooky を **アプリケーション** フォルダにドラッグします。

## Spooky を初めて開く {#first-launch}

Spooky は Apple の公証を受けていません。初めて開くとき、macOS は起動を止めて警告を表示します。それでも開くには、次のようにします。

1. **アプリケーション** フォルダで Spooky をダブルクリックします。警告が表示されたら閉じます。
2. **アップルメニュー › システム設定** と選択し、サイドバーで **プライバシーとセキュリティ** をクリックします。下にスクロールする必要がある場合があります。
3. **セキュリティ** に移動し、**このまま開く** をクリックします。このボタンは、Spooky を開こうとしてから約 1 時間のあいだ表示されます。
4. ログインパスワードを入力して、**OK** をクリックします。

macOS はこの選択を覚えています。以降、Spooky は普通に開けます。起動すると、まずリポジトリウインドウが表示されます。そこに何があるかは [Spooky の画面構成](/guide/start/tour/) で説明しています。

## Spooky を最新の状態に保つ {#updates}

デフォルトでは、Spooky が自分でアップデートを確認します。:ui[app.name > updates.check] を選ぶと、すぐに確認します。

アップデートにはすべて署名が付いています。Spooky はインストールの前に署名を検証します。検証に通らなかったアップデートが、いまの Spooky を置き換えることはありません。

アップデートの方法を変えるには、:ui[app.name > settings.title] を開いて :ui[settings.updates] をクリックします。

| 設定 | 内容 |
|---|---|
| :ui[updates.channel] | 受け取るリリースの種類。[リリースチャンネル](#channels) を参照してください。 |
| :ui[updates.automaticChecks] | バックグラウンドでアップデートを確認します。デフォルトでオンです。 |
| :ui[updates.automaticDownloads] | バックグラウンドでアップデートをダウンロードし、Spooky の終了時にインストールします。デフォルトでオフです。自動確認がオンで、Spooky が書き込み可能なフォルダにあるときだけ使えます。 |
| :ui[updates.interval] | 確認の頻度：:ui[updates.interval.hourly]、:ui[updates.interval.daily]、:ui[updates.interval.weekly] のいずれか。デフォルトは毎日です。自動確認がオンのときだけ使えます。 |

最後の行の :ui[updates.lastCheck] には、Spooky が最後に確認した日時が表示されます。まだ確認していないときは :ui[updates.never] と表示されます。

### リリースチャンネル {#channels}

| チャンネル | 受け取るリリース |
|---|---|
| :ui[updates.channel.stable] | 安定版。これがデフォルトです。 |
| :ui[updates.channel.beta] | 安定版とベータ版 |
| :ui[updates.channel.development] | 開発ビルドを含むすべてのリリース |

### 変更点を確認する {#whats-new}

新しいバージョンの Spooky を初めて起動すると、リポジトリのウインドウのサイドバー下部に :ui[whatsNew.card.title] が表示されます。:ui[whatsNew.card.learnMore] をクリックすると変更点を読めます。カードをそのまま閉じてもかまいません。

あとで読みたいときは :ui[menu.help > help.whatsNew] を選びます。:ui[menu.help > help.releaseNotes] は GitHub のリリースページを開きます。

## 表示言語を選ぶ {#language}

Spooky は英語、簡体字中国語、繁体字中国語、日本語、韓国語、ドイツ語、フランス語、スペイン語に対応しています。表示言語は macOS で設定した言語の優先順序に従います。対応する言語が 1 つもないときは英語になります。

Spooky だけ別の言語にするには、次のようにします。

1. **アップルメニュー › システム設定** と選択し、サイドバーで **一般** をクリックします。
2. **言語と地域** をクリックし、**アプリケーション** に移動します。
3. **追加** ボタンをクリックし、Spooky と言語を選んで、**追加** をクリックします。
4. Spooky が開いている場合は、終了してからもう一度開きます。

システムの言語に戻すには、同じ一覧で Spooky を選択して **削除** ボタンをクリックします。

## アンインストール {#uninstall}

1. :ui[app.name > menu.quit]（<kbd>⌘Q</kbd>）で Spooky を終了します。
2. Spooky を **アプリケーション** フォルダから **ゴミ箱** に移動します。

設定とデータは Mac に残ります。これらも削除するには、次のようにします。

- 設定：**ターミナル** で `defaults delete com.rakuyo.spooky` を実行します。
- テーマやアクティビティの記録などのデータ：フォルダ `~/Library/Application Support/Spooky/` を削除します。
- キャッシュ：フォルダ `~/Library/Caches/com.rakuyo.spooky/` と、`~/Library/HTTPStorages/` の中で名前が `com.rakuyo.spooky` で始まる項目を削除します。
- Spooky が保存したパスワードとトークン：キーチェーンの中で名前が `com.rakuyo.spooky.` で始まる項目を削除します。
- 使用した各サーバー：そのサーバーのホームフォルダにあるフォルダ `~/.spooky/` を削除します。

リポジトリの Git 設定には、Spooky が追加した `branch.<name>.spooky-*` の項目が残ります。Spooky が何をどこに保存するかは [データとプライバシー](/reference/data-privacy/) にまとめてあります。

## 関連ページ

- [Spooky の画面構成](/guide/start/tour/)
- [システム要件](/reference/requirements/)
- [データとプライバシー](/reference/data-privacy/)

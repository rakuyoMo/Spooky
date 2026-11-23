---
title: "システム要件"
description: "Spooky が macOS、Git、サーバに求める条件を確認します。"
---

このページでは、Spooky が Mac と接続先のサーバで必要とするものをまとめます。

## Mac {#mac}

| 項目 | 要件 |
|---|---|
| macOS | macOS 26 以降 |
| Git | Git 2.41.0 以降。:ui[app.name > settings.title] › :ui[settings.gitConfig] の :ui[settings.gitProgram] の横で別のものを選ばない限り、Spooky は `/usr/bin/git` を使います。[Git プログラム](/guide/settings/identity/#git-program) を参照してください。 |
| SSH | macOS に付属する SSH。サーバリポジトリはこれで接続します。 |

Spooky はバージョン 2.41.0 で加わった Git の機能を使うので、それより古いバージョンでは動きません。

## サーバ {#servers}

サーバは Linux マシンでも Mac でもかまいません。Spooky はサーバの管理者権限を必要とせず、サービスもインストールしません。

| 項目 | 要件 |
|---|---|
| ログイン | 鍵を使った SSH ログイン。Mac の `~/.ssh/config` にあるホストエイリアスを通します。パスワードでしかログインできないアカウントは使えません。[SSH を準備する](/guide/server/prepare-ssh/) を参照してください。 |
| Git | Git 2.41.0 以降。非対話の SSH ログインが使う `PATH` にあること |
| SSH サーバ | SFTP がオンで、Unix ソケットの転送が許可されている OpenSSH。どちらもデフォルトでオンです。`MaxSessions` は 10 以上が必要で、これもデフォルトの値です。 |
| パスフレーズの入力 | OpenSSH 8.4 以降。サーバ上の Git が SSH 鍵のパスフレーズを必要とする場合 |
| Perl | `/usr/bin/perl` と、その標準モジュール `IO::Socket::UNIX`、`JSON::PP`、`POSIX`、`Fcntl` |
| ファイル | サーバのホームフォルダにある `~/.spooky/bin` と、`/tmp` への書き込み権限 |
| ゴミ箱 | 任意。Mac では、macOS 15 以降に付属する `/usr/bin/trash` を使います。Linux では、`gio` または `trash-put` を使います。どれもない場合、Spooky は先に確認してから、ファイルを完全に削除します。 |

リポジトリを追加する前にサーバの状態を確かめるには、[SSH を準備する](/guide/server/prepare-ssh/#test) のテストを実行します。:ui[app.name > settings.title] › :ui[settings.environment] でサーバを確認することもできます。[サーバを確認する](/guide/settings/general/#server-check) を参照してください。

## 任意 {#optional}

| 使うもの | 必要なもの |
|---|---|
| Git LFS | Git LFS 2.9.0 以降。リポジトリのあるマシンで、そこの Git が使う `PATH` にあること |
| sshfs マウント | Mac 上の sshfs と、macFUSE または FUSE-T |
| SMB マウント | サーバ上の SMB ファイル共有 |
| プルリクエストとマージリクエスト | github.com または GitLab.com のアカウント、あるいはセルフマネージドの GitLab 9.0 以降のアカウント |

## 関連ページ

- [Spooky をインストールする](/guide/start/install/)
- [サーバリポジトリの仕組み](/guide/server/overview/)
- [データとプライバシー](/reference/data-privacy/)

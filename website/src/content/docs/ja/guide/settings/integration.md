---
title: "連携"
description: "外部の比較ツールとマージツール、エディタ、ターミナルを選び、Finder との連携を設定します。"
---

Spooky は、Mac のほかのアプリケーションと連携します。ブラウザ、比較ツールとマージツール、エディタ、ターミナル、Finder です。このページでは、それぞれをどこで設定するかを説明します。

## 「連携」ページ {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration] には 3 つの設定があります。

### github.com からのリンク {#github-links}

github.com では、リポジトリをデスクトップアプリケーションで開くボタンが、Mac にリンクを送ります。どのアプリケーションが受け取るかは、:ui[settings.github] で決めます。メニューには、こうしたリンクを開ける Mac 上のアプリケーションが並びます。

Spooky を選ぶと、これらのリンクはクローンのダイアログを開きます。[リポジトリをクローンする](/guide/repositories/navigation/#link-clone) を参照してください。

### SSH エージェント {#ssh-agent}

SSH エージェントは、ロックを解除した鍵を保持します。Spooky は、SSH でサーバーやリモートにログインするときと、SSH 鍵でコミットに署名するときに使います。

:ui[settings.sshAgent] の選択肢は :ui[settings.sshAgent.system] の 1 つです。Spooky は次の順序でエージェントを探します。

1. :ui[settings.environment] ページで自分で追加した変数の `SSH_AUTH_SOCK`（[この Mac 上の変数](/guide/settings/general/#local-variables) を参照）
2. ログインシェルの `SSH_AUTH_SOCK`。そのページでログインシェルの読み取りがオンになっている場合
3. macOS が起動するエージェント

パスワードマネージャに付属するものなど、別のエージェントを使うには、:ui[settings.environment] ページかログインシェルで `SSH_AUTH_SOCK` を設定します。

エージェントが動いていないと、メニューの横に黄色の警告ボタンが表示されます。クリックすると、対処方法が表示されます。

:::note[サーバーリポジトリ]
Spooky がエージェントをサーバーに転送することはありません。サーバーの Git は、そのマシン自身のエージェントと鍵を使います。
:::

### クラッシュレポート {#crash-reports}

Spooky が前回予期せず終了したときは、次の起動時に、クラッシュを報告するかどうかを尋ねます。:ui[settings.crashReports.always] を選択すると、確認を省いてすぐに Issue ページを開きます。最初はオフです。

レポートに含まれる内容は [クラッシュレポート](/reference/data-privacy/#crash-reports) を参照してください。

## 比較ツールとマージツール {#diff-merge-tools}

ツールは :ui[settings.gitConfig] ページで設定します。

| 設定 | 内容 |
|---|---|
| :ui[externalTool.diffTool] | ファイルを比較するアプリケーション。最初は :ui[externalTool.noneSelected] です。 |
| :ui[externalTool.directoryDiff] | 複数のファイルを比較するとき、2 つのフォルダとして 1 つのウインドウで開きます。対応しているのは Kaleidoscope だけです。ほかのアプリケーションは、ファイルを 1 つずつ開きます。最初はオンです。 |
| :ui[externalTool.mergeTool] | 競合を解決するアプリケーション。最初は :ui[externalTool.noneSelected] です。 |
| :ui[externalTool.keepBackups] | マージ前のファイルを、末尾に `.orig` を付けて同じ場所に残します。最初はオフです。 |

Spooky は次のアプリケーションに対応しています。

| アプリケーション | 比較 | マージ |
|---|---|---|
| Araxis Merge | ○ | ○ |
| BBEdit | ○ | × |
| Beyond Compare | ○ | ○ |
| DeltaWalker | ○ | ○ |
| FileMerge | ○ | ○ |
| Kaleidoscope | ○ | ○ |
| P4Merge | ○ | ○ |
| TextMate | ○ | × |
| Visual Studio Code | ○ | ○ |

メニューには、インストールされていないアプリケーションも並びますが、選べません。ツールを選ぶ前に使おうとすると、どのアプリケーションを使うかを Spooky が尋ねます。

使い方は、[ほかのアプリケーションで比較する](/guide/work/diff/#external) と [ほかのアプリケーションでマージする](/guide/work/conflicts/#merge-tool) を参照してください。

## エディタ {#editors}

Spooky には、エディタを選ぶ独自の設定はありません。ファイルをほかのアプリケーションで開くには、作業コピーで右クリックして、:ui[files.open] または :ui[files.openWith] を選びます。:ui[files.openWith] サブメニューには、そのファイルを開けるアプリケーションが、デフォルトのものを先頭にして並びます。同じサブメニューは、コミットのファイルツリーと競合ウィザードにもあります。

サーバーリポジトリでは、Visual Studio Code、Visual Studio Code Insiders、Cursor は、Remote SSH 拡張機能がインストールされていれば、サーバー上のファイルを直接開きます。ほかのアプリケーションには、コピーが渡されます。保存すると、Spooky が変更をサーバーに書き戻します。[ターミナルとほかのアプリケーション](/guide/server/local-location/#terminal) を参照してください。

## ターミナル {#terminal}

:ui[settings.general] ページの :ui[settings.terminal] で、:ui[action.openTerminal] に使うアプリケーションを選びます。Spooky は、ターミナル、iTerm、Warp、Ghostty、WezTerm、Otty に対応しています。メニューには、インストールされているものが並びます。最初はターミナルが使われます。

:ui[action.openTerminal] は次の場所にあります。

- :ui[menu.file] メニュー
- ツールバーの :ui[toolbar.terminal]
- サイドバーの作業コピーのメニュー
- 作業コピーのファイル一覧にあるファイルまたはフォルダのメニュー。ターミナルは、そのフォルダ、またはファイルのあるフォルダで開きます。
- リポジトリウインドウのリポジトリのメニューと、最近のクローンのメニュー
- サイドバーのワークツリーのメニュー
- [クイックアクション](/guide/repositories/navigation/#quick-actions)

ローカルのリポジトリでは、ターミナルはこの Mac 上のフォルダで開きます。サーバーリポジトリでは、SSH でログインして、サーバー上のフォルダに移動します。[ターミナルとほかのアプリケーション](/guide/server/local-location/#terminal) を参照してください。

Spooky がターミナルまたは iTerm を初めて開くとき、macOS は Spooky による制御を許可するかどうかを尋ねます。許可しないと、Spooky は :ui[error.terminal] と表示します。あとで許可するには、**アップルメニュー › システム設定 › プライバシーとセキュリティ › オートメーション** と選択し、Spooky の下でそのアプリケーションをオンにします。

## Finder {#finder}

- **フォルダを表示する**：:ui[action.revealFinder] は、リポジトリのフォルダまたはファイルを Finder で表示します。サーバーリポジトリでは、この Mac 上の場所が必要です。[Finder で表示する](/guide/server/local-location/#show-in-finder) を参照してください。
- **リポジトリを追加する**：Finder からリポジトリのフォルダをリポジトリウインドウにドラッグします。[リポジトリを追加する](/guide/repositories/manager/#add) を参照してください。
- **Dock**：Spooky のアイコンにフォルダをドロップすると、そのフォルダがあるリポジトリが開きます。アイコンを右クリックすると、サーバーリポジトリも含めて、最近使ったリポジトリを選べます。[最近使ったリポジトリと Dock](/guide/repositories/navigation/#recent) を参照してください。
- **テーマ**：Finder で `.spookytheme` ファイルを開くと、テーマが追加されます。[テーマを共有する](/guide/settings/appearance/#share-themes) を参照してください。

## 関連ページ

- [一般、アップデート、環境](/guide/settings/general/)
- [ユーザプロファイルと Git 設定](/guide/settings/identity/)
- [この Mac 上の場所](/guide/server/local-location/)
- [SSH を準備する](/guide/server/prepare-ssh/)

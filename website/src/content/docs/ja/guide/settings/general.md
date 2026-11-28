---
title: "一般、アップデート、環境"
description: "設定ウインドウの構成と、「一般」「アップデート」「環境」ページのオプションを説明します。"
---

設定は Spooky 全体に適用されます。ほとんどの設定は、変更するとすぐに有効になります。保存ボタンはありません。

## 設定ウインドウ {#window}

:ui[app.name > settings.title]（<kbd>⌘,</kbd>）を選びます。ウインドウの上部にページが並び、タイトルには現在のページが表示されます。

| ページ | 設定する内容 | 説明 |
|---|---|---|
| :ui[settings.general] | クローン、バックグラウンドの操作、確認、履歴、ファイル一覧、ウインドウ | [一般](#general) |
| :ui[settings.appearance] | ライトまたはダーク、アプリケーションアイコン | [外観とテーマ](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | Git プログラム、グローバルの Git ユーザ情報、署名、外部の比較ツールとマージツール | [ユーザプロファイルと Git 設定](/guide/settings/identity/#git-config) |
| :ui[settings.text] | 差分とファイルでのシンタックスカラーリング、不可視文字、タブ幅 | [外観とテーマ](/guide/settings/appearance/#text) |
| :ui[settings.editor] | コミットメッセージのチェックと折り返しの方法 | [外観とテーマ](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | 差分とファイルの色とフォント | [外観とテーマ](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | コミット時に切り替えて使うユーザ情報 | [ユーザプロファイルと Git 設定](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | GitHub と GitLab のアカウント | [ホスティングアカウント](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | サーバのホストエイリアス。`~/.ssh/config` に保存されます | [SSH を準備する](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | github.com からのリンク、SSH エージェント、クラッシュレポート | [連携](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | この Mac 上の Git の環境変数、サーバの環境の確認 | [環境](#environment) |
| :ui[settings.updates] | Spooky のアップデート方法 | [アップデート](#updates) |

ユーザ情報や署名など、1 つのリポジトリだけの設定は、リポジトリのウインドウにあります。[リポジトリの設定](/guide/settings/identity/#repository) を参照してください。

## 一般 {#general}

:ui[settings.general] ページは長い一覧です。以下の各節は、上から下への順に並んでいます。

::screenshot[設定ウインドウの「一般」ページ。クローンの保存先、ターミナルアプリケーション、操作と確認のオプション、履歴と差分のオプション、ファイル一覧のオプションがあります。]{name="settings-general" frame="window"}

### クローンとターミナル {#cloning}

| 設定 | 内容 |
|---|---|
| :ui[settings.cloneDirectory] | クローンのダイアログが、新しいリポジトリの保存先として提示する場所。最初はホームフォルダです。`~/Development` があれば、メニューにも表示されます。別のフォルダを選ぶには、:ui[settings.cloneDirectory.select] を選びます。 |
| :ui[settings.terminal] | :ui[action.openTerminal] が使うアプリケーション。[ターミナル](/guide/settings/integration/#terminal) を参照してください。 |

### 操作 {#operations}

| 設定 | デフォルト | 内容 |
|---|---|---|
| :ui[settings.autoFetch] | 30 分ごと | Spooky がバックグラウンドでフェッチする頻度。[自動でフェッチする](/guide/branches/sync/#auto-fetch) を参照してください。 |
| :ui[stash.offerAutoStash] | オン | ローカルの変更が操作を妨げるとき、先にスタッシュするかどうかを尋ねます。[自動スタッシュ](/guide/work/stash/#auto-stash) を参照してください。 |
| :ui[settings.autoUpdateSubmodules] | オフ | サブモジュールのポインタを動かす操作のあと、チェックアウト済みのサブモジュールを確認なしで更新します。[ほかの操作のあとに更新する](/guide/advanced/submodules/#auto-update) を参照してください。 |
| :ui[branch.cleanNames] | オン | ブランチ、タグ、リモートの名前を、入力中に Git で使える形に直します。[ブランチを作成する](/guide/branches/branches/#create) を参照してください。 |
| :ui[settings.autoArchive] | オフ | 作業が終わったと思われるブランチをアーカイブします。[自動でアーカイブする](/guide/branches/review/#auto-archive) を参照してください。 |

### 確認 {#confirmations}

これらの確認には、それぞれ :ui[dialog.doNotAskAgain] があります。そこで選択すると、ここの対応する設定がオフになります。もう一度確認を表示するには、設定をオンに戻します。4 つとも最初はオンです。

| 設定 | 確認するタイミング |
|---|---|
| :ui[settings.warnDiscardingChunks] | ブロックまたは行を破棄する前。どのリポジトリでも同じです。[変更を破棄する](/guide/work/diff/#discard) を参照してください。 |
| :ui[settings.warnDiscardingOnServer] | サーバリポジトリでファイル全体を破棄する前 |
| :ui[settings.warnDeletingOnServer] | ゴミ箱のないサーバでファイルを完全に削除する前 |
| :ui[settings.warnRestoringOnServer] | サーバリポジトリでリビジョンからファイルを復元する前。[リビジョンからファイルを復元する](/guide/history/file-views/#restore) を参照してください。 |

ローカルのリポジトリでは、ファイル全体を破棄するときは必ず確認します。

### 履歴と差分 {#history}

| 設定 | デフォルト | 内容 |
|---|---|---|
| :ui[history.pageSize] | 100 | 履歴が一度に読み込むコミットの数：100、200、500、1,000 のいずれか |
| :ui[settings.dateFormat] | 絶対 | 絶対日付は、2026/10/26 のような短い形式です。相対日付は、今日と昨日を「今日」「昨日」と表示し、それ以外の日付は省略せずに表示します。メニューにそれぞれの例が表示されます。 |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | マージコミットの変更セットに表示する内容。[変更セット](/guide/history/commit-details/#changeset) を参照してください。 |
| :ui[working.diffThreshold] | 20,000 | このキロバイト数より大きい差分は、表示する前に確認します。値を選ぶか、入力します。[差分を読む](/guide/work/diff/#read) を参照してください。 |

日付形式は、履歴、スタッシュ、ファイル履歴、Reflog に適用されます。

### ファイル一覧 {#file-list}

| 設定 | デフォルト | 内容 |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | または比較ツールでファイルを開きます |
| :ui[files.openSubmodules] | オン | サブモジュールをダブルクリックすると、ほかのアプリケーションではなく Spooky で開きます |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | またはクイックルックでファイルを表示します |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | または :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | または長い名前の中央を省略します |

作業コピーでの動作は [ファイル一覧の設定](/guide/work/working-copy/#settings) を参照してください。

### ウインドウとリポジトリ一覧 {#windows}

| 設定 | デフォルト | 内容 |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | Spooky の起動時に開き直すもの。[前回の続きから始める](/guide/repositories/navigation/#restore) を参照してください。 |
| :ui[settings.showLaunchWindow] | オフ | Spooky の起動時に、最近使ったリポジトリのウインドウを表示します |
| :ui[settings.showWorktreesInRepositoryList] | オフ | 「リポジトリ」の一覧に、各リポジトリのワークツリーを表示します |
| :ui[settings.showHostAliasesInRepositoryList] | オン | 「リポジトリ」の一覧に、各サーバリポジトリのホストエイリアスを表示します |
| :ui[settings.showDeveloperMenu] | オフ | :ui[menu.developer] メニューを追加します。Spooky 自体をテストするためのツールが入っています |

## アップデート {#updates}

:ui[settings.updates] ページでは、リリースチャンネル、Spooky が自分でアップデートを確認してダウンロードするかどうか、確認の頻度を設定します。各オプションは [Spooky を最新の状態に保つ](/guide/start/install/#updates) で説明しています。

## 環境 {#environment}

Finder や Dock から開いたアプリケーションには、ターミナルと同じ環境が渡されません。たとえば、`PATH` に `/opt/homebrew/bin` のようなフォルダが入っていないことがあります。そうなると、Git フック、認証情報ヘルパー、Git LFS が見つからないことがあります。:ui[settings.environment] ページで、この Mac 上の Git についてこれを直せます。

### この Mac 上の変数 {#local-variables}

| 設定 | 内容 |
|---|---|
| :ui[settings.environment.loginShell] | ログインシェルを一度起動し、起動ファイルが設定する変数を読み取って、Git とツールバーボタンのスクリプトに渡します。下の表に、読み取った内容が表示されます。最初はオンです。 |
| :ui[settings.environment.custom] | 自分で追加する変数。追加ボタンで追加し、削除ボタンで選択した変数を削除します。ログインシェルの変数より優先されます。 |

知っておくとよい点がいくつかあります。

- 変更は次の Git コマンドから適用されます。Spooky を再起動する必要はありません。
- ログインシェルは、Spooky を起動するたびに読み取り直されます。読み取りに失敗すると、ページにその旨が表示されます。
- 2 つのカスタム変数が同じ名前のときは、下にあるほうが使われます。名前が正しくない変数は、表には残りますが、Git には渡されません。
- システムのエージェント以外の SSH エージェントを使うには、ここかログインシェルで `SSH_AUTH_SOCK` を設定します。[SSH エージェント](/guide/settings/integration/#ssh-agent) を参照してください。

:::note[サーバリポジトリ]
これらの変数は、この Mac 上の Git とツールバーボタンのスクリプトにだけ適用されます。サーバの Git は、サーバ自身の環境を使います。
:::

### サーバを確認する {#server-check}

ページの下部では、リポジトリを追加せずに、サーバで Git に渡される環境を確認できます。

1. :ui[remote.host] フィールドにホストエイリアスを入力します。:ui[settings.environment.server.hosts] メニューから選ぶこともできます。メニューには、サーバリポジトリのサーバが並びます。
2. :ui[settings.environment.server.check] をクリックします。

::screenshot[設定の「環境」ページ下部にあるサーバの確認。ホストエイリアスを確認した結果として、サーバで見つかった Git とそのバージョンが表示されています。]{name="settings-environment" frame="closeup"}

結果には、SSH でログインしたときに見つかる Git とそのバージョン、または :ui[settings.environment.server.noGit] が表示されます。その下に、`PATH` の各フォルダと、名前が `GIT_` で始まる変数の名前が並びます。Git が見つからないときは、[サーバで Git が見つからない](/reference/troubleshooting/#server-path) を参照してください。

## 関連ページ

- [外観とテーマ](/guide/settings/appearance/)
- [ユーザプロファイルと Git 設定](/guide/settings/identity/)
- [連携](/guide/settings/integration/)
- [Spooky をインストールする](/guide/start/install/)

---
title: "変更をコミットする"
description: "コミットの件名と説明の書き方、自動補完の使い方、直前のコミットの修正、コミットに使う ID と署名の選び方を説明します。"
---

コミットは、ステージ済みの変更をメッセージと一緒にリポジトリの履歴に保存します。まず [変更を確認してステージする](/guide/work/diff/) の手順で変更をステージします。次に、作業コピーの上部にあるコミットエリアでメッセージを書きます。

## メッセージを書く {#write}

メッセージは 2 つの部分に分かれています。

- :ui[working.subject] は、変更を要約する短い 1 行です。<kbd>Return</kbd> または <kbd>Tab</kbd> を押すと、説明に移動します。
- :ui[working.body] は省略できます。何を、なぜ変更したかを説明するのに使います。

::screenshot[展開した状態のコミットエリア。件名は Add a units toggle で、その下に 2 行の説明があります。説明欄の下端にはピンのボタンと折り返しのボタンがあります。その下に「直前のコミットを修正」と「サインオフ」のチェックボックスがあり、右側に作成者の名前、メールアドレス、画像が表示されています。一番下に「すべてステージ」ボタンと「コミット」ボタンがあります。]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. ピンのボタンと折り返しのボタン
3. 作成者の画像

コミットエリアは、どちらかの欄に入力している間は展開され、説明にテキストがある間は開いたままになります。常に開いておくには、説明欄の下端にあるピンのボタンをクリックします。説明欄の下端をドラッグすると、高さを変えられます。

入力を始めると、件名の末尾の数字が残りの文字数を示します。上限を超えた文字は強調表示されます。

説明欄の下端にあるもう 1 つのボタンで、2 種類の折り返しを切り替えます。

- :ui[editor.softWrap] は、欄の端で行を折り返します。
- :ui[editor.hardWrap] は、等幅フォントを使い、折り返しません。文字数の上限の位置にガイドが表示され、それより長い行は強調表示されます。現在の段落を上限の位置で改行するには、:ui[menu.edit > commit.reformatParagraph]（<kbd>⇧⌘W</kbd>）を選びます。

以下のオプションは :ui[app.name > settings.title] › :ui[settings.editor] にあります。

| 設定 | デフォルト |
|---|---|
| :ui[editor.showsCounter] | オン |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72。:ui[editor.hardWrap] を選んでいるときに変更できます。 |
| :ui[editor.showsGuide] | オン。:ui[editor.hardWrap] で使われます。 |
| :ui[editor.warnsComments] | オン。[メッセージ内のコメント](#comments) を参照してください。 |
| :ui[editor.stripsComments] | オフ。警告がオフのときに使えます。 |
| :ui[editor.completesIssues] | オン。[自動補完](#autocomplete) を参照してください。 |

[エディタ](/guide/settings/appearance/#editor) を参照してください。

## コミットする {#commit}

メッセージが書けたら、:ui[working.commit] をクリックするか、メッセージの入力中に <kbd>⌘↩</kbd> を押します。件名にテキストがあり、ステージ済みの変更があるときだけ、ボタンが使えるようになります。

ウインドウのどこからでも件名に移動するには、:ui[workspace.title > working.commitMenu]（<kbd>⇧⌘C</kbd>）を選びます。

説明欄の下にある 2 つのチェックボックスで、コミットのしかたを変えられます。

- :ui[commit.signOff] は、名前とメールアドレスの入った `Signed-off-by` 行をメッセージの末尾に追加します。チェックボックスの状態は、すべてのリポジトリでそのまま保たれます。
- :ui[commit.skipHooks] は、リポジトリの `pre-commit` フックと `commit-msg` フックを実行せずにコミットします。リポジトリにこれらのフックがあるときだけ表示され、コミットのたびにオフに戻ります。

コミットに失敗しても、メッセージはコミットエリアに残ります。作成したばかりのコミットを取り消すには、:ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）を選びます。[取り消しと復元](/guide/work/undo/) を参照してください。

### メッセージ内のコメント {#comments}

別のコメント文字を設定していない限り、Git では `#` で始まる行はコメントとして扱われます。Spooky はメッセージを書いたとおりにコミットするため、そのような行があるときは先に確認を求めます：:ui[commit.comments]

- :ui[commit.removeComments] は、それらの行を除いてコミットします。
- :ui[commit.keepComments] は、そのままコミットします。

:ui[commit.doNotAskAgain] を選択すると、次回以降もその選択が使われます。もう一度確認されるようにするには、:ui[app.name > settings.title] › :ui[settings.editor] で :ui[editor.warnsComments] をオンにします。[エディタ](/guide/settings/appearance/#editor) を参照してください。

メッセージがコメントだけの場合、Spooky は :ui[commit.commentsOnly] と尋ねます。それでもコミットするには、:ui[commit.keepCommentsAndCommit] をクリックします。

## 自動補完 {#autocomplete}

件名または説明に次のいずれかを入力すると、入力に合わせて候補が表示されます。

| 入力 | 挿入されるもの |
|---|---|
| `c:` | 直近 100 件のコミットのうち 1 件の短いハッシュ。ハッシュ、件名、作成者の一部を入力します。 |
| `\` | ステージ済みのファイルのパス |
| `#` | GitHub または GitLab のオープン中の Issue の番号 |
| 件名の先頭の `fixup!` または `squash!` | 以前のコミットの件名。このコミットをその修正としてマークします |

::screenshot[c: と入力したあとのコミットの件名。その下の一覧に最近のコミットが並び、それぞれに作成者、日付、短いハッシュ、件名が表示されています。最初の項目が選択されています。]{name="work-commit-completion" frame="closeup"}

<kbd>↑</kbd> または <kbd>↓</kbd> で候補を選び、<kbd>Return</kbd> で挿入し、<kbd>Esc</kbd> で一覧を閉じます。

Issue 番号の補完には、リポジトリのリモートに対応する [ホスティングアカウント](/guide/hosting/accounts/) が必要で、:ui[app.name > settings.title] › :ui[settings.editor] の :ui[editor.completesIssues] をオンにしておく必要があります。[エディタ](/guide/settings/appearance/#editor) を参照してください。`fixup!` または `squash!` を付けたコミットは、あとで対象のコミットにまとめられます。[履歴を書き換える](/guide/history/rewrite/) を参照してください。

## 直前のコミットを修正する {#amend}

修正すると、直前のコミットが新しいコミットに置き換わります。メッセージを直したり、入れ忘れた変更を追加したりするのに使います。

1. 説明欄の下にある :ui[working.amend] を選択します。Spooky が直前のコミットのメッセージを入力し、チェックボックスにそのコミットの短いハッシュが表示されます。
2. メッセージを編集し、入れたい変更をステージします。
3. :ui[working.amend] をクリックします。

チェックボックスの選択を解除すると、それまで書いていたメッセージに戻ります。

すばやく修正するには、どちらのメッセージ欄も編集していない状態で <kbd>⌥</kbd> を押したままにします。キーを放すまで、コミットエリアは直前のコミットを修正する状態に切り替わります。キーを押したまま :ui[working.amend] をクリックするか、<kbd>⌥⌘↩</kbd> を押します。コミットのメッセージはそのままで、ステージ済みの変更が取り込まれます。

:::caution
直前のコミットをすでにプッシュしている場合、修正するとリモート上のコミットと異なるものになります。その後にプッシュするには、強制プッシュが必要です。[強制プッシュ](/guide/branches/sync/#force-push) を参照してください。
:::

それより前のコミットを変更するには、[履歴を書き換える](/guide/history/rewrite/) を参照してください。

## コミットする人を選ぶ {#identity}

チェックボックスの右にある名前とメールアドレスは、コミットの作成者として記録されます。これらは Git の `user.name` と `user.email` の設定から取得されます。その横の画像は、メールアドレスをもとに検索されます。[データとプライバシー](/reference/data-privacy/) を参照してください。

仕事用のメールアドレスを使うなど、別の ID でコミットするには、ユーザプロファイルを使います。

1. 画像をクリックします。メニューにプロファイルが並び、使用中のものにチェックマークが付いています。
2. プロファイルを選びます。
3. Spooky が書き込もうとしている設定を確認し、:ui[profiles.apply.submit] をクリックします。

プロファイルの名前、メールアドレス、署名鍵は、このリポジトリ自体の Git 設定に書き込まれるため、ほかのリポジトリには影響しません。

現在の ID がまだプロファイルになっていない場合は、メニューに :ui[profiles.addCurrent]{1="alex@example.com"} が表示され、プロファイルとして保存できます。プロファイルを設定するには、同じメニューから :ui[profiles.manage] を選びます。[ユーザプロファイル](/guide/settings/identity/#profiles) を参照してください。

:::note[サーバリポジトリ]
プロファイルは、サーバ上のリポジトリの設定に書き込まれます。サーバ上の同じリポジトリでコミットするほかのツールも、この設定を使います。
:::

## コミットに署名する {#signing}

署名付きのコミットには、鍵の所有者が作成したことを示す証明が付きます。Spooky は SSH 鍵と OpenPGP 鍵に対応しています。

コミットエリアの画像にポインタを合わせると、次のコミットが署名されるかどうか、どの鍵で署名されるかを確認できます。

- **すべてのリポジトリ**：:ui[app.name > settings.title] › :ui[settings.gitConfig] で :ui[gitConfig.signCommits] をオンにし、:ui[gitConfig.signingKey] を選びます。[署名](/guide/settings/identity/#signing) を参照してください。
- **1 つのリポジトリ**：サイドバーの :ui[repositorySettings.title] をクリックします。:ui[repositorySettings.signing] で、:ui[repositorySettings.signCommits] と :ui[repositorySettings.signingKey] を設定します。[リポジトリの設定](/guide/settings/identity/#repository) を参照してください。

鍵にパスフレーズが必要な場合は、:ui[signing.unlock] ダイアログで入力を求められます。

## 関連ページ

- [変更を確認してステージする](/guide/work/diff/)
- [取り消しと復元](/guide/work/undo/)
- [ユーザプロファイルと Git 設定](/guide/settings/identity/)

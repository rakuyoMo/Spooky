---
title: "サブモジュール"
description: "サブモジュールを開く、更新する、フェッチする、初期化する、同期する、移動する、名前を変える、削除する方法を説明します。"
---

サブモジュールは、リポジトリのフォルダの中にある別の Git リポジトリです。リポジトリには、サブモジュールのどのコミットを使うかが記録されます。Spooky では、この記録をサブモジュールポインタと呼びます。

## サイドバーでの表示 {#sidebar}

サブモジュールは、サイドバーの :ui[submodule.group] の下にパスの順で並びます。ポインタを合わせると、名前と URL が表示されます。

- 淡く表示されている行は、まだチェックアウトされていないサブモジュールです。
- 警告アイコンは、設定が不完全であるか、URL の同期が必要であることを示します。
- 数字は、サブモジュール内で変更されたファイルの数です。
- ↑ と ↓ は、チェックアウトされているコミットがポインタよりどれだけ進んでいるか、遅れているかを示します。

サブモジュールをクリックすると、その詳細が表示されます。チェックアウト済みのサブモジュールをダブルクリックすると、同じウインドウでリポジトリとして開きます。開いている間は、ツールバーの :ui[toolbar.parentRepository] で元のリポジトリに戻れます。

作業コピーのファイル一覧でチェックアウト済みのサブモジュールをダブルクリックしても、同じように開きます。ほかのファイルと同じように開くようにするには、:ui[app.name > settings.title] › :ui[settings.general] で :ui[files.openSubmodules] をオフにします。[ファイル一覧](/guide/settings/general/#file-list) を参照してください。

## 詳細 {#details}

詳細には 3 つのページがあり、上部で切り替えます。

- :ui[submodule.page.general]：名前、パス、状態、ローカルの変更、チェックアウトされているコミット、ポインタ、有効になっている設定。サブモジュールが初期化されていない場合や、`.gitmodules` の URL が変更されている場合は、上部の注記に修正するためのボタンが表示されます。
- :ui[submodule.page.shared]：`.gitmodules` の設定。リポジトリをクローンする全員に適用されます。ここでの変更は作業コピーに表示されます。ほかの変更と同じようにコミットします。
- :ui[submodule.page.local]：このリポジトリ自体の設定にある設定。ここだけに適用されます。`.gitmodules` より優先されます。

2 つの設定ページでは、サブモジュールの名前の変更、移動、URL の変更と、3 つのオプションの設定ができます。:ui[submodule.useDefault] はオプションを取り除きます。その場合は Git のデフォルトが適用されます。

- :ui[submodule.field.fetchMode]：親リポジトリをフェッチするときに、このサブモジュールもフェッチするかどうか。:ui[submodule.fetchMode.always]、:ui[submodule.fetchMode.onDemand]（フェッチしたコミットがポインタを変更するときだけ。デフォルト）、:ui[submodule.fetchMode.never] から選びます。
- :ui[submodule.field.ignoreMode]：サブモジュール内のどの変更を、親の作業コピーが無視するか。:ui[submodule.ignoreMode.none]（デフォルト）、:ui[submodule.ignoreMode.untracked]、:ui[submodule.ignoreMode.dirty]（別のコミットがチェックアウトされている場合だけが変更として扱われます）、:ui[submodule.ignoreMode.all] から選びます。
- :ui[submodule.field.updateStrategy]：更新するときに、サブモジュールをどのようにポインタの位置に合わせるか。:ui[submodule.updateStrategy.checkout]（デフォルト）、現在のブランチへの :ui[submodule.updateStrategy.rebase] または :ui[submodule.updateStrategy.merge]、:ui[submodule.updateStrategy.none] から選びます。

## サブモジュールを追加する {#add}

1. メニューバーで :ui[menu.repository > menu.addSubmodule] を選びます。サイドバー下部にある追加ボタンをクリックするか、:ui[submodule.group] を右クリックして、メニューから :ui[submodule.add.menu] を選ぶこともできます。
2. サブモジュールのリポジトリの URL を入力します。
3. :ui[submodule.path] で :ui[submodule.path.select] を選び、リポジトリ内の空のフォルダを選びます。
4. :ui[submodule.add.submit] をクリックします。

以前に削除したサブモジュールなどで、同じ名前のサブモジュールの Git ディレクトリがすでにリポジトリにある場合、Spooky はどうするかを尋ねます。:ui[submodule.forceAdd.reuse] は、それを再利用します。:ui[submodule.forceAdd.overwrite] は、それを削除してクローンし直します。

## フェッチと更新 {#update}

- **フェッチ** は、サブモジュールのリモートから新しいコミットをダウンロードします。チェックアウトされている内容は変わりません。
- **更新** は、ポインタが記録しているコミットをチェックアウトします。初期化されていないサブモジュールは、先に初期化されます。

サブモジュールを右クリックして、メニューから :ui[submodule.fetch.menu]{1="vendor/charts"} または :ui[submodule.update.menu]{1="vendor/charts"} を選びます。:ui[menu.repository] メニューにも同じ項目があり、すべてのサブモジュールをまとめて処理する項目もあります。

ダイアログには次のオプションがあります。

- フェッチのときは :ui[sync.prune]
- 更新のときは :ui[submodule.update.recursive]。サブモジュールの中にあるサブモジュールも更新します。それらのリモートは、すでに設定済みの認証情報で使える必要があります。Spooky は途中で認証情報を尋ねることができません。

右クリックメニューで <kbd>⌥</kbd> を押したままにすると、:ui[submodule.quickFetch]{1="vendor/charts"} と :ui[submodule.quickUpdate]{1="vendor/charts"} が表示されます。ダイアログを表示せず、前回のオプションを使います。メニューバーの :ui[menu.fetchAllSubmodules] と :ui[menu.updateAllSubmodules] も同じです。

更新は、することがあるときだけ使えます。サブモジュールがチェックアウトされていないとき、または別のコミットがチェックアウトされているときです。

### ほかの操作のあとに更新する {#auto-update}

チェックアウト、プル、マージなどの操作によって、チェックアウト済みのサブモジュールのポインタが変わることがあります。その場合、Spooky は操作のあとで、それらのサブモジュールを更新するかどうかを尋ねます。:ui[submodule.autoUpdate.always] を選択すると、それ以降はすぐに更新されます。:ui[app.name > settings.title] › :ui[settings.general] の :ui[settings.autoUpdateSubmodules] で、オフに戻せます。[操作](/guide/settings/general/#operations) を参照してください。

### 初期化と同期 {#initialize}

- **初期化** は、サブモジュールの設定を `.gitmodules` からリポジトリの設定にコピーします。チェックアウトするには、そのあとで更新します。
- **同期** は、`.gitmodules` の URL が変更されたときに使います。リポジトリの設定と、サブモジュール自体のリポジトリにある URL を、新しい URL に合わせます。

どちらも右クリックメニューにあり、必要なときは :ui[submodule.page.general] ページの注記にも表示されます。

## 別のリビジョンをチェックアウトする {#checkout}

チェックアウト済みのサブモジュールを右クリックし、:ui[submodule.checkoutRevision] からサブモジュールのブランチまたはタグを選びます。現在のものにはチェックマークが付いています。

サブモジュール内の変更が妨げになる場合、チェックアウトは失敗します。Spooky は、それらをスタッシュするかどうかは尋ねません。リポジトリのスタッシュは、サブモジュールを対象にしません。

リポジトリのポインタは、サブモジュールの新しいコミットをコミットするまで動きません。

## 移動、名前の変更、削除 {#manage}

3 つとも右クリックメニューにあります。

- **移動** は、サブモジュールのパスを変更します。名前も新しいパスに変えるには、:ui[submodule.move.rename] を選択します。
- **名前の変更** は、サブモジュールの名前を変更します。`.gitmodules` とリポジトリの設定は、この名前でサブモジュールを参照します。フォルダはそのままの場所に残ります。
- **削除** は、サブモジュールをリポジトリから取り除きます。設定だけを削除してファイルを残すには、:ui[submodule.delete.keepWorkingTree] を選択します。サブモジュール内に変更がある場合、Spooky は確認を求め、:ui[submodule.forceDelete.submit] でそのまま削除できます。

これらの操作は、`.gitmodules` とリポジトリのインデックスを変更します。ほかの人にも反映されるように、コミットします。

削除したあとも、サブモジュールの Git ディレクトリはリポジトリの `.git` フォルダの中に残ります。もう一度追加するときに再利用できます。

### サブモジュールを修復する {#repair}

サブモジュールの設定が不完全な場合、その詳細には :ui[submodule.invalid] と表示され、2 つのボタンがあります。:ui[submodule.repair.submit] は、欠けているものを復元します。`.gitmodules` のエントリ、ポインタ、またはチェックアウトされたリポジトリです。Spooky がサブモジュールの URL をどこにも見つけられない場合は、削除してから追加し直します。

## 取り消し {#undo}

サブモジュールの追加、移動、名前の変更、削除、サブモジュール内での別のリビジョンのチェックアウト、URL やオプションの変更は取り消せます。[取り消しと復元](/guide/work/undo/) を参照してください。

初期化、同期、修復は取り消せません。いずれかを行うと、それより前の操作も取り消せなくなります。

フェッチと更新は、リポジトリのフェッチやプルと同じく記録されません。それより前の操作は、引き続き取り消せます。

:::note[サーバリポジトリ]
これらはすべてサーバ上で実行されます。サブモジュールを追加するときは、サーバ上のフォルダを選びます。
:::

## 関連ページ

- [フェッチ、プル、プッシュ](/guide/branches/sync/)
- [ワークツリー](/guide/advanced/worktrees/)
- [取り消しと復元](/guide/work/undo/)
